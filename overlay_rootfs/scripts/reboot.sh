#!/bin/sh
HACK_INI=/tmp/hack.ini
REBOOT=$(awk -F "=" '/^REBOOT *=/ {print $2}' $HACK_INI)

if [ "$REBOOT" = "on" ]; then
  /scripts/cmd timelapse stop
  sleep 3
  killall -SIGUSR2 iCamera_app
  sync
  sync
  sync
  reboot
fi
