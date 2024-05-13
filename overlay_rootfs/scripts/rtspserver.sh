#!/bin/sh

if [ "$1" = "off" -o "$1" = "restart" ]; then
  /scripts/cmd audio 0 off > /dev/null
  /scripts/cmd audio 1 off > /dev/null
  /scripts/cmd video 0 off > /dev/null
  /scripts/cmd video 1 off > /dev/null
  /scripts/cmd video 2 off > /dev/null
  kill `pidof v4l2rtspserver` > /dev/null 2>&1
  [ "$1" = "off" ] && exit 0
  while pidof v4l2rtspserver > /dev/null ; do
    sleep 0.5
  done
  echo `date +"%Y/%m/%d %H:%M:%S"` ": v4l2rtspserver stop"
fi

HACK_INI=/tmp/hack.ini
RTSP_VIDEO0=$(awk -F "=" '/^RTSP_VIDEO0 *=/ {print $2}' $HACK_INI)
RTSP_AUDIO0=$(awk -F "=" '/^RTSP_AUDIO0 *=/ {print $2}' $HACK_INI)
RTSP_VIDEO1=$(awk -F "=" '/^RTSP_VIDEO1 *=/ {print $2}' $HACK_INI)
RTSP_AUDIO1=$(awk -F "=" '/^RTSP_AUDIO1 *=/ {print $2}' $HACK_INI)
RTSP_VIDEO2=$(awk -F "=" '/^RTSP_VIDEO1 *=/ {print $2}' $HACK_INI)
RTSP_AUDIO2=$(awk -F "=" '/^RTSP_AUDIO1 *=/ {print $2}' $HACK_INI)
RTSP_OVER_HTTP=$(awk -F "=" '/^RTSP_OVER_HTTP *=/ {print $2}' $HACK_INI)
RTSP_AUTH=$(awk -F "=" '/^RTSP_AUTH *=/ {print $2}' $HACK_INI)
RTSP_USER=$(awk -F "=" '/^RTSP_USER *=/ {print $2}' $HACK_INI)
RTSP_PASSWD=$(awk -F "=" '/^RTSP_PASSWD *=/ {print $2}' $HACK_INI)

if [ "$1" = "watchdog" ]; then
  [ "$RTSP_VIDEO0" = "on" -o "$RTSP_VIDEO1" = "on" -o "$RTSP_VIDEO2" = "on" ] || exit 0
  pidof v4l2rtspserver > /dev/null && exit 0
fi

if [ "$1" = "on" -o "$1" = "restart" -o "$1" = "watchdog" -o "$RTSP_VIDEO0" = "on" -o "$RTSP_VIDEO1" = "on" -o "$RTSP_VIDEO2" = "on" ]; then
  /scripts/cmd video 0 $RTSP_VIDEO0 > /dev/null
  /scripts/cmd video 1 $RTSP_VIDEO1 > /dev/null
  /scripts/cmd video 2 $RTSP_VIDEO2 > /dev/null
  /scripts/cmd audio 0 on > /dev/null
  /scripts/cmd audio 1 on > /dev/null
  /scripts/cmd audio 2 on > /dev/null
  if ! pidof v4l2rtspserver > /dev/null ; then
    while netstat -ltn 2> /dev/null | egrep ":(8554|8080)"; do
      sleep 0.5
    done
    echo `date +"%Y/%m/%d %H:%M:%S"` ": v4l2rtspserever start"
    [ "$RTSP_OVER_HTTP" = "on" ] && option="-p 8080"
    [ "$RTSP_AUTH" = "on" -a "$RTSP_USER" != "" -a "$RTSP_PASSWD" != "" ] && option="$option -U $RTSP_USER:$RTSP_PASSWD"
    [ "$RTSP_VIDEO0" = "on" -o "$RTSP_AUDIO0" = "on" ] && path="/dev/video0,hw:0,0 "
    [ "$RTSP_VIDEO1" = "on" -o "$RTSP_AUDIO1" = "on" ] && path="$path /dev/video1,hw:1,0 "
    [ "$RTSP_VIDEO2" = "on" -o "$RTSP_AUDIO2" = "on" ] && path="$path /dev/video2,hw:2,0 "
    /usr/bin/v4l2rtspserver $option -C 1 -a S16_LE $path >> /tmp/log/rtspserver.log 2>&1 &
  fi
  while [ "`pidof v4l2rtspserver`" = "" ]; do
    sleep 0.5
  done
  /scripts/cmd audio 0 $RTSP_AUDIO0 > /dev/null
  /scripts/cmd audio 1 $RTSP_AUDIO1 > /dev/null
  /scripts/cmd audio 2 $RTSP_AUDIO2 > /dev/null
fi

exit 0
