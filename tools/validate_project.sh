#!/usr/bin/env bash
# Imports the project and runs every unit and integration test. Stops at the first failure.
#   tools/validate_project.sh [godot]
# New tests are picked up automatically: any .gd file in tests/unit or tests/integration.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
"$GODOT" --headless --path . --editor --quit
for test in tests/unit/*.gd tests/integration/*.gd; do
    "$GODOT" --headless --path . --script "res://$test"
done
echo "All Godot checks passed; manual gameplay testing still required."
