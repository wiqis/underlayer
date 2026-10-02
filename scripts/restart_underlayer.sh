#!/bin/bash
# restart_underlayer.sh -- stop the dev server and start a fresh one, reliably.
#
# WHY THIS EXISTS.  `pkill` + `nohup ... &` inside a one-shot shell command
# leaves the server dead: the process is killed as the tool's shell session
# tears down.  `setsid` detaches it from the session, but `setsid` still needs
# the new process to outlive the session AND the old one to be gone first, or
# the new one fails to bind :9000 and exits silently.  This script does both in
# the right order, waits for the port to answer, and fails loudly with the log
# if it does not -- so "the server is up" is never an assumption.
#
# Usage: bash scripts/restart_underlayer.sh [port]
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-9000}"
EXE="$ROOT/build/underlayer.exe"
LOG="$ROOT/build/server.log"

cd "$ROOT" || exit 1

pkill -f 'build/underlayer.exe' >/dev/null 2>&1
# Wait for the port to be released.  20 x 0.25s.
for _ in $(seq 1 20); do
    if ! pgrep -f 'build/underlayer.exe' >/dev/null 2>&1; then break; fi
    sleep 0.25
done
if pgrep -f 'build/underlayer.exe' >/dev/null 2>&1; then
    pkill -9 -f 'build/underlayer.exe' >/dev/null 2>&1
    sleep 1
fi

if [ ! -x "$EXE" ]; then
    echo "FAIL: $EXE not found or not executable.  Build it first." >&2
    exit 1
fi

mkdir -p "$ROOT/build"
setsid "$EXE" > "$LOG" 2>&1 < /dev/null &
disown 2>/dev/null

for _ in $(seq 1 40); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/api/health" 2>/dev/null)
    if [ "$code" = "200" ]; then
        pid=$(pgrep -f 'build/underlayer.exe' | head -1)
        echo "up: pid=$pid health=200 port=$PORT log=$LOG"
        exit 0
    fi
    sleep 0.5
done

echo "FAIL: /api/health did not return 200 on port $PORT after 20s." >&2
echo "---- last 30 lines of $LOG ----" >&2
tail -30 "$LOG" >&2
exit 1