# SPEC: Dark Nova ][ Multiplayer — "GALNET"

Status: **DESIGN DRAFT — for review with Shon before any implementation.**
Author: design session 2026-07-07.

## The thesis

Dark Nova's soul is that **fame and infamy are information** — deeds
travel only if witnessed, the news is how the galaxy learns who you are.
That mechanic is *already* a multiplayer design: it just needs other
people on the receiving end.

So: not an MMO, not real-time co-presence. **An asynchronous shared
universe** where every player flies their own game, but their witnessed
deeds, market footprints, and ship silhouettes propagate to everyone
else's galaxy through the same information channels the single-player
game already has (GNN, encounters, rumors). Play alone at 2am; wake to
find your mayday-ignoring cowardice is sector news and someone posted a
bounty on you.

Why async beats real-time here:
- **Playability**: sessions of any length count; no lobbies, no waiting,
  no dead servers at low population. One other active player per week is
  already fun (their name keeps appearing in your news).
- **Fit**: turn-based warp loop + personal narrative (quests, rivals,
  vignettes) would be diluted, not enhanced, by live co-presence.
- **Feasibility**: no netcode, no tick sync. REST + polling on the VPS
  we already run. The engine is pure Dart — **the server reuses the
  exact same engine code** for validation and news rendering.

## Design pillars

1. **Offline-first, forever.** The full single-player game works with
   zero connectivity. GALNET is an opt-in link that enriches it.
2. **Your progress is yours.** No player can destroy, steal, or roll
   back another player's save. All PvP is mediated through ghosts,
   reputation, and competition — never direct loss.
3. **Server-authoritative only where players touch.** Personal layer
   (credits, cargo, quests, rivals) stays client-side — a cheater there
   only cheats their own story. Anything that affects *other* players
   (news, ghosts, bounties, leaderboards, contracts) is server-verified.
4. **The witness mechanic scales socially.** Destroy a player's ghost
   with no witnesses and its owner never learns who did it — just "lost
   contact near the Vaeldun Gulf." Leave a survivor and your name is in
   their morning news. This is the whole game, multiplied.

## The two-layer world

| Layer | Contents | Authority | Offline behavior |
|---|---|---|---|
| Personal | ship, credits, cargo, quests, rivals, vignettes, police record, personal day counter | Client | unchanged |
| Shared (GALNET) | news feed, player presence/ghosts, bounty board, market pressure, golden contracts, leaderboards, season chronicle | Server | absent; game falls back to pure local sim |

**The clock problem, solved by not sharing a clock.** Single-player time
advances per-warp (player-driven); a shared economy usually demands a
shared clock. We don't share the economy — we share *pressure on it*:
real-time decaying modifiers (below). Personal days, quest deadlines,
and interest keep working untouched, online or off.

## Seasons

- A **season** = one shared galaxy seed, ~8 weeks. Every linked player
  flies the *same* 400 systems — shared geography is what makes "meet
  me in the Korris Expanse" and "avoid the Deep, someone's hunting
  there" possible.
- New game while linked → season seed. Existing/offline games keep
  their private seeds and can only consume the news feed (read-only
  GALNET) — full features require season games.
- Season end: leaderboards freeze, a **season chronicle** is generated
  from the full public event ledger (this is a flagship LLM feature
  later — the server has every witnessed deed of every player), new
  seed begins. Old season saves remain playable offline.

## Features by phase

### Phase 1 — The Shared Wire (small, huge payoff)
- **Link**: commander handle + server-issued token (stored in prefs; a
  recovery code shown once). No email/password in v1.
- **Event publishing**: client pushes its *witnessed* ledger events
  (typed `GameEvent`s, not prose) on dock/warp, batched. Unwitnessed
  events NEVER leave the device — secrets stay secret even from us
  being tempted to use them.
- **Shared GNN**: server merges all players' public events + the
  season world's crisis wire into one feed; clients interleave it with
  local headlines. Your news now contains real people:
  "CMDR VOSS IGNORED MAYDAY NEAR TYCHO — SURVIVORS SPEAK."
- **Presence**: "last seen docked at X" per commander, shown on a
  GALNET roster screen.
- Server renders headlines with the same `NewsEngine` templates by
  reusing the engine package (see Architecture).

### Phase 2 — Market Pressure
- Aggregate *server-verified* trade reports (good, qty, system, buy/
  sell) produce per-(system, good) **price modifiers**, capped ±25%,
  decaying over real hours. Clients apply modifiers on top of local
  price computation while linked.
- Emergent play: a crisis makes the news → five players race medicine
  to the plague world → price collapses for the latecomers. The market
  now remembers that other people exist, without a shared clock.
- Trade reports are plausibility-checked server-side against the season
  galaxy (does that system trade that good? is qty ≤ ship class max?)
  and rate-limited. Perfect anti-cheat is a non-goal (pillar 3).

