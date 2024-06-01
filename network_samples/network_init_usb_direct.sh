#!/bin/sh
# Place it in the top-directory of the SD-Card with the name network_init.sh.

HACK_INI=/media/mmc/hack.ini
HOSTNAME=$(tail /media/mmc/hostname)

case "$1" in
  start)

    devmem 0x13500000 32 0x001100cc
    devmem 0x10000040 32 0x0b000096
    devmem 0x10000040 32 0x0b000FFF

    HOSTADDR=$(awk -F "=" '/USB_DIRECT_HOST_ADDR *=/ {print $2}' $HACK_INI)
    [ "$HOST_ADDR" == ""] && HOSTADDR=$(echo "$HOSTNAME"|md5sum|sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\).*$/02:\1:\2:\3:\4:\5/')
    

    USB_DIRECT_MAC_ADDR=$(awk -F "=" '/USB_DIRECT_MAC_ADDR *=/ {print $2}' $HACK_INI)
    [ "$USB_DIRECT_MAC_ADDR" == "" ] && USB_DIRECT_MAC_ADDR=$(awk -F "=" '/(CONFIG_INFO|NETRELATED_MAC)=/ { printf("%s:%s:%s:%s:%s:%02X\n", substr($2,1,2), substr($2,3,2), substr($2,5,2), substr($2,7,2), substr($2,9,2), (("0x" substr($2,11,2)) + 2) % 255) ; exit;}' /atom/configs/.product_config)


    modprobe g_ncm host_addr=$HOSTADDR dev_addr=$USB_DIRECT_MAC_ADDR iManufacturer=atomcam_tools_ncm
  
    count=0
    while ! ip link | grep usb0 > /dev/null
    do
      sleep 0.5
      let count++
      [ 20 -le $count ] && break
    done


    ifconfig usb0 up

    
    udhcpc -i usb0 -x hostname:ATOM -p /var/run/udhcpc.pid -b

    count=0
    while ! ifconfig usb0 | grep 'inet addr' > /dev/null
    do
      sleep 0.5
      let count++
      [ 20 -le $count ] && exit 1 # fallback to WiFi
    done


    exit 0
  ;;
  restart)
   ifconfig usb0 down
    ifconfig usb0 up
    killall -USR1 udhcpc
    ps | grep -v grep | grep udhcpc || udhcpc -i usb0 -x hostname:ATOM -p /var/run/udhcpc.pid -b

    exit 0
  ;;
  *)
    echo "Usage: $0 (start|restart)"
    exit 1
esac

exit $?
