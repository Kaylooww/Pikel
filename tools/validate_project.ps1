# Imports the project and runs every unit and integration test. Stops at the first failure.
#   .\tools\validate_project.ps1 [-Godot path\to\godot.exe]
# New tests are picked up automatically: any .gd file in tests/unit or tests/integration.
param([string]$Godot = "godot")
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

# The standard Windows Godot.exe is a window-mode program: called plainly, PowerShell does
# not wait for it and gets no exit code. Piping its output makes PowerShell do both.
function Invoke-Godot([string]$what, [string[]]$godotArgs) {
    & $Godot --headless --path . @godotArgs | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "$what failed with exit code $LASTEXITCODE" }
}

Invoke-Godot "Godot import" @("--editor", "--quit")
foreach ($folder in @("unit", "integration")) {
    Get-ChildItem "tests/$folder/*.gd" | Sort-Object Name | ForEach-Object {
        Invoke-Godot "tests/$folder/$($_.Name)" @("--script", "res://tests/$folder/$($_.Name)")
    }
}
Write-Host "All Godot checks passed. Manual F5 gameplay playtesting is still required."
