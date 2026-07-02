# Dark Nova ][ — AI Modernization Concept

**Expanding the game with LLM-driven narrative (Claude) and near-realtime generated
graphics (Nano Banana 2 Lite).**

Status: concept / design draft — 2026-07-01

---

## 1. Where the game stands today

The remake is a solid, cleanly-layered Space Trader core (~8k lines of Dart):

| Layer | State |
|---|---|
| Data model (goods, ships, governments, skills, reputation) | ✅ Complete, JSON-serializable |
| Economy (price formula, quantities, drift, status events) | ✅ Complete |
| Galaxy generation (120 systems, wormholes, deterministic seed) | ✅ Complete (name-list bug fixed 2026-07-01; 41/41 tests green) |
| Travel (fuel, range, wormholes, auto-repair) | ✅ Complete |
| Trade / shipyard / finance (debt, escape pod, insurance) | ✅ Complete |
| Encounters | ⚠️ **Rolled but never played** — `warpTo` rolls police/pirate/trader/monster and generates an NPC ship, but no screen consumes it. No combat, no parley. |
| Persistence | ✅ Auto-save via shared_preferences |
| UI | ✅ 7 screens, dark sci-fi Material 3 theme |

The single biggest classic-gameplay gap is the **encounter system** — and it is
exactly where LLM integration lands most naturally, so the two workstreams merge.

---

## 2. The vision

Space Trader's magic was emergent narrative from dry numbers: you *imagined* the
pirate ambush, the plague on Japori, the smuggling run. The 2026 remake makes the
imagination layer real:

- **Every faceless encounter becomes a conversation.** Pirates hail you. Police
  captains have moods. Traders haggle in character.
- **The galaxy reports on itself.** A Galactic News Network writes daily bulletins
  from actual engine state — the war on Carzon that doubles ore prices is now a
  headline, not just a `SystemStatus` enum.
- **Quests are authored on demand** around engine-verified objectives.
- **Every system, ship, and character has a face** — generated in ~4 seconds,
  cached forever.

The design rule that keeps this shippable: **the deterministic Dart engine remains
the single source of truth.** The AI layer narrates and illustrates state; it never
*decides* state. If the network is down, the game plays exactly like classic Space
Trader with canned text and stock art.

---

## 3. LLM layer (Claude API)

### 3.1 Architecture

Dart has no official Anthropic SDK, and API keys must never ship in a client
binary. So all AI traffic goes through a thin **backend proxy**:

```
Flutter client (iOS/Android/Web/Desktop)
   │  POST /narrate  { event: "encounter", state: {...trimmed game state...} }
   ▼
Proxy (Cloudflare Worker or small Dart/Node server)
   │  - holds ANTHROPIC_API_KEY + GEMINI_API_KEY
   │  - assembles prompt: [stable system prompt (cached)] + [game-state JSON]
   │  - enforces per-player rate limits & spend caps
   │  - caches deterministic outputs (news, system descriptions)
   ▼
Claude API  (raw HTTPS /v1/messages — structured outputs via output_config.format)
```

Key API techniques (current as of mid-2026):

- **Structured outputs** (`output_config: {format: {type: "json_schema", ...}}`)
  so every AI response is schema-validated JSON the engine can trust — e.g. a
  parley result is `{disposition, dialogue, demandCredits?, offer?}`, never free
  text the client has to parse.
- **Tool use for negotiation**: during a parley the model gets tools like
  `demand_cargo(good, qty)`, `accept_bribe(credits)`, `attack()`, `flee()` —
  the engine executes only legal moves, so the LLM can't invent credits or cargo.
- **Prompt caching**: the game-lore system prompt (~2–4k tokens: universe bible,
  tone guide, faction voices) is a frozen cacheable prefix; volatile game state
  goes after the breakpoint. Cache reads cost ~0.1× input price.
- **Batch API** (50% off) for the daily news cycle and any pre-generation.

### 3.2 Model tiering

