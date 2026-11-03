# crontab checks: the lines set_crontab.sh makes from hack.ini are in the crontab. Read only.
# Extra lines are not checked.
# crontab の確認: set_crontab.sh が hack.ini から作る行が crontab にあるか（読み出しのみ）

cron=$(remote 'crontab -l')

# logrotate: -s STATEFILE is accepted, as the default state file is on the read-only rootfs
if echo "$cron" | grep -qxE '\*/15 \* \* \* \* /usr/sbin/logrotate (-s [^ ]+ )?/etc/logrotate.conf'; then
  pass "cron: logrotate"
else
  fail "cron: logrotate" "not in crontab: */15 * * * * /usr/sbin/logrotate [-s STATEFILE] /etc/logrotate.conf"
fi

# fixed lines
for l in "5 * * * * /scripts/remove_old.sh" \
         "10 * * * * /scripts/memory_check.sh" \
         "* * * * * /scripts/lighttpd.sh watchdog >> /media/mmc/atomhack.log" \
         "* * * * * /scripts/rtspserver.sh watchdog >> /media/mmc/atomhack.log" \
         "* * * * * /atom_patch/system_bin/mount_cifs.sh watchdog >> /media/mmc/atomhack.log"; do
  read -r -a w <<< "$l"
  name="cron: ${w[5]##*/}"
  [ "${w[6]}" = watchdog ] && name="$name watchdog"
  if echo "$cron" | grep -qxF "$l"; then
    pass "$name"
  else
    fail "$name" "not in crontab: $l"
  fi
done

# expected_lines : the lines from /media/mmc/crontab, REBOOT_SCHEDULE and TIMELAPSE_SCHEDULE
expected_lines() {
  remote 'cat /media/mmc/crontab 2> /dev/null'
  echo "$INI" | awk -F "=" '
    /^REBOOT_SCHEDULE *=/ {
      if($2 == "") next;
      gsub(/:/, ",", $2);
      printf("%s /scripts/reboot.sh\n", $2);
    }
    /^TIMELAPSE_SCHEDULE *=/ {
      n = split($2, schedule, ";");
      for(i = 1; i <= n; i++) {
        if(schedule[i] == "") continue;
        gsub(/:/, ",", schedule[i]);
        printf("%s %d\n", schedule[i], i);
      }
    }'
}
expected=$(expected_lines)
if [ -z "$expected" ]; then
  skip "cron: schedules from hack.ini" "no REBOOT_SCHEDULE, TIMELAPSE_SCHEDULE or /media/mmc/crontab"
else
  missing=$(echo "$expected" | while IFS= read -r l; do
    [ -z "$l" ] && continue
    echo "$cron" | grep -qxF "$l" || echo "$l"
  done)
  if [ -z "$missing" ]; then
    pass "cron: schedules from hack.ini ($(echo "$expected" | grep -c .) lines)"
  else
    fail "cron: schedules from hack.ini" "not in crontab: $(echo "$missing" | tr '\n' ';')"
  fi
fi
