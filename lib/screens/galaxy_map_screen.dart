import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../engine/sphere.dart';
import '../engine/travel.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/solar_system.dart';
import '../providers/game_provider.dart';
import '../ui/globe_camera.dart';

class GalaxyMapScreen extends ConsumerStatefulWidget {
  const GalaxyMapScreen({super.key});

  @override
  ConsumerState<GalaxyMapScreen> createState() => _GalaxyMapScreenState();
}

class _GalaxyMapScreenState extends ConsumerState<GalaxyMapScreen>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;

  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  Duration _lastTick = Duration.zero;

  final GlobeCamera _camera =
      GlobeCamera(yaw: 0, pitch: 0, radiusPx: 300);

  // Fly-to animation.
  GlobeCamera? _flyFrom;
  GlobeCamera? _flyTo;
  double _flyT = 1.0;

  // Gesture state.
  Offset _lastFocal = Offset.zero;
  double _lastScale = 1.0;
  Offset _spin = Offset.zero; // angular inertia, screen px/s

  bool _initialised = false;

  double get _fitRadius =>
      0.42 * min(_camera.viewport.width, _camera.viewport.height);
  double get _maxRadius =>
      2.4 * min(_camera.viewport.width, _camera.viewport.height);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    if (_flyT < 1.0 && _flyFrom != null && _flyTo != null) {
      _flyT = min(1.0, _flyT + dt / 0.7);
      final eased = Curves.easeInOutCubic.transform(_flyT);
      final pose = lerpGlobe(_flyFrom!, _flyTo!, eased);
      _camera
        ..yaw = pose.yaw
        ..pitch = pose.pitch
        ..radiusPx = pose.radiusPx;
    }

    // Spin inertia: flick the globe and it keeps turning.
    if (_spin.distance > 10) {
      _camera.dragBy(_spin * dt);
      _spin *= exp(-2.8 * dt);
    }

    _time.value = elapsed.inMicroseconds / 1e6;
  }

  void _flyToPose(double yaw, double pitch, double radiusPx) {
    _flyFrom = _camera.copy();
    _flyTo = GlobeCamera(
      yaw: yaw,
      pitch: pitch,
      radiusPx: radiusPx.clamp(_fitRadius, _maxRadius),
    )..viewport = _camera.viewport;
    _flyT = 0.0;
    _spin = Offset.zero;
  }

  void _flyToSystem(GameState game, int index, {double? radiusPx}) {
    final sys = game.solarSystems[index];
    final (yaw, pitch) = GlobeCamera.faceAngles(sys.x, sys.y);
    _flyToPose(yaw, pitch, radiusPx ?? _camera.radiusPx);
  }

  void _focusRange(GameState game) {
    final rangePc = max(4.0, Travel.maxRange(game.ship));
    final alpha = min(pi * 0.9, rangePc / SphereGeo.radius);
    final shortest =
        min(_camera.viewport.width, _camera.viewport.height);
    final radiusPx = shortest / (2.5 * sin(min(alpha, pi / 2)));
    final sys = game.solarSystems[game.currentSystemIndex];
    final (yaw, pitch) = GlobeCamera.faceAngles(sys.x, sys.y);
    _flyToPose(yaw, pitch, radiusPx);
  }

  void _showFullGalaxy() =>
      _flyToPose(_camera.yaw, _camera.pitch, _fitRadius);

  int? _wormholeTarget(GameState game) {
    final here = game.currentSystem;
    if (here.specialEvent != null && here.specialEvent! >= 1000) {
      final idx = here.specialEvent! - 1000;
      if (idx < game.solarSystems.length) return idx;
    }
    return null;
  }

  void _handleTap(TapUpDetails details, GameState game) {
    const hitRadiusPx = 28.0;
    int? closest;
    double closestDist = double.infinity;
    for (int i = 0; i < game.solarSystems.length; i++) {
      final sys = game.solarSystems[i];
      final p = _camera.projectChart(sys.x, sys.y);
      if (!p.front) continue; // only the visible hemisphere is tappable
      final d = (p.screen - details.localPosition).distance;
      if (d < closestDist && d < hitRadiusPx) {
        closestDist = d;
        closest = i;
      }
    }

    if (closest != null && closest != game.currentSystemIndex) {
      HapticFeedback.selectionClick();
      setState(() => _selectedIndex = closest);
      return;
    }

    // Limb markers: tapping a far-side point of interest spins to it.
    for (final poi in _farSidePois(game)) {
      final marker = _limbMarkerPos(poi.$2);
      if (marker != null &&
          (marker - details.localPosition).distance < 24) {
        HapticFeedback.selectionClick();
        _flyToSystem(game, poi.$1);
        return;
      }
    }

    setState(() => _selectedIndex = null);
  }

  /// Far-side points of interest: (index, projected point, color, label).
  List<(int, GlobePoint, Color, String)> _farSidePois(GameState game) {
    final pois = <(int, GlobePoint, Color, String)>[];
    void add(int? idx, Color color, String label) {
      if (idx == null) return;
      final sys = game.solarSystems[idx];
      final p = _camera.projectChart(sys.x, sys.y);
      if (!p.front) pois.add((idx, p, color, label));
    }

    add(game.currentSystemIndex, Theme.of(context).colorScheme.primary,
        'YOU');
    add(game.activeQuest?.targetSystemIndex, const Color(0xFFfacc15),
        'CONTRACT');
    add(_wormholeTarget(game), const Color(0xFFa78bfa), 'WORMHOLE');
    add(_selectedIndex, Theme.of(context).colorScheme.secondary, '');
    return pois;
  }

  Offset? _limbMarkerPos(GlobePoint p) {
    final rel = p.screen - _camera.center;
    if (rel.distance < 1) return null;
    final dir = rel / rel.distance;
    return _camera.center + dir * (_camera.radiusPx + 16);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    if (game == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final reachable = ref.watch(reachableSystemsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GALAXY'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/game'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'FUEL ${game.ship.fuel}/${game.ship.maxFuel} · '
                'RANGE ${Travel.maxRange(game.ship).toStringAsFixed(0)} pc',
                style: tt.labelMedium?.copyWith(color: cs.secondary),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _camera.viewport =
                    Size(constraints.maxWidth, constraints.maxHeight);
                if (!_initialised) {
                  _initialised = true;
                  final sys =
                      game.solarSystems[game.currentSystemIndex];
                  final (yaw, pitch) =
                      GlobeCamera.faceAngles(sys.x, sys.y);
                  _camera
                    ..yaw = yaw
                    ..pitch = pitch
                    ..radiusPx = _fitRadius;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _focusRange(game));
                }
                return Listener(
                  onPointerSignal: (signal) {
                    if (signal is PointerScrollEvent) {
                      final factor =
                          signal.scrollDelta.dy > 0 ? 0.88 : 1.14;
                      _camera.radiusPx = (_camera.radiusPx * factor)
                          .clamp(_fitRadius, _maxRadius);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _handleTap(d, game),
                    onScaleStart: (d) {
                      _flyT = 1.0;
                      _spin = Offset.zero;
                      _lastFocal = d.localFocalPoint;
                      _lastScale = 1.0;
                    },
                    onScaleUpdate: (d) {
                      _camera.dragBy(d.localFocalPoint - _lastFocal);
                      if (d.scale != _lastScale && _lastScale > 0) {
                        _camera.radiusPx =
                            (_camera.radiusPx * d.scale / _lastScale)
                                .clamp(_fitRadius, _maxRadius);
                      }
                      _lastFocal = d.localFocalPoint;
                      _lastScale = d.scale;
                    },
                    onScaleEnd: (d) {
                      _spin = d.velocity.pixelsPerSecond;
                    },
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: _camera.viewport,
                          painter: GlobePainter(
                            repaint: _time,
                            time: _time,
                            camera: _camera,
                            systems: game.solarSystems,
                            currentIndex: game.currentSystemIndex,
                            selectedIndex: _selectedIndex,
                            reachableIndices: reachable,
                            rangeParsecs: Travel.maxRange(game.ship),
                            wormholeTargetIndex: _wormholeTarget(game),
                            questTargetIndex:
                                game.activeQuest?.targetSystemIndex,
                            galaxySeed: game.galaxySeed,
                            cs: cs,
                          ),
                          child: SizedBox(
                            width: _camera.viewport.width,
                            height: _camera.viewport.height,
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Column(
                            children: [
                              IconButton.filledTonal(
                                icon: const Icon(Icons.my_location, size: 20),
                                tooltip: 'Focus warp range',
                                onPressed: () => _focusRange(game),
                              ),
                              const SizedBox(height: 8),
                              IconButton.filledTonal(
                                icon:
                                    const Icon(Icons.public, size: 20),
                                tooltip: 'Whole globe',
                                onPressed: _showFullGalaxy,
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          left: 12,
                          top: 12,
                          child: _MapLegend(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selectedIndex != null)
            _SystemInfoCard(
              system: game.solarSystems[_selectedIndex!],
              game: game,
              isReachable: reachable.contains(_selectedIndex),
              selectedIndex: _selectedIndex!,
              onWarp: () {
                final route = ref
                    .read(gameProvider.notifier)
                    .warpTo(_selectedIndex!);
                setState(() => _selectedIndex = null);
                context.go(route);
              },
              onClose: () => setState(() => _selectedIndex = null),
            ),
        ],
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c) => Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: c.withOpacity(0.7), blurRadius: 4)],
          ),
        );
    Widget item(Widget lead, String label) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            lead,
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: Color(0xFF94a3b8),
                    fontWeight: FontWeight.w600)),
          ]),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xAA0a0e1a),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1e2d42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(dot(threatColor(ThreatLevel.safe)), 'SAFE'),
          item(dot(threatColor(ThreatLevel.contested)), 'CONTESTED'),
          item(dot(threatColor(ThreatLevel.hostile)), 'HOSTILE'),
          item(dot(const Color(0xFFa78bfa)), 'WORMHOLE'),
          item(
            const Icon(Icons.diamond_outlined,
                size: 9, color: Color(0xFFfacc15)),
            'CONTRACT',
          ),
        ],
      ),
    );
  }
}

