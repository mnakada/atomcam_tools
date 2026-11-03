#!/bin/sh

# PTZ glue for onvif_simple_server (see onvif.sh for the command wiring).
# Moves go through the cam's command socket: "move" is absolute, "relmove" a native relative
# step move in degrees (+ = right / up in the image), "contmove"/"contstop" a continuous drive.
# The cam is tiny and Frigate polls GetStatus in a tight loop, so the status hooks are wired
# straight to the socket in onvif.sh and never come through here; this script is for moves.

HACK_INI=/tmp/hack.ini
MOVING_PREFIX=/tmp/onvif_ptz_moving
CONT_FILE=/tmp/onvif_ptz_cont   # "<h> <v> <speed> <nonce>": the continuous move in flight, h/v = -1/0/1 (right/up = 1)
CAL_FILE=/tmp/onvif_ptz_cal     # "<h> <v>": direction (+1/-1 in reported pan/tilt) of the SDK's raw command 1
PRI=2                           # 0 (cancels everything) - 3
CONT_TIMEOUT=6                  # a continuous move nobody stops is stopped after this many seconds
SLOW_SPEED=3                    # the SDK runs cam speeds 1-3 at one and the same pace (30 deg in ~0.69 s; 5 / 7 / 9: 0.49 / 0.35 / 0.29 s)
CONT_SPEED_CAP=3                # continuous drives stay on that slow plateau (~47 deg/s): the watchdog margin was sized for it
CONT_MARGIN=30                  # ... and so is one that gets this close (degrees) to the end of travel: ~47 deg/s, 0.2 s polls, ~10 deg coast

# one "<number>=<name> <pan> <tilt> 0" per line, which is what the server's get_presets expects
PRESET_FILE=/media/mmc/onvif_presets.txt
MAX_PRESETS=32
HOME_NAME=home

MAX_SPEED=$(awk -F "=" '$1 ~ "^[ \t]*ONVIF_MAX_SPEED[ \t]*$" { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' $HACK_INI 2> /dev/null)
case "$MAX_SPEED" in
  [1-9]) ;;
  *) MAX_SPEED=5 ;;
esac

raw_pos()
{
  /scripts/cmd move 2> /dev/null | awk 'NF >= 2 { print $1, $2; exit }'
}

# ONVIF speed (0, 1] (empty / <= 0 = not given) -> cam speed. Speeds 1..SLOW_SPEED are all the same pace, so the
# ONVIF range is spread over SLOW_SPEED+1..MAX_SPEED instead of wasting most of it on the floor.
cam_speed()
{
  awk -v s="$1" -v m="$MAX_SPEED" -v f="$SLOW_SPEED" 'BEGIN {
    s += 0;
    if(m <= f || s <= 0 || s >= 1) { print m; exit }
    v = f + int(s * (m - f) + 0.999);
    if(v < f + 1) v = f + 1;
    if(v > m) v = m;
    print v;
  }'
}

moving_flags()
{
  for f in $MOVING_PREFIX.*; do
    [ -e "$f" ] && return 0
  done
  return 1
}

stop_cont()
{
  [ -f $CONT_FILE ] || return
  rm -f $CONT_FILE
  /scripts/cmd contstop > /dev/null 2>&1
}

# a priority 0 move cancels the one in flight; aim it at where we are so the head settles there
cancel_inflight()
{
  moving_flags || return
  set -- $(raw_pos)
  [ "$2" != "" ] && /scripts/cmd move "$1" "$2" 9 0 > /dev/null 2>&1
}

stop_move()
{
  stop_cont
  cancel_inflight
}

# the cam dismisses a move while another one runs at the same priority, so the newest request first
# cancels whatever is in flight, then retries for a moment in case the cancel is still settling.
# One flag file per running move, so a cancelled move can't clear the flag of the move that replaced it.
run_move()
{
  stop_cont
  cancel_inflight
  touch $MOVING_PREFIX.$$
  trap "rm -f $MOVING_PREFIX.$$" EXIT
  tries=0
  while : ; do
    out=$(/scripts/cmd "$@" 2> /dev/null)
    case "$out" in
      *dismiss*) ;;
      *) break ;;
    esac
    tries=$((tries + 1))
    [ $tries -ge 10 ] && break
    sleep 0.15
  done
}

