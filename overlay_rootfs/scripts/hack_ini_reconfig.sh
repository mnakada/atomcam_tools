#!/bin/sh

HACK_INI=/media/mmc/hack.ini
CONFIG_VER=$(awk -F "=" '/CONFIG_VER *=/ {print $2}' $HACK_INI)
[ "$CONFIG_VER" = "1.0.0" ] && exit 0
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
