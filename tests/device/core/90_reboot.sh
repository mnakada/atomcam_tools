# Reboot check (-R): reboot from the web UI path (cmd.cgi -> webcmd.sh), wait for the camera
# to come back, and run the basic, web, libcallback and cron checks again.
# Skipped while a busy hook reports a recording.
# 再起動の確認（-R）: Web 画面と同じ経路で再起動し、復帰後に基本・Web・libcallback・cron を再確認する

[ $REBOOT = 1 ] || return 0

reason=$(busy | tr '\n' ',' | sed 's/,$//')
if [ -n "$reason" ]; then
  skip "reboot: from cmd.cgi" "$reason"
  return 0
fi

boot_id=$(remote 'cat /proc/sys/kernel/random/boot_id')
res=$(http /cgi-bin/cmd.cgi -X POST -H 'Content-Type: application/json' -d '{"exec":"reboot"}')
if ! echo "$res" | grep -q '^reboot .*OK$'; then
  fail "reboot: from cmd.cgi" "response: '$res'"
  return 0
fi
t0=$(date +%s)

# down within 60s
down=
while [ $(($(date +%s) - t0)) -lt 60 ]; do
  ping -c 1 -W 1 "$HOST" > /dev/null 2>&1 || { down=$(($(date +%s) - t0)); break; }
  sleep 1
done
# up: ssh answers with a new boot_id, within 300s
up=
while [ $(($(date +%s) - t0)) -lt 300 ]; do
  id=$(remote 'cat /proc/sys/kernel/random/boot_id')
  [ -n "$id" ] && [ "$id" != "$boot_id" ] && { up=$(($(date +%s) - t0)); break; }
  sleep 5
done
if [ -z "$up" ]; then
  fail "reboot: from cmd.cgi" "${down:+down after ${down}s, }not back after 300s"
  abort "reboot"
fi
pass "reboot: from cmd.cgi (down after ${down:-?}s, ssh after ${up}s)"

# web and libcallback ready
ready=
while [ $(($(date +%s) - t0)) -lt 300 ]; do
  res=$(remote '/scripts/cmd audio' | tr -d '\0')
  if [ "$res" = on -o "$res" = off ] && [ "$(http / -o /dev/null -w '%{http_code}')" = 200 ]; then
    ready=$(($(date +%s) - t0))
    break
  fi
  sleep 5
done
if [ -n "$ready" ]; then
  pass "reboot: web and libcallback ready (${ready}s)"
else
  fail "reboot: web and libcallback ready" "not ready after 300s"
fi

echo "--- core after reboot ---"
for t in "$DIR"/core/[1-4]0_*.sh; do
  . "$t"
done
