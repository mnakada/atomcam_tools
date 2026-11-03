# Common functions for the device tests. Sourced by run.sh.
# 実機テストの共通関数（run.sh から読み込む）
#
# Globals set by run.sh: DIR, HOST, SSH, DISRUPTIVE, MOTOR, LOAD, REBOOT, STRICT, ZOMBIE_WAIT
# Globals set by the tests: INI (hack.ini read through hack_ini.cgi)

PASS=0
FAIL=0
SKIP=0
KNOWN=0

if [ -t 1 ]; then
  GREEN='\e[32m'; RED='\e[31m'; YELLOW='\e[33m'; CYAN='\e[36m'; RESET='\e[0m'
fi
pass() { PASS=$((PASS + 1)); printf "${GREEN}PASS${RESET} %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "${RED}FAIL${RESET} %s\n" "$1"; [ -n "$2" ] && printf '     %s\n' "$2"; }
skip() { SKIP=$((SKIP + 1)); printf "${YELLOW}SKIP${RESET} %s\n" "$1"; [ -n "$2" ] && printf '     %s\n' "$2"; }
known() { KNOWN=$((KNOWN + 1)); printf "${CYAN}KNOWN${RESET} %s\n" "$1"; [ -n "$2" ] && printf '     %s\n' "$2"; }
remote() { $SSH "$1" 2> /dev/null; }

# fail_known NAME DETAIL ISSUE : failure caused by a known issue (reported, with a fix proposed).
# KNOWN (not counted as a failure), or FAIL with -k for a build that should have the fix.
fail_known() {
  if [ $STRICT = 1 ]; then
    fail "$1" "$2 (known issue, should be fixed in this build: $3)"
  else
    known "$1" "$2 (known issue: $3)"
  fi
}

# http PATH [curl options] : request to the web server (digest auth with $ATOMCAM_AUTH=user:password)
curl_config_value() {
  local value=$1
  case $value in
    *$'\n'*|*$'\r'*) return 1 ;;
  esac
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '"%s"' "$value"
}

http() {
  local p=$1
  shift
  if [ -n "$ATOMCAM_AUTH" ]; then
    local auth_config
    auth_config=$(curl_config_value "$ATOMCAM_AUTH") || {
      printf 'ATOMCAM_AUTH must not contain newline characters\n' >&2
      return 2
    }
    (
      export -n ATOMCAM_AUTH
      printf 'user = %s\ndigest\n' "$auth_config" |
        env -u ATOMCAM_AUTH curl -s --max-time 10 --config - "$@" "http://$HOST$p"
    )
  else
    curl -s --max-time 10 "$@" "http://$HOST$p"
  fi
}

load_ini() { INI=$(http /cgi-bin/hack_ini.cgi); }

# ini_get KEY : value of KEY in hack.ini
ini_get() { echo "$INI" | sed -ne "s/^$1=//p"; }

counts() { echo "$1 passed, $2 failed, $3 skipped, $4 known"; }
summary() { echo "=== $1$(counts $PASS $FAIL $SKIP $KNOWN) ==="; }

# busy : the reasons not to disturb the camera now, from the hooks in BUSY_HOOKS (set by */hooks.sh)
busy() { local h; for h in $BUSY_HOOKS; do $h; done; }

# abort MESSAGE : stop the remaining tests
abort() { summary "aborted: $1: "; exit 1; }
