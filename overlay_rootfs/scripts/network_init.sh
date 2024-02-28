#!/bin/sh

if [ "$1" = "stop" -o "$1" = "restart" ] ; then
  killall -SIGKILL wpa_supplicant
  killall -SIGKILL udhcpc
  [ "$1" = "stop" ] && exit 0
fi

devmem 0x10011110 32 0x6e094800
devmem 0x10011138 32 0x300
devmem 0x10011134 32 0x300

ifconfig lo up

[ -x /media/mmc/network_init.sh ] && /media/mmc/network_init.sh start && exit

VENDERID="0x024c"
if [ -f /atom/system/driver/mmc_detect_test.ko ]; then
  insmod /atom/system/driver/mmc_detect_test.ko
  while [ ! -f /sys/bus/mmc/devices/mmc1\:0001/mmc1\:0001\:1/vendor ]; do
    sleep 0.1
  done
  VENDERID=`cat /sys/bus/mmc/devices/mmc1\:0001/mmc1\:0001\:1/vendor`
fi
if [ "0x024c" = "$VENDERID" ]; then
  insmod /atom/system/driver/rtl8189ftv.ko
elif [ "0x007a" = "$VENDERID" ]; then
  if [ -f /atom/therdlib/atbm603x_wifi_sdio.ko ] ; then
    insmod /atom/therdlib/atbm603x_wifi_sdio.ko
  elif [ -f /atom/system/driver/atbm603x_wifi_sdio.ko ] ; then
    [ -f /atom/usr/share/atbm603x_conf/atbm_txpwer_dcxo_cfg.txt ] && cp /atom/usr/share/atbm603x_conf/atbm_txpwer_dcxo_cfg.txt /tmp
    [ -f /atom/usr/share/atbm603x_conf/set_rate_power.txt ] && cp /atom/usr/share/atbm603x_conf/set_rate_power.txt /tmp
    insmod /atom/system/driver/atbm603x_wifi_sdio.ko
    if [ ! -f /sys/module/atbm603x_wifi_sdio/parameters/fw_ver ]; then
      sync
      echo 3 > /proc/sys/vm/drop_caches
      insmod /atom/system/driver/atbm603x_wifi_sdio.ko
    fi
  fi
  echo "LOG_ERR=OFF LOG_SCAN=OFF" > /sys/module/atbm603x_wifi_sdio/atbmfs/atbm_printk_mask 2> /dev/null
elif [ "0x5653" = "$VENDERID" ]; then
  insmod /atom/system/driver/ssv6x5x.ko stacfgpath=/atom/system/driver/ssv6x5x-wifi.cfg
elif [ "0x424c" = "$VENDERID" ]; then
    insmod /atom/system/driver/bl_fdrv.ko
fi

if [ -f /media/mmc/wpa_supplicant.conf ] ; then
  cat /media/mmc/wpa_supplicant.conf > /configs/etc/wpa_supplicant.conf
else
  USER_CONFIG=/atom/configs/.user_config
  SSID=$(awk -F "=" '/\[NET\]/ { f = 1; } /ssid=/ {if(!f) next; gsub(/\/$/, "", $2); print $2}' $USER_CONFIG)
  PSK=$(awk -F "=" '/\[NET\]/ { f = 1; } /password=/ {if(!f) next; gsub(/\/$/, "", $2); print $2}' $USER_CONFIG)
  cat > /configs/etc/wpa_supplicant.conf << EOF
ctrl_interface=/var/run/wpa_supplicant
update_config=1
network={
  ssid="$SSID"
  key_mgmt=WPA-PSK
  pairwise=CCMP TKIP
  group=CCMP TKIP WEP104 WEP40
  psk="$PSK"
  scan_ssid=1
}
EOF
fi

count=0
while ! ip link | grep wlan0 > /dev/null
do
  sleep 0.5
  let count++
  [ 20 -le $count ] && break
done

HWADDR=$(awk -F "=" '/(CONFIG_INFO|NETRELATED_MAC)=/ { print substr($2,1,2) ":" substr($2,3,2) ":" substr($2,5,2) ":" substr($2,7,2) ":" substr($2,9,2) ":" substr($2,11,2); exit;}' /atom/configs/.product_config)
ifconfig wlan0 hw ether $HWADDR up
wpa_supplicant -f /tmp/log/wpa_supplicant.log -D nl80211 -i wlan0 -c /configs/etc/wpa_supplicant.conf -B
udhcpc -i wlan0 -x hostname:atomcam -p /var/run/udhcpc.pid -b &

count=0
while ! ifconfig wlan0 | grep 'inet addr' > /dev/null
do
  sleep 0.5
  let count++
  [ 20 -le $count ] && break
done
