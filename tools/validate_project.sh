#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
"$GODOT" --headless --path . --editor --quit
"$GODOT" --headless --path . --script res://tests/unit/test_rules.gd
"$GODOT" --headless --path . --script res://tests/unit/test_net_collision.gd
echo "Basic Godot checks passed; manual gameplay testing still required."
