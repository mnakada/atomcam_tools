#!/bin/sh

HACK_INI=/tmp/hack.ini
RTMP_ENABLE=$(awk -F "=" '/^RTMP_ENABLE *=/ {print $2}' $HACK_INI)
RTMP_RESET=$(awk -F "=" '/^RTMP_RESET *=/ {print $2}' $HACK_INI)

if [ "$1" = "restart-rtmp" ]; then
  [ "$RTMP_ENABLE" = "on" ] && [ "$RTMP_RESET" = "on" ] || exit 0
  while pidof go2rtc > /dev/null ; do
    killall go2rtc > /dev/null 2>&1
    sleep 0.5
  done
  echo `date +"%Y/%m/%d %H:%M:%S"` ": go2rtc stop"
fi

if [ "$1" = "off" -o "$1" = "restart" ]; then
  /scripts/cmd audio 0 off > /dev/null
  /scripts/cmd audio 1 off > /dev/null
  /scripts/cmd video 0 off > /dev/null
  /scripts/cmd video 1 off > /dev/null
  /scripts/cmd video 2 off > /dev/null
  while pidof go2rtc > /dev/null ; do
    killall go2rtc > /dev/null 2>&1
    sleep 0.5
  done
  echo `date +"%Y/%m/%d %H:%M:%S"` ": go2rtc stop"
  while pidof v4l2rtspserver > /dev/null ; do
    killall v4l2rtspserver > /dev/null 2>&1
    sleep 0.5
  done
  echo `date +"%Y/%m/%d %H:%M:%S"` ": v4l2rtspserver stop"
  [ "$1" = "off" ] && exit 0
fi

RTSP_VIDEO0=$(awk -F "=" '/^RTSP_VIDEO0 *=/ {print $2}' $HACK_INI)
RTSP_AUDIO0=$(awk -F "=" '/^RTSP_AUDIO0 *=/ {print $2}' $HACK_INI)
[ "$RTSP_AUDIO0" = "on" ] && RTSP_AUDIO0="S16_BE"
AUDIO0="on"
[ "$RTSP_AUDIO0" = "off" -o "$RTSP_AUDIO0" = "" ] && AUDIO0="off"
[ "$AUDIO0" = "off" -a "$RTMP_ENABLE" = "on" ] && RTSP_AUDIO0="AAC"
RTSP_VIDEO1=$(awk -F "=" '/^RTSP_VIDEO1 *=/ {print $2}' $HACK_INI)
RTSP_AUDIO1=$(awk -F "=" '/^RTSP_AUDIO1 *=/ {print $2}' $HACK_INI)
[ "$RTSP_AUDIO1" = "on" ] && RTSP_AUDIO1="S16_BE"
AUDIO1="on"
[ "$RTSP_AUDIO1" = "off" -o "$RTSP_AUDIO1" = "" ] && AUDIO1="off"
RTSP_VIDEO2=$(awk -F "=" '/^RTSP_VIDEO2 *=/ {print $2}' $HACK_INI)
RTSP_AUDIO2=$(awk -F "=" '/^RTSP_AUDIO2 *=/ {print $2}' $HACK_INI)
[ "$RTSP_AUDIO2" = "on" ] && RTSP_AUDIO2="S16_BE"
AUDIO2="on"
[ "$RTSP_AUDIO2" = "off" -o "$RTSP_AUDIO2" = "" ] && AUDIO2="off"
RTSP_OVER_HTTP=$(awk -F "=" '/^RTSP_OVER_HTTP *=/ {print $2}' $HACK_INI)
RTSP_AUTH=$(awk -F "=" '/^RTSP_AUTH *=/ {print $2}' $HACK_INI)
RTSP_USER=$(awk -F "=" '/^RTSP_USER *=/ {print $2}' $HACK_INI)
RTSP_PASSWD=$(awk -F "=" '/^RTSP_PASSWD *=/ {print $2}' $HACK_INI)
if [ "$1" = "watchdog" ]; then
  [ "$RTSP_VIDEO0" = "on" -o "$RTSP_VIDEO1" = "on" -o "$RTSP_VIDEO2" = "on" ] || exit 0
  pidof v4l2rtspserver > /dev/null && exit 0
fi

if [ "$1" != "restart-rtmp" ]; then

  [ "$1" != "on" -a "$1" != "restart" -a "$1" != "watchdog" -a "$RTSP_VIDEO0" != "on" -a "$RTSP_VIDEO1" != "on" -a "$RTSP_VIDEO2" != "on" ] && exit 0

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
    [ "$RTSP_VIDEO0" = "on" ] && path="/dev/video0,hw:0,0@$RTSP_AUDIO0 "
    [ "$RTSP_VIDEO1" = "on" ] && path="$path /dev/video1,hw:2,0@$RTSP_AUDIO1 "
    [ "$RTSP_VIDEO2" = "on" ] && path="$path /dev/video2,hw:4,0@$RTSP_AUDIO2 "
    /usr/bin/v4l2rtspserver $option -C 1 -a S16_LE $path >> /tmp/log/rtspserver.log 2>&1 &
  fi
  while [ "`pidof v4l2rtspserver`" = "" ]; do
    sleep 0.5
  done
  [ "$RTSP_VIDEO0" = "on" ] && /scripts/cmd audio 0 $AUDIO0 > /dev/null
  [ "$RTSP_VIDEO1" = "on" ] && /scripts/cmd audio 1 $AUDIO1 > /dev/null
  [ "$RTSP_VIDEO2" = "on" ] && /scripts/cmd audio 2 $AUDIO2 > /dev/null
