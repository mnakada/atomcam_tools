#!/bin/sh

mkfifo /var/run/webcmd
chmod 666 /var/run/webcmd
mkfifo /var/run/webres
chmod 666 /var/run/webres
tail -F /var/run/webcmd | while read line
do
  echo "[webcmd] $line"
  cmd=${line%% *}
  params=${line#* }
  if [ "$cmd" = "reboot" ]; then
    echo "$cmd $params OK" >> /var/run/webres
    /scripts/cmd timelapse stop
    sleep 3
    killall -SIGUSR2 iCamera_app
    sync
    sync
    sync
    reboot
    cmd=""
  fi
  if [ "$cmd" = "setCron" ]; then
    /scripts/set_crontab.sh
  fi
  if [ "$cmd" = "setwebhook" ]; then
    kill `ps -l | awk '/ps -l/ { next } /webhook.sh/ { print $3 } /awk  BEGIN/ { print $3 }'`
    /scripts/webhook.sh &
    echo "$cmd $params OK" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "hostname" ] && [ "$params" != "" ]; then
    echo ${params%%.*} > /media/mmc/hostname
    hostname ${params%%.*}
    if [ "`pidof avahi-daemon`" != "" ]; then
      /usr/sbin/avahi-daemon -k
      /usr/sbin/avahi-daemon -D
    fi
    if [ "`pidof nmbd`" != "" ]; then
      killall -9 nmbd
      nmbd -D
    fi
    echo "$cmd $params OK" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "mp4write" ]; then
    res=`/scripts/cmd mp4write ${params}`
    echo "$cmd $params $res" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "framerate" ]; then
    res=`/scripts/cmd video fps ${params}`
    echo "$cmd $params $res" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "bitrate" ]; then
    res=`/scripts/cmd video bitrate ${params}`
    echo "$cmd $params $res" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "alarm" ]; then
    res=`/scripts/cmd alarm ${params}`
    echo "$cmd $params $res" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "curl" ]; then
    res=`/scripts/cmd curl ${params}`
    echo "$cmd $params $res" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "skipRecJpeg" ]; then
    res=`/scripts/cmd skipRecJpeg ${params}`
    echo "$cmd $params $res" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "flip" ]; then
    res=`/scripts/cmd video flip ${params}`
    awk '
    /verSwitch/ {
      if(params == "normal") {
        printf("verSwitch=2\n");
      } else {
        printf("verSwitch=1\n");
      }
      next;
    }
    /horSwitch/ {
      if(params == "normal") {
        printf("horSwitch=2\n");
      } else {
        printf("horSwitch=1\n");
      }
      next;
    }
    {
      print;
    }
    ' params="$params" /atom/configs/.user_config > /atom/configs/.user_config_new
    mv -f /atom/configs/.user_config_new /atom/configs/.user_config
    echo 3 > /proc/sys/vm/drop_caches
    echo "$cmd $params $res" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "rtspserver" ] && [ "$params" != "" ]; then
    /scripts/rtspserver.sh $params
    echo "$cmd $params OK" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "cruise" ]; then
    kill -9 `pidof cruise.sh`
    /scripts/cruise.sh &
    echo "$cmd $params OK" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "lighttpd" ]; then
    echo "$cmd OK" >> /var/run/webres
    sleep 3
    /scripts/lighttpd.sh restart
    cmd=""
  fi
  if [ "$cmd" = "samba" ] && [ "$params" != "" ]; then
    /scripts/samba.sh $params
    echo "$cmd $params OK" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "sderase" ]; then
    busybox rm -rf /media/mmc/record
    busybox rm -rf /media/mmc/alarm_record
    busybox rm -rf /media/mmc/time_lapse
    echo "$cmd $params OK" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "update_status" ]; then
    stat="-1"
    [ -f /tmp/update_status ] && stat=`cat /tmp/update_status`
    echo "$cmd $stat OK" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "update" -a "$UPDATE_SEQ" = "" ]; then
    HACK_INI=/tmp/hack.ini
    CUSTOM_ZIP=$(awk -F "=" '/^CUSTOM_ZIP *=/ {print $2}' $HACK_INI)
    ZIP_URL=$(awk -F "=" '/^CUSTOM_ZIP_URL *=/ {print $2}' $HACK_INI)
    if [ "$CUSTOM_ZIP" = "off" ] || [ "$ZIP_URL" = "" ]; then
      latest=`curl -w "%{redirect_url}" -s -o /dev/null https://github.com/mnakada/atomcam_tools/releases/latest`
      ZIP_URL="https://github.com/mnakada/atomcam_tools/releases/download/${latest##*tag/}/atomcam_tools.zip"
    fi
    mkdir -p /media/mmc/update
    UPDATE_SEQ=1
    echo "0" > /tmp/update_status
    (
      cd /media/mmc/update;
      curl -H 'Cache-Control: no-cache, no-store' -H 'Pragma: no-cache' -L -o atomcam_tools.zip $ZIP_URL 2>&1 | awk 'BEGIN { RS="\r"; } /Total/ { next; } { printf("%d\n", $3) > "/tmp/update_status"; close("/tmp/update_status"); }'
      /scripts/cmd timelapse stop > /dev/null
      sleep 3
      killall -SIGUSR2 iCamera_app
      sync
      sync
      sync
      reboot
    ) &
    echo "$cmd $params OK" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "posrec" ]; then
    pos=`/scripts/cmd move`;
    awk '
    /slide_x/ {
      split(POS, pos, " ");
      x = int(pos[1] * 100 + 0.5);
      if(pos[3] != 0) x = 35000 - x;
      printf("slide_x=%d\n", x);
      next;
    }
    /slide_y/ {
      split(POS, pos, " ");
      y = int(pos[2] * 100 + 0.5);
      if(pos[4] != 0) y = 18000 - y;
      printf("slide_y=%d\n", y);
      next;
    }
    {
      print;
    }
    ' POS="$pos" /atom/configs/.user_config > /atom/configs/.user_config_new
    mv -f /atom/configs/.user_config_new /atom/configs/.user_config
    echo 3 > /proc/sys/vm/drop_caches
    echo "$cmd OK" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" = "moveinit" ]; then
    /scripts/motor_init
    echo "$cmd OK" >> /var/run/webres
    cmd=""
  fi
  if [ "$cmd" != "" ]; then
    echo "$cmd $param : syntax error" >> /var/run/webres
  fi
done
