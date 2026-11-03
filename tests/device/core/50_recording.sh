# Recording checks.
# 録画の確認

# --- periodic recording ---
# A file is written for every minute: /media/mmc/record/YYYYMMDD/HH/MM.mp4
# PERIODICREC_SCHEDULE_LIST: [index_NN];Rule=<bit (1<<weekday), Mon=1..Sun=7>;ContinueTime=<min>;StartTime=<min>;...
# ContinueTime is negative when the period crosses midnight.
# Prints the minutes since the active period started and 1 if the period crosses midnight,
# or nothing outside the schedule.
schedule_elapsed() { # list weekday(1-7) minute-of-day
  echo "$1" | tr ';' '\n' | awk -F= -v w=$2 -v m=$3 '
    function on(d) { return int(rule / 2 ^ d) % 2; }
    $1 == "Rule" { rule = $2; }
    $1 == "ContinueTime" { cross = ($2 <= 0); len = cross ? $2 + 1440 : $2; }
    $1 == "StartTime" {
      if(on(w) && m >= $2 && m < $2 + len) { print m - $2, cross; exit; }
      if(on(w == 1 ? 7 : w - 1) && m + 1440 < $2 + len) { print m + 1440 - $2, cross; exit; }
    }'
}

if [ "$(ini_get PERIODICREC_SDCARD)" != "on" ]; then
  skip "recording: periodic recording to SD card" "PERIODICREC_SDCARD is not on"
