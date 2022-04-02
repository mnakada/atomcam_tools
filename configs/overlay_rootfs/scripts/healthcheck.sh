#!/bin/sh

HACK_INI=/tmp/hack.ini
HEALTHCHECK=$(awk -F "=" '/HEALTHCHECK *=/ {print $2}' $HACK_INI)
HEALTHCHECK_PING_URL=$(awk -F "=" '/HEALTHCHECK_PING_URL *=/ {print $2}' $HACK_INI)
[ "$HEALTHCHECK" != "on" ] || [ "$HEALTHCHECK_PING_URL" == "" ] && exit 0

curl -fsS -m 10 --retry 5 -o /tmp/log/healthcheck.log $HEALTHCHECK_PING_URL