# Starts the dedicated match server on this PC. Leave the window open while you play;
# press Ctrl+C in it to stop the server.
# Players then choose JOIN LAN MATCH in the game and enter this PC's address and the port.
#   .\tools\run_server.ps1                 two players needed
#   .\tools\run_server.ps1 -Bot            one player, a bot takes the other seat
# Windows will ask to allow Godot through the firewall the first time: allow it on Private networks only.
param([string]$Godot = "godot", [int]$Port = 7777, [int]$Points = 11, [int]$WinBy = 2, [switch]$Bot)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$gameArgs = @("--port=$Port", "--points=$Points", "--win-by=$WinBy")
if ($Bot) { $gameArgs += "--bot" }
# Piped so PowerShell stays attached to the server: the standard Windows Godot.exe is a
# window-mode program that PowerShell would otherwise start and immediately walk away from.
& $Godot --headless --path . res://scenes/server/match_server.tscn -- @gameArgs | Out-Host
