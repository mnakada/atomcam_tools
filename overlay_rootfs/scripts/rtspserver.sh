#!/bin/sh

if [ "$1" = "off" -o "$1" = "restart" ]; then
  /scripts/cmd audio 0 off > /dev/null
  /scripts/cmd audio 1 off > /dev/null
  /scripts/cmd video 0 off > /dev/null
  /scripts/cmd video 1 off > /dev/null
  /scripts/cmd video 2 off > /dev/null
  killall v4l2rtspserver > /dev/null 2>&1
  killall go2rtc > /dev/null 2>&1
  [ "$1" = "off" ] && exit 0
  while pidof v4l2rtspserver > /dev/null ; do
    sleep 0.5
  done
  echo `date +"%Y/%m/%d %H:%M:%S"` ": v4l2rtspserver stop"
fi

HACK_INI=/tmp/hack.ini
HOMEKIT_CONFIG=/media/mmc/homekit.yaml
GO2RTC_CONFIG=/media/mmc/go2rtc.yaml
RTSP_VIDEO0=$(awk -F "=" '/^RTSP_VIDEO0 *=/ {print $2}' $HACK_INI)
RTSP_AUDIO0=$(awk -F "=" '/^RTSP_AUDIO0 *=/ {print $2}' $HACK_INI)
RTSP_VIDEO1=$(awk -F "=" '/^RTSP_VIDEO1 *=/ {print $2}' $HACK_INI)
RTSP_AUDIO1=$(awk -F "=" '/^RTSP_AUDIO1 *=/ {print $2}' $HACK_INI)
RTSP_VIDEO2=$(awk -F "=" '/^RTSP_VIDEO2 *=/ {print $2}' $HACK_INI)
RTSP_AUDIO2=$(awk -F "=" '/^RTSP_AUDIO2 *=/ {print $2}' $HACK_INI)
RTSP_OVER_HTTP=$(awk -F "=" '/^RTSP_OVER_HTTP *=/ {print $2}' $HACK_INI)
RTSP_AUTH=$(awk -F "=" '/^RTSP_AUTH *=/ {print $2}' $HACK_INI)
RTSP_USER=$(awk -F "=" '/^RTSP_USER *=/ {print $2}' $HACK_INI)
RTSP_PASSWD=$(awk -F "=" '/^RTSP_PASSWD *=/ {print $2}' $HACK_INI)
HOMEKIT_ENABLE=$(awk -F "=" '/^HOMEKIT_ENABLE *=/ {print $2}' $HACK_INI)
[ "$HOMEKIT_ENABLE" = "on" ] && export HOMEKIT_KEY="homekit"
export HOMEKIT_SETUP_ID=$(awk -F "=" '/^HOMEKIT_SETUP_ID *=/ {print $2}' $HACK_INI)
export HOMEKIT_DEVICE_ID=$(awk -F "=" '/^HOMEKIT_DEVICE_ID *=/ {print $2}' $HACK_INI)
export HOMEKIT_PIN=$(awk -F "=" '/^HOMEKIT_PIN *=/ {print $2}' $HACK_INI)
export HOMEKIT_SOURCE=$(awk -F "=" '/^HOMEKIT_SOURCE *=/ {print $2}' $HACK_INI)
export HOMEKIT_NAME=`hostname`
WEBRTC_ENABLE=$(awk -F "=" '/^WEBRTC_ENABLE *=/ {print $2}' $HACK_INI)
[ "$WEBRTC_ENABLE" = "on" ] && export WEBRTC_LISTEN=":8555/tcp"

if [ "$1" = "watchdog" ]; then
  [ "$RTSP_VIDEO0" = "on" -o "$RTSP_VIDEO1" = "on" -o "$RTSP_VIDEO2" = "on" ] || exit 0
  pidof v4l2rtspserver > /dev/null && exit 0
fi

