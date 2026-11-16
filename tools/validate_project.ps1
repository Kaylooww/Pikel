param([string]$Godot = "godot")
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
& $Godot --headless --path . --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import/parse failed: $LASTEXITCODE" }
& $Godot --headless --path . --script res://tests/unit/test_rules.gd
if ($LASTEXITCODE -ne 0) { throw "Godot unit checks failed: $LASTEXITCODE" }
Write-Host "Basic Godot checks passed. Manual F6/F5 gameplay playtesting is still required."
