# 11 — Six-month roadmap, backlog and gates

**Estimate:** 16–24 weeks for a stable playable beta with consistent small-team work and AI assistance; no promise of completion. Scope and actual velocity will change after the first prototype.

## Stage milestones
| ID | Weeks | Deliverable | Exit gate |
|---|---|---|---|
| P0 | 1–2 | Repository, scene imports, specs, tests | Godot opens; baseline project runs |
| P1 | 3–5 | Movement, camera, cursor aim | Human can aim and move consistently |
| P2 | 5–9 | Ball, collision, contact, shots | Repeated predictable local rallies |
| P3 | 9–12 | Full rules, serves, scoring, local singles | Complete legal test matches |
| P4 | 12–16 | Server/LAN and private online singles | Two real PCs play synchronized matches |
| P5 | 16–20 | Doubles, character integration, UX/animation | Four players finish a full match |
| P6 | 20–24 | Regression, accessibility, optimization, beta | External testers can run packaged PC build |

Progress is tracked here: `[x]` done, `[ ]` open. `prompts/NEXT.md` picks the first open task.

## Sprint 0: audit and stabilize starter
- [x] **RP-001 (P0):** Open Godot 4.7.2 project and fix any import/parser errors. **Acceptance:** no headless import errors.
- [x] **RP-002 (P0):** Run existing smoke tests; remove any faulty assertions. **Acceptance:** green tests with documented output.
- [ ] **RP-003 (P0):** Manually test menu → practice → mouse aim/drive/dink/reset. **Acceptance:** reproduction report.
- [x] **RP-004 (P0):** Freeze units and court dimensions. **Acceptance:** exact court predicates documented and tested.
- [x] **RP-005 (P0):** Establish reusable gameplay tuning config. **Acceptance:** changes don't require replacing physics logic.

## Sprint 1: ball and input quality
- [x] **RP-010 (P0):** Swept net collision (avoid tunneling), including net top and posts.
- [x] **RP-011 (P0):** Basic valid shot solver with target, contact height and net clearance.
- [x] **RP-012 (P0):** Honest trajectory/landing preview and miss feedback.
- [x] **RP-013 (P0):** Separate in-game and training camera controllers.
- [x] **RP-014 (P1):** Input action map + rebinding-ready API.
- [x] **RP-015 (P1):** Player paddle contact windows and swing quality.

## Sprint 2: legal gameplay
- [x] **RP-020 (P0):** Rally event IDs and distinct state transitions.
- [x] **RP-021 (P0):** Two-bounce rule (serve/return/open rally).
  - [x] Rule itself: `RallyState` faults a volleyed serve or return (done with RP-020, tested).
  - [x] Live play: the ball and players emit `RallyEvent`s and the training rally is adjudicated by `RallyState` instead of the ball's own fault strings.
- [x] **RP-022 (P0):** Legal serves and proper diagonal service landing.
- [x] **RP-023 (P0):** NVZ/volley/momentum logic.
- [x] **RP-024 (P0):** Side-out score/rotation and match end condition.
- [x] **RP-025 (P1):** Full local singles with bot or second controller.

## Sprint 3: networking foundation
- [x] **RP-030 (P0):** Dedicated headless match server with fixed tick and match IDs. One match per server process.
- [ ] **RP-031 (P0):** LAN join, ownership, validated inputs and snapshots.
  - [x] Join by address, seats owned by connection, validated inputs, snapshots. Verified on localhost: in one process and as three separate processes.
  - [ ] Human check: two real PCs on one LAN play a match (firewall prompt, real addresses). Needs two machines.
- [ ] **RP-032 (P0):** Client prediction, opponent interpolation and reconciliation.
  - [x] Implemented and unit-tested with simulated latency, loss and bursts; exercised over localhost sockets.
  - [ ] Human check: play with real or injected latency, jitter and loss and judge whether movement and the delayed opponent feel right. No network-condition simulator is wired into the game yet.
- [x] **RP-033 (P0):** Accurate authoritative hit and fault events. The server decides every swing, fault and point; clients receive numbered reliable events.
- [ ] **RP-034 (P1):** Timeout, reconnect and error states.
- [ ] **RP-035 (P1):** Private match codes and public server deployment.

## Sprint 4: doubles and art
- [ ] **RP-040 (P0):** Four-player server match state with teams and rotation.
- [ ] **RP-041 (P0):** Character GLB wrapper / rig handoff contract.
- [ ] **RP-042 (P0):** Animations, shot tells, SFX and effects.
- [ ] **RP-043 (P1):** Game HUD, settings, tutorial, pause and match-end screens.
- [ ] **RP-044 (P1):** Cosmetics selection (non-ranked).

## Sprint 5: quality and public beta
- [ ] **RP-050 (P0):** Replayable automated rules/physics scenarios.
- [ ] **RP-051 (P0):** Multiclient latency, jitter, loss, stress tests.
- [ ] **RP-052 (P0):** Windows export, crash fixes, playtest telemetry if consented.
- [ ] **RP-053 (P1):** Accessibility/input settings and feedback improvements.
- [ ] **RP-054 (P1):** Store page, asset rights and player support checklist.

## Defer until after reliable private matches
Ranked queues, battle passes, microtransactions, complex cosmetics progression, spectator mode, public chat, social gym, full replays, tournaments, elaborate bot skills. These create cost and security obligations that can derail core gameplay.

## Task template
`ID; owner; module; objective; dependencies; acceptance test; risk; screenshots/logs; PR; review status` — keep it in GitHub Issues/Projects or a Markdown checklist per sprint.
