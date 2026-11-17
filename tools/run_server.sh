#!/usr/bin/env bash
# Starts the dedicated match server on this machine. Leave it running while you play.
# Players then choose JOIN LAN MATCH in the game and enter this machine's address and the port.
#   tools/run_server.sh                    two players needed, port 7777
#   tools/run_server.sh --bot              one player, a bot takes the other seat
#   tools/run_server.sh --port=7800 --points=5
set -euo pipefail
cd "$(dirname "$0")/.."
exec "${GODOT:-godot}" --headless --path . res://scenes/server/match_server.tscn -- "$@"
