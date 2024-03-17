#!/bin/sh

# ex.
# CRUISE_LIST="move 180 90;detect 10 10;move 210 90;follow 10 10;move 240 90;sleep 10;"
#    move <pan> <tilt> [<speed>] Point the camera.
#    detect <wait> <timeout>  If an object is detected, wait.
#    follow <wait> <timeout> [<speed>] If an object is detected, follow it.
#    sleep <wait>  Sleep.

HACK_INI=/tmp/hack.ini
CRUISE=$(awk -F "=" '/^CRUISE *=/ {print $2}' $HACK_INI)
CRUISE_LIST=$(awk -F "=" '/^CRUISE_LIST *=/ {gsub(/^ */, "", $2);gsub(/ *; */, ";", $2);print $2}' $HACK_INI)
[ "$CRUISE" != "on" ] && exit 0

PRODUCT_CONFIG=/atom/configs/.product_config
PRODUCT_MODEL=$(awk -F "=" '/^PRODUCT_MODEL *=/ {print $2}' $PRODUCT_CONFIG)
[ "ATOM_CAKP1JZJP" != "$PRODUCT_MODEL" ] && exit 0

while : ; do
  IFS=";"
  for str in $CRUISE_LIST ; do
    cmd=${str%% *}
    param=${str#* }
    echo `date +"%Y/%m/%d %H:%M:%S"` : $cmd :  $param
    if [ "$cmd" = "move" ] ; then
      echo "$cmd $param" | /usr/bin/nc localhost 4000
    fi
    if [ "$cmd" = "detect" ] ; then
      wait=${param%% *}
      while : ; do
        IFS=" "
        motion=`echo "waitMotion $wait" | /usr/bin/nc localhost 4000`
        if [ "$motion" = "timeout" ] ; then
          break;
        fi
        wait=${param##* }
      done
    fi
    if [ "$cmd" = "follow" ] ; then
      IFS=" "
      set $param
      wait=$1
      wait2=$2
      speed=$3
      [ "$speed" = "" ] && speed=9
      while : ; do
        motion=`echo "waitMotion $wait" | /usr/bin/nc localhost 4000`
        if [ "$motion" = "timeout" ] ; then
          break;
        fi
        set $motion
        if [ "$1" = "detect" ] ; then
          echo "detect move $6 $7 $speed"
          echo "move $6 $7 $speed" | /usr/bin/nc localhost 4000
        fi
        wait=$wait2
      done
      IFS=";"
    fi
    if [ "$cmd" = "sleep" ] ; then
      wait=${param%% *}
      sleep $wait
    fi
  done
done >> /tmp/log/cruise.log
