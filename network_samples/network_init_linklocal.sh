#!/bin/sh
# Place it in the top-directory of the SD-Card with the name network_init.sh.

case "$1" in
  start)
    devmem 0x10000040 32 0x0b000FFF

    HOSTADDR=$(awk -F "=" '/(CONFIG_INFO|NETRELATED_MAC)=/ { printf("%s:%s:%s:%s:%s:%02X\n", substr($2,1,2), substr($2,3,2), substr($2,5,2), substr($2,7,2), substr($2,9,2), (("0x" substr($2,11,2)) + 1) % 255) ; exit;}' /atom/configs/.product_config)
    DEVADDR=$(awk -F "=" '/(CONFIG_INFO|NETRELATED_MAC)=/ { printf("%s:%s:%s:%s:%s:%02X\n", substr($2,1,2), substr($2,3,2), substr($2,5,2), substr($2,7,2), substr($2,9,2), (("0x" substr($2,11,2)) + 2) % 255) ; exit;}' /atom/configs/.product_config)
    modprobe g_ncm host_addr=$HOSTADDR dev_addr=$DEVADDR
    modprobe rndis_host

    count=0
    while ! ip link | grep usb0 > /dev/null
    do
      sleep 0.5
      let count++
      [ 20 -le $count ] && break
    done

    ifconfig usb0 up
    /usr/sbin/avahi-autoipd -D --no-drop-root usb0

    count=0
    while ! ifconfig usb0:avahi | grep 'inet addr' > /dev/null
    do
      sleep 0.5
      let count++
      [ 20 -le $count ] && exit 1 # fallback to WiFi
    done

    exit 0
  ;;
  restart)
    ifconfig | grep usb0:avahi && exit 100 # skip error reboot
    ifconfig usb0:avahi down
    ifconfig usb0 down
    ifconfig usb0 up
    /usr/sbin/avahi-autoipd -k usb0
    /usr/sbin/avahi-autoipd -D --no-drop-root usb0

    exit 100 # skip error reboot
  ;;
  *)
    echo "Usage: $0 (start|restart)"
    exit 1
esac

exit $?
