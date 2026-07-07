# SPEC: Galaxy Expansion — 400 Systems, Clustered Sphere

Status: approved for implementation · Target: darknova2 `main`
Author: design session 2026-07-06. Implementer: any model. Follow exactly;
where this spec is silent, preserve existing behavior.

## Goal

Expand the spherical galaxy from 120 systems / R=36pc to **400 systems /
R=66pc**, with **dramatic clustering** (named reaches separated by voids),
procedural frontier names, more wormholes, and painter LOD so the map
stays at 60fps. Trade-hop density stays the same; crossing the galaxy
grows from ~4 to ~7–8 full-tank jumps.

## Invariants — do not break

1. `flutter analyze` produces **no errors**; `flutter test` fully green.
2. Engine files stay pure Dart (no Flutter imports) — everything under
   `lib/engine/` and `lib/models/`.
3. Old saves (120 systems) must still **load and play**. All code must
   derive counts from `state.solarSystems.length` — never hardcode 400.
   (Search for existing hardcoded `120`; the only allowed ones are inside
   `GalaxyGenerator` and the canonical name list.)
4. `GalaxyGenerator.solIndex == 92` and `systems[92].name == 'Sol'` with
   its existing fixed attributes (tech 7, democracy, size 5, uneventful).
5. Determinism: same seed → identical galaxy. No `Random()` without a
   seed inside generation code paths.
6. Every system must be reachable: nearest-neighbor great-circle
   distance < 28.0 pc (full starter-class tank) for **every** system.
   This is enforced by an existing test — keep it passing at N=400.
7. Do not touch: `lib/engine/parley.dart`, combat, quests, news, events,
   rivals, providers (except where listed), any screen except
   `galaxy_map_screen.dart`.

## 1. Constants — `lib/engine/sphere.dart`

Change `SphereGeo.radius` from `36.0` to `66.0`. Update the doc comment:
area now ≈ 4π·66² ≈ 54 700 pc², ~137 pc² per system at N=400 — same
density as the old chart. Everything else in this file is unchanged.

## 2. Generation — `lib/engine/galaxy_generator.dart`

### 2.1 Counts

```dart
static const int _systemCount = 400;
static const int _wormholeCount = 12;   // was 6
static const int _clusterCount = 10;
```

### 2.2 Clustered placement (replaces the plain Fibonacci loop)

Keep the existing Fibonacci-lattice loop that yields `(lat, lon)` per
index (with the same jitter). Then add a **cluster pull** step before
converting to chart coordinates:

```
// 1. Pick cluster centers: 10 points, themselves from the Fibonacci
//    lattice of size 10 with a seeded random spin offset (rng from the
//    same `rng` object, drawn AFTER the spinOffset draw so existing
//    draw order for names/attributes is otherwise unchanged — see 2.5).
// 2. For each system point p (unit vector):
//      find nearest cluster center c (max dot product)
//      θ = angle between p and c            // acos(clamp(dot,-1,1))
//      pull = 0.45 * exp(-(θ/0.55)^2)       // strong near center, ~0 far
//      p' = slerp(p, c, pull)               // move fraction `pull` toward c
//      normalize p'
// 3. Convert p' to (lon, lat) → SphereGeo.chartOf → round to ints,
//    clamp x to 0..149, y to 1..109 (same as now).
```

`slerp(a, b, t)`: if angle Ω between a and b < 1e-6, return a; else
`(sin((1-t)Ω)·a + sin(tΩ)·b) / sin(Ω)`.

This produces dense reaches around 10 centers and visible voids between
them (the "dramatic" look), while the lattice base guarantees no huge
bald patches.

### 2.3 Stranding repair pass

After all 400 positions exist (before building `SolarSystem` objects):

```
repeat up to 5 times:
  changed = false
  for each point i:
    d = min great-circle distance (via SphereGeo.angleBetween × radius)
        to any other point
    if d >= 27.0:                     // 1 pc safety margin under 28
      j = index of nearest point
      move i 40% of the way toward j (slerp t=0.4), re-round to chart ints
      changed = true
  if !changed: break
```