### Phase 3 — Ghosts & Bounties
- **Ghost snapshots**: on dock, client uploads ship build + commander
  name + threat profile. Other players' Arrival Director may (low
  frequency, cap ~1 per session, opt-out) roll a **ghost encounter**:
  an engine-AI-driven NPC flying that exact build, hailing as
  "CMDR <handle>". Fighting it is a normal encounter for you; the owner
  loses nothing — they get a GALNET notification whose content obeys
  the witness rules (survivor → they know who; no witness → "contact
  lost", attacker unknown).
- **Renown**: a server-side currency earned ONLY through verified
  multiplayer acts (ghost victories, contract wins, fame milestones).
  Client credits can't buy it, so client-side cheating can't touch the
  competitive layer.
- **Bounty board**: post Renown on a commander (because their deeds in
  the news annoyed you, or for sport). Defeating that commander's ghost
  claims it. Bounties are visible on the roster and in the news —
  social drama as content.

### Phase 4 — Competition
- **Golden contracts**: server-posted, first-to-deliver races
  ("40 medicine to Japori — 5,000 Renown, expires in 72h"), verified by
  trade reports. The async equivalent of a raid.
- **Leaderboards**: per season, from server-verified data only: Renown,
  contracts won, ghost record, "most newsworthy" (headline count —
  infamy counts!).

### Phase 5 — future, out of scope for this spec
Live duels (real-time, both online), co-op convoys, player messages
(parley-style LLM-mediated hails between commanders), shared player-run
stations.

## Architecture

```
Flutter client (web/PWA, later stores)
   │  HTTPS JSON, bearer token; poll on dock/warp + 60s while map open
   ▼
Caddy (2.darknova.org)  ──  /api/*  ──►  darknova-server (Dart, :8095)
                                          │  systemd user unit, VPS
                                          ▼
                                        SQLite (season.db)
```

- **Engine extraction (the one real refactor):** move `lib/engine/` +
  `lib/models/` into `packages/darknova_core` — a pure-Dart package the
  Flutter app AND the server both depend on (the app's pubspec gains a
  path dependency; imports change `package:darknova2/engine/...` →
  `package:darknova_core/engine/...`; zero logic changes). This is
  mechanical, Sonnet-speccable, and is Phase 0.
- **Server**: Dart `shelf` app in `server/` (same repo). Reuses
  `darknova_core` for: season galaxy generation (seed → identical
  world), news template rendering, trade plausibility checks, ghost
  encounter validation. SQLite via `sqlite3`. Deployed like everything
  else here: rsync + systemd + Caddy route (no PaaS).
- **Client**: a `GalnetService` (Riverpod provider) that queues
  outbound events while offline and syncs opportunistically. UI: link
  screen, GALNET feed section in the hub news panel (tagged so players
  can tell galactic news from player news), roster/bounty screen
  (Phase 3).
- **Rate/abuse**: token-bucket per commander; handle profanity filter;
  block list (client-side mute + server honor); event schema validation.

## What stays deliberately single-player

Quests, rivals, vignettes, and the police/reputation ladders remain
personal narrative — every player has their own Vex Marrow. Rationale:
these systems are paced for one protagonist; sharing them creates
contention for story beats instead of drama. The shared layer gets its
drama from *people*, not from splitting the campaign.

## Cost & effort sketch

| Phase | Server | Client | Notes |
|---|---|---|---|
| 0 engine extraction | — | mechanical refactor | Sonnet + spec, low risk |
| 1 wire | ~600 LOC | ~400 LOC | biggest bang/buck |
| 2 market | ~300 | ~150 | needs balance tuning |
| 3 ghosts/bounties | ~500 | ~400 | most design-sensitive |
| 4 competition | ~300 | ~200 | mostly server |

VPS load: trivial (JSON + SQLite; hundreds of players fine on the $12
box). Marginal cost ≈ $0 until LLM chronicle.

## Open questions for our review

1. **Ghost frequency & consent**: opt-out default on or off? My lean:
   ON by default (it's consequence-free and it's the fun), with a
   settings toggle.
2. **Market pressure at all?** Phase 2 is the only feature that touches
   game balance. Alternative: ship Phases 1+3 and skip 2 until the
   economy proves it needs it. My lean: build it, cap it hard.
3. **Renown vs credits** for bounties — I chose Renown to firewall
   client-side cheating; costs us the visceral "10,000 credits on your
   head." Worth it?
4. **Season length** (8 weeks?) and what carries across seasons
   (handle + lifetime Renown + chronicle mentions; nothing material?).
5. **Handle impersonation**: reserve canonical handles first-come
   per-season or globally?
6. **When**: multiplayer before or after the LLM proxy? They're
   independent workstreams, but the season chronicle and ghost-parley
   both get much better with the proxy live. My lean: proxy first
   (single-player gets richer for everyone), multiplayer Phase 0+1
   right after.
