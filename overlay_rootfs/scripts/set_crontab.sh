#!/bin/sh

HACK_INI=/tmp/hack.ini
/usr/bin/awk -F "=" '
BEGIN {
  printf("#  DO NOT EDIT THIS FILE\n");
  printf("*/15 * * * * /usr/sbin/logrotate /etc/logrotate.conf\n");
  printf("5 * * * * /scripts/remove_old.sh\n");
  printf("10 * * * * /scripts/memory_check.sh\n");
  printf("* * * * * /scripts/health_check.sh\n");
  printf("* * * * * /scripts/lighttpd.sh watchdog >> /media/mmc/atomhack.log\n");
  printf("* * * * * /scripts/rtspserver.sh watchdog >> /media/mmc/atomhack.log\n");
  printf("* * * * * /atom_patch/system_bin/mount_cifs.sh watchdog >> /media/mmc/atomhack.log\n");
  while((getline line < "/media/mmc/crontab") == 1) {
    print line;
  }
}

/^REBOOT_SCHEDULE *=/ {
  if($2 == "") next;
  gsub(/:/,",", $2);
  printf("%s /scripts/reboot.sh\n", $2);
}

/^RTMP_RESET_SCHEDULE *=/ {
  if($2 == "") next;
  gsub(/:/,",", $2);
  printf("%s /scripts/rtspserver.sh restart-rtmp\n", $2);
}

/^TIMELAPSE_SCHEDULE *=/ {
  split($2, schedule, ";");
  for(i in schedule) {
    if(schedule[i] == "") continue;
    gsub(/:/,",", schedule[i]);
    printf("%s %d\n", schedule[i], i);
  }
}
' $HACK_INI | crontab -
