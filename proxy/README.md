# Dark Nova ][ — LLM Proxy

Thin backend proxy between the Flutter game client and the Claude API
(phase 1 of `docs/AI_MODERNIZATION.md`). It generates **flavor prose only**:

- `POST /v1/dialogue` — one in-character line for a parley/hail beat. The
  request carries the engine's **already-decided outcome** plus trimmed
  context; the proxy never decides outcomes, amounts, or rules.
- `POST /v1/news` — one Galactic News Network item (headline + short
  paragraph) from an engine-provided event summary.
- `GET /healthz` — liveness probe; reports the configured model.

Design rule (same as the game): **the deterministic Dart engine is the single
source of truth.** If this service is down, slow, rate-limited, or refuses,
it answers `503` and the game plays on with canned classic-Space-Trader text.

Built in: zod request validation (strict — unknown fields rejected), per-IP
token-bucket rate limiting, an in-memory LRU response cache with TTL keyed on
the request hash, BYOK (`X-Api-Key` header overrides the server key), a strict
prose-only system prompt with word caps enforced server-side, and hard
per-call timeouts (default 3 s).

## Requirements

- Node.js 22+
- An Anthropic API key (unless all clients bring their own)

## Run locally

```sh
cd proxy
npm install
cp .env.example .env        # edit: set ANTHROPIC_API_KEY
set -a; . ./.env; set +a
npm start                   # listens on :8095 by default
```

Smoke test:

```sh
curl -s localhost:8095/healthz

curl -s localhost:8095/v1/dialogue \
  -H 'content-type: application/json' \
  -d '{
    "speaker":  {"role": "pirate", "shipType": "Gnat"},
    "outcome":  {"action": "demand_credits", "details": {"credits": 500}},
    "context":  {"systemName": "Tarchannen", "commanderName": "Jameson"},
    "maxWords": 30
  }'

curl -s localhost:8095/v1/news \
  -H 'content-type: application/json' \
  -d '{
    "event":   {"type": "drought", "summary": "Drought on Regulas enters its third week; water reserves critically low."},
    "system":  {"name": "Regulas", "government": "Feudal State"},
    "gameDay": 42,
    "seed":    "galaxy-1"
  }'
```

## Tests

No live API calls — the Anthropic client is injected and mocked.

```sh
npm test
```

## API

### `POST /v1/dialogue`

Request (all objects are strict — unknown fields are a `400`):

| field | type | notes |
|---|---|---|
| `speaker.role` | `pirate \| police \| trader` | who speaks (never the player) |
| `speaker.shipType` | string | e.g. `Gnat` |
| `speaker.name` | string? | optional NPC name |
| `outcome.action` | enum | `hail`, `demand_cargo`, `demand_credits`, `attack_warning`, `accept_surrender`, `accept_bribe`, `refuse_bribe`, `inspection_clean`, `inspection_contraband`, `trade_offer`, `ignore`, `flee`, `taunt` |
| `outcome.details` | map? | engine facts only (amounts, goods) — string/number/bool values |
| `context.systemName` | string | current system |
| `context.government`, `context.commanderName`, `context.reputation`, `context.policeRecord` | string? | trimmed flavor context |
| `maxWords` | int 5–80, default 40 | hard cap, also enforced server-side |

### `POST /v1/news`

| field | type | notes |
|---|---|---|
| `event.type` | enum | `war`, `plague`, `drought`, `boredom`, `cold`, `crop_failure`, `lack_of_workers`, `status_ended`, `player_deed`, `market` |
| `event.summary` | string ≤500 | the facts; the article may not add new ones |
| `system.name` | string | plus optional `government`, `techLevel` |
| `gameDay` | int ≥0 | part of the cache identity |
| `seed` | string/number? | galaxy seed, so all clients of a galaxy share cached articles |
| `maxWords` | int 20–200, default 120 | hard cap |

### Responses (both endpoints)

- `200` — `{"text": "...", "model": "...", "cached": true|false}` plus an
  `X-Cache: HIT|MISS` header. `text` is plain prose (news: ALL-CAPS headline
  on line 1, body after).
- `400` — `{"error": "invalid_request", "issues": [...]}` or `invalid_json`.
- `401` — `{"error": "invalid_api_key"}` (upstream rejected the key — fix the
  BYOK key rather than falling back).
- `429` — `{"error": "rate_limited", "retryAfterSec": n}` + `Retry-After`.
- `503` — `{"error": "llm_unavailable"}` — **use engine-side canned prose.**

### Client integration notes

- Treat `503`, `429`, timeouts, and network errors identically: show the
  canned line. Set the client-side HTTP timeout a bit above `LLM_TIMEOUT_MS`
  (e.g. 4 s for the default 3 s).
- Send the outcome *after* the engine resolves it; never apply anything from
  the response except displaying `text`.
- BYOK: pass the player's key as `X-Api-Key`. Cached responses are shared
  across keys (they're just prose).
- News caching: keep `seed` + `gameDay` stable for a given galaxy/day so the
  daily bulletin is generated once and served from cache afterwards.

## Deploy (Ubuntu VPS, systemd)

```sh
# as root on the VPS
adduser --system --group --home /opt/darknova-proxy darknova
# copy or clone the repo's proxy/ directory to /opt/darknova-proxy/app
cd /opt/darknova-proxy/app && sudo -u darknova npm install --omit=dev

install -m 600 -o darknova .env.example /opt/darknova-proxy/env
$EDITOR /opt/darknova-proxy/env    # set ANTHROPIC_API_KEY (and TRUST_PROXY=1 if proxied)
```

`/etc/systemd/system/darknova-proxy.service`:

```ini
[Unit]
Description=Dark Nova ][ LLM proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=darknova
Group=darknova
WorkingDirectory=/opt/darknova-proxy/app
EnvironmentFile=/opt/darknova-proxy/env
ExecStart=/usr/bin/node src/server.js
Restart=on-failure
RestartSec=2

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=

[Install]
WantedBy=multi-user.target
```

```sh
systemctl daemon-reload
systemctl enable --now darknova-proxy
curl -s localhost:8095/healthz
```

Put it behind your reverse proxy of choice (nginx/caddy) under whatever
hostname you like, terminate TLS there, and set `TRUST_PROXY=1` so per-IP
rate limiting sees real client addresses. Example nginx location block:

```nginx
location / {
    proxy_pass http://127.0.0.1:8095;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $host;
}
```

## What's deliberately NOT here yet

- Per-player spend caps / daily budgets (phase 1 doc calls for them; the
  per-IP limiter is the interim guard).
- Persistent cache (in-memory only — restarts regenerate).
- Structured-output parley negotiation with tool use (phase 2).
- Image generation endpoints (phase 3).