class GlobePainter extends CustomPainter {
  final ValueNotifier<double> time;
  final GlobeCamera camera;
  final List<SolarSystem> systems;
  final int currentIndex;
  final int? selectedIndex;
  final List<int> reachableIndices;
  final double rangeParsecs;
  final int? wormholeTargetIndex;
  final int? questTargetIndex;
  final int galaxySeed;
  final ColorScheme cs;

  final Map<String, TextPainter> _labelCache = {};
  List<Offset>? _dustNear;
  List<Offset>? _dustFar;

  GlobePainter({
    required Listenable repaint,
    required this.time,
    required this.camera,
    required this.systems,
    required this.currentIndex,
    required this.selectedIndex,
    required this.reachableIndices,
    required this.rangeParsecs,
    required this.wormholeTargetIndex,
    required this.questTargetIndex,
    required this.galaxySeed,
    required this.cs,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF04060d), Color(0xFF070c18), Color(0xFF04060d)],
        ).createShader(Offset.zero & size),
    );

    _paintDust(canvas, size, t);
    _paintGlobeBody(canvas);
    _paintGraticule(canvas);
    _paintWormholeLinks(canvas);
    _paintRangeCap(canvas);
    _paintSystems(canvas, size, t);
    _paintLimbMarkers(canvas, t);
    _paintVignette(canvas, size);
  }

  void _paintDust(Canvas canvas, Size size, double t) {
    _dustFar ??= _makeDust(galaxySeed ^ 0xD05, 90, size);
    _dustNear ??= _makeDust(galaxySeed ^ 0xD06, 55, size);

    void layer(List<Offset> pts, double parallax, double maxR, double alpha) {
      final paint = Paint();
      final shift = Offset(camera.yaw * 60, camera.pitch * 90) * parallax;
      for (var i = 0; i < pts.length; i++) {
        final base = pts[i] - shift;
        final wx = (base.dx % (size.width + 40)) - 20;
        final wy = (base.dy % (size.height + 40)) - 20;
        final twinkle =
            0.6 + 0.4 * sin(t * (0.6 + (i % 7) * 0.13) + i * 1.7);
        paint.color = Colors.white.withOpacity(alpha * twinkle);
        canvas.drawCircle(
            Offset(wx, wy), maxR * (0.5 + (i % 3) * 0.25), paint);
      }
    }

    layer(_dustFar!, 0.35, 0.9, 0.20);
    layer(_dustNear!, 0.7, 1.3, 0.28);
  }

  List<Offset> _makeDust(int seed, int count, Size size) {
    final rng = Random(seed);
    return List.generate(
        count,
        (_) => Offset(rng.nextDouble() * (size.width + 40),
            rng.nextDouble() * (size.height + 40)));
  }

  void _paintGlobeBody(Canvas canvas) {
    final c = camera.center;
    final r = camera.radiusPx;
    // Dark glass sphere with an off-center inner glow.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.3),
          radius: 1.1,
          colors: const [
            Color(0xFF11203a),
            Color(0xFF0a1226),
            Color(0xFF050912),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Limb glow.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = cs.primary.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(
      c,
      r + 5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            cs.primary.withOpacity(0.0),
            cs.primary.withOpacity(0.10),
            cs.primary.withOpacity(0.0),
          ],
          stops: const [0.9, 0.965, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r + 5)),
    );
  }

  void _paintGraticule(Canvas canvas) {
    final front = Paint()
      ..color = const Color(0xFF3b5b8c).withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final back = Paint()
      ..color = const Color(0xFF3b5b8c).withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    void polyline(List<(double, double, double)> units) {
      Path? path;
      var pathFront = true;
      GlobePoint? prev;
      for (final (ux, uy, uz) in units) {
        final p = camera.projectUnit(ux, uy, uz);
        if (prev != null && (p.front == prev.front)) {
          if (path == null) {
            path = Path()..moveTo(prev.screen.dx, prev.screen.dy);
            pathFront = p.front;
          }
          path.lineTo(p.screen.dx, p.screen.dy);
        } else if (path != null) {
          canvas.drawPath(path, pathFront ? front : back);
          path = null;
        }
        prev = p;
      }
      if (path != null) canvas.drawPath(path, pathFront ? front : back);
    }

    // Latitude rings.
    for (var latDeg = -60; latDeg <= 60; latDeg += 30) {
      final lat = latDeg * pi / 180;
      polyline([
        for (var i = 0; i <= 72; i++)
          (
            cos(lat) * cos(i / 72 * 2 * pi),
            sin(lat),
            cos(lat) * sin(i / 72 * 2 * pi)
          )
      ]);
    }
    // Meridians.
    for (var lonDeg = 0; lonDeg < 360; lonDeg += 30) {
      final lon = lonDeg * pi / 180;
      polyline([
        for (var i = 0; i <= 48; i++)
          (
            cos((i / 48 - 0.5) * pi) * cos(lon),
            sin((i / 48 - 0.5) * pi),
            cos((i / 48 - 0.5) * pi) * sin(lon)
          )
      ]);
    }
  }

  void _paintWormholeLinks(Canvas canvas) {
    for (int i = 0; i < systems.length; i++) {
      final ev = systems[i].specialEvent;
      if (ev != null && ev >= 1000 && ev - 1000 < systems.length) {
        final j = ev - 1000;
        if (j > i) {
          final a = camera.projectChart(systems[i].x, systems[i].y);
          final b = camera.projectChart(systems[j].x, systems[j].y);
          final throughGlass = !a.front || !b.front;
          final paint = Paint()
            ..color = const Color(0xFF7c3aed)
                .withOpacity(throughGlass ? 0.22 : 0.5)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke;
          _dashedLine(canvas, a.screen, b.screen, paint);
        }
      }
    }
  }

  void _paintRangeCap(Canvas canvas) {
    if (rangeParsecs <= 0) return;
    final alpha = min(pi * 0.98, rangeParsecs / SphereGeo.radius);
    final sys = systems[currentIndex];
    final (nx, ny, nz) = SphereGeo.unitOf(sys.x, sys.y);
    // Tangent basis at the current system.
    var (e1x, e1y, e1z) = (-ny * nx, 1 - ny * ny, -ny * nz);
    final e1len = sqrt(e1x * e1x + e1y * e1y + e1z * e1z);
    if (e1len < 1e-6) {
      (e1x, e1y, e1z) = (1.0, 0.0, 0.0);
    } else {
      e1x /= e1len;
      e1y /= e1len;
      e1z /= e1len;
    }
    final (e2x, e2y, e2z) = (
      ny * e1z - nz * e1y,
      nz * e1x - nx * e1z,
      nx * e1y - ny * e1x,
    );

    final ca = cos(alpha), sa = sin(alpha);
    final paintFront = Paint()
      ..color = cs.primary.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final paintBack = Paint()
      ..color = cs.primary.withOpacity(0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    GlobePoint? prev;
    for (var i = 0; i <= 72; i++) {
      final th = i / 72 * 2 * pi;
      final px = ca * nx + sa * (cos(th) * e1x + sin(th) * e2x);
      final py = ca * ny + sa * (cos(th) * e1y + sin(th) * e2y);
      final pz = ca * nz + sa * (cos(th) * e1z + sin(th) * e2z);
      final p = camera.projectUnit(px, py, pz);
      if (prev != null) {
        canvas.drawLine(prev.screen, p.screen,
            (p.front && prev.front) ? paintFront : paintBack);
      }
      prev = p;
    }
  }

  void _paintSystems(Canvas canvas, Size size, double t) {
    final projected = <(int, GlobePoint)>[];
    for (var i = 0; i < systems.length; i++) {
      projected.add((i, camera.projectChart(systems[i].x, systems[i].y)));
    }
    // Painter's algorithm: deepest first.
    projected.sort((a, b) => a.$2.z.compareTo(b.$2.z));

    for (final (i, p) in projected) {
      final sys = systems[i];
      final pos = p.screen;
      final isCurrent = i == currentIndex;
      final isSelected = i == selectedIndex;
      final isReachable = reachableIndices.contains(i);
      final isWormholeExit = i == wormholeTargetIndex;
      final isQuestTarget = i == questTargetIndex;

      final threat = threatLevel(sys);
      final baseColor = isCurrent ? cs.primary : threatColor(threat);

      if (!p.front) {
        // Ghosts through the glass — enough to sense the far side.
        canvas.drawCircle(
            pos,
            1.6,
            Paint()
              ..color = baseColor.withOpacity(0.13 * p.scale.clamp(0.5, 1)));
        continue;
      }

      final dimmed = !isCurrent && !isReachable && !isWormholeExit;
      final twinkle = 1.0 + 0.1 * sin(t * 1.8 + i * 2.3);
      var r = (1.0 + (sys.size - 1) * 0.35) *
          (camera.radiusPx / 110).clamp(1.7, 5.4) *
          p.scale *
          twinkle;
      if (dimmed) r *= 0.72;

      final alpha = dimmed ? (sys.visited ? 0.45 : 0.30) : 1.0;
      final color = baseColor.withOpacity(alpha);

      final haloR = r * (dimmed ? 2.2 : 3.4);
      canvas.drawCircle(
        pos,
        haloR,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withOpacity(0.5 * alpha),
            color.withOpacity(0.0),
          ]).createShader(Rect.fromCircle(center: pos, radius: haloR)),
      );
      canvas.drawCircle(pos, r, Paint()..color = color);
      canvas.drawCircle(
          pos, r * 0.45, Paint()..color = Colors.white.withOpacity(alpha));

      if (isCurrent) {
        for (var k = 0; k < 2; k++) {
          final phase = ((t * 0.6 + k * 0.5) % 1.0);
          canvas.drawCircle(
              pos,
              r + 4 + phase * 16,
              Paint()
                ..color = cs.primary.withOpacity(0.5 * (1 - phase))
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.3);
        }
      }

      if (isWormholeExit) {
        canvas.drawCircle(
            pos,
            r + 5,
            Paint()
              ..color = const Color(0xFFa78bfa).withOpacity(0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      }

      if (isQuestTarget) {
        final pulse = 1.0 + 0.15 * sin(t * 3.0);
        final d = (r + 7) * pulse;
        final path = Path()
          ..moveTo(pos.dx, pos.dy - d)
          ..lineTo(pos.dx + d, pos.dy)
          ..lineTo(pos.dx, pos.dy + d)
          ..lineTo(pos.dx - d, pos.dy)
          ..close();
        canvas.drawPath(
            path,
            Paint()
              ..color = const Color(0xFFfacc15).withOpacity(0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6);
      }

      if (isSelected) {
        final rr = r + 9;
        final rect = Rect.fromCircle(center: pos, radius: rr);
        final sweep = pi * 0.55;
        final reticle = Paint()
          ..color = cs.secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(rect, t * 1.6, sweep, false, reticle);
        canvas.drawArc(rect, t * 1.6 + pi, sweep, false, reticle);
        final rect2 = Rect.fromCircle(center: pos, radius: rr + 5);
        canvas.drawArc(rect2, -t * 1.1, sweep * 0.6, false,
            reticle..strokeWidth = 1.0);
        canvas.drawArc(rect2, -t * 1.1 + pi, sweep * 0.6, false, reticle);
      }

      final labelBudget = camera.radiusPx;
      final showLabel = isCurrent ||
          isSelected ||
          isQuestTarget ||
          ((isReachable || isWormholeExit) && labelBudget > 210) ||
          (sys.visited && sys.size >= 3 && labelBudget > 520);
      if (showLabel) {
        final labelColor = isCurrent
            ? cs.primary
            : isSelected
                ? cs.secondary
                : isQuestTarget
                    ? const Color(0xFFfacc15)
                    : isWormholeExit
                        ? const Color(0xFFc4b5fd)
                        : color.withOpacity(max(0.65, alpha));
        final fontSize = (isCurrent || isSelected) ? 11.0 : 9.5;
        final tp = _label(sys.name, labelColor, fontSize,
            bold: isCurrent || isSelected || isQuestTarget);
        tp.paint(canvas, pos + Offset(r + 7, -tp.height / 2));
      }
    }
  }

  void _paintLimbMarkers(Canvas canvas, double t) {
    void marker(int? idx, Color color, String label) {
      if (idx == null) return;
      final p = camera.projectChart(systems[idx].x, systems[idx].y);
      if (p.front) return;
      final rel = p.screen - camera.center;
      if (rel.distance < 1) return;
      final dir = rel / rel.distance;
      final pos = camera.center + dir * (camera.radiusPx + 16);
      final pulse = 0.75 + 0.25 * sin(t * 2.5);

      // Chevron pointing outward: "it's around the back, this way".
      final perp = Offset(-dir.dy, dir.dx);
      final tip = pos + dir * 7;
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(pos.dx + perp.dx * 5 - dir.dx * 3,
            pos.dy + perp.dy * 5 - dir.dy * 3)
        ..lineTo(pos.dx - perp.dx * 5 - dir.dx * 3,
            pos.dy - perp.dy * 5 - dir.dy * 3)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withOpacity(pulse));
      if (label.isNotEmpty) {
        final tp = _label(label, color.withOpacity(0.9), 8, bold: true);
        final labelPos = pos + dir * 10;
        tp.paint(canvas,
            labelPos - Offset(tp.width / 2, tp.height / 2) + dir * 8);
      }
    }

    marker(currentIndex, cs.primary, 'YOU');
    marker(questTargetIndex, const Color(0xFFfacc15), 'CONTRACT');
    marker(wormholeTargetIndex, const Color(0xFFa78bfa), '');
    marker(selectedIndex, cs.secondary, '');
  }

  TextPainter _label(String text, Color color, double size,
      {bool bold = false}) {
    final key = '$text|${color.value}|$size|$bold';
    return _labelCache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: size,
            letterSpacing: 0.8,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            shadows: const [
              Shadow(color: Color(0xCC000000), blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    });
  }

  void _paintVignette(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 1.15,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.42),
          ],
          stops: const [0.62, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  void _dashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 5.0;
    const gapLen = 5.0;
    final delta = p2 - p1;
    final dist = delta.distance;
    if (dist == 0) return;
    final dir = delta / dist;
    double traveled = 0;
    bool drawing = true;
    while (traveled < dist) {
      final end = (traveled + (drawing ? dashLen : gapLen)).clamp(0.0, dist);
      if (drawing) {
        canvas.drawLine(p1 + dir * traveled, p1 + dir * end, paint);
      }
      traveled = end;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(GlobePainter old) => true;
}

class _SystemInfoCard extends StatelessWidget {
  final SolarSystem system;
  final GameState game;
  final bool isReachable;
  final int selectedIndex;
  final VoidCallback onWarp;
  final VoidCallback onClose;

  const _SystemInfoCard({
    required this.system,
    required this.game,
    required this.isReachable,
    required this.selectedIndex,
    required this.onWarp,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final dist = Travel.distance(game.currentSystem, system);
    final isWormhole =
        Travel.isWormholePartner(game.currentSystem, selectedIndex);
    final cost = Travel.fuelCostIndexed(
        game.solarSystems, game.currentSystemIndex, selectedIndex, game.ship);
    final affordable = cost <= game.ship.fuel;
    final threat = threatLevel(system);
    final isQuestTarget =
        game.activeQuest?.targetSystemIndex == selectedIndex;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.primary.withOpacity(0.2))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(system.name.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleLarge?.copyWith(
                                color: cs.primary, letterSpacing: 2)),
                      ),
                      const SizedBox(width: 8),
                      _chip(
                        threat.name.toUpperCase(),
                        threatColor(threat),
                      ),
                      if (isQuestTarget) ...[
                        const SizedBox(width: 6),
                        _chip('CONTRACT', const Color(0xFFfacc15)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isWormhole
                        ? '${dist.toStringAsFixed(1)} pc · WORMHOLE — FREE TRANSIT'
                        : '${dist.toStringAsFixed(1)} pc · $cost FUEL',
                    style: tt.bodySmall?.copyWith(
                      color: isWormhole
                          ? const Color(0xFFa78bfa)
                          : affordable
                              ? cs.secondary
                              : cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${system.government.displayName} · Tech ${system.techLevel} · ${system.status.displayName}',
                    style: tt.bodySmall,
                  ),
                  if (system.specialResource !=
                      SpecialResource.nothingSpecial) ...[
                    const SizedBox(height: 2),
                    Text(system.specialResource.displayName,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.secondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (isReachable)
              ElevatedButton.icon(
                onPressed: onWarp,
                icon: const Icon(Icons.rocket_launch, size: 16),
                label: const Text('WARP'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              )
            else
              Text('OUT OF RANGE',
                  style: tt.labelSmall?.copyWith(
                    color: cs.error.withOpacity(0.7),
                  )),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              style: IconButton.styleFrom(
                foregroundColor: cs.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      ),
    );
  }
}
