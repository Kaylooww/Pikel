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
Write-Host "Basic Godot checks passed. Manual F6/F5 gameplay playtesting is still required."
