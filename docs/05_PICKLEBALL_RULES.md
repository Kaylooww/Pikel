# 05 — Pickleball rules and match state machine

## Authoritative source
Implement the applicable **2026 USA Pickleball Official Rulebook** from <https://usapickleball.org/rules/>. Re-check revisions before tournament/competitive release. This file is a **software implementation plan**, not a replacement for the official rules.

## Geometry
- Court: 20×44 ft = 6.096×13.4112 m, lines inclusive.
- Kitchen/non-volley zone: 7 ft = 2.1336 m from either side of net, with bounding line part of the zone.
- Net height 34 in (0.8636 m) center; 36 in (0.9144 m) at sidelines.
- World origin at net center, X across width, Z along length, Y up.
- Singles and doubles have the same court dimensions; doubles adds server sequence and position bookkeeping.

## Essential predicates
- `landing_in_bounds`: include boundary line as in (physical ball contact vs line geometry to be resolved).
- `served_to_correct_diagonal_service_court`: not kitchen, correct opposite-side service rectangle.
- `two_bounce_condition`: serve must bounce on receiver half; return must bounce on serving half before volleys can occur.
- `kitchen_volley_fault`: volley contact while player touches NVZ or boundary, OR momentum carries them into NVZ in a prohibited way.
- `net_contact_fault`: player or equipment touches the net during live ball when prohibited.
- `ball_double_bounce_fault`: second bounce before a legal return.
- `serve_legality`: choose volley or drop-serve implementation and model correct legal motion/position requirements explicitly.

## Rally state machine (planned)
```mermaid
stateDiagram-v2
  [*] --> WaitingForServe
  WaitingForServe --> ServeInFlight: server contacts legally
  ServeInFlight --> WaitingForReturn: valid diagonal bounce
  ServeInFlight --> Fault: illegal serve / out / net
  WaitingForReturn --> ReturnInFlight: receiver hits after bounce
  WaitingForReturn --> Fault: illegal early volley / second bounce
  ReturnInFlight --> OpenRally: ball bounces on server half
  ReturnInFlight --> Fault: out / net / wrong event
  OpenRally --> OpenRally: valid hits and single bounces
  OpenRally --> Fault: second bounce / net / kitchen / out
  Fault --> AwardAndRotate
  AwardAndRotate --> WaitingForServe: match not over
  AwardAndRotate --> MatchOver: target score + winning margin
```

## Scoring engine
- Implement **traditional side-out scoring** as the competitive default; only serving side scores points.
- Track team/individual scores, current service team, server number (for doubles), player positions, right/left court assignment, first service sequence nuance, win-by-two and score cap/match configuration.
- Do not derive server rotation solely from score without storing team/person state.
- Support rally scoring later as an explicit configurable mode; don't mix with side-out rules.
- Test 0-0-2 doubles start and subsequent first/second server sequence against rulebook, including side-out.

## Player-foot and momentum logic
The kitchen is not forbidden ground. Standing there is allowed; hitting an airborne ball as a volley is illegal when touching NVZ, and the momentum prohibition requires additional state even if feet are outside at contact. Track stance/contact/momentum transitions as validated player events; do not trigger a fault for merely stepping into the zone.

## Test examples
| Scenario | Expected |
|---|---|
| Serve lands on kitchen line | Service fault |
| Legal groundstroke after kitchen bounce while standing in NVZ | Allowed |
| Volley made with player's foot on NVZ line | Fault |
| Volley from outside followed by prohibited momentum into NVZ | Fault |
| Volley of serve return without letting it bounce | Fault |
| Volley of third shot without letting return bounce | Fault |
| Ball touches outer court line | In |
| Team scores while receiving under traditional rules | Side-out rather than point |

## Known starter status
`RulesEngine` has **only helper geometry and diagonal-target predicates**; full serve/scoring state transitions and kitchen/momentum logic are **not implemented**. The practice HUD explicitly avoids claiming official scoring.
