#!/bin/sh

if [ "$1" == "on" ]; then
  HACK_INI=/tmp/hack.ini
  STORAGE_SDCARD_PUBLISH=$(awk -F "=" '/^STORAGE_SDCARD_PUBLISH *=/ {print $2}' $HACK_INI)

  if [ "$STORAGE_SDCARD_PUBLISH" = "on" ]; then
    printf "Starting SMB services: "
    pidof smbd || smbd -D
    [ $? = 0 ] && echo "OK" || echo "FAIL"

    printf "Starting NMB services: "
    pidof nmbd || nmbd -D
    [ $? = 0 ] && echo "OK" || echo "FAIL"
  fi
fi

if [ "$1" = "off" ]; then
  killall -9 smbd > /dev/null 2>&1
  killall -9 nmbd > /dev/null 2>&1
fi