else
  rec=$(remote 'cut -d. -f1 /proc/uptime
    date +"%u %H %M %S"
    f=$(ls -t $(find /media/mmc/record -name "*.mp4" -mmin -3) 2> /dev/null | sed -n 2p)
    echo "$f"
    [ -n "$f" ] && ls -l "$f" | awk "{ print \$5 }" && dd if="$f" bs=1 skip=4 count=4 2> /dev/null && echo
    find /media/mmc/record -name "*.mp4" -mmin -5 | wc -l')
  # seconds since recording should have started: since boot, or since the schedule period started
  started=$(echo "$rec" | sed -n 1p)
  reason="just booted"
  if [ "$(ini_get PERIODICREC_SCHEDULE)" = "on" ]; then
    read wday hour min sec <<< "$(echo "$rec" | sed -n 2p)"
    read elapsed cross <<< "$(schedule_elapsed "$(ini_get PERIODICREC_SCHEDULE_LIST)" $wday $((10#$hour * 60 + 10#$min)))"
    if [ -z "$elapsed" ]; then
      started=
    elif [ $((elapsed * 60 + 10#$sec)) -lt $started ]; then
      started=$((elapsed * 60 + 10#$sec))
      reason="schedule just started"
    fi
  fi
  file=$(echo "$rec" | sed -n 3p)
  if [ -z "$started" ]; then
    skip "recording: periodic recording to SD card" "outside PERIODICREC_SCHEDULE_LIST"
  elif [ -z "$file" ]; then
    if [ "$started" -lt 180 ]; then
      skip "recording: periodic recording to SD card" "$reason (${started}s)"
    else
      # The recordings in a period crossing midnight were deleted as outside the schedule (issue #155)
      if [ "$cross" = 1 ]; then
        fail_known "recording: periodic recording to SD card" "no mp4 file in the last 3 minutes" \
          "#155 a schedule crossing midnight is treated as outside the schedule"
      else
        fail "recording: periodic recording to SD card" "no mp4 file in the last 3 minutes"
      fi
    fi
  else
    size=$(echo "$rec" | sed -n 4p)
    type=$(echo "$rec" | sed -n 5p)
    count=$(echo "$rec" | sed -n 6p)
    if [ "$size" -ge 100000 ] && [ "$type" = "ftyp" ]; then
      pass "recording: periodic recording to SD card (${file#/media/mmc/record/} ${size}bytes)"
    else
      fail "recording: periodic recording to SD card" "$file size:$size type:$type"
    fi
    if [ "$started" -lt 360 ]; then
      skip "recording: no gap in the last 5 minutes" "$reason (${started}s)"
    elif [ "$count" -ge 4 ]; then
      pass "recording: no gap in the last 5 minutes ($count files)"
    else
      fail "recording: no gap in the last 5 minutes" "only $count files"
    fi
  fi
fi

# --- timelapse ---
# TIMELAPSE_SCHEDULE: <min> <hour> * * <weekdays 0-6 joined by :> /scripts/timelapse.sh start <interval> <count>;...
# While recording, libcallback writes <file>._mp4 and <file>.stsz every interval,
# and resumes after a reboot (S61atomcam).
# timelapse_window weekday(0-6) minute-of-day : the interval in seconds if a schedule should be recording now
timelapse_window() {
  echo "$(ini_get TIMELAPSE_SCHEDULE)" | tr ';' '\n' | awk -v w=$1 -v m=$2 '
    function on(days, d,   a, n, i) {
      n = split(days, a, ":");
      for(i = 1; i <= n; i++) if(a[i] == d) return 1;
      return 0;
    }
    $6 == "/scripts/timelapse.sh" && $7 == "start" {
      start = $2 * 60 + $1;
      len = $8 * $9 / 60;
      if((on($5, w) && m >= start && m < start + len) ||
         (on($5, (w + 6) % 7) && m + 1440 < start + len)) { print $8; exit; }
    }'
}

if [ "$(ini_get TIMELAPSE_SDCARD)" != on ] && [ "$(ini_get TIMELAPSE_CIFS)" != on ]; then
  skip "recording: timelapse" "TIMELAPSE_SDCARD and TIMELAPSE_CIFS are not on"
else
  tl=$(remote 'cut -d. -f1 /proc/uptime
    date +"%w %H %M %s"
    /scripts/cmd timelapse | tr -d "\0" | tr "\n" " "; echo
    f=$(/scripts/cmd timelapse | sed -ne "s/^file: \([^ ]*\)\.mp4 .*/\1/p")
    [ -n "$f" ] && date -r "$f.stsz" +%s
    echo')
  uptime=$(echo "$tl" | sed -n 1p)
  read wday hour min now <<< "$(echo "$tl" | sed -n 2p)"
  status=$(echo "$tl" | sed -n 3p)
  stsz=$(echo "$tl" | sed -n 4p)
  interval=$(timelapse_window $wday $((10#$hour * 60 + 10#$min)))
  if echo "$status" | grep -q '^file: '; then
    sec=$(echo "$status" | sed -ne 's/.*interval: \([0-9]*\)sec.*/\1/p')
    count=$(echo "$status" | sed -ne 's/.*count: \([0-9/]*\).*/\1/p')
    if [ -n "$stsz" ] && [ $((now - stsz)) -le $((sec + 30)) ]; then
      pass "recording: timelapse in progress ($count, last frame $((now - stsz))s ago)"
    elif [ "$uptime" -lt $((sec + 180)) ]; then
      skip "recording: timelapse in progress" "just booted (${uptime}s)"
    else
      fail "recording: timelapse in progress" "last frame ${stsz:+$((now - stsz))s ago}${stsz:-not found}, interval ${sec}s"
    fi
  elif [ -n "$interval" ]; then
    if [ "$uptime" -lt 180 ]; then
      skip "recording: timelapse in progress" "just booted (${uptime}s)"
    else
      fail "recording: timelapse in progress" "TIMELAPSE_SCHEDULE is active but: $status"
    fi
  else
    skip "recording: timelapse in progress" "outside TIMELAPSE_SCHEDULE"
  fi
fi
if [ "$(ini_get TIMELAPSE_SDCARD)" = on ]; then
  res=$(remote 'f=$(ls -t /media/mmc/time_lapse/*.mp4 2> /dev/null | head -1)
    [ -n "$f" ] && echo "$f $(ls -l "$f" | awk "{ print \$5 }") $(dd if="$f" bs=1 skip=4 count=4 2> /dev/null)"')
  set -- $res
  if [ -z "$1" ]; then
    skip "recording: timelapse mp4 on SD card" "no file yet"
  elif [ "$3" = ftyp ] && [ "$2" -gt 0 ]; then
    pass "recording: timelapse mp4 on SD card (${1#/media/mmc/} ${2}bytes)"
  else
    fail "recording: timelapse mp4 on SD card" "$1 size:$2 type:$3"
  fi
fi

# --- alarm recording (only the last file; a motion is not triggered) ---
if [ "$(ini_get ALARMREC_SDCARD)" != on ]; then
  skip "recording: alarm recording to SD card" "ALARMREC_SDCARD is not on"
else
  res=$(remote 'f=$(ls -t $(find /media/mmc/alarm_record -name "*.mp4" 2> /dev/null) 2> /dev/null | head -1)
    [ -n "$f" ] && echo "$f $(ls -l "$f" | awk "{ print \$5 }") $(dd if="$f" bs=1 skip=4 count=4 2> /dev/null)"')
  set -- $res
  if [ -z "$1" ]; then
    skip "recording: alarm recording to SD card" "no alarm recorded"
  elif [ "$3" = ftyp ] && [ "$2" -gt 0 ]; then
    pass "recording: alarm recording to SD card (last ${1#/media/mmc/alarm_record/} ${2}bytes)"
  else
    fail "recording: alarm recording to SD card" "$1 size:$2 type:$3"
  fi
fi
