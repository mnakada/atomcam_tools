#!/bin/sh

echo "Cache-Control: no-cache"
echo "Content-Type: application/octet-stream"
echo ""

if [ "$REQUEST_METHOD" = "POST" ]; then
  cat > /media/mmc/watermark.bgra
  echo "watermark update" | /usr/bin/nc localhost:4000
  exit 0
fi

[ -f /media/mmc/watermark.bgra ] && cat /media/mmc/watermark.bgra
