# 09 — UI / UX requirements

## Screens needed for beta
1. **Splash & main menu:** Play, Training, Private Match, Settings, Exit.
2. **Practice select:** static ball, return feeder, serve, aiming drills (future).
3. **Match lobby:** slots 1–4, ready status, team selection, lobby code, privacy/region/connection quality, start requirements.
4. **Character select:** rig-compatible cosmetic variants; locked/unlocked state later.
5. **In-match HUD:** game score, server/team, serving order, rally state, compact controls, ping, predicted target, aim strength.
6. **Pause/settings:** volume, camera, input bindings, HUD scale, accessibility.
7. **Match end:** winner, score breakdown, rematch, return to lobby.
8. **Disconnected/rejoin:** helpful explanation and safe retry/forfeit options.

## Visual hierarchy
Ball and court first; reticle second; opponent and player third; score and hints readable but unobtrusive. Center screen should not be obscured by menus during live play. Use icons + text labels, not only color to express faults and target confidence.

## Training feedback
- Current input type (`DRIVE`, `DINK`).
- Why a shot failed (unreachable, illegal, net, out).
- Highlight predicted bounce point, actual bounce point and error distance for practice.
- Render hit quality feedback without giving a false notion of guaranteed targeting.

## States and transitions
Every button must do something or be clearly disabled. Menu actions should never block the game thread with I/O. A player unable to connect must see actionable troubleshooting information. Nonessential transitions may be disabled for low-end devices.

## Prototype state
The starter creates labels and controls from scripts; these are deliberately temporary. The final UI should use reusable `Control` scenes, theme resources, responsive anchoring, and keyboard navigation.
