# Disruptive checks (-d): change the camera state and restore it.
# The video and motor checks are skipped while a busy hook reports a recording.
# 停止を伴う確認（-d）: カメラの状態を変えて元に戻す。撮影中は映像とモーターの確認を飛ばす

[ $DISRUPTIVE = 1 ] || return 0

# --- lighttpd restart (the web UI is down for a moment) ---
remote '/scripts/lighttpd.sh restart > /dev/null 2>&1'
for i in 1 2 3 4 5 6 7 8 9 10; do
  code=$(http / -o /dev/null -w '%{http_code}')
  [ "$code" = 200 ] && break
  sleep 1
done
if [ "$code" = 200 ]; then
  pass "disruptive: lighttpd restart (web up after ${i}s)"
else
  fail "disruptive: lighttpd restart" "web status $code after 10s. restart: /scripts/lighttpd.sh restart"
fi

reason=$(busy | tr '\n' ',' | sed 's/,$//')

# --- video bri: set, read back and restore ---
if [ -n "$reason" ]; then
  skip "disruptive: video bri set and restore" "$reason"
else
  bri=$(remote '/scripts/cmd video bri' | tr -d '\0')
  if ! echo "$bri" | grep -qE '^[0-9]+$'; then
    fail "disruptive: video bri set and restore" "video bri: '$bri'"
  else
    t=$((bri >= 128 ? bri - 10 : bri + 10))
    res=$(remote "/scripts/cmd video bri $t > /dev/null; /scripts/cmd video bri; /scripts/cmd video bri $bri > /dev/null; /scripts/cmd video bri" | tr -d '\0')
    set -- $res
    if [ "$1" = "$t" ] && [ "$2" = "$bri" ]; then
      pass "disruptive: video bri set and restore ($bri -> $t -> $bri)"
    else
      fail "disruptive: video bri set and restore" "set $t read '$1', restore $bri read '$2'. restore: /scripts/cmd video bri $bri"
    fi
  fi
fi

# --- video flip: flip the image, read it back and restore ---
# Only the ISP flip of libcallback (the web UI's flip also writes verSwitch to the vendor config).
# On Swing, move reports the position in the flipped view (355 - pan, 180 - tilt) with the flip
# flags, so the position read while flipped must be the same unflipped position.
if [ -n "$reason" ]; then
  skip "disruptive: video flip set and restore" "$reason"
