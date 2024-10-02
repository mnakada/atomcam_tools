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
  {
    gsub(/\"[ \t]*:[ \t]*\"?/, "=");
    gsub(/\"/, "");
    print;
  }
  ' > /media/mmc/video_isp.conf
  echo 3 > /proc/sys/vm/drop_caches
  exit 0
fi

cat /media/mmc/video_isp.conf
