#!/bin/bash
#
# Tests for a running ATOM Cam with atomcam_tools.
# 実機の ATOM Cam に対するテスト
#
# usage: tests/device/run.sh [-d] [-m] [-L] [-R] [-k] [-s suite] [host]
#   host : default $ATOMCAM_HOST or atomcam.local
#   -d   : also run disruptive checks (they change the camera state and restore it)
#   -m   : with -d, also move the motor. The pointing may shift by the backlash
#   -L   : also stream over RTSP and WebRTC with a timelapse and record the memory and load
#          (about 3 minutes; needs ffprobe and python3 aiortc)
#   -R   : also reboot the camera and check it again after the reboot
#   -k   : count a known issue as a failure (for a build that should have the fix)
#   -s   : test suite to run (default all)
# env  : ZOMBIE_WAIT    seconds to wait before re-checking zombie processes (default 10)
#        ATOMCAM_AUTH   user:password for the web UI when DIGEST is set in hack.ini
#
# Suites are the directories here. Each runs its [0-9]*.sh in name order, and hooks.sh of
# every suite is sourced first.
#   core/ : the atomcam_tools features
#
# SSH logs in as root with public key auth (authorized_keys on the SD card). For a key with a
# passphrase, add it to ssh-agent first.
# Exit status: 0 if no check failed, 1 otherwise.

DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/lib.sh"

usage() { echo "usage: $0 [-d] [-m] [-L] [-R] [-k] [-s suite] [host]" >&2; exit 2; }

DISRUPTIVE=0
MOTOR=0
LOAD=0
REBOOT=0
STRICT=0
SUITES=
while getopts dmLRks: opt; do
  case $opt in
    d) DISRUPTIVE=1 ;;
    m) MOTOR=1 ;;
    L) LOAD=1 ;;
    R) REBOOT=1 ;;
    k) STRICT=1 ;;
    s) [ -d "$DIR/$OPTARG" ] || usage
       SUITES=$OPTARG ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
# core first, then the other suites in name order
[ -z "$SUITES" ] && SUITES="core $(cd "$DIR" && ls -d */ | tr -d / | grep -vx core)"

HOST=${1:-${ATOMCAM_HOST:-atomcam.local}}
ZOMBIE_WAIT=${ZOMBIE_WAIT:-10}
SSH="ssh -o BatchMode=yes -o ConnectTimeout=5 -o PubkeyAcceptedKeyTypes=ssh-rsa root@$HOST"

for h in "$DIR"/*/hooks.sh; do
  [ -f "$h" ] && . "$h"
done

echo "=== atomcam device test: $HOST ==="
results=
for suite in $SUITES; do
  ls "$DIR/$suite"/[0-9]*.sh > /dev/null 2>&1 || continue
  echo "--- $suite ---"
  # core/10_base.sh loads hack.ini after checking the network
  [ "$suite" != core ] && [ -z "$INI" ] && load_ini
  p0=$PASS f0=$FAIL s0=$SKIP k0=$KNOWN
  for t in "$DIR/$suite"/[0-9]*.sh; do
    . "$t"
  done
  results="$results$suite: $(counts $((PASS - p0)) $((FAIL - f0)) $((SKIP - s0)) $((KNOWN - k0)))"$'\n'
done

printf '%s' "$results"
summary
[ $FAIL = 0 ]
