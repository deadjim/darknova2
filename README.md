# Dark Nova ][

**A space trading adventure.** Buy low, sell high, outrun the law, and try
not to think too hard about what's waiting when you drop out of warp.

Dark Nova ][ is a cross-platform remake of *Dark Nova* (iPhone, 2009),
itself descended from Pieter Spronck's classic
[Space Trader for Palm OS](https://www.spronck.net/spacetrader/) — one of
the great open-source trading games. This remake preserves the economic
simulation that made Space Trader special and builds a modern narrative
layer on top of it.

## The game

- **120 star systems** on a seeded galaxy map — tech levels, governments,
  special resources, and system crises that move real prices
- **A working economy**: the classic price model (base + tech × increment
  ± variance, doubled by wars and plagues, discounted by resources)
- **Combat encounters**: police inspections, pirate attacks, traders,
  and things in the dark that are none of the above
- **The witness system**: destroyed ships tell no tales. Let a survivor
  escape and the Galactic News Network runs your name; leave no witnesses
  and your deeds stay yours. Fame and infamy are information, not meters.
- **Persistent rivals**: eight named captains per galaxy who remember.
  The pirate you spare comes back — in a bigger ship, holding a grudge.
- **Dice-spawned quests**: relief runs to plague worlds, fixers offering
  to launder your police record, freight contracts recovered from
  derelict flight recorders. Stakes are locked when the job is offered.
- **Arrival vignettes**: distress calls that might be bait, dead ships
  with intact airlocks, interdictors who know exactly what you're hauling

An LLM-driven narrative layer (dynamic dialogue, generated news prose,
rival voices) and AI-generated scene art are designed and in progress —
see [docs/AI_MODERNIZATION.md](docs/AI_MODERNIZATION.md). The game is
offline-first by design: every AI feature has an engine-side fallback,
and the deterministic game engine is always the sole authority over
game state.

## Running it

Requires [Flutter](https://flutter.dev) 3.x+.

```sh
flutter pub get
flutter test          # 91 tests
flutter run -d chrome # or any device
```

The engine (`lib/engine/`, `lib/models/`) is pure Dart with no Flutter
dependencies — it runs headless, which is how the test suite drives
entire fights, quests, and rescue decisions without a UI.

## License

Dark Nova ][ is free software, released under the
**GNU General Public License v3** (see [LICENSE](LICENSE)).

It honors its lineage: the game data model and economic design derive
from *Space Trader for Palm OS* by **Pieter Spronck**, released under the
GNU General Public License. Thank you, Pieter — this genre exists because
you gave it away.

Copyright © 2026 Shon Burton.
