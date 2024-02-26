#!/bin/sh
# chroot /atom environment

export PATH=/tmp/system/bin:/system/bin:/bin:/sbin:/usr/bin:/usr/sbin
export LD_LIBRARY_PATH=/thirdlib:/system/lib:/tmp:/tmp/system/lib/modules/
PRODUCT_CONFIG=/configs/.product_config
PRODUCT_MODEL=$(awk -F "=" '/PRODUCT_MODEL *=/ {print $2}' $PRODUCT_CONFIG)
APPVER_FILE=/configs/app.ver
APPVER=$(awk -F "=" '/appver *=/ {print $2}' $APPVER_FILE)
HACK_INI=/tmp/hack.ini
export MINIMIZE_ALARM_CYCLE=$(awk -F "=" '/MINIMIZE_ALARM_CYCLE *=/ {print $2}' $HACK_INI)
export FRAMERATE=$(awk -F "=" '/FRAMERATE *=/ {print $2}' $HACK_INI)
if [ "$(awk -F "=" '/ATOM_DEBUG_LOG *=/ {print $2}' $HACK_INI)" = "on" ]; then
  export ASSIS_LOG="/tmp/log/assis.log"
else
  export ASSIS_LOG="/dev/null"
fi
AWS_VIDEO_DISABLE=$(awk -F "=" '/AWS_VIDEO_DISABLE *=/ {print $2}' $HACK_INI)
[ "$AWS_VIDEO_DISABLE" = "on" ] && export ATOMTECH_AWS_ACCESS=disable_video

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

if [ "on" = "$MINIMIZE_ALARM_CYCLE" ]; then
  grep '^alarmInterval=30$' /configs/.user_config || sed -i.old -e 's/^alarmInterval=.*$/alarmInterval=30/' /configs/.user_config
else
  grep '^alarmInterval=300$' /configs/.user_config || sed -i.old -e 's/^alarmInterval=.*$/alarmInterval=300/' /configs/.user_config
fi

[ -f /media/mmc/atom-debug ] && exit 0

/system/bin/ver-comp
/system/bin/assis >> $ASSIS_LOG 2>&1 &
/system/bin/hl_client >> /dev/null 2>&1 &
LD_PRELOAD=/tmp/system/lib/modules/libcallback.so /system/bin/iCamera_app >> /var/run/atomapp &
[ "AC1" = "$PRODUCT_MODEL" -o "ATOM_CamV3C" = "$PRODUCT_MODEL" ] && /system/bin/dongle_app >> /dev/null &
