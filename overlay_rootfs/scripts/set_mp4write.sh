#!/bin/sh

HACK_INI=/tmp/hack.ini
STORAGE_SDCARD=$(awk -F "=" '/STORAGE_SDCARD *=/ {print $2}' $HACK_INI)

PERIODIC="ram"
[ "$STORAGE_SDCARD" = "on" -o "$STORAGE_SDCARD" = "record" ] && PERIODIC="sd"
/scripts/cmd mp4write periodicRec $PERIODIC

ALARM="ram"
[ "$STORAGE_SDCARD" = "on" -o "$STORAGE_SDCARD" = "alarm" ] && ALARM="sd"
/scripts/cmd mp4write alarmRec $ALARM
