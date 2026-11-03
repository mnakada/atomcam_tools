#!/bin/sh

HACK_INI=/tmp/hack.ini
CONF=/tmp/onvif_simple_server.conf
LOG_DIR=/tmp/log
LOG=$LOG_DIR/onvif.log
ONVIF_SERVER_LOG=$LOG_DIR/onvif_simple_server.log
WSD_SERVER_LOG=$LOG_DIR/wsd_simple_server.log
NOTIFY_SERVER_LOG=$LOG_DIR/onvif_notify_server.log
WSD_PID=/var/run/wsd_simple_server.pid
NOTIFY_PID=/var/run/onvif_notify_server.pid

log()
{
  mkdir -p $LOG_DIR
  echo `date +"%Y/%m/%d %H:%M:%S"` ": $*" >> $LOG
}

get_ini()
{
  awk -F "=" -v key="$1" '$1 ~ "^[ \t]*" key "[ \t]*$" { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' $HACK_INI
}

active_if()
{
  for ifs in eth0 wlan0 ; do
    if ifconfig $ifs 2> /dev/null | grep 'inet addr' > /dev/null ; then
      echo $ifs
      return
    fi
  done
}

stop_onvif()
{
  if [ -f $WSD_PID ]; then
    kill -15 `cat $WSD_PID` > /dev/null 2>&1
    rm -f $WSD_PID
  fi
  if [ -f $NOTIFY_PID ]; then
    kill -15 `cat $NOTIFY_PID` > /dev/null 2>&1
    rm -f $NOTIFY_PID
  fi
  /scripts/onvif_event.sh stop > /dev/null 2>&1
  killall wsd_simple_server > /dev/null 2>&1
  killall onvif_notify_server > /dev/null 2>&1
  rm -f /dev/shm/onvif_subscription /dev/shm/sem.sub_mem_lock
}

if [ "$1" = "off" -o "$1" = "restart" ]; then
  stop_onvif
  log "onvif stop"
  [ "$1" = "off" ] && exit 0
fi

ONVIF_ENABLE=$(get_ini ONVIF_ENABLE)
[ "$1" != "on" -a "$1" != "restart" -a "$ONVIF_ENABLE" != "on" ] && exit 0

RTSP_VIDEO0=$(get_ini RTSP_VIDEO0)
RTSP_AUDIO0=$(get_ini RTSP_AUDIO0)
RTSP_VIDEO1=$(get_ini RTSP_VIDEO1)
RTSP_VIDEO2=$(get_ini RTSP_VIDEO2)
[ "$RTSP_VIDEO0" = "on" -o "$RTSP_VIDEO1" = "on" -o "$RTSP_VIDEO2" = "on" ] || {
  log "onvif requires at least one RTSP stream"
  exit 0
}

IFACE=$(active_if)
[ "$IFACE" = "" ] && {
  log "no active network interface"
  exit 1
}

mkdir -p $LOG_DIR
mkdir -p /tmp/onvif_notify_server
touch $LOG $ONVIF_SERVER_LOG $WSD_SERVER_LOG
touch $NOTIFY_SERVER_LOG
chmod 666 $LOG $ONVIF_SERVER_LOG $WSD_SERVER_LOG $NOTIFY_SERVER_LOG > /dev/null 2>&1
/scripts/rtspserver.sh on

HOSTNAME=`hostname`
MODEL=$(awk -F "=" '/^PRODUCT_MODEL *=/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' /atom/configs/.product_config 2> /dev/null)
[ "$MODEL" = "" ] && MODEL="ATOMCam"
SERIAL=$(awk -F "=" '/^(CONFIG_INFO|NETRELATED_MAC) *=/ { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' /atom/configs/.product_config 2> /dev/null)
[ "$SERIAL" = "" ] && SERIAL="$HOSTNAME"

RTSP_OVER_HTTP=$(get_ini RTSP_OVER_HTTP)
RTSP_PORT=8554
[ "$RTSP_OVER_HTTP" = "on" ] && RTSP_PORT=8080

RTSP_AUTH=$(get_ini RTSP_AUTH)
RTSP_USER=$(get_ini RTSP_USER)
RTSP_PASSWD=$(get_ini RTSP_PASSWD)
AUTH=""
if [ "$RTSP_AUTH" = "on" -a "$RTSP_USER" != "" -a "$RTSP_PASSWD" != "" ]; then
  AUTH="$RTSP_USER:$RTSP_PASSWD@"
fi

ONVIF_USER=$(get_ini ONVIF_USER)
ONVIF_PASSWD=$(get_ini ONVIF_PASSWD)
ONVIF_MAIN_STREAM=$(get_ini ONVIF_MAIN_STREAM)
[ "$ONVIF_MAIN_STREAM" = "" ] && ONVIF_MAIN_STREAM=avc

audio_encoder()
{
  if [ "$1" = "AAC" ]; then
    echo "AAC"
  elif [ "$1" = "S16_BE" ]; then
    echo "G711"
  else
    echo "NONE"
  fi
}

profile_count=0
emit_profile()
{
  profile_count=$((profile_count + 1))
  echo "name=Profile_$((profile_count - 1))"
  echo "width=$1"
  echo "height=$2"
  echo "url=rtsp://${AUTH}%s:$RTSP_PORT/$3"
  echo "snapurl=http://%s/cgi-bin/get_jpeg.cgi"
  echo "type=$4"
  echo "audio_encoder=$(audio_encoder "$5")"
  echo "audio_decoder=NONE"
}

PTZ=0
if [ "$MODEL" = "ATOM_CAKP1JZJP" ]; then
  PTZ=1
