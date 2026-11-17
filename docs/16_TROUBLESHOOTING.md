# 16 — Troubleshooting reference

## Godot and project import
**No project found?** Choose Import and browse to `project.godot`, not `README.md` or a subfolder. **Project appears blank?** Press F5; this starter constructs some mesh geometry at runtime rather than storing every mesh in the court scene editor. **Script parse error?** Copy first error and line number; fix before requesting more features. **Godot can't find `CourtDimensions`?** Let the editor finish its global-class scan/import; run headless editor import again.

## Windows command issues
**`godot` command not recognized:** use full path to `godot.exe`, or add executable folder to user PATH and restart terminal. **`claude` not recognized:** follow native installer PATH instructions; ensure VS Code terminal restarted. **`npx.ps1` denied:** use `npx.cmd` in PowerShell, or modify only your process-scoped policy after assessing security. Do **not** set a machine-wide unrestricted execution policy casually.

## PowerShell and Godot
**A script calls `godot` and carries on at once, or `$LASTEXITCODE` is empty:** the standard Windows `Godot.exe` is a window-mode program, so PowerShell does not wait for it. Pipe its output, for example `& godot --headless --path . --script res://tests/unit/test_rules.gd | Out-Host`; then PowerShell waits and sets `$LASTEXITCODE`. The scripts in `tools/` already do this.

## Godot MCP
**Cannot connect:** verify chosen MCP server installed, Godot plugin installed and enabled, Godot editor running, correct Node version, and Claude Code client restarted. Some MCP tools cannot work if only a headless project is running. **Server/tool appears unavailable:** do not install random alternatives simultaneously. Fall back to direct Claude file editing.

## Visual/model issues
**GLB too big/small:** check Blender units, applied transform and Godot import root scale. **Facing backward:** confirm model's actual forward orientation and wrapper transform rather than changing input signs randomly. **Animation missing:** inspect armature/action export and imported AnimationPlayer. **Court mesh mismatches hit detection:** core gameplay uses numeric court dimensions; visual lines must be aligned with those numbers.

## LAN match issues
**"SERVER could not listen on port":** another server is already running on that port, or another program uses it; close it or start with `-Port 7800` and join that port. **"No server answered at that address" (after 8 seconds):** check the address and port, that both PCs are on the same network, and that Windows Firewall allowed Godot on Private networks on the server PC (UDP). **"Connected. Waiting for an opponent":** the match starts when the second player joins; use `-Bot` to play alone. **Disconnected straight after joining:** the server already has two players (or a bot in the second seat), or the two copies of the game are different versions of the protocol. **Opponent looks slightly behind:** that is intended; the opponent and ball are drawn a few ticks in the past so they move smoothly. **`run_server.ps1` cannot be loaded:** run the `godot --headless ...` command it contains directly rather than loosening the machine's script policy.

## Physics/gameplay issues
**Ball passes through net:** the net check is swept (`scripts/physics/net_collision.gd`); reproduce the case in `tests/unit/test_net_collision.gd` before changing it. **Ball feels floaty:** tune shot timing and drag only with test fixtures; don't increase gravity independently across clients. **Opponent misses:** practice bot is intentionally simple and may not return difficult balls. **No score in practice:** the practice court keeps no score on purpose; play **SINGLES MATCH** for a scored game.

## Where to report failures
Include exact Godot version, script file and line, full error, OS, reproduction steps, and if available a screenshot. Use `docs/10_TESTING_AND_QA.md` bug template.
