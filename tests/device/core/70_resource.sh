# Resource checks: memory, /tmp, load, iCamera_app restarts, kernel errors and logrotate. Read only.
# 資源の確認: メモリ、/tmp、負荷、iCamera_app の再起動、カーネルのエラー、logrotate（読み出しのみ）

res=$(remote 'free; echo ---; df /tmp | tail -1; echo ---; cat /proc/loadavg; echo ---
  cat /proc/uptime; p=$(pidof iCamera_app); [ -n "$p" ] && cut -d" " -f22 /proc/$p/stat; echo ---
  dmesg; echo ---
  a=$(crontab -l | sed -n "s|^\*/15 \* \* \* \* /usr/sbin/logrotate ||p")
  /usr/sbin/logrotate -d ${a:-/etc/logrotate.conf} 2>&1 | grep "^error"')
part() { echo "$res" | awk -v n=$1 '/^---$/ { s++; next; } s == n'; }

# --- memory ---
# free memory including buffers and cache
avail=$(part 0 | awk '/buffers\/cache/ { print $4 }')
if [ -n "$avail" ] && [ "$avail" -ge 10240 ]; then
  pass "memory: available ${avail}KB"
else
  fail "memory: available" "${avail:-?}KB (less than 10MB)"
fi
set -- $(part 0 | awk '/^Swap:/ { print $2, $3 }')
if [ -n "$1" ] && [ "$1" -gt 0 ] && [ $(($2 * 100 / $1)) -lt 50 ]; then
  pass "memory: swap used ${2}KB / ${1}KB"
else
  fail "memory: swap used" "${2:-?}KB / ${1:-?}KB"
fi

# --- /tmp (tmpfs in RAM) ---
use=$(part 1 | awk '{ sub(/%/, "", $5); print $5 }')
if [ -n "$use" ] && [ "$use" -lt 80 ]; then
  pass "tmp: ${use}% used"
else
  fail "tmp: used" "$(part 1)"
fi

# --- load ---
load=$(part 2 | cut -d' ' -f1-3)
if [ -n "$load" ] && [ "${load%%.*}" -lt 8 ]; then
  pass "load average: $load"
else
  fail "load average" "${load:-?}"
fi

# --- iCamera_app: started at boot and not restarted (a restart is usually a crash) ---
set -- $(part 3) # uptime idle starttime
up=${1%.*}
started=$((${3:-0} / 100)) # clock ticks (100/s) after boot
if [ -z "$3" ]; then
  fail "iCamera_app: not restarted" "not running"
elif [ $started -le 180 ]; then
  pass "iCamera_app: not restarted (started ${started}s after boot, up ${up}s)"
else
  fail "iCamera_app: not restarted" "started ${started}s after boot ($(((up - started) / 60)) minutes ago)"
fi

# --- kernel errors ---
kerr=$(part 4 | grep -iE '\<(oops|segfault)\>|unable to handle|kernel panic|out of memory|oom-killer|exception')
if [ -z "$kerr" ]; then
  pass "kernel: no oops, segfault, OOM or exception in dmesg"
else
  fail "kernel: no oops, segfault, OOM or exception in dmesg" "$(echo "$kerr" | tail -3 | tr '\n' ';')"
fi

# --- logrotate (cron */15, run with the same options in debug mode) can rotate the logs ---
# In debug mode a log that needs rotating also reports the old rotated file it would remove
# as missing, so that error is ignored.
lerr=$(part 5 | grep -v 'error opening .*: No such file or directory')
if [ -z "$lerr" ]; then
  pass "logrotate: no error"
elif echo "$lerr" | grep -q 'error creating state file .*Read-only file system'; then
  fail_known "logrotate: no error" "$(echo "$lerr" | head -1)" \
    "the default state file is on the read-only rootfs"
else
  fail "logrotate: no error" "$(echo "$lerr" | head -3 | tr '\n' ';')"
fi
