# Timestamp size: libcallback scales the Main HD timestamp by TIMESTAMP_SIZE at boot and when it
# is changed from the web UI. "timestamp" returns the size that is applied. Read only.
# タイムスタンプの大きさ: 反映されている大きさが TIMESTAMP_SIZE と同じか（読み出しのみ）

want=$(ini_get TIMESTAMP_SIZE)
want=${want:-100}
got=$(remote '/scripts/cmd timestamp' | tr -d '\0\r\n')
if [ "$got" = "$want" ]; then
  pass "timestamp: size ($want%)"
else
  fail "timestamp: size" "TIMESTAMP_SIZE=$want, applied: ${got:-no answer}"
fi
