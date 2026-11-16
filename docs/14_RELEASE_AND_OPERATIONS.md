# 14 — Windows builds, servers and publishing

## Prototype distribution
Use Godot Editor to run locally and share a tagged source ZIP for development. A source project is not a Windows executable. For a player-facing `.exe`, install matching Godot 4.7.2 export templates and configure export presets in the editor.

## Windows packaging steps (after validation)
1. Open Project → Export; install matching templates if prompted.
2. Add **Windows Desktop** preset; set output path `builds/windows/RallyPop.exe`.
3. Check runtime asset inclusion; reference Markdown need not be exported to the actual game.
4. Export, test on a second Windows machine, verify textures, controller, input and crash behavior.
5. Package `.exe` with required `.pck`/data files as instructed by Godot (unless embedded).
6. Record Godot version, commit hash, export presets and build checksum.

## Dedicated server plan
Use headless Godot export for a server-only project/binary when networking is implemented. Run a public host or approved relay; don't depend on all players configuring home-router UDP forwarding. Monitor concurrency, CPU, memory, outgoing bandwidth, crashes and error rate.

## Pre-release checklist
- [ ] Official court and rules verified by automated and human tests.
- [ ] Single/doubles complete matches verified across real PCs.
- [ ] Asset and audio rights audited.
- [ ] Build runs on minimum target hardware at target FPS.
- [ ] Network abuse controls and reconnect behavior tested.
- [ ] Settings and accessibility verified.
- [ ] Privacy policy/support contact ready if collecting data.
- [ ] Steam/itch.io account, age rating and platform fees verified for current terms.
- [ ] Test notes and version changelog ready.

## Costs
Godot and Blender are free to use. AI agents, hosting, backend, DNS and store distribution may have fees. Do not promise a monthly hosting cost without server-load measurements.
