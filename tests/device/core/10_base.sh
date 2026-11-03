# Basic checks: network, web, ssh, processes, cron, time, storage and memory.
# 基本確認: ネットワーク、Web、SSH、プロセス、cron、時刻、ストレージ、メモリ

# --- network / web ---
if ping -c 1 -W 2 "$HOST" > /dev/null 2>&1; then
  pass "ping"
else
  fail "ping" "$HOST is unreachable"
  abort "ping"
fi

res=$(http / -w '\n%{http_code}')
if [ "${res##*$'\n'}" = "200" ] && echo "$res" | grep -q "ATOMCam Hack Setup"; then
  pass "web: top page"
else
  fail "web: top page" "http status: ${res##*$'\n'}"
fi

load_ini
ver=$(ini_get ATOMHACKVER)
if [ -n "$ver" ]; then
  pass "web: hack_ini.cgi (atomcam_tools Ver.$ver)"
else
  fail "web: hack_ini.cgi" "ATOMHACKVER not found"
fi

# --- ssh ---
if [ "$(remote 'echo ok')" = "ok" ]; then
  pass "ssh login"
else
  fail "ssh login" "check SSH_AUTH_SOCK and the key (ssh-add -l)"
  abort "ssh"
fi

# --- processes ---
ps=$(remote 'ps')
for p in iCamera_app lighttpd sshd crond ntpd avahi-daemon webhook.sh webcmd.sh; do
  if echo "$ps" | grep -v grep | grep -q "$p"; then
    pass "process: $p"
  else
    fail "process: $p" "not running"
  fi
done

# Zombies appear transiently for a while after boot.
# Only those still present after ZOMBIE_WAIT seconds are reported as failures.
zombies=$(echo "$ps" | awk '$4 ~ /^Z/ { print $1 }')
if [ -z "$zombies" ]; then
  pass "no zombie process"
else
  sleep $ZOMBIE_WAIT
  persistent=$(remote "for p in $(echo $zombies); do
    grep -q '^State:.*Z' /proc/\$p/status 2> /dev/null || continue
    pp=\$(awk '/^PPid/ { print \$2 }' /proc/\$p/status)
    ppp=\$(awk '/^PPid/ { print \$2 }' /proc/\$pp/status)
    grep -q webhook.sh /proc/\$ppp/cmdline && tag=webhook || tag=
    echo \"\$tag \$p <- \$pp: \$(tr '\\0\\n' '  ' < /proc/\$pp/cmdline | cut -c1-80)\"
  done")
  # the awk in webhook.sh did not close the "hostname" pipe (issue #149)
  webhook=$(echo "$persistent" | sed -ne 's/^webhook //p')
  others=$(echo "$persistent" | sed -ne 's/^ //p')
  if [ -n "$others" ]; then
    fail "no zombie process" "$(echo "$others" | tr '\n' ';')"
  elif [ -n "$webhook" ]; then
    fail_known "no zombie process" "child of webhook.sh: $(echo "$webhook" | cut -d: -f1 | tr '\n' ';')" \
      "#149 webhook.sh does not close the hostname pipe"
  else
    pass "no zombie process ($(echo $zombies | wc -w) transient, gone after ${ZOMBIE_WAIT}s)"
  fi
fi

# --- libcallback ---
res=$(remote '/scripts/cmd audio' | tr -d '\0')
if [ "$res" = "on" -o "$res" = "off" ]; then
  pass "libcallback: /scripts/cmd responds"
else
  fail "libcallback: /scripts/cmd responds" "response: '$res'"
fi

# --- cron ---
cron=$(remote 'crontab -l')
if echo "$cron" | grep -q "/scripts/health_check.sh"; then
  pass "cron: health_check"
else
  fail "cron: health_check" "not in crontab"
fi

# --- time ---
cam=$(remote 'date +%s')
now=$(date +%s)
if [ -n "$cam" ] && [ $((cam > now ? cam - now : now - cam)) -le 60 ]; then
  pass "time: synchronized (diff $((cam - now))s)"
else
  fail "time: synchronized" "camera:${cam:-?} host:$now"
fi

# --- storage / memory ---
df=$(remote 'df /media/mmc | tail -1')
use=$(echo "$df" | awk '{ sub(/%/, "", $5); print $5 }')
if [ -n "$use" ] && [ "$use" -lt 95 ]; then
  pass "sdcard: mounted (${use}% used)"
else
  fail "sdcard: mounted" "df: $df"
fi
if remote 'touch /media/mmc/.smoke_test && rm /media/mmc/.smoke_test'; then
  pass "sdcard: writable"
else
  fail "sdcard: writable"
fi
# libcallback (mmc_mount.c) keeps iCamera_app from mounting the SD card again over the one mounted
# at boot; a mount point mounted twice breaks the file system. "/" is rootfs and the squashfs.
dup=$(remote 'cat /proc/mounts' | awk '$2 != "/" { print $2 }' | sort | uniq -d)
if [ -z "$dup" ]; then
  pass "sdcard: not mounted twice"
else
  fail "sdcard: not mounted twice" "mounted twice: $(echo $dup)"
fi

swap=$(remote 'free' | awk '/^Swap:/ { print $2 }')
if [ -n "$swap" ] && [ "$swap" -gt 0 ]; then
  pass "memory: swap enabled (${swap}KB)"
else
  fail "memory: swap enabled"
fi
