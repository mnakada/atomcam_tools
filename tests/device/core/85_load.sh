# Load check (-L): stream the main video over RTSP and WebRTC, take a short timelapse while a
# WebRTC client watches, and record the memory and load of each phase. Takes about 3 minutes.
# When RTSP or WebRTC is off in hack.ini, a temporary v4l2rtspserver (port 18554) and go2rtc
# (ports 11984, 18555) are started the same way as rtspserver.sh and stopped afterwards.
# Only one 1080p stream: two of them make a Swing run out of memory (see 80_disruptive.sh).
# Skipped while a busy hook reports a recording.
# 負荷の確認（-L）: RTSP と WebRTC でメイン映像を配信し、WebRTC で見ながら短いタイムラプスを撮って、
# 区間ごとのメモリと負荷を記録する（約3分）

[ $LOAD = 1 ] || return 0

reason=$(busy | tr '\n' ',' | sed 's/,$//')
if [ -n "$reason" ]; then
  skip "load: RTSP, WebRTC and timelapse" "$reason"
  return 0
fi
if ! command -v ffprobe > /dev/null || ! python3 -c 'import aiortc' 2> /dev/null; then
  skip "load: RTSP, WebRTC and timelapse" "ffprobe and python3 aiortc are needed"
  return 0
fi

st=$(remote 'cat /proc/sys/kernel/random/boot_id; pidof iCamera_app')
boot_id=$(echo "$st" | sed -n 1p) app_pid=$(echo "$st" | sed -n 2p)
rtsp_pid=$(remote 'pidof v4l2rtspserver') go2rtc_pid=$(remote 'pidof go2rtc')
v0=$(remote '/scripts/cmd video 0' | tr -d '\0\n') a0=$(remote '/scripts/cmd audio 0' | tr -d '\0\n')

# RTSP: the running server when video0 is on in hack.ini, a temporary one otherwise
own_rtsp=0
if [ -n "$rtsp_pid" ] && [ "$(ini_get RTSP_VIDEO0)" = on ]; then
  port=8554
  [ "$(ini_get RTSP_OVER_HTTP)" = on ] && port=8080
  auth=
  [ "$(ini_get RTSP_AUTH)" = on ] && auth="$(ini_get RTSP_USER):$(ini_get RTSP_PASSWD)@"
  rtsp_url="rtsp://$auth$HOST:$port/video0_unicast"
  rtsp_local="rtsp://${auth}localhost:$port/video0_unicast"
elif [ -n "$rtsp_pid" ]; then
  skip "load: RTSP, WebRTC and timelapse" "v4l2rtspserver runs without video0"
  return 0
else
  own_rtsp=1
  rtsp_url="rtsp://$HOST:18554/video0_unicast"
  rtsp_local="rtsp://localhost:18554/video0_unicast"
fi
# WebRTC: the running go2rtc when WEBRTC_ENABLE is on, a temporary one otherwise
own_go2rtc=0
if [ -n "$go2rtc_pid" ] && [ "$(ini_get WEBRTC_ENABLE)" = on ]; then
  webrtc_url="http://$HOST:1984/api/webrtc?src=video0"
elif [ -n "$go2rtc_pid" ]; then
  skip "load: RTSP, WebRTC and timelapse" "go2rtc runs without WebRTC"
  return 0
else
  own_go2rtc=1
  webrtc_url="http://$HOST:11984/api/webrtc?src=video0"
fi
# timelapse: not when its end would post to the user's webhook or copy the file to the NAS
tl=1
[ -n "$(ini_get WEBHOOK_URL)" ] && [ "$(ini_get WEBHOOK_TIMELAPSE_FINISH)" = on ] && tl=0
[ "$(ini_get TIMELAPSE_CIFS)" = on ] && tl=0

# monitor: load, MemFree, SwapFree, VmallocUsed every second, and the phase marks
mon=/tmp/loadtest.log
remote "rm -f $mon; touch $mon.run; (while [ -f $mon.run ]; do echo \"\$(cut -d' ' -f1 /proc/loadavg) \$(awk '/^MemFree|^SwapFree|^VmallocUsed/ { printf(\"%s \", \$2) }' /proc/meminfo)\" >> $mon; sleep 1; done) > /dev/null 2>&1 &"
# remote_retry: ssh may not answer in time while the camera swaps; retry the steps that clean up
remote_retry() {
  local i out
  for i in 1 2 3 4 5 6; do
    out=$($SSH "$1" 2> /dev/null) && { printf '%s\n' "$out"; return 0; }
    sleep 5
  done
  return 1
}
phase() { remote_retry "echo '# $1' >> $mon" > /dev/null; }

phase base
sleep 10
phase servers
if [ $own_rtsp = 1 ]; then
  remote "/scripts/cmd video 0 on; /scripts/cmd audio 0 on
    (/usr/bin/v4l2rtspserver -P 18554 -C 1 -a S16_LE /dev/video0,hw:0,0@OPUS > /dev/null 2>&1 &)" > /dev/null
fi
if [ $own_go2rtc = 1 ]; then
  remote "printf 'api:\n    listen: \":11984\"\nrtsp:\n    listen: \"\"\nwebrtc:\n    listen: \":18555/tcp\"\nstreams:\n    video0:\n        - http://localhost/cgi-bin/get_jpeg.cgi\n        - $rtsp_local#video=copy#audio=copy\n' > /tmp/loadtest-go2rtc.yaml
    (/usr/bin/go2rtc -config /tmp/loadtest-go2rtc.yaml > /dev/null 2>&1 &)"
fi
sleep 15

