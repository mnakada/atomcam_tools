#!/bin/sh

echo "Cache-Control: no-cache"
echo "Content-Type: text/plain"
echo ""

if [ "$REQUEST_METHOD" = "GET" ]; then
  NAME=${QUERY_STRING##name=}
  if [ "$NAME" = "" -o "$NAME" = "latest-ver" ] ; then
    latest=`curl -w "%{redirect_url}" -s -o /dev/null https://github.com/mnakada/atomcam_tools/releases/latest`
    echo LATESTVER=${latest##*Ver.}
  fi
  if [ "$NAME" = "" -o "$NAME" = "status" ] ; then
    echo TIMELAPSE=`echo "timelapse" | nc localhost:4000`
  fi
  if [ "$NAME" = "" -o "$NAME" = "status" ] ; then
    export TZ=`cat /tmp/TZ`
    echo TIMESTAMP=`date +"%Y/%m/%d %X"`
  fi
  if [ "$NAME" = "" -o "$NAME" = "status" ] ; then
    res=`echo center | nc localhost:4000`
    echo CENTER=$res
  fi
  if [ "$NAME" = "" -o "$NAME" = "status" ] ; then
    res=`echo video flip | nc localhost:4000`
    echo FLIP=$res
  fi
  if [ "$NAME" = "" -o "$NAME" = "media-size" ] ; then
    df -k /media/mmc | awk '/\/media\/mmc/ { printf("MEDIASIZE=%d %d\n", $4, $2); }'
  fi
  if [ "$NAME" = "" -o "$NAME" = "status" ] ; then
    if [ -f /tmp/motor_initialize_done ] ; then
      res=`echo move | nc localhost:4000`
      [ "$res" = "error" ] || echo MOTORPOS=$res
    else
      awk '
        BEGIN {
          FS = "=";
          x = 0;
          y = 0;
        }
        /slide_x/ {
          x = $2 / 100;
        }
        /slide_y/ {
          y = $2 / 100;
        }
        /horSwitch/ {
          h = $2;
        }
        /verSwitch/ {
          v = $2;
        }
        END {
          if(h == 1) x = 355 - x;
          if(v == 1) y = 180 - y;
          printf("MOTORPOS=%f %f %d %d 0\n", x, y, h, v);
        }
      ' /atom/configs/.user_config
    fi
  fi
fi

if [ "$REQUEST_METHOD" = "POST" ]; then
  PORT=${QUERY_STRING##port=}
  awk '
    BEGIN {
      RS="[{},]";
    }
    /^$/ { next; }
    /\"exec\"\s*:\s*\"/ {
      gsub(/^\s*\"exec\"\s*:\s*\"/, "");
      gsub(/\"\s*$/, "");
      print $0;
      fflush();
    }
  ' | (
    if [ "$PORT" = "socket" ]; then
      /usr/bin/nc localhost:4000
    else
      cat >> /var/run/webcmd
      read ack < /var/run/webres
      echo $ack
    fi
  )
fi
