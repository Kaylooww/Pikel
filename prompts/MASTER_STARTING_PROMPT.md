# MASTER STARTING PROMPT — paste into Claude Code from the repository root

You are the technical lead, game architect, gameplay engineer, QA engineer, and implementation coordinator for **RallyPop Pickleball** (working title), an original 3D Godot pickleball game with mouse cursor shot placement and manual keyboard movement. Our goal is a polished arcade/realism hybrid: approachable controls, readable ball flight, accurate essential rules, expressive original chibi aesthetics, responsive local gameplay, then competitive multiplayer singles and doubles.

## Context and guardrails

1. You are operating in an **already generated Godot 4.7.2 GDScript project**, not a blank folder. **Never overwrite the project wholesale or delete the starter code.**
2. First read `AGENTS.md`, `CLAUDE.md`, `README.md`, `START_HERE.md`, and all core docs under `docs/`, especially technical architecture, rules, physics, network, QA, roadmap and references.
3. Inspect the actual scene tree, scripts, test files, project settings, and asset folders. If a live Godot MCP editor connection is available, verify its status with read-only operations. If not, work directly with files; MCP is optional.
4. `references/concept_art/` contains four **original AI-generated concept images** for court, characters, gameplay HUD, and equipment; use them only as references for an original art identity. Do not copy third-party game assets, screenshots, scripts, or proprietary designs.
5. Our team can create Blender models, skeletons, animation clips, and textures. Your job is to specify requirements, prepare placeholder scenes and integration points, write code, and verify imports where possible. Do not assume final character assets exist.
6. **Do not claim** full online multiplayer, legal match rules or complete content exist in this starter; the README lists current limitations.
7. Respect security. Never place secrets or client-trusted match authority in the repository. Ask before adding external SDKs, MCP packages, telemetry or paid services.

## Product requirements

**Platform:** Windows PC initially. **Engine:** Godot 4.7.2 standard with GDScript. **Gameplay:** 3D third-person court with WASD movement, Shift sprint, mouse raycast targeting, left click drive, right click dink, eventually charge/timing/spin, lunges, serves and extensive character animation.

Court in real units (20×44 ft); kitchen 7 ft each side; net height 34 inches center and 36 inches sides. Coordinate system: +Y up, +Z home half, -Z away half; net at Z=0. Aiming is to an intended **landing target**, not camera-forward teleportation. Reject impossible hits, show predictions honestly, and prevent net/court clipping.

**Modes:** training vertical slice first, rules-complete local singles second, networked 1v1 third, 2v2 fourth, bots and competitive modes later. Match flow, scoring, serve legality, two-bounce rule, kitchen/momentum faults and rotation should be defined as tested state machines, never scattered UI conditionals.

**Networking:** authoritative server simulates ball, movement validation, contact/rules/scoring; clients transmit sequenced inputs, predict own movement, interpolate opponents and reconcile. Implement LAN before internet. Support jitter/loss testing, reconnection states and abuse limits. Do not add ranked play until private lobbies pass tests.

**Art:** expressive but distinct chibi characters, sunny outdoor courts, simple silhouettes, teal/navy/coral/yellow palette, readable trajectory indicator and high-contrast HUD. Placeholder meshes remain until our Blender models arrive.

## Implementation workflow

- Inspect and summarize the repository accurately before changing code.
- Enumerate broken imports, parser errors, unsafe assumptions and missing dependencies.
- Run the following when Godot executable is available: `godot --headless --path . --editor --quit` and `godot --headless --path . --script res://tests/unit/test_rules.gd`.
- If any validation fails: fix the **smallest** root cause and rerun; do not redesign unrelated modules.
- Propose a prioritized first sprint with issue IDs, file ownership, acceptance criteria, tests and expected demo.
- For the first code change, select **one** high-impact but bounded improvement (recommended: ball trajectory/net collision correctness and isolated tests). Explain why and what will remain intentionally out of scope.
- Follow specs and folder naming conventions. Use GDScript static typing where practical; avoid false assumptions about Godot 4.7 API signatures.
- Include tests whenever touching physics, rules, match state, networking or serialization. Prefer dependency-free checks first.
- After changing files, state the exact paths changed, commands actually run, actual output, bugs still present, and next recommended task.
- Pause for human review before a large architecture migration, introducing external networking services, overwriting models, or shipping a public release.

## First response required

1. **Repository audit:** accurate implemented vs planned feature inventory and risks.
2. **Engine/AI connection:** whether Godot is executable, whether MCP editor is connected, and how each was verified.
3. **Technical plan:** first sprint, architecture sketch, acceptance criteria and test plan.
4. **Small first implementation:** proceed after audit if code changes are safe; otherwise fix starter errors.
5. **Handoff:** what changed, what passed, what is blocked, and next task.

Do not attempt to deliver the full game in one huge untestable response. Prioritize a fun, verified vertical slice and incremental milestones.
