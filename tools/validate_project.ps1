param([string]$Godot = "godot")
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
& $Godot --headless --path . --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import/parse failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/unit/test_rules.gd
if ($LASTEXITCODE -ne 0) { throw "Godot unit checks failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/unit/test_net_collision.gd
if ($LASTEXITCODE -ne 0) { throw "Godot net collision checks failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/unit/test_court_dimensions.gd
if ($LASTEXITCODE -ne 0) { throw "Godot court dimension checks failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/unit/test_gameplay_tuning.gd
if ($LASTEXITCODE -ne 0) { throw "Godot gameplay tuning checks failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/unit/test_shot_solver.gd
if ($LASTEXITCODE -ne 0) { throw "Godot shot solver checks failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/integration/test_training_preview.gd
if ($LASTEXITCODE -ne 0) { throw "Godot training preview checks failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/unit/test_camera.gd
if ($LASTEXITCODE -ne 0) { throw "Godot camera checks failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/unit/test_input.gd
if ($LASTEXITCODE -ne 0) { throw "Godot input checks failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/unit/test_swing_contact.gd
if ($LASTEXITCODE -ne 0) { throw "Godot swing contact checks failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/unit/test_rally_state.gd
if ($LASTEXITCODE -ne 0) { throw "Godot rally state checks failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/unit/test_rally_controller.gd
if ($LASTEXITCODE -ne 0) { throw "Godot rally controller checks failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/integration/test_training_rally.gd
if ($LASTEXITCODE -ne 0) { throw "Godot training rally checks failed: $LASTEXITCODE" }
Write-Host "Basic Godot checks passed. Manual F6/F5 gameplay playtesting is still required."
