# libcallback checks: the read forms of the commands, and the settings applied at startup
# (set_icamera_config.sh). Read only.
# libcallback の確認: 読み出し形式のコマンドの応答と、起動時に反映された設定（読み出しのみ）

# cb_all : "command<TAB>response" for each read command, in one ssh session.
# Only the forms without a value: e.g. "video fps 10" sets the frame rate.
cb_all=$(remote 'for c in "audio" "audio vol" "video flip" "video fps" "video bitrate 0" "video bitrate 1" "video bitrate 3" \
    "video aeitmax" "video aemin" "video again" "video dgain" "video expr" \
    "property nightVision" "property recordType" "move" "center" "timelapse" \
    "mp4write" "skipRecJpeg" "curl upload" "alarm" \
    "video cont" "video bri" "video sat" "video sharp" "video dpc" "video drc" "video hilight" "video aecomp"; do
    printf "%s\t%s\n" "$c" "$(/scripts/cmd $c | tr -d "\0" | tr "\n" " " | sed "s/ *$//")"
  done')
cb() { echo "$cb_all" | awk -F'\t' -v c="$1" '$1 == c { print $2 }'; }

# cb_check COMMAND REGEX : the response matches REGEX
cb_check() {
  local res=$(cb "$1")
  if echo "$res" | grep -qE "^($2)\$"; then
    pass "libcallback: $1 ($res)"
  else
    fail "libcallback: $1" "response: '$res'"
  fi
}

NUM='[0-9]+'
cb_check "audio" "on|off"
cb_check "audio vol" "-?$NUM"
cb_check "video flip" "normal|flip|mirror|flip_mirror"
cb_check "video fps" "$NUM isp:$NUM/$NUM enc:$NUM/$NUM"
cb_check "video bitrate 0" "(auto )?$NUM"
cb_check "video bitrate 1" "(auto )?$NUM"
# ch3 is the HEVC main stream, not on WyzeCamV3
[ "$(ini_get PRODUCT_MODEL)" = WYZE_CAKP2JFUS ] || cb_check "video bitrate 3" "(auto )?$NUM"
cb_check "video aeitmax" "$NUM"
cb_check "video aemin" "$NUM $NUM $NUM $NUM"
cb_check "video again" "$NUM"
cb_check "video dgain" "$NUM"
cb_check "video expr" "(auto|manual) $NUM $NUM $NUM $NUM"
cb_check "property nightVision" "on|off|auto"
cb_check "property recordType" "cont|motion|off"
cb_check "center" "on|off"
cb_check "mp4write" "periodicRec: (sd|ram), alarmRec: (sd|ram)"
cb_check "skipRecJpeg" "on|off"
cb_check "curl upload" "enable|disable"
cb_check "alarm" "$NUM"
res=$(cb timelapse)
if [ -n "$res" ] && [ "$res" != error ]; then
  pass "libcallback: timelapse (${res:0:60})"
else
  fail "libcallback: timelapse" "response: '$res'"
fi

# property : all the items as "name = value" and "ok" (the mobile app settings in iCamera_app)
prop=$(remote '/scripts/cmd property' | tr -d '\0' | grep -vE '^ *(ok)? *$')
bad=$(echo "$prop" | grep -vE '^[A-Za-z]+ += .+$')
if [ -n "$prop" ] && [ -z "$bad" ] && echo "$prop" | grep -qE '^nightVision ' && echo "$prop" | grep -qE '^recordType '; then
  pass "libcallback: property ($(echo "$prop" | wc -l) items)"
else
  fail "libcallback: property" "unexpected: $(echo "${bad:-$prop}" | head -3 | tr '\n' ';')"
fi

# jpeg 1 : a JPEG of the sub stream (get_jpeg.cgi gives the main one)
j=$(remote '/scripts/cmd jpeg 1 -n' | od -An -v -tx1 | tr -d ' \n')
j=${j%00}
if [ "${j:0:4}" = ffd8 ] && [ "${j: -4}" = ffd9 ] && [ ${#j} -ge 10000 ]; then
  pass "libcallback: jpeg 1 ($((${#j} / 2))bytes)"
else
  fail "libcallback: jpeg 1" "$((${#j} / 2))bytes, head ${j:0:4} tail ${j: -4}"
fi

if [ "$(ini_get PRODUCT_MODEL)" = ATOM_CAKP1JZJP ]; then # ATOM Cam Swing
  cb_check "move" "[0-9.]+ [0-9.]+ [01] [01] [01]"
else
  skip "libcallback: move" "no motor"
fi

# --- settings applied by set_icamera_config.sh ---
# cb_expect NAME COMMAND EXPECTED
cb_expect() {
  if [ "$(cb "$2")" = "$3" ]; then
    pass "setting: $1 ($2 = $3)"
  else
    fail "setting: $1" "$2 = '$(cb "$2")', expected '$3'"
  fi
}

periodic=ram
alarm=ram
if [ "$(ini_get STORAGE_SDCARD_DIRECT_WRITE)" = on ]; then
  [ "$(ini_get PERIODICREC_SDCARD)" = on ] && periodic=sd
  [ "$(ini_get ALARMREC_SDCARD)" = on ] && alarm=sd
fi
cb_expect "STORAGE_SDCARD_DIRECT_WRITE" mp4write "periodicRec: $periodic, alarmRec: $alarm"
v=$(ini_get PERIODICREC_SKIP_JPEG)
[ -n "$v" ] && cb_expect "PERIODICREC_SKIP_JPEG" skipRecJpeg "$v"
[ "$(ini_get MINIMIZE_ALARM_CYCLE)" = on ] && cb_expect "MINIMIZE_ALARM_CYCLE" alarm 30
[ "$(ini_get AWS_VIDEO_DISABLE)" = on ] && cb_expect "AWS_VIDEO_DISABLE" "curl upload" disable
v=$(ini_get FRAMERATE)
if [ -n "$v" ] && [ "$v" -gt 0 ]; then
  res=$(cb "video fps")
  if [ "${res%% *}" = "$v" ]; then
    pass "setting: FRAMERATE (video fps = $v)"
  else
    fail "setting: FRAMERATE" "video fps = '$res', expected $v"
  fi
fi
v=$(ini_get BITRATE_MAIN_AVC)
[ -n "$v" ] && [ "$v" -gt 0 ] && cb_expect "BITRATE_MAIN_AVC" "video bitrate 0" "$v"

# video_isp.conf (saved by the video settings of the web UI).
# The values set by the commands in hack.ini at some time (e.g. "video cont 195") are not compared.
isp=$(http /cgi-bin/video_isp.cgi)
if [ -z "$isp" ]; then
  skip "setting: video_isp.conf" "not saved"
else
  timed=$(echo "$INI" | grep -oE 'video [a-z]+ ' | awk '{ print $2 }' | sort -u | tr '\n' ' ')
  differ= checked= ignored=
  for k in cont bri sat sharp dpc drc hilight aecomp; do
    v=$(echo "$isp" | sed -ne "s/^$k=//p")
    [ -z "$v" ] && continue
    case " $timed" in *" $k "*) ignored="$ignored $k"; continue ;; esac
    checked="$checked $k"
    [ "$(cb "video $k")" = "$v" ] || differ="$differ $k:$(cb "video $k")(conf $v)"
  done
  if [ -n "$differ" ]; then
    fail "setting: video_isp.conf" "differs:$differ"
  elif [ -n "$checked" ]; then
    pass "setting: video_isp.conf (${checked# }${ignored:+; not compared:$ignored})"
  else
    skip "setting: video_isp.conf" "all values are set at some time:$ignored"
  fi
fi

# --- libcallback startup (tools.log since iCamera_app started, i.e. since its last "iCamera_app address:") ---
# property.c finds functions of iCamera_app from its machine code, so a vendor firmware update can
# break it; the other hooks print an error only to the log. "jpeg err: save_jpeg(fd) failed" is
# not counted: it means the client closed the connection before the JPEG was sent.
boot=$(remote 'zcat /media/mmc/tools.log.1.gz 2> /dev/null; cat /media/mmc/tools.log' |
  awk '/^iCamera_app address:/ { b = ""; } { b = b $0 "\n"; } END { printf("%s", b); }')
if ! echo "$boot" | grep -q '^iCamera_app address:'; then
  skip "libcallback: startup" "no 'iCamera_app address:' in tools.log (rotated out?)"
else
  parse=$(echo "$boot" | sed -ne 's/^set_property_init: P2P_ReceiveProtocol_Parse: //p' | tail -1)
  setprop=$(echo "$boot" | sed -ne 's/^set_property_init: P2P_ReceiveProtocol_SetProperty: //p' | tail -1)
  if [ -n "$parse" ] && [ -n "$setprop" ]; then
    pass "libcallback: property hook found (P2P_ReceiveProtocol_Parse $parse, SetProperty $setprop)"
  else
    fail "libcallback: property hook found" "$(echo "$boot" | grep -E '^set_property_init:|^setItemProp:' | head -3 | tr '\n' ';')"
  fi
  errors=$(echo "$boot" | grep -E "^set_property_init: (not found|file can't open|/proc/pid/maps format error)|^setItemProp: not found|^watermark file .*error|^local_sdk_video_osd_set_logo_bitmap error|^sdkosd_update_logo_data error|^regionHandle[01] error|^IMP_OSD_SetRgnAttr[01] error|^failed to (allocate memory for|open) PCM|^\[command\] jpeg err|^\[timelapse\] error" |
    grep -v '^\[command\] jpeg err: save_jpeg([0-9]*) failed$')
  if [ -z "$errors" ]; then
    pass "libcallback: no startup or hook error in tools.log ($(echo "$boot" | grep -c .) lines since iCamera_app started)"
  else
    fail "libcallback: no startup or hook error in tools.log" "$(echo "$errors" | sort | uniq -c | head -5 | tr '\n' ';')"
  fi
fi
