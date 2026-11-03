# Web server checks: the CGIs used by the web UI and the SD card listing. Read only.
# Web サーバの確認: Web 画面が使う CGI と SD カードの一覧（読み出しのみ）

# --- hack_ini.cgi ---
missing=
for k in appver PRODUCT_MODEL HOSTNAME KERNELVER HWADDR; do
  [ -n "$(ini_get $k)" ] || missing="$missing $k"
done
if [ -z "$missing" ]; then
  pass "web: hack_ini.cgi device info ($(ini_get PRODUCT_MODEL) app $(ini_get appver))"
else
  fail "web: hack_ini.cgi device info" "missing:$missing"
fi

# --- get_jpeg.cgi ---
jpeg=$(mktemp)
res=$(http /cgi-bin/get_jpeg.cgi -o "$jpeg" -w '%{http_code} %{content_type} %{size_download}')
set -- $res
head=$(head -c 2 "$jpeg" | od -An -tx1 | tr -d ' ')
tail=$(tail -c 2 "$jpeg" | od -An -tx1 | tr -d ' ')
if [ "$1" = 200 ] && [ "$2" = image/jpeg ] && [ "$head" = ffd8 ] && [ "$tail" = ffd9 ] && [ "$3" -ge 10000 ]; then
  if command -v ffprobe > /dev/null; then
    size=$(ffprobe -v error -show_entries stream=width,height -of csv=p=0:s=x "$jpeg")
    pass "web: get_jpeg.cgi (${size:-?} ${3}bytes)"
  else
    pass "web: get_jpeg.cgi (${3}bytes)"
  fi
else
  fail "web: get_jpeg.cgi" "status:$1 type:$2 size:$3 head:$head tail:$tail"
fi
rm -f "$jpeg"

# --- cmd.cgi GET (name=status, name=media-size; latest-ver is not used: it accesses github) ---
status=$(http "/cgi-bin/cmd.cgi?name=status")
st_get() { echo "$status" | sed -ne "s/^$1=//p"; }
cam=$(date -d "$(st_get TIMESTAMP)" +%s 2> /dev/null)
now=$(date +%s)
if [ -n "$cam" ] && [ $((cam > now ? cam - now : now - cam)) -le 60 ]; then
  pass "web: cmd.cgi status TIMESTAMP"
else
  fail "web: cmd.cgi status TIMESTAMP" "TIMESTAMP=$(st_get TIMESTAMP)"
fi
center=$(st_get CENTER)
flip=$(st_get FLIP)
if echo "$center" | grep -qE '^(on|off)$' && [ -n "$flip" ] && [ "$flip" != error ] && echo "$status" | grep -q '^TIMELAPSE='; then
  pass "web: cmd.cgi status (CENTER=$center FLIP=$flip)"
else
  fail "web: cmd.cgi status" "$(echo "$status" | grep -E '^(CENTER|FLIP|TIMELAPSE)=' | tr '\n' ';')"
fi
pos=$(st_get MOTORPOS)
if [ -z "$pos" ]; then
  skip "web: cmd.cgi status MOTORPOS" "no motor"
elif echo "$pos" | grep -qE '^[0-9.]+ [0-9.]+ [01] [01]'; then
  pass "web: cmd.cgi status MOTORPOS ($pos)"
else
  fail "web: cmd.cgi status MOTORPOS" "MOTORPOS=$pos"
fi

set -- $(http "/cgi-bin/cmd.cgi?name=media-size" | sed -ne 's/^MEDIASIZE=//p')
if [ -n "$2" ] && [ "$2" -gt 0 ] && [ "$1" -le "$2" ]; then
  pass "web: cmd.cgi media-size (free $(($1 / 1024))MB / $(($2 / 1024))MB)"
else
  fail "web: cmd.cgi media-size" "MEDIASIZE=$*"
fi

# --- cmd.cgi POST: through webcmd.sh, and directly to libcallback (port=socket) ---
res=$(http /cgi-bin/cmd.cgi -X POST -H 'Content-Type: application/json' -d '{"exec":"update_status"}')
if echo "$res" | grep -qE '^update_status -?[0-9]+ OK$'; then
  pass "web: cmd.cgi POST to webcmd.sh ($res)"
else
  fail "web: cmd.cgi POST to webcmd.sh" "response: '$res'"
fi
res=$(http "/cgi-bin/cmd.cgi?port=socket" -X POST -H 'Content-Type: application/json' -d '{"exec":"audio"}' | tr -d '\0')
if [ "$res" = on -o "$res" = off ]; then
  pass "web: cmd.cgi POST to libcallback (audio $res)"
else
  fail "web: cmd.cgi POST to libcallback" "response: '$res'"
fi

# --- video_isp.cgi, watermark.cgi (GET returns the saved file, empty if not saved) ---
res=$(http /cgi-bin/video_isp.cgi -w '\n%{http_code}')
code=${res##*$'\n'}
body=${res%$'\n'*}
if [ "$code" != 200 ]; then
  fail "web: video_isp.cgi" "http status: $code"
elif [ -z "$body" ]; then
  pass "web: video_isp.cgi (not saved)"
elif echo "$body" | grep -q '^ver=' && ! echo "$body" | grep -vqE '^([A-Za-z0-9_]+=[^=]*)?$'; then
  pass "web: video_isp.cgi ($(echo "$body" | grep -c =) values)"
else
  fail "web: video_isp.cgi" "unexpected lines: $(echo "$body" | grep -vE '^([A-Za-z0-9_]+=[^=]*)?$' | head -3 | tr '\n' ';')"
fi
set -- $(http /cgi-bin/watermark.cgi -o /dev/null -w '%{http_code} %{size_download}')
if [ "$1" = 200 ]; then
  pass "web: watermark.cgi (${2}bytes)"
else
  fail "web: watermark.cgi" "http status: $1"
fi

# --- SD card listing ---
res=$(http /sdcard/ -w '\n%{http_code}')
if [ "${res##*$'\n'}" = 200 ] && echo "$res" | grep -q 'Index of /sdcard/'; then
  pass "web: /sdcard/ listing"
else
  fail "web: /sdcard/ listing" "http status: ${res##*$'\n'}"
fi
