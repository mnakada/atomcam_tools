# Streaming and network storage checks: RTSP (v4l2rtspserver), go2rtc (HomeKit, RTMP, WebRTC),
# Samba and CIFS. Each is checked only when enabled in hack.ini. Read only.
# 配信とネットワークストレージの確認（hack.ini で有効なものだけ。読み出しのみ）

net=$(remote 'ps; echo ---; netstat -ltn 2> /dev/null; echo ---; mount')
part() { echo "$net" | awk -v n=$1 '/^---$/ { s++; next; } s == n'; }
ps_part=$(part 0)
listen_part=$(part 1)
mount_part=$(part 2)
running() { echo "$ps_part" | grep -v grep | grep -q "$1"; }
listening() { echo "$listen_part" | grep -qE "[:.]$1 .*LISTEN"; }

# --- RTSP ---
streams=
for n in 0 1 2; do
  [ "$(ini_get RTSP_VIDEO$n)" = on ] && streams="$streams video$n"
done
if [ -z "$streams" ]; then
  skip "stream: RTSP" "RTSP_VIDEO0-2 are not on"
else
  port=8554
  [ "$(ini_get RTSP_OVER_HTTP)" = on ] && port=8080
  if running v4l2rtspserver && listening $port; then
    pass "stream: v4l2rtspserver (port $port)"
  else
    fail "stream: v4l2rtspserver" "not running or not listening on $port"
  fi
  auth=
  [ "$(ini_get RTSP_AUTH)" = on ] && auth="$(ini_get RTSP_USER):$(ini_get RTSP_PASSWD)@"
  for s in $streams; do
    if ! command -v ffprobe > /dev/null; then
      skip "stream: RTSP $s" "ffprobe is not installed"
      continue
    fi
    res=$(timeout 20 ffprobe -v error -rtsp_transport tcp -show_entries stream=codec_type,codec_name,width,height \
      -of csv=p=0 "rtsp://$auth$HOST:$port/${s}_unicast" 2>&1 | tr '\n' ' ')
    # codec_name,codec_type,width,height (ffprobe prints them in its own order)
    if echo "$res" | grep -qE '(h264|hevc),video,[0-9]+,[0-9]+'; then
      pass "stream: RTSP $s ($res)"
    else
      fail "stream: RTSP $s" "ffprobe: ${res:-no response}"
    fi
  done
fi

# --- go2rtc (HomeKit, RTMP, WebRTC) ---
uses=
[ "$(ini_get HOMEKIT_ENABLE)" = on ] && uses="$uses HomeKit"
[ "$(ini_get RTMP_ENABLE)" = on ] && uses="$uses RTMP"
[ "$(ini_get WEBRTC_ENABLE)" = on ] && uses="$uses WebRTC"
if [ -z "$uses" ]; then
  skip "stream: go2rtc" "HOMEKIT_ENABLE, RTMP_ENABLE and WEBRTC_ENABLE are not on"
elif [ -z "$(ini_get HOMEKIT_SOURCE)" ]; then
  skip "stream: go2rtc" "HOMEKIT_SOURCE is empty, so rtspserver.sh does not start it"
elif running go2rtc; then
  pass "stream: go2rtc ($uses )"
  if [ "$(ini_get WEBRTC_ENABLE)" = on ]; then
    if listening 8555; then
      pass "stream: WebRTC (port 8555)"
    else
      fail "stream: WebRTC" "not listening on 8555"
    fi
  fi
else
  fail "stream: go2rtc" "not running ($uses )"
fi

# --- Samba (publish the SD card) ---
if [ "$(ini_get STORAGE_SDCARD_PUBLISH)" != on ]; then
  skip "storage: samba" "STORAGE_SDCARD_PUBLISH is not on"
elif running smbd && running nmbd && listening 445; then
  pass "storage: samba (smbd, nmbd, port 445)"
else
  fail "storage: samba" "smbd/nmbd not running or not listening on 445"
fi

# --- CIFS (record to a network share) ---
cifs=
for k in PERIODICREC_CIFS ALARMREC_CIFS TIMELAPSE_CIFS; do
  [ "$(ini_get $k)" = on ] && cifs="$cifs $k"
done
server=$(ini_get STORAGE_CIFSSERVER)
server=${server%/}
if [ -z "$cifs" ]; then
  skip "storage: CIFS" "PERIODICREC_CIFS, ALARMREC_CIFS and TIMELAPSE_CIFS are not on"
elif [ -z "$server" ]; then
  fail "storage: CIFS" "$cifs on but STORAGE_CIFSSERVER is empty"
elif echo "$mount_part" | grep -qF "$server"; then
  pass "storage: CIFS mounted ($server)"
else
  fail "storage: CIFS" "$server is not mounted"
fi