O(N²) per pass (400² = 160k dots) is fine at generation time.

### 2.4 Names

Keep `_systemNames` (120 canonical) exactly as is. Assign names AFTER
attributes are rolled (see 2.5 ordering caveat):

- Sort candidate indices by desirability: `techLevel*10 + size`,
  descending, but **force index 92 (Sol) to always receive 'Sol'** and
  skip it in the sort.
- The top 119 non-Sol systems get the remaining canonical names
  (shuffled with the existing `rng` as today).
- All other systems get procedural names from `_frontierName(rng)`:

```dart
static const _onsets = ['K','V','Th','Dr','S','M','R','Az','Bel','Cor',
  'Dal','Er','Gr','Hal','J','L','N','Or','P','T','Vy','Z','Qu','X'];
static const _mids   = ['a','e','i','o','u','ae','ia','or','ar','un',
  'el','ir','os','ur','an'];
static const _ends   = ['ris','mar','dun','th','ka','von','das','x',
  'nia','rus','tis','gol','ph','met','zar','din'];
String name = onset + mid + end                 // e.g. 'Korris', 'Vaeldun'
if rng.nextInt(5) == 0: name += ' ' + ['Reach','Deep','Gate','Verge',
  'Anchorage','Drift'][rng.nextInt(6)];
```

Collision-check against all names assigned so far; on collision, redraw
(loop; the space is ~5 000 combos, plenty for 280).

### 2.5 RNG draw-order caveat (determinism, not compatibility)

Galaxy layout changes anyway, so byte-identical galaxies vs. today are
NOT required. Just keep every draw inside `generate()` on the single
seeded `rng`, in one fixed code order, so a given seed is reproducible.

### 2.6 Cluster names (regions)

Generate 10 region names with `_frontierName` + forced suffix from
`['Reach','Expanse','Verge','Cluster','Gulf','Chain','Rim','Spur',
'Corridor','Shoals']` (index = cluster number, no rng needed for the
suffix). **Storage:** add to `SolarSystem` a new field
`final String region;` (default `''`), serialized in
`toJson`/`fromJson` as `'region'` with `json['region'] ?? ''` fallback
(old saves → empty). Assign each system the name of its nearest cluster
center. Sol's region: whatever cluster it lands in (no special case).

Display: in `galaxy_map_screen.dart` `_SystemInfoCard`, append region to
the government/tech line when non-empty:
`'${system.government.displayName} · Tech ${system.techLevel} · ${system.status.displayName}${system.region.isEmpty ? '' : ' · ${system.region}'}'`.

### 2.7 Wormholes

Existing pair logic unchanged, count now 12. Add one improvement: when
picking wormhole endpoints, reject a pair whose great-circle distance
< 60 pc (redraw, max 200 attempts, then accept whatever) — wormholes
should span voids, not link neighbors.

## 3. Map performance — `lib/screens/galaxy_map_screen.dart`

In `GlobePainter._paintSystems` (400 systems/frame):

1. **Halo LOD**: skip the radial-gradient halo entirely when
   `dimmed && camera.radiusPx < 420` OR the star's computed `r < 2.0`.
   Draw only core + white center in that case (2 cheap circles).
2. **Ghost LOD**: for back-hemisphere ghosts, draw at most every 2nd
   system (`if (i.isOdd) continue;` inside the `!p.front` branch) when
   `camera.radiusPx < 420`.
3. **Label LOD**: change thresholds — reachable/wormhole labels at
   `radiusPx > 320` (was 210); visited-major labels at `radiusPx > 760`
   (was 520).
4. Everything else in the painter is unchanged.

## 4. Fuel-range framing

`_focusRange` in `galaxy_map_screen.dart`: unchanged code, but sanity
check after R change: with range 28pc, `alpha = 28/66 ≈ 0.42 rad` — the
zoom formula already handles it. No edit expected; just verify manually.

