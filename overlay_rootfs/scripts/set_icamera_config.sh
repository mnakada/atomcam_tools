#!/bin/sh

HACK_INI=/tmp/hack.ini
STORAGE_SDCARD=$(awk -F "=" '/STORAGE_SDCARD *=/ {print $2}' $HACK_INI)
FRAMERATE=$(awk -F "=" '/FRAMERATE *=/ {print $2}' $HACK_INI)
BITRATE_MAIN_AVC=$(awk -F "=" '/BITRATE_MAIN_AVC *=/ {print $2}' $HACK_INI)
BITRATE_SUB_HEVC=$(awk -F "=" '/BITRATE_SUB_HEVC *=/ {print $2}' $HACK_INI)
BITRATE_MAIN_HEVC=$(awk -F "=" '/BITRATE_MAIN_HEVC *=/ {print $2}' $HACK_INI)

PERIODIC="ram"
[ "$STORAGE_SDCARD" = "on" -o "$STORAGE_SDCARD" = "record" ] && PERIODIC="sd"
ALARM="ram"
[ "$STORAGE_SDCARD" = "on" -o "$STORAGE_SDCARD" = "alarm" ] && ALARM="sd"
/scripts/cmd mp4write $PERIODIC $ALARM

[ "$FRAMERATE" = "" ] || /scripts/cmd video fps $FRAMERATE
[ "$BITRATE_MAIN_AVC" = "" ] || [ "$BITRATE_MAIN_AVC" -eq 0 ] || /scripts/cmd video bitrate 0 $BITRATE_MAIN_AVC
[ "$BITRATE_SUB_HEVC" = "" ] || [ "$BITRATE_SUB_HEVC" -eq 0 ] || /scripts/cmd video bitrate 1 $BITRATE_SUB_HEVC
[ "$BITRATE_MAIN_HEVC" = "" ] || [ "$BITRATE_MAIN_HEVC" -eq 0 ] || /scripts/cmd video bitrate 3 $BITRATE_MAIN_HEVC
