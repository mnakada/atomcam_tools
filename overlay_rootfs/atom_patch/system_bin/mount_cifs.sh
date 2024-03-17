#!/bin/sh
# tools and chroot /atom environment

LOCKFILE=/tmp/mount_cifs.lock
HACK_INI=/tmp/hack.ini
STORAGE_CIFS=$(awk -F "=" '/^STORAGE_CIFS *=/ {print $2}' $HACK_INI)
STORAGE_CIFSSERVER=$(awk -F "=" '/^STORAGE_CIFSSERVER *=/ {gsub(/\/$/, "", $2); print $2}' $HACK_INI)
STORAGE_CIFSUSER=$(awk -F "=" '/^STORAGE_CIFSUSER *=/ {print $2}' $HACK_INI)
STORAGE_CIFSPASSWD=$(awk -F "=" '/^STORAGE_CIFSPASSWD *=/ {print $2}' $HACK_INI)

if [ "$STORAGE_CIFS" = "on" -o "$STORAGE_CIFS" = "alarm" -o "$STORAGE_CIFS" = "record" ] && [ "$STORAGE_CIFSSERVER" != "" ]; then
  mount | grep "$STORAGE_CIFSSERVER" > /dev/null && exit
  while [ -f $LOCKFILE ] ; do
    sleep 0.5
  done
  touch $LOCKFILE
  if mount | grep "$STORAGE_CIFSSERVER" > /dev/null ; then
    /bin/busybox rm -f $LOCKFILE
    exit
  fi
  for VER in 3.0 2.1 2.0
  do
    if [ -d /atom ] ; then
      if mount -t cifs -ousername=$STORAGE_CIFSUSER,password=$STORAGE_CIFSPASSWD,vers=$VER,iocharset=utf8 $STORAGE_CIFSSERVER /atom/mnt ; then
        /bin/busybox rm -f $LOCKFILE
        exit 0
      fi
    else
      if LD_LIBRARY_PATH=/tmp/system/lib:/tmp/system/usr/lib:/tmp/system/usr/lib/samba /tmp/system/lib/ld.so.1 /tmp/system/bin/busybox mount -t cifs -ousername=$STORAGE_CIFSUSER,password=$STORAGE_CIFSPASSWD,vers=$VER,iocharset=utf8 $STORAGE_CIFSSERVER /mnt ; then
        /bin/busybox rm -f $LOCKFILE
        exit 0
      fi
    fi
  done
  /bin/busybox rm -f $LOCKFILE
fi
exit -1
