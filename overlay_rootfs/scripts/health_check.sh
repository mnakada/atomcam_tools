#!/bin/sh

HACK_INI=/tmp/hack.ini
MONITORING_NETWORK=$(awk -F "=" '/MONITORING_NETWORK *=/ {print $2}' $HACK_INI)
MONITORING_REBOOT=$(awk -F "=" '/MONITORING_REBOOT *=/ {print $2}' $HACK_INI)
HEALTHCHECK=$(awk -F "=" '/HEALTHCHECK *=/ {print $2}' $HACK_INI)
HEALTHCHECK_PING_URL=$(awk -F "=" '/HEALTHCHECK_PING_URL *=/ {print $2}' $HACK_INI)

for retry in 0 1 2 3 4 5; do
  ifconfig | grep 'Link encap:' | grep -v Loopback || break

  ERR=0
  [ -f /tmp/router_address ] && ROUTER=`cat /tmp/router_address`
  if [ "$ROUTER" = "" ]; then
    ip route | awk '/default/ { print $3 }' > /tmp/router_address
    ROUTER=`cat /tmp/router_address`
  fi
  if [ "$ROUTER" != "" ] && ping -c 1 $ROUTER > /dev/null ; then
    if [ "$HEALTHCHECK" = "on" -a "$HEALTHCHECK_PING_URL" != "" ] ; then
      RES=`curl --ipv4 --max-time 5 --retry 3 --retry-delay 1 --location --silent --show-error --output /dev/null --write-out "%{http_code}" $HEALTHCHECK_PING_URL`
      echo $(date +"%Y/%m/%d %H:%M:%S : ") $RES >> /media/mmc/healthcheck.log
    fi
    exit 0
  fi

  [ "$MONITORING_NETWORK" = "off" ] && exit 0

  if [ $retry -lt 3 ] ; then
    echo $(date +"%Y/%m/%d %H:%M:%S : Network error : ") $retry  >> /media/mmc/healthcheck.log
  else
    echo $(date +"%Y/%m/%d %H:%M:%S : Network restart : ") $retry >> /media/mmc/healthcheck.log
    if [ -x /media/mmc/network_init.sh ] ; then
      /media/mmc/network_init.sh restart >> /media/mmc/healthcheck.log 2>&1
      [ "$?" = "100" ] && exit 0
    else
      if ifconfig | grep wlan0 > /dev/null 2>&1 ; then
        ifconfig wlan0 down
        ifconfig wlan0 up
        killall -USR1 udhcpc
        ps | grep -v grep | grep udhcpc || udhcpc -i wlan0 -x hostname:ATOM -p /var/run/udhcpc.pid -b >> /media/mmc/healthcheck.log 2>&1
      fi
    fi
  fi
  sleep 10
done

[ "$MONITORING_REBOOT" = "off" -o -f /media/mmc/atom-debug ] && exit 0

echo $(date +"%Y/%m/%d %H:%M:%S : retry error -> reboot") >> /media/mmc/healthcheck.log
echo router=$ROUTER >> /media/mmc/healthcheck.log
[ "$ROUTER" != "" ] && ping -c 1 $ROUTER >> /media/mmc/healthcheck.log 2>&1
ping -c 1 8.8.8.8 >> /media/mmc/healthcheck.log 2>&1
ifconfig >> /media/mmc/healthcheck.log 2>&1
df -k >> /media/mmc/healthcheck.log
free >> /media/mmc/healthcheck.log
/scripts/cmd timelapse stop
sleep 3
sync
reboot