phase rtsp
res=$(timeout 30 ffprobe -v error -rtsp_transport tcp -read_intervals %+10 -count_packets \
  -show_entries stream=codec_type,codec_name,width,height,sample_rate,nb_read_packets -of csv=p=0 "$rtsp_url" 2>&1 | tr '\n' ' ')
if echo "$res" | grep -qE '(h264|hevc),video,[0-9]+,[0-9]+,[1-9]'; then
  pass "load: RTSP video0 10s ($res)"
else
  fail "load: RTSP video0 10s" "ffprobe: ${res:-no response}"
fi

phase webrtc
res=$(timeout 60 python3 "$DIR/webrtc_recv.py" "$webrtc_url" 20 2>&1 | tail -1)
if echo "$res" | grep -qE '^video [1-9]'; then
  pass "load: WebRTC 20s ($res)"
else
  fail "load: WebRTC 20s" "webrtc_recv.py: ${res:-no response}"
fi

if [ $tl = 0 ]; then
  skip "load: timelapse while watching WebRTC" "its end would post to WEBHOOK_URL or copy to TIMELAPSE_CIFS"
else
  phase timelapse+webrtc
  # a new file name each time: libcallback closes the file named in .time_lapse.info first, so
  # reusing a name would close the new, empty file. The answer comes after the first frame.
  tl_file=/media/mmc/time_lapse/loadtest-$(date +%s).mp4
  tl_res=$(remote "mkdir -p ${tl_file%/*}; /scripts/cmd timelapse $tl_file 1 20 20" | tr -d '\0\n')
  res=$(timeout 60 python3 "$DIR/webrtc_recv.py" "$webrtc_url" 20 2>&1 | tail -1)
  # the timelapse ends after 20 frames, and timelapse.sh finish deletes the file unless
  # TIMELAPSE_SDCARD. Never delete the files while it records: libcallback retries forever.
  for i in $(seq 1 30); do
    remote '/scripts/cmd timelapse' | tr -d '\0' | grep -q 'not operating' && break
    sleep 2
  done
  [ $i = 30 ] && remote '/scripts/cmd timelapse stop' > /dev/null
  done_line=$(remote "grep -h '\\[timelapse\\] finish $tl_file' /media/mmc/tools.log | tail -1; rm -f ${tl_file%.mp4}.*" | tr -d '\0')
  if [ "$tl_res" = ok ] && echo "$done_line" | grep -q ' 20/20 ' && echo "$res" | grep -qE '^video [1-9]'; then
    pass "load: timelapse while watching WebRTC (20/20, $res)"
  else
    # libcallback ends the timelapse at start + 20 s, so a slow camera records fewer frames
    frames=$(echo "$done_line" | sed -ne 's|.* \([0-9]*\)/[0-9]* [0-9]*$|\1|p')
    fail "load: timelapse while watching WebRTC" "timelapse: '$tl_res', frames ${frames:-?} of 20 ('$done_line'), webrtc_recv.py: '$res'"
  fi
fi

phase stop
restore=
if [ $own_go2rtc = 1 ]; then
  remote_retry 'killall go2rtc; rm -f /tmp/loadtest-go2rtc.yaml; true' > /dev/null
  restore="killall go2rtc; "
fi
if [ $own_rtsp = 1 ]; then
  remote_retry "killall v4l2rtspserver; sleep 1; /scripts/cmd video 0 $v0; /scripts/cmd audio 0 $a0" > /dev/null
  restore="${restore}killall v4l2rtspserver; /scripts/cmd video 0 $v0; /scripts/cmd audio 0 $a0"
fi
sleep 10
log=$(remote_retry "rm -f $mon.run; sleep 2; cat $mon; rm -f $mon") || restore="${restore:+$restore; }rm -f $mon $mon.run"

# the camera kept running: same boot and the same iCamera_app, and the temporary servers stopped
st=$(remote_retry 'cat /proc/sys/kernel/random/boot_id; pidof iCamera_app')
left=
[ $own_rtsp = 1 ] && [ -n "$(remote_retry 'pidof v4l2rtspserver; true')" ] && left="$left v4l2rtspserver"
[ $own_go2rtc = 1 ] && [ -n "$(remote_retry 'pidof go2rtc; true')" ] && left="$left go2rtc"
servers="RTSP $([ $own_rtsp = 1 ] && echo temporary || echo hack.ini), WebRTC $([ $own_go2rtc = 1 ] && echo temporary || echo hack.ini)"
if [ "$st" = "$boot_id"$'\n'"$app_pid" ] && [ -z "$left" ]; then
  pass "load: camera kept running ($servers)"
else
  fail "load: camera kept running" "boot_id/iCamera_app '$boot_id $app_pid' -> '$(echo $st)', still running:${left:- none}. restore: $restore"
fi

# memory and load of each phase (kB): MemFree and SwapFree at least, VmallocUsed and load at most
echo "$log" | awk '
  /^# / { p = $2; if(!(p in seen)) { seen[p] = 1; ord[++n] = p; } next; }
  NF == 4 && p != "" {
    if(!(p in ld) || $1 > ld[p]) ld[p] = $1;
    if(!(p in mf) || $2 < mf[p]) mf[p] = $2;
    if(!(p in sf) || $3 < sf[p]) sf[p] = $3;
    if(!(p in vm) || $4 > vm[p]) vm[p] = $4;
  }
  END {
    printf("     %-17s %6s %8s %9s %8s\n", "phase", "load", "MemFree", "SwapFree", "Vmalloc");
    for(i = 1; i <= n; i++) {
      p = ord[i];
      if(p in ld) printf("     %-17s %6s %8d %9d %8d\n", p, ld[p], mf[p], sf[p], vm[p]);
    }
  }'
