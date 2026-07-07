# SPEC: Wormhole Visibility & Path Visualization

Status: approved · Scope: UI only — `lib/screens/galaxy_map_screen.dart`
(and its test file). Do NOT touch any engine file, model, or provider.

## Problem

12 wormhole pairs among 400 systems are nearly invisible: thin dashed
chords, and only the *current* system's partner gets a ring. Players
can't find wormholes, and selecting a wormhole system gives no sense of
where its tunnel goes.

## Invariants

1. `flutter analyze` zero errors; full `flutter test` green ×3.
2. 60fps discipline: no per-frame allocations beyond what the painter
   already does; reuse the existing `time` ValueNotifier for animation.
3. Existing behaviors unchanged unless listed: threat colors, range cap,
   quest beacon, limb markers, legend, info card contents (except the
   addition in §4), tap handling (except §5).
4. No git commit/push/deploy.

## Definitions

A system `s` "has a wormhole" iff `s.specialEvent != null &&
s.specialEvent! >= 1000 && s.specialEvent! - 1000 < systems.length`.
Its partner index is `s.specialEvent! - 1000`. Add ONE private helper in
galaxy_map_screen.dart (top-level or on the painter):
`int? _wormholeOf(SolarSystem s, int systemCount)` and use it everywhere
below (including refactoring the two existing call sites that inline
this check in the screen state and painter).

## 1. Wormhole overlay toggle button

Add a third `IconButton.filledTonal` in the existing Positioned button
column (below "Whole globe"): icon `Icons.hub`, tooltip `'Wormholes'`.
It toggles `bool _wormholeMode` (screen state, default false; plain
`setState`). Visual toggled state: when ON use `IconButton.filled`
instead of `filledTonal` (same icon/tooltip).

Pass `wormholeMode` into `GlobePainter` (new final field, include in
constructor).

## 2. Painter behavior when `wormholeMode == true`

a. **Dim everything else**: in `_paintSystems`, for systems that do NOT
   have a wormhole and are not `currentIndex`: multiply their computed
   `alpha` by 0.35 (front) and skip ghosts entirely (back). Threat
   colors otherwise unchanged.
b. **Endpoint beacons**: every system that has a wormhole gets, in
   addition to its normal rendering, two expanding pulse rings in violet
   `Color(0xFFa78bfa)` — same ring code pattern as the current-system
   pulse (phase `(t * 0.6 + k * 0.5) % 1.0`, radius `r + 4 + phase*16`,
   stroke 1.3, opacity `0.6 * (1 - phase)`).
c. **Labels**: systems with wormholes always show their label in
   wormhole mode (color `Color(0xFFc4b5fd)`), regardless of zoom LOD.
d. **Links at full strength**: link opacity 0.85 front / 0.35
   through-glass (vs the normal 0.5/0.22).

## 3. Animated energy flow on links (always, mode or not)

Upgrade `_dashedLine` with an optional named param
`double phase = 0.0`: start `traveled` at `-phase % (dashLen + gapLen)`
so dashes march along the line. For wormhole links pass
`phase = t * 14.0` (t = the painter's time value). Dash motion must run
in BOTH directions consistently from endpoint a→b (pick the pair's
lower-index endpoint as `a` so the direction is stable frame to frame).

Additionally, in wormhole mode OR when the link touches the selected
system (§5), draw a **traveling pulse**: a glow dot moving a→b:
`f = (t * 0.30 + pairIndex * 0.23) % 1.0`,
`pos = a.screen + (b.screen - a.screen) * f`,
drawn as a radial-gradient circle radius 6 (violet, opacity 0.9 → 0).
One dot per link. `pairIndex` = ordinal of the pair as discovered in the
existing iteration order.

## 4. Info card: wormhole chip

In `_SystemInfoCard`, when the selected system has a wormhole, add a
chip (reuse the existing `_chip` helper) after the threat/contract
chips: label `'WORMHOLE → ${partnerName.toUpperCase()}'`, color
`Color(0xFFa78bfa)`. `partnerName` = name of the partner system. The
card already receives `game`; derive the partner via the §Definitions
helper. Keep the row's existing `Flexible`/overflow behavior — wrap the
chips row in a `Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment:
WrapCrossAlignment.center)` instead of `Row` if overflow becomes
possible (it does — do this).

## 5. Selection path emphasis

When the SELECTED system has a wormhole (regardless of mode):

a. Its link renders at full strength (§2d opacities) with the marching
   dashes (§3) AND the traveling pulse dot.
b. The partner endpoint gets one violet pulse ring (same spec as §2b but
   a single ring, k=0 only).
c. If the partner is on the back hemisphere, the existing limb-marker
   system already shows nothing for it — add a limb chevron for "the
   selected system's wormhole partner" in violet with label 'EXIT'
   (reuse the `marker(...)` helper in `_paintLimbMarkers`, passing the
   partner index). Also make that chevron tappable exactly like the
   other far-side POIs: add the partner to `_farSidePois` (empty label
   is fine there; the painter draws the labeled chevron) so tapping it
   spins the globe to the partner.

## 6. Tests — extend `test/starmap_test.dart` "Map widget" group

a. Existing smoke test: also toggle the wormhole button
   (`await tester.tap(find.byTooltip('Wormholes'))`), pump 6 frames of
   90ms, assert no exception, toggle it back off, assert no exception.
b. New test 'selecting a wormhole endpoint shows the wormhole chip':
   build the game via the provider, find a system with
   `specialEvent >= 1000` (guaranteed to exist — 12 pairs), inject the
   selection by tapping is unreliable — instead expose selection for
   testing: give `GalaxyMapScreen` an optional constructor param
   `final int? debugInitialSelection;` that seeds `_selectedIndex` in
   `initState`. Use it in this test; assert
   `find.textContaining('WORMHOLE →')` finds one widget after pumping.
   (The param is null in production; document it with a `/// Test only.`
   comment.)
c. Unit test for the helper: `_wormholeOf` must be top-level (not
   underscored-private if that blocks importing — name it
   `wormholeOf` public in that case, lowerCamelCase, doc comment) so the
   test can call it directly with a hand-built SolarSystem: returns
   partner for specialEvent 1005 → 5; null for specialEvent null, for
   specialEvent < 1000, and for partner index out of range.

## Pitfalls

- The painter's `_dashedLine` is also used by nothing else currently —
  still, keep the `phase` param optional/defaulted so any future caller
  is unaffected.
- Negative modulo in Dart: `-phase % len` can be negative; normalize
  (`((x % len) + len) % len`) before using as the start offset.
- Don't create `Paint`/gradient objects outside paint scope caching —
  per-frame creation is what the painter already does; just don't add
  loops that allocate per system in wormhole mode beyond the 24 endpoint
  systems.
- `IconButton.filled` vs `filledTonal` both need the same fixed column
  width — they do by default; no layout change.
- After edits run the FULL suite ×3 (not just starmap_test).
