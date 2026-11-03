# Hooks of the core suite. Sourced by run.sh before the tests of every suite.
# core スイートのフック（全スイートの実行前に run.sh が読み込む）

# busy hook: a timelapse is recording (the disruptive checks would spoil its frames)
busy_timelapse() { remote '/scripts/cmd timelapse' | tr -d '\0' | grep -q '^file: ' && echo "timelapse is recording"; }
BUSY_HOOKS="$BUSY_HOOKS busy_timelapse"
