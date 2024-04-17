#!/bin/sh

HACK_INI=/tmp/hack.ini
ALARMREC_SDCARD=$(awk -F "=" '/^ALARMREC_SDCARD *=/ {print $2}' $HACK_INI)
PERIODICREC_SDCARD=$(awk -F "=" '/^PERIODICREC_SDCARD *=/ {print $2}' $HACK_INI)
STORAGE_SDCARD_DIRECT_WRITE=$(awk -F "=" '/^STORAGE_SDCARD_DIRECT_WRITE *=/ {print $2}' $HACK_INI)
FRAMERATE=$(awk -F "=" '/^FRAMERATE *=/ {print $2}' $HACK_INI)
BITRATE_MAIN_AVC=$(awk -F "=" '/^BITRATE_MAIN_AVC *=/ {print $2}' $HACK_INI)
BITRATE_SUB_HEVC=$(awk -F "=" '/^BITRATE_SUB_HEVC *=/ {print $2}' $HACK_INI)
BITRATE_MAIN_HEVC=$(awk -F "=" '/^BITRATE_MAIN_HEVC *=/ {print $2}' $HACK_INI)
MINIMIZE_ALARM_CYCLE=$(awk -F "=" '/^MINIMIZE_ALARM_CYCLE *=/ {print $2}' $HACK_INI)
AWS_VIDEO_DISABLE=$(awk -F "=" '/^AWS_VIDEO_DISABLE *=/ {print $2}' $HACK_INI)

PERIODIC="ram"
ALARM="ram"
if [ "$STORAGE_SDCARD_DIRECT_WRITE" = "on" ] ; then
  [ "$PERIODICREC_SDCARD" = "on" ] && PERIODIC="sd"
  [ "$ALARMREC_SDCARD" = "on" ] && ALARM="sd"
fi
/scripts/cmd mp4write $PERIODIC $ALARM > /dev/null

[ "$MINIMIZE_ALARM_CYCLE" = "on" ] && /scripts/cmd alarm 30 > /dev/null
[ "$AWS_VIDEO_DISABLE" = "on" ] && /scripts/cmd curl upload disable > /dev/null
[ "$FRAMERATE" = "" ] || [ "$FRAMERATE" -le 0 ] || /scripts/cmd video fps $FRAMERATE > /dev/null
[ "$BITRATE_MAIN_AVC" = "" ] || [ "$BITRATE_MAIN_AVC" -le 0 ] || /scripts/cmd video bitrate 0 $BITRATE_MAIN_AVC > /dev/null
[ "$BITRATE_SUB_HEVC" = "" ] || [ "$BITRATE_SUB_HEVC" -le 0 ] || /scripts/cmd video bitrate 1 $BITRATE_SUB_HEVC > /dev/null
[ "$BITRATE_MAIN_HEVC" = "" ] || [ "$BITRATE_MAIN_HEVC" -le 0 ] || /scripts/cmd video bitrate 3 $BITRATE_MAIN_HEVC > /dev/null