else
  flip=$(remote '/scripts/cmd video flip' | tr -d '\0')
  if ! echo "$flip" | grep -qxE 'normal|flip|mirror|flip_mirror'; then
    fail "disruptive: video flip set and restore" "video flip: '$flip'"
  else
    t=$([ "$flip" = normal ] && echo flip_mirror || echo normal)
    swing=$([ "$(ini_get PRODUCT_MODEL)" = ATOM_CAKP1JZJP ] && echo 1 || echo 0)
    # each answer ends with a newline (move with an empty line after it)
    res=$(remote "/scripts/cmd move; /scripts/cmd video flip $t; /scripts/cmd video flip
      /scripts/cmd move; /scripts/cmd video flip $flip; /scripts/cmd video flip" | tr -d '\0' | grep -v '^$')
    m0=$(echo "$res" | sed -n 1p) set1=$(echo "$res" | sed -n 2p) read1=$(echo "$res" | sed -n 3p)
    m1=$(echo "$res" | sed -n 4p) set2=$(echo "$res" | sed -n 5p) read2=$(echo "$res" | sed -n 6p)
    # move: unflip both positions with their own flags and compare
    pos=$(printf '%s\n%s\n' "$m0" "$m1" | awk -v swing=$swing '
      function unflip(p, t, h, v) { return sprintf("%.2f/%.2f", h ? 355 - p : p, v ? 180 - t : t); }
      NR == 1 { a = unflip($1, $2, $3, $4); h0 = $3; v0 = $4; }
      NR == 2 { b = unflip($1, $2, $3, $4); h1 = $3; v1 = $4; }
      END { if(!swing) print "ok"; else if(a == b && h0 != h1 && v0 != v1) print "ok " a; else print "ng"; }')
    if [ "$set1 $read1 $set2 $read2" = "ok $t ok $flip" ] && [ "${pos%% *}" = ok ]; then
      mv=${pos#ok}
      pass "disruptive: video flip set and restore ($flip -> $t -> $flip${mv:+, move unflipped$mv})"
    else
      fail "disruptive: video flip set and restore" "set $t: '$set1' read '$read1', restore $flip: '$set2' read '$read2', move '$m0' -> '$m1'. restore: /scripts/cmd video flip $flip"
    fi
  fi
fi

# --- center: show the center mark, read it back and restore ---
if [ -n "$reason" ]; then
  skip "disruptive: center mark set and restore" "$reason"
else
  center=$(remote '/scripts/cmd center' | tr -d '\0')
  if ! echo "$center" | grep -qxE 'on|off'; then
    fail "disruptive: center mark set and restore" "center: '$center'"
  else
    t=$([ "$center" = on ] && echo off || echo on)
    res=$(remote "/scripts/cmd center $t; /scripts/cmd center; /scripts/cmd center $center; /scripts/cmd center" | tr -d '\0')
    if [ "$(echo $res)" = "ok $t ok $center" ]; then
      pass "disruptive: center mark set and restore ($center -> $t -> $center)"
    else
      fail "disruptive: center mark set and restore" "'$(echo $res)'. restore: /scripts/cmd center $center"
    fi
  fi
fi

# --- property indicator: switch the status LED, read it back and restore ---
# The setting goes through the vendor app (the same path as the web UI). The LED does not
# affect the video, so this also runs while recording.
ind=$(remote '/scripts/cmd property indicator' | tr -d '\0')
if ! echo "$ind" | grep -qxE 'on|off'; then
  fail "disruptive: property indicator set and restore" "property indicator: '$ind'"
else
  t=$([ "$ind" = on ] && echo off || echo on)
  res=$(remote "/scripts/cmd property indicator $t; /scripts/cmd property indicator
    /scripts/cmd property indicator $ind; /scripts/cmd property indicator" | tr -d '\0')
  if [ "$(echo $res)" = "ok $t ok $ind" ]; then
    pass "disruptive: property indicator set and restore ($ind -> $t -> $ind)"
  else
    fail "disruptive: property indicator set and restore" "'$(echo $res)'. restore: /scripts/cmd property indicator $ind"
  fi
fi

# --- RTSP hooks: stream the sub video and its audio from a temporary v4l2rtspserver ---
# When RTSP is off, nothing reads the frames the video and audio hooks pass to v4l2loopback and
# the ALSA loopback. Start a server on another port the same way as rtspserver.sh, for the sub
# video only, and read a few seconds with ffprobe. v4l2loopback makes each buffer of a compressed
# format width x height x 4 bytes, two per channel (16.6 MB of kernel memory for 1080p): video0 and
# video2 together made a Swing swap heavily, and all three channels rebooted it.
rtsp_port=18554
if [ -n "$reason" ]; then
  skip "disruptive: RTSP hooks (video1 and audio1)" "$reason"
elif echo "$INI" | grep -qE '^RTSP_VIDEO[0-2]=on'; then
  skip "disruptive: RTSP hooks (video1 and audio1)" "RTSP is on (checked by stream: RTSP)"
elif ! command -v ffprobe > /dev/null; then
  skip "disruptive: RTSP hooks (video1 and audio1)" "ffprobe is not installed"
else
  st=$(remote '/scripts/cmd video 1; /scripts/cmd audio 1; pidof v4l2rtspserver' | tr -d '\0' | grep -v '^$')
  v1=$(echo "$st" | sed -n 1p) a1=$(echo "$st" | sed -n 2p) pid=$(echo "$st" | sed -n 3p)
  if [ -n "$pid" ] || ! echo "$v1 $a1" | grep -qxE '(on|off) (on|off)'; then
    fail "disruptive: RTSP hooks (video1 and audio1)" "video 1: '$v1', audio 1: '$a1', v4l2rtspserver: '$pid'"
  else
    remote "/scripts/cmd video 1 on; /scripts/cmd audio 1 on
      (/usr/bin/v4l2rtspserver -P $rtsp_port -C 1 -a S16_LE /dev/video1,hw:2,0@S16_BE > /dev/null 2>&1 &)" > /dev/null
    sleep 3
    res=$(timeout 20 ffprobe -v error -rtsp_transport tcp -read_intervals %+3 -count_packets \
      -show_entries stream=codec_type,codec_name,width,height,sample_rate,nb_read_packets -of csv=p=0 \
      "rtsp://$HOST:$rtsp_port/video1_unicast" 2>&1 | tr '\n' ' ')
    remote "killall v4l2rtspserver; sleep 1; /scripts/cmd video 1 $v1; /scripts/cmd audio 1 $a1" > /dev/null
    # video: codec,type,width,height,packets  audio: codec,type,rate,packets
    if echo "$res" | grep -qE '(h264|hevc),video,[0-9]+,[0-9]+,[1-9]' && echo "$res" | grep -qE 'pcm_s16be,audio,[0-9]+,[1-9]'; then
      pass "disruptive: RTSP hooks (video1 and audio1) ($res)"
    else
      fail "disruptive: RTSP hooks (video1 and audio1)" "ffprobe: ${res:-no response}. restore: killall v4l2rtspserver; /scripts/cmd video 1 $v1; /scripts/cmd audio 1 $a1"
    fi
  fi
fi

# --- motor (-m): move through the whole range and back to the original position ---
# Checks that move answers and reports the commanded position. 0, 355 and 180 are beyond the
# mechanical stops, so the step count is synced at the ends on the way. The position is the step
# count, not the view: the backlash (pan about 5 degrees) may shift the view after the return.
# Speed 5 (speed 9 loses steps). The angle is truncated to steps, so a read position is
# commanded with +0.01.
if [ "$(ini_get PRODUCT_MODEL)" != ATOM_CAKP1JZJP ]; then
  :
elif [ $MOTOR != 1 ]; then
  skip "disruptive: motor move through the range" "use -m to move the motor"
elif [ -n "$reason" ]; then
  skip "disruptive: motor move through the range" "$reason"
else
  set -- $(remote '/scripts/cmd move' | tr -d '\0')
  pan=$1 tilt=$2
  if ! echo "$pan $tilt" | grep -qE '^[0-9.]+ [0-9.]+$'; then
    fail "disruptive: motor move through the range" "move: '$*'"
  else
    back=$(awk -v p=$pan -v t=$tilt 'BEGIN { printf("%.2f %.2f", p + 0.01, t + 0.01) }')
    route=
    err=
    for to in "0 0" "0 90" "180 90" "355 90" "355 180" "0 0" "$back"; do
      res=$(remote "/scripts/cmd move $to 5 0" | tr -d '\0')
      set -- $to
      ok=$(echo "$res" | awk -v p=$1 -v t=$2 '{
        e1 = $1 - p; e2 = $2 - t; if(e1 < 0) e1 = -e1; if(e2 < 0) e2 = -e2;
        print ($1 ~ /^[0-9.]+$/ && e1 < 0.2 && e2 < 0.2) ? 1 : 0 }')
      route="$route -> $(echo "$res" | awk '{ printf("%.1f/%.1f", $1, $2) }')"
      [ "$ok" = 1 ] || { err="move $to: '$res'"; break; }
    done
    if [ -z "$err" ]; then
      pass "disruptive: motor move through the range ($pan/$tilt$route)"
    else
      fail "disruptive: motor move through the range" "$err. restore: /scripts/cmd move $back 5 0"
    fi
  fi
fi
