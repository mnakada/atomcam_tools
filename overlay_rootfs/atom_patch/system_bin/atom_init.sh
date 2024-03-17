#!/bin/sh
# chroot /atom environment

export PATH=/tmp/system/bin:/system/bin:/bin:/sbin:/usr/bin:/usr/sbin
export LD_LIBRARY_PATH=/thirdlib:/system/lib:/tmp:/tmp/system/lib/modules/
PRODUCT_CONFIG=/configs/.product_config
PRODUCT_MODEL=$(awk -F "=" '/^PRODUCT_MODEL *=/ {print $2}' $PRODUCT_CONFIG)
APPVER_FILE=/configs/app.ver
APPVER=$(awk -F "=" '/^appver *=/ {print $2}' $APPVER_FILE)
HACK_INI=/tmp/hack.ini
if [ -f /media/mmc/atom-log ]; then
  export ASSIS_LOG="/tmp/log/assis.log"
  export TOOLS_LOG="/media/mmc/tools.log"
else
  export ASSIS_LOG="/dev/null"
  export TOOLS_LOG="/dev/stderr"
fi

insmod /system/driver/tx-isp-t31.ko isp_clk=100000000
if [ "ATOM_CAKP1JZJP" = "$PRODUCT_MODEL" ] ; then
  insmod /system/driver/audio.ko spk_gpio=-1 alc_mode=0 mic_gain=0
else
  insmod /system/driver/audio.ko spk_gpio=-1
fi
insmod /system/driver/avpu.ko
insmod /system/driver/sinfo.ko
insmod /system/driver/sample_pwm_core.ko
insmod /system/driver/sample_pwm_hal.ko
insmod /system/driver/speaker_ctl.ko
[ "ATOM_CAKP1JZJP" = "$PRODUCT_MODEL" ] && insmod /system/driver/sample_motor.ko vstep_offset=0 hmaxstep=2130 vmaxstep=1580

/bin/busybox rm -rf /media/mmc/.Trashes

[ -f /media/mmc/atom-debug ] && exit 0

/system/bin/ver-comp
/system/bin/assis >> $ASSIS_LOG 2>&1 &
/system/bin/hl_client >> /dev/null 2>&1 &
LD_PRELOAD=/tmp/system/lib/modules/libcallback.so /system/bin/iCamera_app >> /var/run/atomapp 2>> /$TOOLS_LOG &
[ "AC1" = "$PRODUCT_MODEL" -o "ATOM_CamV3C" = "$PRODUCT_MODEL" ] && /system/bin/dongle_app >> /dev/null &