move_abs()
{
  pan=$1
  tilt=$2
  [ "$pan" = "" ] && pan=0
  [ "$tilt" = "" ] && tilt=0
  run_move move "$pan" "$tilt" "$3" $PRI
}

move_rel()
{
  dpan=$1
  dtilt=$2
  [ "$dpan" = "" ] && dpan=0
  [ "$dtilt" = "" ] && dtilt=0
  run_move relmove "$dpan" "$dtilt" "$3" $PRI
}

# fixed 30 degree nudge per unit of velocity: only used when a continuous move can't be calibrated
step()
{
  value=$(awk -v v="$1" 'BEGIN { d = int((v + 0.05) * 30); if(d < 1) d = 1; print d }')
  speed=$(cam_speed "$1")
  case "$2" in
    left)  move_rel -$value 0 $speed ;;
    right) move_rel $value 0 $speed ;;
    up)    move_rel 0 $value $speed ;;
    down)  move_rel 0 -$value $speed ;;
  esac
}

# Which way does the SDK's raw direction command 1 drive the head? It depends on the mounting, so
# measure it once per boot with a short blip on both axes (not near the ends of travel).
calibrate()
{
  [ -f $CAL_FILE ] && return 0
  set -- $(raw_pos)
  [ "$2" = "" ] && return 1
  p0=$1
  t0=$2
  awk -v p="$p0" -v t="$t0" 'BEGIN { exit !(p > 25 && p < 330 && t > 25 && t < 155) }' || return 1
  /scripts/cmd contmove 1 1 1 $PRI > /dev/null 2>&1
  sleep 0.4
  /scripts/cmd contstop > /dev/null 2>&1
  sleep 0.8
  set -- $(raw_pos)
  [ "$2" = "" ] && return 1
  res=$(awk -v p0="$p0" -v t0="$t0" -v p="$1" -v t="$2" 'BEGIN {
    dp = p - p0;
    dt = t - t0;
    if((dp > 0.3 || dp < -0.3) && (dt > 0.3 || dt < -0.3)) printf("%d %d\n", (dp > 0) ? 1 : -1, (dt > 0) ? 1 : -1);
  }')
  move_abs "$p0" "$t0" 5
  [ "$res" = "" ] && return 1
  echo "$res" > $CAL_FILE
}

# $1 = pan|tilt, $2 = signed velocity -1..1 (0 = stop that axis). The server runs one hook per axis
# back to back, so the axes are merged through CONT_FILE; the last hook of a request wins.
cont_axis()
{
  axis=$1
  h=0
  v=0
  sp=$(cam_speed "")
  [ -f $CONT_FILE ] && read h v sp nonce < $CONT_FILE
  dir=$(awk -v x="$2" 'BEGIN { x += 0; print (x > 0) ? 1 : ((x < 0) ? -1 : 0) }')
  mag=$(awk -v x="$2" 'BEGIN { x += 0; if(x < 0) x = -x; print x }')
  if [ "$axis" = pan ]; then h=$dir; else v=$dir; fi
  if [ "$h" = 0 ] && [ "$v" = 0 ]; then
    stop_cont
    return
  fi
  [ "$dir" != 0 ] && sp=$(cam_speed "$mag")
  [ "$sp" -gt $CONT_SPEED_CAP ] && sp=$CONT_SPEED_CAP
  if ! calibrate; then
    if [ "$dir" != 0 ]; then
      if [ "$axis" = pan ]; then
        if [ "$dir" = 1 ]; then step "$mag" right; else step "$mag" left; fi
      else
        if [ "$dir" = 1 ]; then step "$mag" up; else step "$mag" down; fi
      fi
    fi
    return
  fi
  read ch cv < $CAL_FILE
  rh=0
  rv=0
  if [ "$h" != 0 ]; then
    if [ "$h" = "$ch" ]; then rh=1; else rh=2; fi
  fi
  if [ "$v" != 0 ]; then
    if [ "$v" = "$cv" ]; then rv=1; else rv=2; fi
  fi
  cancel_inflight
  echo "$h $v $sp $$" > $CONT_FILE
  /scripts/cmd contmove $rh $rv $sp $PRI > /dev/null 2>&1
  # watchdog (the newest request owns the nonce): stop before the end of travel, because nothing says the
  # SDK soft-limits a continuous drive (~47 deg/s at speed 1), and stop anyway if nobody sends a Stop
  me=$$
  (
    n=0
    while [ $n -lt $((CONT_TIMEOUT * 5)) ]; do
      sleep 0.2
      n=$((n + 1))
      [ -f $CONT_FILE ] || exit
      read h2 v2 s2 n2 < $CONT_FILE
      [ "$n2" = "$me" ] || exit
      set -- $(/scripts/cmd ptzstatus 2> /dev/null | tr ',' ' ')
      [ "$2" = "" ] && continue
      if [ "$4" = 0 ]; then   # the drive ended on its own
        rm -f $CONT_FILE
        exit
      fi
      lim=0
      if [ "$h2" = 1 ] && [ "$1" -ge $((355 - CONT_MARGIN)) ]; then lim=1; fi
      if [ "$h2" = -1 ] && [ "$1" -le $CONT_MARGIN ]; then lim=1; fi
      if [ "$v2" = 1 ] && [ "$2" -ge $((180 - CONT_MARGIN)) ]; then lim=1; fi
      if [ "$v2" = -1 ] && [ "$2" -le $CONT_MARGIN ]; then lim=1; fi
      if [ $lim = 1 ]; then
        stop_cont
        exit
      fi
    done
    stop_cont
  ) > /dev/null 2>&1 < /dev/null &
}