| Use case | Model | Why | Rough cost |
|---|---|---|---|
| Encounter dialogue, parley turns | `claude-haiku-4-5` ($1/$5 per MTok) | Fast, cheap, character voice is well within Haiku | ~$0.001–0.003 per encounter |
| Galactic News Network (daily digest) | `claude-haiku-4-5` via Batch API | High volume, not latency-sensitive | fractions of a cent per bulletin |
| Quest generation, story arcs, GM | `claude-opus-4-8` ($5/$25 per MTok) | Multi-constraint plotting against real game state | ~$0.02–0.05 per quest |
| Ship's computer companion ("EVA") | Haiku default, Opus for milestone moments | | |

A heavy play session (20 warps, 8 talky encounters, 1 generated quest, news each
day) lands around **$0.05–0.10/session** — before caching and batch discounts.

### 3.3 Feature set

**F1 — Galactic News Network (lowest risk, highest charm).**
Each in-game day, the proxy feeds the engine's system statuses + recent player
deeds to Haiku and gets back 3–5 headlines ("DROUGHT ON REGULAS ENTERS THIRD
WEEK — WATER FUTURES SOAR"). Prices already move on `SystemStatus`; now the player
reads *why* and can trade on the news. Pure flavor → zero gameplay risk, fully
cacheable per (seed, day).

**F2 — Living encounters (completes the missing subsystem).**
Build the deterministic encounter/combat screen first (attack/flee/surrender
resolved by engine math — this is needed regardless). Then add the **Hail**
button: opens a parley where Claude plays the pirate/police/trader using the
structured-output + tool-use scheme above. Commander reputation, police record,
cargo manifest, and government type all feed the character's knowledge. Outcomes
are engine-enforced (a bribe transfers real credits; contraband found in a real
inspection uses the real cargo map).

**F3 — Dynamic quests.**
Opus generates quest *narratives* around objective templates the engine validates:
`deliver(good, qty, systemIndex, deadline)`, `bounty(npcShipType, systemIndex)`,
`rescue(systemIndex)`. The engine checks feasibility (system reachable, goods
tradeable, reward within economy bounds) before offering it. Rejected generations
are retried with the validator error in the prompt.

**F4 — Ship's computer companion.**
A persistent character that comments on the player's trajectory ("Third narcotics
run this week, Commander. The police record concerns me."). Cheap Haiku calls,
strictly rate-limited, easily disabled.

### 3.4 Guardrails

- **Offline-first**: every AI feature has a canned fallback (classic Space Trader
  strings). AI text is an enhancement layer with a timeout (~3s), never a blocker.
- **Spend caps** in the proxy per player/day; hard monthly ceiling.
- **No state authority**: the model proposes via tools; the engine disposes.
- **Content**: system prompt pins tone (PG-13 space opera); structured outputs
  keep responses on-rails.

---

## 4. Graphics layer (Nano Banana 2 Lite)

### 4.1 What it is

Google's **Nano Banana 2 Lite** (model ID `gemini-3.1-flash-lite-image`, launched
2026-06-30 on the Gemini API) generates 1K images in **~4 seconds at $0.034 per
image**, with strong prompt adherence, character consistency, and image-editing /
multi-image-composition support. That price/latency point changes what's feasible:
generated art per *game entity*, not hand-drawn packs.

"Near-realtime" here means **per-scene, not per-frame**: the game stays a 2D
Flutter UI; Nano Banana supplies illustrated vistas, portraits, and event art that
appear within a warp animation's duration.

### 4.2 Where images appear

| Surface | Trigger | Prompt inputs | Volume |
|---|---|---|---|
| System vista (hub screen backdrop) | First arrival at a system | name, tech level, government, special resource, status, size | ≤120 per galaxy |
| Encounter scene | Encounter starts | NPC ship type, encounter type, system backdrop | ~15 ship types × 4 contexts |
| NPC portrait | Parley opens | faction, government style, disposition | small, heavily reused |
| News illustration | Daily GNN bulletin | headline | 1–3/day, optional |
| Quest card | Quest offered | quest synopsis | 1 per quest |
| Commander portrait | New game | player-chosen descriptors | 1, player-facing delight |