fi

{
  echo "model=$MODEL"
  echo "manufacturer=ATOMTech"
  echo "firmware_ver=`cat /etc/atomhack.ver 2> /dev/null`"
  echo "hardware_id=$MODEL"
  echo "serial_num=$SERIAL"
  echo "ifs=$IFACE"
  echo "port=80"
  echo "scope=onvif://www.onvif.org/Profile/Streaming"
  echo "scope=onvif://www.onvif.org/Profile/S"
  echo "scope=onvif://www.onvif.org/name/$HOSTNAME"
  echo "scope=onvif://www.onvif.org/hardware/$MODEL"
  echo "user=$ONVIF_USER"
  echo "password=$ONVIF_PASSWD"
  echo "adv_enable_media2=0"
  echo "adv_fault_if_unknown=0"
  echo "adv_fault_if_set=0"
  echo "adv_synology_nvr=1"

  if [ "$RTSP_VIDEO0" = "on" -a "$RTSP_VIDEO2" = "on" -a "$ONVIF_MAIN_STREAM" = "hevc" ]; then
    emit_profile 1920 1080 video2_unicast H265 "$RTSP_AUDIO2"
  elif [ "$RTSP_VIDEO0" = "on" ]; then
    emit_profile 1920 1080 video0_unicast H264 "$RTSP_AUDIO0"
  elif [ "$RTSP_VIDEO2" = "on" ]; then
    emit_profile 1920 1080 video2_unicast H265 "$RTSP_AUDIO2"
  fi

  if [ "$RTSP_VIDEO1" = "on" -a "$profile_count" -lt 2 ]; then
    if [ "$MODEL" = "ATOM_CamV3C" -o "$MODEL" = "AC1" -o "$MODEL" = "ATOM_CAKP1JZJP" ]; then
      emit_profile 640 360 video1_unicast H265 "$RTSP_AUDIO1"
    else
      emit_profile 640 320 video1_unicast H264 "$RTSP_AUDIO1"
    fi
  fi

  if [ "$RTSP_VIDEO2" = "on" -a "$RTSP_VIDEO0" = "on" -a "$RTSP_VIDEO1" != "on" -a "$profile_count" -lt 2 ]; then
    if [ "$ONVIF_MAIN_STREAM" = "hevc" ]; then
      emit_profile 1920 1080 video0_unicast H264 "$RTSP_AUDIO0"
    else
      emit_profile 1920 1080 video2_unicast H265 "$RTSP_AUDIO2"
    fi
  fi

  echo "ptz=$PTZ"
  if [ "$PTZ" = "1" ]; then
    echo "min_step_x=0"
    echo "max_step_x=355"
    echo "min_step_y=0"
    echo "max_step_y=180"
    echo "min_step_z=0"
    echo "max_step_z=0"
    # GetStatus is polled in a tight loop: talk to the command socket directly (one nc, no shell script)
    # and get "pan,tilt,0,moving" in a single line, so is_moving only has to exist (it advertises MoveStatus)
    echo "get_position=echo ptzstatus | /usr/bin/nc localhost 4000"
    echo "is_moving=/scripts/onvif_ptz.sh is_moving"
    echo "move_left=/scripts/onvif_ptz.sh move_left %f > /dev/null"
    echo "move_right=/scripts/onvif_ptz.sh move_right %f > /dev/null"
    echo "move_up=/scripts/onvif_ptz.sh move_up %f > /dev/null"
    echo "move_down=/scripts/onvif_ptz.sh move_down %f > /dev/null"
    echo "move_stop=/scripts/onvif_ptz.sh stop %s > /dev/null"
    echo "jump_to_abs=/scripts/onvif_ptz.sh absolute %f %f %f %f > /dev/null"
    echo "jump_to_rel=/scripts/onvif_ptz.sh relative %f %f %f %f > /dev/null"
    echo "get_presets=/scripts/onvif_ptz.sh get_presets"
    echo "set_preset=/scripts/onvif_ptz.sh set_preset %d %s > /dev/null"
    echo "move_preset=/scripts/onvif_ptz.sh goto_preset %d > /dev/null"
    echo "remove_preset=/scripts/onvif_ptz.sh remove_preset %d > /dev/null"
    echo "set_home_position=/scripts/onvif_ptz.sh set_home > /dev/null"
    echo "goto_home_position=/scripts/onvif_ptz.sh goto_home > /dev/null"
  fi

  echo "events=3"
  echo "topic=tns1:VideoSource/MotionAlarm"
  echo "source_name=Source"
  echo "source_type=tt:ReferenceToken"
  echo "source_value=VideoSourceToken"
  echo "input_file=/tmp/onvif_notify_server/motion_alarm"
  echo "topic=tns1:AudioAnalytics/Audio/DetectedSound"
  echo "source_name=AudioSourceConfigurationToken"
  echo "source_type=tt:ReferenceToken"
  echo "source_value=AudioSourceToken"
  echo "input_file=/tmp/onvif_notify_server/sound_detection"
} > $CONF

pidof wsd_simple_server > /dev/null || \
  /usr/bin/wsd_simple_server -i $IFACE -x "http://%s/onvif/device_service" -m "$MODEL" -n "ATOMTech" -p $WSD_PID -d 5 >> $LOG 2>&1
pidof onvif_notify_server > /dev/null || \
  /usr/bin/onvif_notify_server -c $CONF -p $NOTIFY_PID -d 5 >> $LOG 2>&1
/scripts/onvif_event.sh start > /dev/null 2>&1

log "onvif start on $IFACE"