## 5. Tests — update/add in `test/starmap_test.dart`

Update:
- 'antipodal points…' test: unchanged (angle-based, radius-agnostic).
- Generation test: expect `systems.length == 400`; Sol assertions as-is.
- Spacing test: O(N²) at 400 is 80k pairs — keep, assert
  `minAngle > 0.008` (chart-grid rounding at N=400 allows close pairs;
  the real guarantee is the stranding test below).
- 'every system can reach a neighbor on a full tank': keep threshold
  `lessThan(28.0)` — this is the load-bearing test for 2.3.

Add:
- 'canonical names go to the biggest worlds': generate; assert
  `systems[92].name == 'Sol'`; assert every canonical name from a copied
  list appears at most once; assert ≥ 200 systems have names NOT in the
  canonical list (procedural frontier).
- 'names are unique': `systems.map((s)=>s.name).toSet().length == 400`.
- 'regions assigned': every `system.region` is non-empty for a NEW
  galaxy; exactly ≤ 10 distinct region names.
- 'old saves without region field load': take `newGame().toJson()`,
  remove `'region'` from every entry in `json['solarSystems']`, call
  `GameState.fromJson`, expect no throw and `region == ''`.
- 'wormholes span distance': for each of the 12 pairs assert
  `SphereGeo.distance(a, b) >= 60 || true`-style soft check is NOT
  acceptable — instead assert at least 8 of 12 pairs ≥ 60 pc (the
  200-attempt fallback may occasionally accept shorter).

Also update `test/engine_test.dart`:
- The great-circle test values change with R=66: distance(a,b) for the
  fixture (x 10→16 at y=10) scales by 66/36 → expect
  `closeTo(2.54 * 66/36, 0.1)` ≈ 4.66. Antipode: `pi * SphereGeo.radius`
  (already written radius-relative — verify, don't duplicate).
- Any other test that hardcodes 120 or a distance: make it relative to
  `SphereGeo.radius` or `state.solarSystems.length`.

Run the FULL suite 3× (flaky-check) before finishing.

## 6. Balance check (manual, report numbers in the summary)

After building, print from a scratch test or debug print:
- average nearest-neighbor distance (expect ≈ 8–14 pc),
- max nearest-neighbor distance (must be < 28),
- min/max wormhole span.
Include these numbers in the final summary message.

## 7. Deploy

```sh
flutter build web --release
rsync -az --delete build/web/ shon@45.77.127.32:~/darknova2-web/
ssh shon@45.77.127.32 'systemctl --user restart darknova2.service'
curl -s -o /dev/null -w "%{http_code}" https://2.darknova.org/   # expect 200
```

Commit style: imperative subject, body explaining what/why, and append:

```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Pitfalls (read twice)

- `SolarSystem` is immutable with `copyWith`/`toJson`/`fromJson` — when
  adding `region`, update **constructor, copyWith, toJson, fromJson,
  and every existing constructor call site** (galaxy_generator builds
  them via `_buildSolarSystem`; engine_test builds three fixtures — give
  fixtures `region: ''` via the default, i.e. make the parameter
  optional with default `''` so call sites don't need edits).
- Chart coordinates are INTs on a 150×110 grid. At N=400 two systems MAY
  round to the same cell after clustering; that's acceptable for
  gameplay (distance 0 → fuel 1) but the stranding pass must not
  infinite-loop on identical points: `slerp` guard for angle < 1e-6
  returns `a` — then nudge by adding 1 to x mod 150 instead.
- `Economy._deterministicRng` seeds off `system.x*31 + y*17 + ...` —
  colliding cells share price RNG; harmless, ignore.
- Do NOT re-introduce `Random()` (unseeded) anywhere in `generate()`.
- The dust layers in the painter key off `galaxySeed` — untouched.
- Keep `_labelCache` — do not clear it per frame.
```