fi

#
# go2rtc
#
HOMEKIT_CONFIG=/media/mmc/homekit.yaml
OLD_GO2RTC_CONFIG=/media/mmc/go2rtc.yaml
GO2RTC_CONFIG=/tmp/go2rtc.yaml
HOMEKIT_ENABLE=$(awk -F "=" '/^HOMEKIT_ENABLE *=/ {print $2}' $HACK_INI)
export HOMEKIT_SETUP_ID=$(awk -F "=" '/^HOMEKIT_SETUP_ID *=/ {print $2}' $HACK_INI)
export HOMEKIT_DEVICE_ID=$(awk -F "=" '/^HOMEKIT_DEVICE_ID *=/ {print $2}' $HACK_INI)
export HOMEKIT_PIN=$(awk -F "=" '/^HOMEKIT_PIN *=/ {print $2}' $HACK_INI)
export HOMEKIT_SOURCE=$(awk -F "=" '/^HOMEKIT_SOURCE *=/ {print $2}' $HACK_INI)
export HOMEKIT_NAME=`hostname`
export RTMP_URL=$(awk -F "=" '/^RTMP_URL *=/ {print $2}' $HACK_INI)
[ "$RTMP_ENABLE" = "on" -a "$RTMP_URL" != "" ] && export PUBLISH="publish"
WEBRTC_ENABLE=$(awk -F "=" '/^WEBRTC_ENABLE *=/ {print $2}' $HACK_INI)
[ "$WEBRTC_ENABLE" = "on" ] && export WEBRTC_LISTEN=":8555/tcp"

[ "$HOMEKIT_SOURCE" = "" ] && exit 0
[ "$HOMEKIT_ENABLE" = "on" -o "$RTMP_ENABLE" = "on" -o "$WEBRTC_ENABLE" = "on" ] || exit 0

# go2rtc config
cat > $GO2RTC_CONFIG << EOF
log:
    api: trace
    streams: error
api:
    origin: '*'
    static_dir: '/var/www-redirect'
rtsp:
    listen: ''
webrtc:
    listen: \${WEBRTC_LISTEN:''}
\${PUBLISH:'zzzz'}:
    video0:
        - \${RTMP_URL:}
streams:
    video0:
        - http://localhost/cgi-bin/get_jpeg.cgi
        - \${HOMEKIT_SOURCE:}#video=copy#audio=copy
EOF

option="-config $GO2RTC_CONFIG "
if [ "$HOMEKIT_ENABLE" = "on" ] ; then
  # homekit (go2rtc) config
  [ "$HOMEKIT_SETUP_ID" = "" -o "$HOMEKIT_PIN" = "" -o "$HOMEKIT_DEVICE_ID" = "" ] && exit 0

  [ ! -f $HOMEKIT_CONFIG -a -f $OLD_GO2RTC_CONFIG ] && mv $OLD_GO2RTC_CONFIG $HOMEKIT_CONFIG
  if [ -f $HOMEKIT_CONFIG ] && ! grep '^# ver.1.0.1' $HOMEKIT_CONFIG > /dev/null ; then
    awk '
      /pairings:/ {
        if($0 !~ /pairings:[ \t]*\[\]/) pairing = 1;
        gsub(/^[ \t]*/, "");
        printf("        %s\n", $0);
        next;
      }
      {
        if($0 !~ /[ \t]*-/) {
          pairing = 0;
          next;
        }
        if(pairing) {
          gsub(/^[ \t]*/, "");
          printf("            %s\n", $0);
        }
      }
    ' $HOMEKIT_CONFIG > $HOMEKIT_CONFIG.pairing
    rm -f $HOMEKIT_CONFIG
  fi

  if [ ! -f $HOMEKIT_CONFIG ] ; then
    cat >> $HOMEKIT_CONFIG << EOF
# ver.1.0.1
homekit:
    video0:
        device_id: \${HOMEKIT_DEVICE_ID:}
        setup_id: \${HOMEKIT_SETUP_ID:}
        name: \${HOMEKIT_NAME:}
        pin: \${HOMEKIT_PIN:}
EOF
    if [ -f $HOMEKIT_CONFIG.pairing ] ; then
      cat $HOMEKIT_CONFIG.pairing >> $HOMEKIT_CONFIG
      rm -f $HOMEKIT_CONFIG.pairing
    fi
    sync
  fi
  option="-config $HOMEKIT_CONFIG $option"
fi

echo -n "go2rtc: "
/usr/bin/go2rtc $option -daemon
exit 0