if [ "$1" = "on" -o "$1" = "restart" -o "$1" = "watchdog" -o "$RTSP_VIDEO0" = "on" -o "$RTSP_VIDEO1" = "on" -o "$RTSP_VIDEO2" = "on" ]; then
  /scripts/cmd video 0 $RTSP_VIDEO0 > /dev/null
  /scripts/cmd video 1 $RTSP_VIDEO1 > /dev/null
  /scripts/cmd video 2 $RTSP_VIDEO2 > /dev/null
  [ "$RTSP_VIDEO0" = "on" ] && /scripts/cmd audio 0 on > /dev/null
  [ "$RTSP_VIDEO1" = "on" ] && /scripts/cmd audio 1 on > /dev/null
  [ "$RTSP_VIDEO2" = "on" ] && /scripts/cmd audio 2 on > /dev/null
  if ! pidof v4l2rtspserver > /dev/null ; then
    while netstat -ltn 2> /dev/null | egrep ":(8554|8080)"; do
      sleep 0.5
    done
    echo `date +"%Y/%m/%d %H:%M:%S"` ": v4l2rtspserever start"
    [ "$RTSP_OVER_HTTP" = "on" ] && option="-p 8080"
    [ "$RTSP_AUTH" = "on" -a "$RTSP_USER" != "" -a "$RTSP_PASSWD" != "" ] && option="$option -U $RTSP_USER:$RTSP_PASSWD"
    [ "$RTSP_VIDEO0" = "on" ] && path="/dev/video0,hw:0,0 "
    [ "$RTSP_VIDEO1" = "on" ] && path="$path /dev/video1,hw:2,0 "
    [ "$RTSP_VIDEO2" = "on" ] && path="$path /dev/video2,hw:4,0 "
    /usr/bin/v4l2rtspserver $option -C 1 -a S16_LE $path >> /tmp/log/rtspserver.log 2>&1 &
  fi
  while [ "`pidof v4l2rtspserver`" = "" ]; do
    sleep 0.5
  done
  [ "$RTSP_VIDEO0" = "on" ] && /scripts/cmd audio 0 $RTSP_AUDIO0 > /dev/null
  [ "$RTSP_VIDEO1" = "on" ] && /scripts/cmd audio 1 $RTSP_AUDIO1 > /dev/null
  [ "$RTSP_VIDEO2" = "on" ] && /scripts/cmd audio 2 $RTSP_AUDIO2 > /dev/null

  [ "$HOMEKIT_SETUP_ID" = "" -o "$HOMEKIT_PIN" = "" -o "$HOMEKIT_DEVICE_ID" = "" -o "$HOMEKIT_SOURCE" = "" ] && exit 0
  [ -f $HOMEKIT_CONFIG -a -f $GO2RTC_CONFIG ] && rm -f $HOMEKIT_CONFIG
  [ -f $HOMEKIT_CONFIG ] && mv $HOMEKIT_CONFIG $GO2RTC_CONFIG
  if [ -f $GO2RTC_CONFIG ] && ! grep '^# ver.1.0.0' $GO2RTC_CONFIG > /dev/null ; then
    awk '
      /pairings:/ {
        if($0 !~ /pairings:[ \t]*\[\]/) pairing = 1;
        print;
        next;
      }
      {
        if($0 !~ /[ \t]*-/) {
          pairing = 0;
          next;
        }
        if(pairing) print;
      }
    ' $GO2RTC_CONFIG > $GO2RTC_CONFIG.pairing
    rm -f $GO2RTC_CONFIG
  fi

  if [ ! -f $GO2RTC_CONFIG ] ; then
    cat >> $GO2RTC_CONFIG << EOF
# ver.1.0.0
log:
    api: trace
    streams: error
api:
    origin: '*'
    static_dir: '/var/www-redirect'
rtsp:
    listen: ''
webrtc:
    listen: \${WEBRTC_LISTEN:}
streams:
    video0:
      - http://localhost/cgi-bin/get_jpeg.cgi
      - \${HOMEKIT_SOURCE:}
\${HOMEKIT_KEY:'zzz'}:
    video0:
        device_id: \${HOMEKIT_DEVICE_ID:}
        setup_id: \${HOMEKIT_SETUP_ID:}
        name: \${HOMEKIT_NAME:}
        pin: \${HOMEKIT_PIN:}
EOF
    if [ -f $GO2RTC_CONFIG.pairing ] ; then
      cat $GO2RTC_CONFIG.pairing >> $GO2RTC_CONFIG
      rm -f $GO2RTC_CONFIG.pairing
    fi
    sync
  fi
  if [ "$HOMEKIT_ENABLE" = "on" -o "$WEBRTC_ENABLE" = "on" ] ; then
    echo -n "go2rtc: "
    /usr/bin/go2rtc -config $GO2RTC_CONFIG -daemon
  fi
fi

exit 0
