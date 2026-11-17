#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
"$GODOT" --headless --path . --editor --quit
"$GODOT" --headless --path . --script res://tests/unit/test_rules.gd
"$GODOT" --headless --path . --script res://tests/unit/test_net_collision.gd
"$GODOT" --headless --path . --script res://tests/unit/test_court_dimensions.gd
"$GODOT" --headless --path . --script res://tests/unit/test_gameplay_tuning.gd
"$GODOT" --headless --path . --script res://tests/unit/test_shot_solver.gd
"$GODOT" --headless --path . --script res://tests/integration/test_training_preview.gd
"$GODOT" --headless --path . --script res://tests/unit/test_camera.gd
"$GODOT" --headless --path . --script res://tests/unit/test_input.gd
"$GODOT" --headless --path . --script res://tests/unit/test_swing_contact.gd
"$GODOT" --headless --path . --script res://tests/unit/test_rally_state.gd
"$GODOT" --headless --path . --script res://tests/unit/test_rally_controller.gd
"$GODOT" --headless --path . --script res://tests/integration/test_training_rally.gd
"$GODOT" --headless --path . --script res://tests/unit/test_match_score.gd
"$GODOT" --headless --path . --script res://tests/unit/test_motion.gd
"$GODOT" --headless --path . --script res://tests/unit/test_match_simulation.gd
"$GODOT" --headless --path . --script res://tests/unit/test_aim_advice.gd
"$GODOT" --headless --path . --script res://tests/integration/test_singles_match.gd
echo "Basic Godot checks passed; manual gameplay testing still required."