### 4.3 Determinism, caching, and cost

The galaxy is seeded and system attributes are finite, so **prompts are
deterministic**: `hash(style_version + entity_attributes)` is the cache key.

```
Client asks proxy for image(key)
  ├─ CDN/storage hit  → serve immediately (vast majority after week 1)
  └─ miss             → Nano Banana 2 Lite (~4s) → store → serve
```

- Full unique-galaxy vista set: 120 × $0.034 ≈ **$4 per galaxy** — but because
  vistas key on *attributes* (not system name), a few hundred archetype images
  serve **all** players' galaxies. Effectively a one-time ~$15–30 art budget,
  amortized to ~zero marginal cost.
- Style consistency: one locked "art bible" style block in every prompt +
  Nano Banana's multi-image composition with 2–3 reference images to pin the
  house style. Bump `style_version` to regenerate the world's look overnight.
- The 4s generation fits inside the warp/hail animation; a blurhash/stock
  placeholder covers the gap; offline mode uses the shipped placeholder pack.

### 4.4 Ambient motion (stretch)

For "alive" backdrops without video costs: generate 2–3 vista variants and
crossfade, or pass a vista to **Gemini Omni Flash** (image→video, same launch)
for short ambient loops on hero moments only (title screen, quest climaxes) —
video is meaningfully more expensive, so it stays a garnish.

---

## 5. Phased roadmap

| Phase | Scope | Depends on |
|---|---|---|
| **0. Core completion** | `git init` + GitHub repo; deterministic encounter/combat screen (consume the existing `Encounter` roll); balance pass | nothing |
| **1. Proxy + GNN** | Deploy proxy (CF Worker), key management, spend caps; Galactic News Network with canned fallback | 0 |
| **2. Living encounters** | Hail/parley UI, structured-output + tool-use negotiation, Haiku | 0, 1 |
| **3. Generated art** | Nano Banana pipeline + CDN cache, system vistas first, then encounter scenes/portraits | 1 |
| **4. Quests + companion** | Opus quest generator with engine validator; ship's computer | 2 |
| **5. Polish/stretch** | Commander portraits, news illustrations, Omni Flash ambient loops | 3 |

Each phase ships independently; the game is fully playable (offline, classic-style)
at every point.

---

## 6. Risks

| Risk | Mitigation |
|---|---|
| API keys in a shipped client | Proxy-only; keys never leave the server |
| Runaway spend | Per-player rate limits, daily caps, aggressive caching, Haiku-first tiering |
| Latency ruins pacing | 3s timeouts + canned fallbacks; images hidden behind warp animation |
| LLM breaks game balance | Engine-authoritative design; structured outputs; validator loop for quests |
| Art style drift | Locked style block + reference-image composition + versioned cache |
| Model churn (both vendors ship fast) | Model IDs are proxy config, not client code |

---

## 7. Sources

- [Google: Start building with Nano Banana 2 Lite and Gemini Omni Flash](https://blog.google/innovation-and-ai/models-and-research/gemini-models/gemini-omni-flash-nano-banana-2-lite/)
- [VentureBeat: Nano Banana 2 Lite (Gemini 3.1 Flash-Lite), 4-second $0.034 image generation](https://venturebeat.com/technology/google-unveils-nano-banana-2-lite-aka-gemini-3-1-flash-lite-for-low-cost-4-second-fast-enterprise-image-generations)
- [Gemini API image generation docs](https://ai.google.dev/gemini-api/docs/image-generation)
- [Nano Banana 2 Lite deep dive (kie.ai)](https://kie.ai/blog/nano-banana-2-lite-google-image-model)
- [Nano Banana family pricing comparison](https://blog.laozhang.ai/en/posts/nano-banana-2-api-pricing-guide)
- Claude API: current model lineup/pricing from the Anthropic API reference (Opus 4.8 $5/$25 per MTok, Haiku 4.5 $1/$5 per MTok; structured outputs via `output_config.format`; prompt caching; Batch API 50% off)
