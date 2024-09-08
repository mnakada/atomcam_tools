#!/bin/sh
# chroot /atom environment

export PATH=/tmp/system/bin:/system/bin:/bin:/sbin:/usr/bin:/usr/sbin
export LD_LIBRARY_PATH=/thirdlib:/system/lib:/tmp:/tmp/system/lib/modules/
PRODUCT_CONFIG=/configs/.product_config
PRODUCT_MODEL=$(awk -F "=" '/^PRODUCT_MODEL *=/ {print $2}' $PRODUCT_CONFIG)
if [ -f /media/mmc/atom-log ]; then
  export ASSIS_LOG="/tmp/log/assis.log"
  export TOOLS_LOG="/media/mmc/tools.log"
else
  export ASSIS_LOG="/dev/null"
  export TOOLS_LOG="/dev/console"
fi

insmod /system/driver/tx-isp-t31.ko isp_clk=220000000
insmod /system/driver/audio.ko spk_gpio=-1 alc_mode=0 mic_gain=0
ubootddr=`sed -n '30p' /proc/jz/clock/clocks | cut -d ' ' -f 7`
if [[ "540.000MHz" == $ubootddr ]]; then
   insmod /system/driver/avpu.ko clk_name='mpll' avpu_clk=540000000
else
   insmod /system/driver/avpu.ko
fi
insmod /system/driver/sinfo.ko
insmod /system/driver/sample_pwm_core.ko
insmod /system/driver/sample_pwm_hal.ko
insmod /system/driver/speaker_ctl.ko

cp /atom/system/driver/*.txt /tmp/ 2> /dev/null
sync

[ -f /media/mmc/atom-debug ] && exit 0

[ ! -f /media/mmc/app.ver ] && /system/bin/ver-comp
[ -f /media/mmc/app.ver ] && cp /media/mmc/app.ver /configs/app.ver

/sbin/syslogd -C2048 -n -S &
count=0
while :
do
  pidof syslogd > /dev/null && break
  sleep 0.5
  let count++
  [ 20 -le $count ] && exit 1
done
/system/bin/assis >> $ASSIS_LOG 2>&1 &
/system/bin/hl_client >> /dev/null 2>&1 &
/system/bin/sinker >> /dev/null 2>&1 &
LD_PRELOAD=/tmp/system/lib/modules/libcallback.so /system/bin/iCamera >> /var/run/atomapp 2>> /$TOOLS_LOG &
