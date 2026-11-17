# Three separate processes on this machine: one headless match server and two headless
# clients whose bots play a short match over UDP on localhost. Passes if all three report
# the same final score. Usage: .\tools\lan_smoke_test.ps1 [-Godot godot] [-Port 47813]
param([string]$Godot = "godot", [int]$Port = 47813)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$logs = Join-Path ([System.IO.Path]::GetTempPath()) ("rallypop_lan_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $logs | Out-Null

function Start-Game([string]$name, [string[]]$gameArgs) {
    $all = @("--headless", "--path", ".") + $gameArgs
    Start-Process -FilePath $Godot -ArgumentList $all -NoNewWindow -PassThru `
        -RedirectStandardOutput (Join-Path $logs "$name.log") -RedirectStandardError (Join-Path $logs "$name.err")
}

$server = Start-Game "server" @("res://scenes/server/match_server.tscn", "--", "--port=$Port", "--points=3", "--win-by=1", "--code=SNEAK7", "--exit-on-match-end")
Start-Sleep -Seconds 2
$homeClient = Start-Game "home" @("res://scenes/game/online_match.tscn", "--", "--join=127.0.0.1:$Port", "--code=SNEAK7", "--autoplay", "--exit-on-match-end", "--seed=7")
Start-Sleep -Seconds 1
$awayClient = Start-Game "away" @("res://scenes/game/online_match.tscn", "--", "--join=127.0.0.1:$Port", "--code=SNEAK7", "--autoplay", "--exit-on-match-end", "--seed=8")

$all = @($server, $homeClient, $awayClient)
$deadline = (Get-Date).AddMinutes(10)
while ((Get-Date) -lt $deadline -and ($all | Where-Object { -not $_.HasExited })) { Start-Sleep -Seconds 1 }
$all | Where-Object { -not $_.HasExited } | ForEach-Object { Stop-Process -Id $_.Id -Force }

function Get-Result([string]$name) {
    $text = Get-Content (Join-Path $logs "$name.log") -Raw
    if ($text -match "FINAL \d+-\d+ winner=-?1") { return $Matches[0] }
    return ""
}
Get-Content (Join-Path $logs "server.log"), (Join-Path $logs "home.log"), (Join-Path $logs "away.log") | Where-Object { $_ -match "SERVER|CLIENT" }
$expected = Get-Result "server"
if ($expected -ne "" -and (Get-Result "home") -eq $expected -and (Get-Result "away") -eq $expected) {
    Write-Host "LAN SMOKE TEST PASSED: server and both clients agree on $expected"
} else {
    throw "LAN SMOKE TEST FAILED: results differ or are missing. Logs are in $logs"
}