# the preset called "home" doubles as the ONVIF home position (Frigate returns to it after tracking)
preset_num_by_name()
{
  awk -F '[= ]' -v n="$1" '$2 == n { print $1; exit }' $PRESET_FILE 2> /dev/null
}

# $1 = preset number (< 1 = new), $2 = name
save_preset()
{
  num=$1
  name=$2
  [ "$name" = "" ] && return
  set -- $(raw_pos)
  [ "$2" = "" ] && return
  pan=$1
  tilt=$2
  touch $PRESET_FILE
  if ! [ "$num" -ge 1 ] 2> /dev/null; then
    [ `wc -l < $PRESET_FILE` -ge $MAX_PRESETS ] && return
    num=$(awk -F= 'BEGIN { n = 0 } $1 + 0 > n { n = $1 + 0 } END { print n + 1 }' $PRESET_FILE)
  fi
  { grep -v "^$num=" $PRESET_FILE; echo "$num=$name $pan $tilt 0"; } > $PRESET_FILE.tmp
  mv -f $PRESET_FILE.tmp $PRESET_FILE
}

goto_preset()
{
  set -- $(awk -F '[= ]' -v n="$1" '$1 == n { print $3, $4; exit }' $PRESET_FILE 2> /dev/null)
  [ "$2" != "" ] && move_abs "$1" "$2" "$(cam_speed "")"
}

remove_preset()
{
  [ -f $PRESET_FILE ] || return
  grep -v "^$1=" $PRESET_FILE > $PRESET_FILE.tmp
  mv -f $PRESET_FILE.tmp $PRESET_FILE
}

case "$1" in
  get_position)
    /scripts/cmd ptzstatus 2> /dev/null | awk -F, 'NF >= 3 { print $1 "," $2 "," $3 }'
    ;;
  is_moving)
    /scripts/cmd ptzstatus 2> /dev/null | awk -F, 'NF >= 4 { print $4 + 0; ok = 1 } END { if(!ok) print 0 }'
    ;;
  move_left)
    cont_axis pan -$2
    ;;
  move_right)
    cont_axis pan $2
    ;;
  move_up)
    cont_axis tilt $2
    ;;
  move_down)
    cont_axis tilt -$2
    ;;
  absolute)
    # x y z speed
    move_abs "$2" "$3" "$(cam_speed "$5")"
    ;;
  relative)
    # dx dy dz speed
    move_rel "$2" "$3" "$(cam_speed "$5")"
    ;;
  stop)
    stop_move
    ;;
  get_presets)
    cat $PRESET_FILE 2> /dev/null
    ;;
  set_preset)
    save_preset "$2" "$3"
    ;;
  set_home)
    save_preset "$(preset_num_by_name $HOME_NAME)" $HOME_NAME
    ;;
  remove_preset)
    remove_preset "$2"
    ;;
  goto_preset)
    goto_preset "$2"
    ;;
  goto_home)
    goto_preset "$(preset_num_by_name $HOME_NAME)"
    ;;
esac
