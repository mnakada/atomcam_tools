# Timestamp size: libcallback scales the Main HD timestamp by TIMESTAMP_SIZE and logs it to
# tools.log when iCamera_app sets the OSD. The last log line is checked, as the log has no boot
# marker. Read only.
# タイムスタンプの大きさ: tools.log の最後の記録が TIMESTAMP_SIZE と同じか（読み出しのみ）

want=$(ini_get TIMESTAMP_SIZE)
if [ -z "$want" ] || [ "$want" = 100 ]; then
  skip "timestamp: size" "TIMESTAMP_SIZE is ${want:-not set}"
  return 0
fi
if [ "$(remote '[ -f /media/mmc/atom-log ] && echo on')" != on ]; then
  # atom_init.sh sends the libcallback log to tools.log only with this file
  skip "timestamp: size" "no /media/mmc/atom-log: the libcallback log goes to the console"
  return 0
fi

l=$(remote '{ zcat /media/mmc/tools.log.1.gz 2> /dev/null; cat /media/mmc/tools.log; } | grep "^\[timestamp\]" | tail -1')
case "$l" in
  "[timestamp] size $want% "*) pass "timestamp: size ($want%, ${l#*% })" ;;
  "") skip "timestamp: size" "no [timestamp] line in tools.log (rotated out?)" ;;
  *) fail "timestamp: size" "TIMESTAMP_SIZE=$want, tools.log: $l" ;;
esac
