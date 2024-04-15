#!/bin/sh

echo "Cache-Control: no-cache"
echo "Content-Type: text/plain"
echo ""

if [ "$REQUEST_METHOD" = "POST" ]; then
  awk '
  BEGIN {
    RS="[{},]";
  }
  /^$/ { next; }
  /appver/ { next; }
  /PRODUCT_MODEL/ { next; }
  /HOSTNAME/ { next; }
  /KERNELVER/ { next; }
  /ATOMHACKVER/ { next; }
  {
    gsub(/\"[ \t]*:[ \t]*\"?/, "=");
    gsub(/\"/, "");
    print;
  }
  ' > /media/mmc/hack.ini
  cat /media/mmc/hack.ini > /tmp/hack.ini
  exit 0
fi

awk '/^appver/ { print }' /atom/configs/app.ver
awk '/^PRODUCT_MODEL/ { print }' /atom/configs/.product_config
echo "HOSTNAME=`hostname`"
echo "KERNELVER=`uname -a`"
echo "ATOMHACKVER=`cat /etc/atomhack.ver`"
cat /tmp/hack.ini
