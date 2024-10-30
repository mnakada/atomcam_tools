#!/bin/sh

HACK_INI=/media/mmc/hack.ini
CONFIG_VER=$(awk -F "=" '/CONFIG_VER *=/ {print $2}' $HACK_INI)

# Ver.1.0.0
if [ "$CONFIG_VER" = "" ] ; then
  TIMELAPSE=$(awk -F "=" '/TIMELAPSE *=/ {print $2}' $HACK_INI)

  cp $HACK_INI ${HACK_INI}_0_9_9.bak
  rm -f $HACK_INI.new
  awk -F "=" '
  BEGIN {
    printf("CONFIG_VER=1.0.0\n");
  }

  /^STORAGE_SDCARD *=/ {
    printf("PERIODICREC_SDCARD=%s\n", ($2 == "on" || $2 == "record") ? "on" : "off");
    printf("ALARMREC_SDCARD=%s\n", ($2 == "on" || $2 == "alarm") ? "on" : "off");
    printf("TIMELAPSE_SDCARD=%s\n", ((TIMELAPSE == "on") && ($2 == "on" || $2 == "record" || $2 == "alarm")) ? "on" : "off");
    next;
  }

  /^STORAGE_SDCARD_PATH *=/ {
    printf("ALARMREC_SDCARD_PATH=%s\n", $2);
    next;
  }

  /^STORAGE_SDCARD_REMOVE *=/ {
    printf("PERIODICREC_SDCARD_REMOVE=%s\n", $2);
    printf("ALARMREC_SDCARD_REMOVE=%s\n", $2);
    printf("TIMELAPSE_SDCARD_REMOVE=%s\n", $2);
    next;
  }

  /^STORAGE_SDCARD_REMOVE_DAYS *=/ {
    printf("PERIODICREC_SDCARD_REMOVE_DAYS=%s\n", $2);
    printf("ALARMREC_SDCARD_REMOVE_DAYS=%s\n", $2);
    printf("TIMELAPSE_SDCARD_REMOVE_DAYS=%s\n", $2);
    next;
  }

  /^STORAGE_CIFS *=/ {
    printf("PERIODICREC_CIFS=%s\n", ($2 == "on" || $2 == "record") ? "on" : "off");
    printf("ALARMREC_CIFS=%s\n", ($2 == "on" || $2 == "alarm") ? "on" : "off");
    printf("TIMELAPSE_CIFS=%s\n", ((TIMELAPSE == "on") && ($2 == "on" || $2 == "record" || $2 == "alarm")) ? "on" : "off");
    next;
  }

  /^STORAGE_CIFS_PATH *=/ {
    printf("PERIODICREC_CIFS_PATH=%s\n", $2);
    printf("ALARMREC_CIFS_PATH=%s\n", $2);
    next;
  }

  /^STORAGE_CIFS_REMOVE *=/ {
    printf("PERIODICREC_CIFS_REMOVE=%s\n", $2);
    printf("ALARMREC_CIFS_REMOVE=%s\n", $2);
    printf("TIMELAPSE_CIFS_REMOVE=%s\n", $2);
    next;
  }

  /^STORAGE_CIFS_REMOVE_DAYS *=/ {
    printf("PERIODICREC_CIFS_REMOVE_DAYS=%s\n", $2);
    printf("ALARMREC_CIFS_REMOVE_DAYS=%s\n", $2);
    printf("TIMELAPSE_CIFS_REMOVE_DAYS=%s\n", $2);
    next;
  }

  /^RECORDING_LOCAL_SCHEDULE *=/ {
    printf("PERIODICREC_SCHEDULE=%s\n", $2);
    printf("ALARMREC_SCHEDHULE=%s\n", $2);
    next;
  }

  /^RECORDING_LOCAL_SCHEDULE_LIST *=/ {
    printf("PERIODICREC_SCHEDULE_LIST=%s\n", $2);
    printf("ALARMREC_SCHEDULE_LIST=%s\n", $2);
    next;
  }

  /^TIMELAPSE_PATH *=/ {
    printf("TIMELAPSE_SDCARD_PATH=%s\n", $2);
    printf("TIMELAPSE_CIFS_PATH=%s\n", $2);
    next;
  }

  {
    print $0;
  }
  ' TIMELAPSE=$TIMELAPSE $HACK_INI > $HACK_INI.new
  mv $HACK_INI.new $HACK_INI
fi

# Ver.1.0.1
if [ "$CONFIG_VER" = "1.0.0" ] ; then
  cp $HACK_INI ${HACK_INI}_1_0_0.bak
  rm -f $HACK_INI.new
  awk -F "=" '
  BEGIN {
    printf("CONFIG_VER=1.0.1\n");
  }

  {
    if((TIMELAPSE_SCHEDULE != "") && (TIMELAPSE_INTERVAL != "") && (TIMELAPSE_COUNT != "")) {
      printf("TIMELAPSE_SCHEDULE=%s /scripts/timelapse.sh start %s %s;\n",TIMELAPSE_SCHEDULE, TIMELAPSE_INTERVAL, TIMELAPSE_COUNT);
      TIMELAPSE_SCHEDULE = "";
      TIMELAPSE_INTERVAL = "";
      TIMELAPSE_COUNT = "";
    }
  }

  /^CONFIG_VER *=/ {
    next;
  }

  /^TIMELAPSE_SCHEDULE *=/ {
    TIMELAPSE_SCHEDULE = $2;
    next;
  }

  /^TIMELAPSE_INTERVAL *=/ {
    TIMELAPSE_INTERVAL = $2;
    next;
  }

  /^TIMELAPSE_COUNT *=/ {
    TIMELAPSE_COUNT = $2;
    next;
  }

  {
    print $0;
  }
  ' $HACK_INI > $HACK_INI.new
  mv $HACK_INI.new $HACK_INI
fi

# Ver.1.0.2
if [ "$CONFIG_VER" = "1.0.1" ] ; then
  cp $HACK_INI ${HACK_INI}_1_0_1.bak
  rm -f $HACK_INI.new
  awk -F "=" '
  BEGIN {
    printf("CONFIG_VER=1.0.2\n");
  }

  /^CONFIG_VER *=/ {
    next;
  }

  /^RTSP_AUDIO[0-2] *=/ {
    if($2 == "on") {
      printf("%s=S16_BE\n", $1);
    } else {
      print $0;
    }
    next;
  }

  {
    print $0;
  }
  ' $HACK_INI > $HACK_INI.new
  mv $HACK_INI.new $HACK_INI
fi

ISP_CONF=/media/mmc/video_isp.conf
if [ -f $ISP_CONF ] ; then
  ISP_CONF_VER=$(awk -F "=" '/ver *=/ {print $2}' $ISP_CONF)
  if [ "$ISP_CONF_VER" = "" ] ; then
    awk '
    BEGIN {
      printf("ver=1.0.0\n");
    }
    /aeitmax=1200/ {
      printf("aeitmax=1683\n");
      next;
    }
    {
      print;
    }
    ' $ISP_CONF > $ISP_CONF.new
    mv $ISP_CONF.new $ISP_CONF
  fi
fi
