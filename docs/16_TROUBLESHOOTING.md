# 16 — Troubleshooting reference

## Godot and project import
**No project found?** Choose Import and browse to `project.godot`, not `README.md` or a subfolder. **Project appears blank?** Press F5; this starter constructs some mesh geometry at runtime rather than storing every mesh in the court scene editor. **Script parse error?** Copy first error and line number; fix before requesting more features. **Godot can't find `CourtDimensions`?** Let the editor finish its global-class scan/import; run headless editor import again.

## Windows command issues
**`godot` command not recognized:** use full path to `godot.exe`, or add executable folder to user PATH and restart terminal. **`claude` not recognized:** follow native installer PATH instructions; ensure VS Code terminal restarted. **`npx.ps1` denied:** use `npx.cmd` in PowerShell, or modify only your process-scoped policy after assessing security. Do **not** set a machine-wide unrestricted execution policy casually.

## Godot MCP
**Cannot connect:** verify chosen MCP server installed, Godot plugin installed and enabled, Godot editor running, correct Node version, and Claude Code client restarted. Some MCP tools cannot work if only a headless project is running. **Server/tool appears unavailable:** do not install random alternatives simultaneously. Fall back to direct Claude file editing.

## Visual/model issues
**GLB too big/small:** check Blender units, applied transform and Godot import root scale. **Facing backward:** confirm model's actual forward orientation and wrapper transform rather than changing input signs randomly. **Animation missing:** inspect armature/action export and imported AnimationPlayer. **Court mesh mismatches hit detection:** core gameplay uses numeric court dimensions; visual lines must be aligned with those numbers.

## Physics/gameplay issues
**Ball passes through net:** current net implementation is approximate; implement swept collision and add a regression test. **Ball feels floaty:** tune shot timing and drag only with test fixtures; don't increase gravity independently across clients. **Opponent misses:** practice bot is intentionally simple and may not return difficult balls. **No official score:** score/serve state machine is planned, not implemented.

## Where to report failures
Include exact Godot version, script file and line, full error, OS, reproduction steps, and if available a screenshot. Use `docs/10_TESTING_AND_QA.md` bug template.
