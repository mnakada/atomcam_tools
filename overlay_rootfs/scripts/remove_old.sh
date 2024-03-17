#!/bin/sh

HACK_INI=/tmp/hack.ini
STORAGE_SDCARD_REMOVE=$(awk -F "=" '/^STORAGE_SDCARD_REMOVE *=/ {print $2}' $HACK_INI)
STORAGE_SDCARD_REMOVE_DAYS=$(awk -F "=" '/^STORAGE_SDCARD_REMOVE_DAYS *=/ {print $2}' $HACK_INI)

STORAGE_CIFS_REMOVE=$(awk -F "=" '/^STORAGE_CIFS_REMOVE *=/ {print $2}' $HACK_INI)
STORAGE_CIFS_REMOVE_DAYS=$(awk -F "=" '/^STORAGE_CIFS_REMOVE_DAYS *=/ {print $2}' $HACK_INI)

STORAGE_CIFS=$(awk -F "=" '/^STORAGE_CIFS *=/ {print $2}' $HACK_INI)
STORAGE_SDCARD=$(awk -F "=" '/^STORAGE_SDCARD *=/ {print $2}' $HACK_INI)
HOSTNAME=`hostname`

if [ "$STORAGE_SDCARD_REMOVE" = "on" ] && [ "$STORAGE_SDCARD_REMOVE_DAYS" != "" ]; then
  if [ "$STORAGE_SDCARD" = "on" -o "$STORAGE_SDCARD" = "alarm" ]; then
    find /media/mmc/alarm_record -depth -type f -mtime +$STORAGE_SDCARD_REMOVE_DAYS -delete
    find /media/mmc/alarm_record -depth -type d -mmin +3 -empty -delete
  fi
  if [ "$STORAGE_SDCARD" = "on" -o "$STORAGE_SDCARD" = "record" ]; then
    find /media/mmc/record -depth -type f -mtime +$STORAGE_SDCARD_REMOVE_DAYS -delete
    find /media/mmc/record -depth -type d -mmin +3 -empty -delete
  fi
  if [ "$STORAGE_SDCARD" = "on" -o "$STORAGE_SDCARD" = "record" -o "$STORAGE_SDCARD" = "alarm" ]; then
    find /media/mmc/time_lapse -depth -type f -mtime +$STORAGE_SDCARD_REMOVE_DAYS -delete
    find /media/mmc/time_lapse -depth -type d -mmin +3 -empty -delete
  fi
fi
find /media/mmc/time_lapse -depth -type f -name '*.h264' -mtime +3 -delete

if [ "$STORAGE_CIFS_REMOVE" = "on" ] && [ "$STORAGE_CIFS_REMOVE_DAYS" != "" ]; then
  if /atom_patch/system_bin/mount_cifs.sh ; then
    if [ "$STORAGE_CIFS" = "on" -o "$STORAGE_CIFS" = "alarm" ] ; then
      find /atom/mnt/$HOSTNAME/alarm_record -depth -type f -mtime +$STORAGE_CIFS_REMOVE_DAYS -delete
      find /atom/mnt/$HOSTNAME/alarm_record -depth -type d -mmin +3 -empty -delete
    fi
    if [ "$STORAGE_CIFS" = "on" -o "$STORAGE_CIFS" = "record" ] ; then
      find /atom/mnt/$HOSTNAME/record -depth -type f -mtime +$STORAGE_CIFS_REMOVE_DAYS -delete
      find /atom/mnt/$HOSTNAME/record -depth -type d -mmin +3 -empty -delete
    fi
    if [ "$STORAGE_CIFS" = "on" -o "$STORAGE_CIFS" = "record" -o "$STORAGE_CIFS" = "alarm" ] ; then
      find /atom/mnt/$HOSTNAME/time_lapse -depth -type f -mtime +$STORAGE_CIFS_REMOVE_DAYS -delete
      find /atom/mnt/$HOSTNAME/time_lapse -depth -type d -mmin +3 -empty -delete
    fi
  fi
fi
