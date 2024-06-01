#!/bin/sh

HACK_INI=/tmp/hack.ini
HOSTNAME=`hostname`
WEBHOOK_URL=$(awk -F "=" '/^WEBHOOK_URL *=/ {print $2}' $HACK_INI)
[ "$(awk -F "=" '/^WEBHOOK_INSECURE *=/ {print $2}' $HACK_INI)" = "on" ] && INSECURE_FLAG="-k "

if [ "$1" = "finish" ] ; then
  TIMELAPSE_CIFS=$(awk -F "=" '/^TIMELAPSE_CIFS *=/ { gsub(/^\/*/, "", $2);print $2}' $HACK_INI)
  TIMELAPSE_SDCARD=$(awk -F "=" '/^TIMELAPSE_SDCARD *=/ {print $2}' $HACK_INI)
  WEBHOOK_TIMELAPSE_FINISH=$(awk -F "=" '/^WEBHOOK_TIMELAPSE_FINISH *=/ {print $2}' $HACK_INI)
  TIMELAPSE_CIFS_PATH=$(awk -F "=" '/^TIMELAPSE_CIFS_PATH *=/ {print $2}' $HACK_INI)
  (
    if [ "$TIMELAPSE_CIFS" = "on" ] && /atom_patch/system_bin/mount_cifs.sh ; then
      CIFSFILE=`date +"time_lapse/$TIMELAPSE_CIFS_PATH.mp4"`
      OUTFILE="/atom/mnt/$HOSTNAME/$CIFSFILE"
      DIR_PATH=${OUTFILE%/*}
      CIFS_ERROR=""
      for i in 1 2 3 4; do
        [ "$i" = "4" ] && CIFS_ERROR="error" && break;
        mkdir -p $DIR_PATH
        cp -f $2 $OUTFILE
        [ -f $OUTFILE ] && cmp $2 $OUTFILE && break
      done
      [ "$CIFS_ERROR" = "error" ] && echo "CIFS error $2 $OUTFILE" >> /media/mmc/atomhack.log
      STORAGE=", \"cifsFile\":\"${CIFSFILE}\""
    fi

    if [ "$TIMELAPSE_SDCARD" = "on" ]; then
      STORAGE="${STORAGE}, \"sdcardFile\":\"${2##*media/mmc/}\""
    else
      [ "$CIFS_ERROR" = "" ] && rm $2
      find /media/mmc/time_lapse -depth -type d -empty -delete
    fi
    if [ "$WEBHOOK_URL" != "" ] && [ "$WEBHOOK_TIMELAPSE_FINISH" = "on" ]; then
      /usr/bin/curl -X POST -m 3 -H "Content-Type: application/json" -d "{\"type\":\"timelapseFinish\", \"device\":\"${HOSTNAME}\"${STORAGE}}" $INSECURE_FLAG $WEBHOOK_URL > /dev/null 2>&1
    fi
  ) &
  exit 0
fi

if [ "$1" = "start" ] ; then
  TIMELAPSE_SDCARD=$(awk -F "=" '/^TIMELAPSE_SDCARD *=/ {print $2}' $HACK_INI)
  TIMELAPSE_CIFS=$(awk -F "=" '/^TIMELAPSE_CIFS *=/ {print $2}' $HACK_INI)
  [ "$TIMELAPSE_SDCARD" = "on" -o "$TIMELAPSE_CIFS" = "on" ] || exit 0

  WEBHOOK_TIMELAPSE_START=$(awk -F "=" '/^WEBHOOK_TIMELAPSE_START *=/ {print $2}' $HACK_INI)
  TIMELAPSE_INTERVAL=$(awk -F "=" '/^TIMELAPSE_INTERVAL *=/ {print $2}' $HACK_INI)
  TIMELAPSE_COUNT=$(awk -F "=" '/^TIMELAPSE_COUNT *=/ {print $2}' $HACK_INI)
  TIMELAPSE_FPS=$(awk -F "=" '/^TIMELAPSE_FPS *=/ {print $2}' $HACK_INI)
  TIMELAPSE_SDCARD_PATH=$(awk -F "=" '/^TIMELAPSE_SDCARD_PATH *=/ {print $2}' $HACK_INI)
  TIMELAPSE_FILE=`date +"/media/mmc/time_lapse/$TIMELAPSE_SDCARD_PATH.mp4"`
  TIMELAPSE_DIR=${TIMELAPSE_FILE%/*}
  mkdir -p $TIMELAPSE_DIR

  res=`/scripts/cmd timelapse $TIMELAPSE_FILE $TIMELAPSE_INTERVAL $TIMELAPSE_COUNT $TIMELAPSE_FPS`
  [ "$res" = "ok" ] || exit 1
  [ -f /media/mmc/timelapse_hook.sh ] && /media/mmc/timelapse_hook.sh
  if [ "$WEBHOOK_URL" != "" ] && [ "$WEBHOOK_TIMELAPSE_START" = "on" ]; then
    /usr/bin/curl -X POST -m 3 -H "Content-Type: application/json" -d "{\"type\":\"timelapseStart\", \"device\":\"${HOSTNAME}\"}" $INSECURE_FLAG $WEBHOOK_URL > /dev/null 2>&1
  fi
fi
