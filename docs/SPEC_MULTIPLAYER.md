# SPEC: Dark Nova ][ Multiplayer — "GALNET" (v2, Trade Wars lineage)

Status: **DESIGN DRAFT — for review with Shon before any implementation.**
v1 2026-07-07; v2 same day after direction: "not MMO, but Trade Wars
2002 style" — real stakes while offline, auto-defense by stats/dice,
cloaks and hiding, insurance, turn limits, message boards.

## The thesis

Dark Nova's witness mechanic — fame and infamy as *information* — is
already a multiplayer design. v2 marries it to the Trade Wars 2002
formula: an **asynchronous persistent world with real consequences**.
Your ship exists in the galaxy even while you sleep. Someone can hunt
it. It fights back with your build and your crew's skills, rolled on
the same combat engine everything else uses. You can cloak, hide in an
anomaly, park under core-world police protection, bank your credits,
and buy insurance — every defense is a real decision, and every loss
is bounded and recoverable. Nothing is ever real-time; everything is
dice, preparation, and reputation. And every station has a wall to
scrawl on.

Why this beats both MMO and my safer v1 draft:
- **Turn limits are the great equalizer** (TW2002's core trick): with
  warps capped per real day, the offline player isn't behind — everyone
  spends the same turns. It also gives the shared economy a real-time
  pulse without a shared game clock.
- **Danger creates society.** Consequence-free ghosts (v1) make other
  players scenery. Raidable ships make them *neighbors* — worth
  scouting, taxing, avenging, or leaving warnings about on the wall.

## Design pillars (v2)

1. **Offline-first, forever.** Unlinked games are the full single-player
   experience, unchanged and unlimited. GALNET is opt-in at new game.
2. **Bounded loss, never ruin.** Turn caps bound exposure. Banked
   credits are untouchable. Insurance floors ship loss. Escape means
   you always continue playing *that same commander*. Personal
   narrative (quests, rivals, vignettes, police record) is never
   PvP-touchable. The sting is real; the wipeout is impossible.
3. **Geography is consent.** Parked under core-world police you are
   effectively safe. The frontier pays better and protects nobody.
   Players choose their exposure by where they fly and park — no
   PvP toggle, no separate servers.
4. **The witness mechanic scales socially.** Raids, escapes, and
   betrayals feed the shared GNN under the same rules: survivors talk,
   dead ships don't. Hunt anonymously or famously — your choice, made
   with dice.
5. **Server-authoritative where players touch.** Anything raidable or
   competitive lives server-side; the solo story stays on-device.

## Seasons & identity (carried from v1)

- Season = one shared galaxy seed, ~8 weeks; all linked players fly the
  same 400 systems. Handle + token auth (recovery code shown once).
  Season end: leaderboards freeze, an LLM-written **season chronicle**
  is generated from the public ledger, new seed. Handles and lifetime
  prestige persist; material state does not.
- Unlinked/legacy games can read the news wire only.

## The turn economy

- Linked season games get **50 warp-turns per real day**, accruing
  continuously (≈1 per 29 min), banked up to **150**. Warping costs 1
  turn (wormhole transit too — free fuel, not free time). Everything
  else (trading, combat rounds, boards, shipyard) is turn-free.
- Out of turns = you can still dock, trade, read boards, fight if
  attacked — you just can't warp. Sessions stay meaningful at any
  length; no-lifing buys breadth, not safety.
- Solo/unlinked games: no turn limits, nothing changes.

## Persistent presence: your ship in the world

When linked, your ship has a **canonical server-side state**: location,
build (hull/weapons/shields/gadgets), carried cargo & credits, banked
credits, pod/insurance flags, parked posture. It updates every time you
dock or warp (each turn spent syncs). While you're offline, your ship
is *parked* wherever you left it.

### Parking postures (chosen at logout/dock, default = safest available)

| Posture | Requirement | Effect while offline |
|---|---|---|
| **Docked, core** | system threat tier SAFE | Unraidable. Police jump any attacker (attacker fights the *police fleet* first, eats a −30 record hit and sector-wide news). |
| **Docked, contested/hostile** | — | Raidable, but station defenses add +2 effective fighter skill and attacker pays a docking-assault news event (always witnessed — stations have cameras). |
| **Cloaked drift** | Cloaking Device gadget | Hidden from scans: 85% undetectable per scan attempt (attacker scanner gadget improves odds). Found = normal fight, no station bonus. |
| **Anomaly shelter** | park in a nebula-anomaly system (each region has ~1; discoverable, marked on map once visited) | Undetectable, period. But anomaly systems have no market/shipyard and entering/leaving costs +1 turn — safety is a detour. |
| **Open berth** | — (the default if you just close the app in space) | Fully scannable. Don't sleep in the open on the frontier. |

### Raids: attacking an offline ship

- Attacker must be in the same system, spend a scan (and beat cloak
  odds if any), then commit to the assault — **no take-backs, and the
  raid consumes 3 turns** (scouting, positioning, the fight).
- Combat resolves **server-side** with the existing engine
  (`Combat.attack` loop): defender fights back automatically using
  their real build and skills, plus posture bonuses. Seeded dice; the
  full combat log is stored and delivered to both parties.
- Defender AI policy (set in settings): *fight to the end*, *flee at
  50% hull* (pilot-skill escape rolls, exactly like live combat), or
  *surrender cargo if outgunned* (lose carried cargo, keep ship).
- **Stakes if the defender's ship dies**: attacker loots carried cargo
  + carried credits (not bank). Defender's pod fires — **online or
  offline, linked commanders never die permanently**: no pod = respawn
  in a rescue Flea at the nearest core world (harsh); pod = same but
  dignified; insurance = ship-value payout on top (premiums and the
  no-claim counter finally earn their keep). Quests in progress fail
  naturally if the cargo died with the ship. Narrative state untouched.
- **Stakes for the attacker**: real combat risk against the defender's
  build (raiding a Wasp in a Flea is suicide-by-dice); a witnessed raid
  (any survivor, any docked assault, any police response) puts their
  name in the galaxy-wide news and makes them bountyable; police
  record consequences mirror live combat rules.
- **Witness rules apply**: destroy an open-berth ship in deep frontier
  with no survivors (pod away = the survivor IS the witness — pods talk)
  and the victim learns only "your ship was lost near X." Pods
  guarantee the victim learns the attacker's name — insurance includes
  the flight recorder. So flying podless is anonymity for your killer;
  one more real trade-off.

### Finding people

- **Port logs**: every station lists the last ~10 dockings (handle,
  real-day timestamp) — unless the visitor paid the harbormaster to be
  scrubbed (credits sink, lawless systems only).
- **Scanner sweeps**: a scan lists non-hidden parked ships in-system.
- **The news**: deeds leave trails. The wall (below) leaves better ones.
- Roster shows region-level location only ("last seen: Korris Expanse").

## Banking

High-tech systems (tech ≥ 6) host the **Bank of the Galaxy**: deposit/
withdraw carried credits, 2% deposit fee (credit sink). Banked credits
are unlootable and fund bounty escrow. Carried credits are loot. The
walk from a big score back to a bank branch through hostile space is
now a genre-defining moment — as it was in 2002.

## Bounties (reworked from v1)

With server-authoritative banks, bounties are **real credits in
escrow** (v1's Renown-only design is dropped; prestige survives as a
leaderboard stat). Post from your bank balance on any handle; claiming
requires destroying that commander's ship in a raid or defense
(server-verified). Multiple bounties stack. The board is public and
juicy news fodder. Minimum bounty high enough to be an insult worth
having (1,000 cr).

## Message boards — "the wall"

Every station has a board; every board is a bathroom wall.

- Post at any station you're docked at: 240 chars, pinned to that
  system, newest-first, capped ~50 visible (older fade out).
- **Signed or anonymous.** Anonymous posts cost 100 cr (the
  harbormaster's discretion fee) and high police-record commanders
  can't post anonymously in core systems (everyone knows the hero).
- Boards are where the game's society actually happens: warnings
  ("VOSS camps the Tycho wormhole"), taunts, trade intel true and
  false, eulogies, bounty ads. Server-side: profanity filter, 5
  posts/day/commander, report + shadow-delete, block list.
- Later LLM hook: NPC dockworkers occasionally reply.

## Shared market pressure (unchanged from v1, now with teeth)

Server-verified trades produce capped (±25%), real-time-decaying price
modifiers per (system, good). Turn caps make cornering a market a
multi-day campaign instead of a no-life afternoon.

## Authority model (v2 — sharper than v1)

| State | Authority | Notes |
|---|---|---|
| Ship build, location, carried cargo/credits, bank, posture, turns | **Server** | The PvP-touchable core. Client actions (buy/sell/warp/park) are commands the server validates against ITS state (prices within modifier bounds, cargo ≤ bays, turns available). |
| Combat vs players (raids/defenses) | **Server** | Engine runs server-side, seeded dice, stored logs. |
| Quests, rivals, vignettes, police record, reputation, solo encounters | **Client** | Personal narrative. Server ingests *witnessed* events for news only. |
| News, boards, bounties, port logs, leaderboards | **Server** | |

Honest note: solo-encounter outcomes still feed credits/cargo deltas
that the server accepts within plausibility bounds (bounty tables,
cargo-class caps, rate limits). A determined cheater can inflate their
solo income; they cannot mint bank balance arbitrarily fast, cannot
fake raid outcomes, and cannot touch anyone else's state. Good enough
for friendly seasons; tighten later if it matters.

## Phases (v2)

| Phase | Contents | Notes |
|---|---|---|
| 0 | Extract `packages/darknova_core` (engine+models, pure Dart); server skeleton (shelf + SQLite) behind Caddy `/api` | mechanical; Sonnet-speccable |
| 1 | Link/auth, season seed, shared GNN wire, presence + port logs, **message boards** | boards moved up from v1 — cheap, defining |
| 2 | Turn economy + server-canonical ship state + banking | the big architectural step |
| 3 | Raids: postures, scans, server combat, pods/insurance, loot; bounty escrow | the Trade Wars heart |
| 4 | Market pressure, golden contracts, leaderboards, season chronicle (LLM) | |
| 5 (future) | Live duels, convoys, corp/guild structures, player stations with citadel-style defenses | TW2002 citadels, one day |

## Open questions for our review

1. **Turn budget**: 50/day banked to 150 — feel right? (TW2002 ran
   150–250 but its turns were cheaper actions.)
2. **Offline-death severity**: v2 says never permadeath (rescue Flea at
   worst). TW2002 was crueler. Keep the floor, or is losing an
   uninsured Wasp not scary enough for you?
3. **Raid turn cost** (3) and cloak odds (85%) are dials I made up —
   playtest and tune, or reason harder now?
4. **Anonymous wall posts**: keep, or does every post being signed make
   better society? (My lean: keep anonymity, it's the bathroom wall.)
5. **Defender AI policy default**: fight / flee-at-50% / surrender —
   I'd default to flee-at-50%.
6. **Solo-income plausibility bounds**: how much anti-cheat rigor
   before it stops being fun to build? My lean: bounds + rate limits,
   nothing fancier this year.
7. **Sequencing vs LLM proxy**: unchanged recommendation — proxy first,
   then Phases 0–1. Boards + wire alone will make the game feel
   inhabited.
