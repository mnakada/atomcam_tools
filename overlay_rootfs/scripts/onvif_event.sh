#!/bin/sh

EVENT_DIR=/tmp/onvif_notify_server
LOG_DIR=/tmp/log
LOG=$LOG_DIR/onvif_event.log
PID=/var/run/onvif_event.pid
HACK_INI=/tmp/hack.ini

log()
{
  mkdir -p $LOG_DIR
  echo `date +"%Y/%m/%d %H:%M:%S"` ": $*" >> $LOG
}

pulse()
{
  file="$1"
  [ "$file" = "" ] && return
  hold=20
  until_file=$EVENT_DIR/$file.until
  until_time=$((`date +%s` + hold))
  mkdir -p $EVENT_DIR
  echo $until_time > $until_file
  touch $EVENT_DIR/$file
  (
    sleep $hold
    now=`date +%s`
    current_until=`cat $until_file 2> /dev/null`
    [ "$current_until" != "" ] && [ "$now" -lt "$current_until" ] && exit 0
    rm -f $EVENT_DIR/$file $until_file
    log "clear $file timeout"
  ) > /dev/null 2>&1 &
  log "trigger $file hold=${hold}s"
}

clear_event()
{
  file="$1"
  [ "$file" = "" ] && return
  rm -f $EVENT_DIR/$file $EVENT_DIR/$file.until
  log "clear $file"
}

get_ini()
{
  awk -F "=" -v key="$1" '$1 ~ "^[ \t]*" key "[ \t]*$" { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' $HACK_INI
}

all_as_motion()
{
  [ "$(get_ini ONVIF_EVENT_ALL_AS_MOTION)" != "off" ]
}

trigger()
{
  case "$1" in
    motion|motion_alarm)
      pulse motion_alarm
    ;;
    sound|sound_detection|caution|fire|co|smoke|alarm_sound)
      pulse sound_detection
      all_as_motion && pulse motion_alarm
    ;;
    *)
      pulse motion_alarm
    ;;
  esac
}

clear()
{
  case "$1" in
    motion|motion_alarm)
      clear_event motion_alarm
    ;;
    sound|sound_detection|caution|fire|co|smoke|alarm_sound)
      clear_event sound_detection
      all_as_motion && clear_event motion_alarm
    ;;
    *)
      clear_event motion_alarm
    ;;
  esac
}

start_event()
{
  mkdir -p $LOG_DIR $EVENT_DIR
  touch $LOG
  chmod 666 $LOG > /dev/null 2>&1
  log "event bridge ready"
}

stop_event()
{
  rm -f $PID
  rm -f $EVENT_DIR/motion_alarm $EVENT_DIR/sound_detection
  rm -f $EVENT_DIR/motion_alarm.until $EVENT_DIR/sound_detection.until
  log "event bridge stop"
}

case "$1" in
  trigger)
    trigger "$2"
  ;;
  clear)
    clear "$2"
  ;;
  start)
    start_event
  ;;
  stop)
    stop_event
  ;;
  restart)
    stop_event
    start_event
  ;;
  *)
    echo "Usage: $0 {trigger|clear <motion|sound|caution>|start|stop|restart}"
    exit 1
  ;;
esac
