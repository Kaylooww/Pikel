# RallyPop Pickleball — Godot + Claude Starter Pack

> **Status:** playable **training vertical-slice scaffold**, not a complete online pickleball game. **RallyPop** is an original placeholder title. Change it before release. Inspired by broad principles of accessible, cursor-aimed arcade sports games; no *just volleyball* assets/code are included.

**Engine:** Godot **4.7.2 stable** (standard, GDScript, not .NET) · **Art:** Blender → `.glb` · **Editor:** Godot + optional VS Code · **AI:** Claude Code, optional community Godot MCP bridge · **Platform:** Windows PC first.

## Open and run

1. Extract the ZIP to a writable folder such as `C:\Dev\RallyPop_Pickleball_Godot_Starter` (do **not** work inside the ZIP).
2. Download Godot 4.7.2 standard build: <https://godotengine.org/download/windows/>.
3. Launch Godot Project Manager → **Import** → choose this folder's `project.godot` → **Import & Edit**.
4. Let the editor import the project, then press **F5**. Choose **PLAY PRACTICE PROTOTYPE**.
5. Use **WASD** to move, **Shift** to sprint, move the **mouse** to aim, **left click** for a drive, **right click** for a softer dink, **R** to reset, **C** to switch camera view, and **Esc** for the menu.
6. Read **[SETUP_WINDOWS_GODOT_CLAUDE.md](SETUP_WINDOWS_GODOT_CLAUDE.md)** and paste **[prompts/MASTER_STARTING_PROMPT.md](prompts/MASTER_STARTING_PROMPT.md)** into Claude Code from this project folder.

## Current implementation — truth table

| Feature | Status |
|---|---|
| Godot project and main menu | Starter implementation |
| Court / kitchen / net geometry | Procedural prototype geometry |
| Local player WASD and Shift | Starter implementation, read through a rebindable input action map (26 unit checks). No settings screen; rebinds are not saved |
| Cursor projected onto opposite half | Starter implementation |
| Left-click drive, right-click soft hit | Starter implementation |
| Swing quality | Reach and timing judged per swing (clean / early / late / stretched); mishits drift by a predictable amount that the preview shows; 22 unit checks. Right-handed forehand only, **feel untested** |
| Ball flight, gravity, bounce | No drag or spin; exact parabola and exact landing point; needs tuning |
| Shot solver | Raises the arc to clear the net and refuses impossible shots; 16 unit checks |
| Net contact | Swept sphere-vs-net test with 11 unit checks; a hit still just ends the rally (no net bounce) |
| Scripted practice opponent | Very basic demonstration, not a complete AI player |
| Court bounds/kitchen/serve-box predicates | Frozen and line-exact; 29 unit checks plus seven smoke checks |
| Gameplay tuning config | `config/gameplay_tuning.tres`; 15 unit checks. Camera values not yet included |
| Trajectory preview and landing feedback | Dotted arcs for drive and dink from the solver, marker and text for OK / blocked / out of reach, landing dot and miss distance; logic tested headless, **not yet seen on screen** |
| Camera | `CourtCamera` with two data-driven rigs (raised training view, lower match chase view), frame-rate independent smoothing, **C** switches; 18 unit checks. Match view values are untuned and unseen |
| Real serves, legal scoring, two-bounce enforcement | **Not implemented** |
| Singles match state machine | **Not implemented** |
| Online multiplayer, dedicated server, matchmaking | **Not implemented** |
| Doubles, cosmetics, model animations | **Not implemented** |
| Full game-ready character models | **Not supplied**; your team creates them |

## Directory map

```text
RallyPop_Pickleball_Godot_Starter/
├── project.godot                     ← Open this, not an individual GDScript
├── README.md, START_HERE.md          ← Navigation + quick start
├── AGENTS.md, CLAUDE.md              ← Agent instructions
├── SETUP_WINDOWS_GODOT_CLAUDE.md     ← Godot, Claude, Godot MCP and troubleshooting
├── prompts/                          ← Copy-paste prompts for Claude
├── docs/                             ← Gameplay, architecture, rules, QA, roadmap
├── references/                       ← ORIGINAL concept images and technical diagrams
├── scenes/                           ← Godot scenes (main, court, player, ball, game)
├── scripts/                          ← Runtime systems, separated by domain
├── assets/                           ← Drop your original Blender/GLB assets here
├── tests/                            ← Godot headless smoke checks
├── tools/                            ← PowerShell and bash validation wrappers
├── .vscode/                           ← Editor recommendations
└── .gitignore, .gitattributes        ← Repo hygiene
```

## Documentation index

- [START_HERE.md](START_HERE.md) — first-hour checklist and exact file import behavior.
- [SETUP_WINDOWS_GODOT_CLAUDE.md](SETUP_WINDOWS_GODOT_CLAUDE.md) — full Windows Claude ↔ Godot connection.
- [prompts/MASTER_STARTING_PROMPT.md](prompts/MASTER_STARTING_PROMPT.md) — first master task for Claude.
- [docs/01_GAME_DESIGN_DOCUMENT.md](docs/01_GAME_DESIGN_DOCUMENT.md) — full game proposal.
- [docs/02_TECHNICAL_ARCHITECTURE.md](docs/02_TECHNICAL_ARCHITECTURE.md) — modules, boundaries, dependencies.
- [docs/03_CONTROLS_AND_CAMERA.md](docs/03_CONTROLS_AND_CAMERA.md) — control spec and cursor input.
- [docs/04_BALL_PHYSICS.md](docs/04_BALL_PHYSICS.md) — ball physics specification.
- [docs/05_PICKLEBALL_RULES.md](docs/05_PICKLEBALL_RULES.md) — rules state machine planning.
- [docs/06_NETWORKING.md](docs/06_NETWORKING.md) — authoritative multiplayer plan.
- [docs/07_ART_DIRECTION.md](docs/07_ART_DIRECTION.md) — aesthetic/style references.
- [docs/08_3D_ASSET_PIPELINE.md](docs/08_3D_ASSET_PIPELINE.md) — Blender/GLB handoff.
- [docs/09_UI_UX.md](docs/09_UI_UX.md) — UI screens and player feedback.
- [docs/10_TESTING_AND_QA.md](docs/10_TESTING_AND_QA.md) — acceptance and regression testing.
- [docs/11_ROADMAP_AND_BACKLOG.md](docs/11_ROADMAP_AND_BACKLOG.md) — deliverables and sprint plan.
- [docs/12_AI_WORKFLOW.md](docs/12_AI_WORKFLOW.md) — multi-agent conventions.
- [docs/13_SECURITY_AND_BACKEND.md](docs/13_SECURITY_AND_BACKEND.md) — security/account concerns.
- [docs/14_RELEASE_AND_OPERATIONS.md](docs/14_RELEASE_AND_OPERATIONS.md) — builds, shipping.
- [docs/15_REFERENCE_INDEX.md](docs/15_REFERENCE_INDEX.md) — image map.
- [docs/16_TROUBLESHOOTING.md](docs/16_TROUBLESHOOTING.md) — known setup pitfalls.
- [docs/17_SOURCES.md](docs/17_SOURCES.md) — official references and verified integration options.
- [docs/19_GITHUB_RULES.md](docs/19_GITHUB_RULES.md) — GitHub rules, commit format and push steps.

## Important limitations

This package was assembled without a Godot executable in the authoring environment, so **the scenes/scripts have not been executed inside Godot**. Treat them as a reviewed starter scaffold; run the headless checks and inspect editor errors locally before asking Claude to add features. The reference images are original **AI-generated direction boards**, not 3D models or editable scene assets. Do not treat them as sprites or export-ready textures.
