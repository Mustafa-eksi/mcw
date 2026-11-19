#!/usr/bin/env bash
set -euo pipefail

binary=${1:-./mcw}
runtime=$(mktemp -d /tmp/mcw-ipc-test.XXXXXX)
daemon_pid=
trap 'if [[ -n "$daemon_pid" ]]; then kill "$daemon_pid" 2>/dev/null || true; wait "$daemon_pid" 2>/dev/null || true; fi; rm -rf "$runtime"' EXIT

unset WAYLAND_DISPLAY DISPLAY
export XDG_RUNTIME_DIR="$runtime" XDG_SESSION_ID=mcw-ipc-test
export SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software

"$binary" daemon > "$runtime/daemon.log" 2>&1 &
daemon_pid=$!
for attempt in {1..50}; do
    if "$binary" status > /dev/null 2>&1; then break; fi
    sleep 0.1
done

[[ $("$binary" status) == *"bar=visible launcher=hidden"* ]]
[[ $("$binary" show launcher) == "OK launcher=visible" ]]
[[ $("$binary" hide launcher) == "OK launcher=hidden" ]]
[[ $("$binary" toggle launcher) == "OK launcher=visible" ]]
[[ $("$binary" show dialog) == "OK dialog=visible" ]]
[[ $("$binary" hide bar) == "OK bar=hidden" ]]
[[ $("$binary" hide launcher) == "OK launcher=hidden" ]]
[[ $("$binary" hide dialog) == "OK dialog=hidden" ]]
[[ $("$binary" show showcase) == "OK showcase=visible" ]]
[[ $("$binary" hide showcase) == "OK showcase=hidden" ]]
[[ $("$binary" status) == *"showcase=hidden"* ]]
[[ $("$binary" show showcase) == "OK showcase=visible" ]]
[[ $("$binary" show bar) == "OK bar=visible" ]]
[[ $("$binary" stop) == "OK stopping" ]]
wait "$daemon_pid"
daemon_pid=
[[ ! -e "$runtime/mcw-mcw-ipc-test.sock" ]]
echo "Daemon IPC smoke test passed"
