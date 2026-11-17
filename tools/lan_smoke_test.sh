#!/usr/bin/env bash
# Three separate processes on this machine: one headless match server and two headless
# clients whose bots play a short match over UDP on localhost. Passes if all three report
# the same final score. Usage: tools/lan_smoke_test.sh [godot] [port]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
PORT="${2:-47812}"
LOGS="$(mktemp -d)"
"$GODOT" --headless --path . res://scenes/server/match_server.tscn -- --port="$PORT" --points=3 --win-by=1 --code=SNEAK7 --exit-on-match-end > "$LOGS/server.log" 2>&1 &
SERVER=$!
sleep 2
"$GODOT" --headless --path . res://scenes/game/online_match.tscn -- --join=127.0.0.1:"$PORT" --code=SNEAK7 --autoplay --exit-on-match-end --seed=7 > "$LOGS/home.log" 2>&1 &
HOME_CLIENT=$!
sleep 1
"$GODOT" --headless --path . res://scenes/game/online_match.tscn -- --join=127.0.0.1:"$PORT" --code=SNEAK7 --autoplay --exit-on-match-end --seed=8 > "$LOGS/away.log" 2>&1 &
AWAY_CLIENT=$!
for _ in $(seq 1 600); do # up to ten minutes
    kill -0 "$SERVER" 2>/dev/null || kill -0 "$HOME_CLIENT" 2>/dev/null || kill -0 "$AWAY_CLIENT" 2>/dev/null || break
    sleep 1
done
kill "$SERVER" "$HOME_CLIENT" "$AWAY_CLIENT" 2>/dev/null
grep -h -E "SERVER|CLIENT" "$LOGS"/server.log "$LOGS"/home.log "$LOGS"/away.log
result() { grep -o -E "FINAL [0-9]+-[0-9]+ winner=-?1" "$LOGS/$1.log" | head -1; }
if [ -n "$(result server)" ] && [ "$(result server)" = "$(result home)" ] && [ "$(result server)" = "$(result away)" ]; then
    echo "LAN SMOKE TEST PASSED: server and both clients agree on $(result server)"
else
    echo "LAN SMOKE TEST FAILED: results differ or are missing. Logs are in $LOGS"
    exit 1
fi
