# 13 — Security, identity, backend and privacy

## No backend in starter
The prototype needs no API keys, login or personal data. Start with local player names/config and LAN experiments. Accounts, profiles, stats and cloud cosmetics should wait until online match flow is validated.

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
