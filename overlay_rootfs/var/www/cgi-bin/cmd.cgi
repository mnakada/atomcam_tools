#!/bin/sh

[ -f /etc/environment ] && . /etc/environment

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
    echo TIMESTAMP=`date +"%Y/%m/%d %X"`
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
          if(h == 1) x = 350 - x;
          if(v == 1) y = 180 - y;
          printf("MOTORPOS=%d %d\n", x, y);
        }
      ' /atom/configs/.user_config
    fi
  fi
  if [ "$NAME" = "kick-homekit" ] ; then
    curl http://localhost:1984/api/homekit
  fi
  if [ "$NAME" = "homekit" ] ; then
    curl http://localhost:1984/api/homekit/pairing
  fi
  if [ "$NAME" = "unpair-homekit" ] ; then
    curl -X DELETE http://localhost:1984/api/homekit/pairing?stream=video0
  fi
fi

if [ "$REQUEST_METHOD" = "POST" ]; then
  PORT=${QUERY_STRING##port=}
  awk '
    BEGIN {
      RS="[{},]";
    }
    /^$/ { next; }
    /\"exec\":\"/ {
      gsub(/^[ \t]*\"exec\":\"/, "");
      gsub(/\"[ \t]*$/, "");
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
