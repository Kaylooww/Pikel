# 13 — Security, identity, backend and privacy

## No backend in starter
The prototype needs no API keys, login or personal data. Start with local player names/config and LAN experiments. Accounts, profiles, stats and cloud cosmetics should wait until online match flow is validated.

## What the LAN match server enforces today
Implemented in `scripts/networking/match_server.gd` and `net_protocol.gd`, with tests:

- The only client messages are `hello(version)` and a numbered input: move vector, sprint, swing type, aim point. There is no message that states a position, a hit, a fault or a score.
- A player's side is taken from which connection sent the input, never from the message.
- Inputs are type- and range-checked; NaN or infinite values, wrong sizes, another match's id, repeated or older sequence numbers and absurd jumps ahead are dropped and counted.
- Movement speed is capped twice: the move vector is cut to length 1, and at most one input per tick on average is applied (a burst of four to catch up after jitter).
- Reach, timing, net clearance, in/out, serve, kitchen and score are all decided by the server's simulation.
- Server-to-client messages use Godot's `authority` RPC mode, and client-to-client relay is switched off.
- Two seats only; a wrong protocol version, a third player, or a connection that never says hello is disconnected.

Not there yet: no accounts, session tokens or encryption (ENet traffic is plain), no admin interface, no per-address rate limiting or ban list, no serve clock (an idle server-side player can stall a match), no protection against a flood of new connections beyond the four-connection cap. Treat it as a trusted-LAN tool and do not expose the port to the internet.

## Server security model
- Client is untrusted for movement, contact, score, currency, rank and match result.
- Use server-validated input bounds, timestamps, session tokens, sequence windows and rate limits.
- Prevent replay of old shot commands and duplicate scoring events.
- Reject unreasonable player speed, teleport requests and impossible paddle contacts.
- Protect authoritative server endpoints; don't expose admin tools or database keys in clients.

## Backend choice when needed
For basic identities and cosmetic profiles, Supabase/PostgreSQL is a possible later option. A game client must use public/appropriately scoped keys only; privileged keys stay server-side. Review authentication rules, row-level security and data retention. A database is not a substitute for a real-time match server.

## Privacy and operations
Publish a privacy policy before collecting player identifiers, chat, crash logs or telemetry. Do not collect chat, device IDs, IP analytics or detailed session history by default. Provide reporting/moderation before public player-to-player communication. Consider minor safety if the intended game audience includes children.

## Secrets
`.env` and `.claude/settings.local.json` are ignored. Scan Git history before public release. Never put Claude API keys, Supabase service keys, Discord tokens or deployment credentials in Markdown/specs or Godot scene files.
