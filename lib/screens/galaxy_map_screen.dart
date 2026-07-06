import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../engine/travel.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/solar_system.dart';
import '../providers/game_provider.dart';
import '../ui/starmap_camera.dart';

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

  final StarMapCamera _camera =
      StarMapCamera(targetX: 75, targetZ: 55, zoom: 4);
  static const double _maxZoom = 16.0;

  // Fly-to animation.
  StarMapCamera? _flyFrom;
  StarMapCamera? _flyTo;
  double _flyT = 1.0;

  // Gesture state.
  Offset _lastFocal = Offset.zero;
  double _lastScale = 1.0;
  Offset _inertia = Offset.zero;

  bool _initialised = false;

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

    // Fly-to animation.
    if (_flyT < 1.0 && _flyFrom != null && _flyTo != null) {
      _flyT = min(1.0, _flyT + dt / 0.7);
      final eased = Curves.easeInOutCubic.transform(_flyT);
      final pose = lerpCamera(_flyFrom!, _flyTo!, eased);
      _camera
        ..targetX = pose.targetX
        ..targetZ = pose.targetZ
        ..zoom = pose.zoom;
    }

    // Pan inertia: flick and glide.
    if (_inertia.distance > 12) {
      _camera.panScreen(_inertia * dt);
      _inertia *= exp(-3.5 * dt);
    }

    // Drives twinkle, pulses, reticle spin, and any camera motion.
    _time.value = elapsed.inMicroseconds / 1e6;
  }

  void _flyToPose(double tx, double tz, double zoom) {
    _flyFrom = _camera.copy();
    _flyTo = StarMapCamera(targetX: tx, targetZ: tz, zoom: zoom)
      ..viewport = _camera.viewport;
    _flyT = 0.0;
    _inertia = Offset.zero;
  }

  void _focusRange(GameState game) {
    final sys = game.solarSystems[game.currentSystemIndex];
    final rangePc = max(6.0, Travel.maxRange(game.ship));
    final shortest =
        min(_camera.viewport.width, _camera.viewport.height);
    final zoom = (shortest / (rangePc * 2.6))
        .clamp(_camera.fitZoom(), _maxZoom)
        .toDouble();
    _flyToPose(sys.x.toDouble(), sys.y.toDouble(), zoom);
  }

  void _showFullGalaxy() => _flyToPose(75, 55, _camera.fitZoom());

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
      final p = _camera.project(sys.x.toDouble(), sys.y.toDouble());
      final d = (p - details.localPosition).distance;
      if (d < closestDist && d < hitRadiusPx) {
        closestDist = d;
        closest = i;
      }
    }

    if (closest != null && closest != game.currentSystemIndex) {
      HapticFeedback.selectionClick();
      setState(() => _selectedIndex = closest);
    } else {
      setState(() => _selectedIndex = null);
    }
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
        title: const Text('GALAXY MAP'),
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
                  // Open on the whole galaxy, then glide into warp range.
                  _camera
                    ..targetX = 75
                    ..targetZ = 55
                    ..zoom = _camera.fitZoom();
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _focusRange(game));
                }
                return Listener(
                  onPointerSignal: (signal) {
                    if (signal is PointerScrollEvent) {
                      final factor =
                          signal.scrollDelta.dy > 0 ? 0.88 : 1.14;
                      _camera.zoomAt(signal.localPosition, factor,
                          _camera.fitZoom(), _maxZoom);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => _handleTap(d, game),
                    onScaleStart: (d) {
                      _flyT = 1.0; // interrupt any fly-to
                      _inertia = Offset.zero;
                      _lastFocal = d.localFocalPoint;
                      _lastScale = 1.0;
                    },
                    onScaleUpdate: (d) {
                      _camera.panScreen(d.localFocalPoint - _lastFocal);
                      if (d.scale != _lastScale && _lastScale > 0) {
                        _camera.zoomAt(d.localFocalPoint,
                            d.scale / _lastScale, _camera.fitZoom(), _maxZoom);
                      }
                      _lastFocal = d.localFocalPoint;
                      _lastScale = d.scale;
                    },
                    onScaleEnd: (d) {
                      _inertia = d.velocity.pixelsPerSecond;
                    },
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: _camera.viewport,
                          painter: StarMapPainter(
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
                                    const Icon(Icons.zoom_out_map, size: 20),
                                tooltip: 'Full galaxy',
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

class StarMapPainter extends CustomPainter {
  final ValueNotifier<double> time;
  final StarMapCamera camera;
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

  StarMapPainter({
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

    // --- deep space backdrop ---
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
    _paintNebulae(canvas);
    _paintGrid(canvas, size);
    _paintRange(canvas);
    _paintWormholeLinks(canvas);
    _paintSystems(canvas, size, t);
    _paintVignette(canvas, size);
  }

  // Parallax star dust: two layers moving at different fractions of the
  // camera, which is what sells the depth.
  void _paintDust(Canvas canvas, Size size, double t) {
    _dustFar ??= _makeDust(galaxySeed ^ 0xD05, 90);
    _dustNear ??= _makeDust(galaxySeed ^ 0xD06, 55);

    void layer(List<Offset> pts, double parallax, double maxR, double alpha) {
      final paint = Paint();
      for (var i = 0; i < pts.length; i++) {
        final pt = pts[i];
        final sx = size.width / 2 +
            (pt.dx - camera.targetX) * camera.zoom * parallax;
        final sy = size.height / 2 +
            (pt.dy - camera.targetZ) * camera.zoom * parallax * 0.64;
        // Wrap into view so dust is endless.
        final wx = (sx % (size.width + 40)) - 20;
        final wy = (sy % (size.height + 40)) - 20;
        final twinkle =
            0.6 + 0.4 * sin(t * (0.6 + (i % 7) * 0.13) + i * 1.7);
        paint.color = Colors.white.withOpacity(alpha * twinkle);
        canvas.drawCircle(Offset(wx, wy), maxR * (0.5 + (i % 3) * 0.25), paint);
      }
    }

    layer(_dustFar!, 0.22, 0.9, 0.20);
    layer(_dustNear!, 0.45, 1.3, 0.30);
  }

  List<Offset> _makeDust(int seed, int count) {
    final rng = Random(seed);
    return List.generate(
        count,
        (_) => Offset(
            rng.nextDouble() * 400 - 125, rng.nextDouble() * 300 - 95));
  }

  void _paintNebulae(Canvas canvas) {
    const blobs = [
      (30.0, 30.0, 42.0, Color(0xFF12244d)),
      (105.0, 68.0, 55.0, Color(0xFF0d2038)),
      (70.0, 18.0, 34.0, Color(0xFF1b1440)),
      (128.0, 92.0, 38.0, Color(0xFF0e2a33)),
      (18.0, 88.0, 36.0, Color(0xFF241036)),
    ];
    for (final (wx, wz, r, color) in blobs) {
      final center = camera.project(wx, wz);
      final p = camera.perspectiveAt(wz);
      final radius = r * camera.zoom * p;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withOpacity(0.32),
            color.withOpacity(0.0),
          ]).createShader(
              Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF35507a).withOpacity(0.14)
      ..strokeWidth = 1.0;
    const step = 15.0;
    // Verticals.
    for (double x = 0; x <= 150; x += step) {
      final path = Path()..moveTo0(camera.project(x, 0));
      for (double z = 5; z <= 110; z += 5) {
        path.lineTo0(camera.project(x, z));
      }
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }
    // Horizontals.
    for (double z = 0; z <= 110; z += step) {
      final a = camera.project(0, z);
      final b = camera.project(150, z);
      canvas.drawLine(a, b, paint);
    }
  }

  void _paintRange(Canvas canvas) {
    if (rangeParsecs <= 0) return;
    final sys = systems[currentIndex];
    final path = Path();
    for (var i = 0; i <= 64; i++) {
      final a = i / 64 * 2 * pi;
      final p = camera.project(
          sys.x + cos(a) * rangeParsecs, sys.y + sin(a) * rangeParsecs);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = cs.primary.withOpacity(0.05)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = cs.primary.withOpacity(0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
  }

  void _paintWormholeLinks(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF7c3aed).withOpacity(0.45)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < systems.length; i++) {
      final ev = systems[i].specialEvent;
      if (ev != null && ev >= 1000 && ev - 1000 < systems.length) {
        final j = ev - 1000;
        if (j > i) {
          _dashedLine(
              canvas,
              camera.project(
                  systems[i].x.toDouble(), systems[i].y.toDouble()),
              camera.project(
                  systems[j].x.toDouble(), systems[j].y.toDouble()),
              paint);
        }
      }
    }
  }

  void _paintSystems(Canvas canvas, Size size, double t) {
    // Draw far-to-near so nearer stars overlap distant ones.
    final order = List<int>.generate(systems.length, (i) => i)
      ..sort((a, b) => systems[a].y.compareTo(systems[b].y));

    for (final i in order) {
      final sys = systems[i];
      final pos = camera.project(sys.x.toDouble(), sys.y.toDouble());
      if (pos.dx < -60 ||
          pos.dx > size.width + 60 ||
          pos.dy < -60 ||
          pos.dy > size.height + 60) {
        continue;
      }
      final persp = camera.perspectiveAt(sys.y.toDouble());
      final isCurrent = i == currentIndex;
      final isSelected = i == selectedIndex;
      final isReachable = reachableIndices.contains(i);
      final isWormholeExit = i == wormholeTargetIndex;
      final isQuestTarget = i == questTargetIndex;

      final threat = threatLevel(sys);
      final baseColor = isCurrent ? cs.primary : threatColor(threat);
      final dimmed = !isCurrent && !isReachable && !isWormholeExit;

      final sizeScale = camera.zoom * persp;
      final twinkle = 1.0 + 0.1 * sin(t * 1.8 + i * 2.3);
      var r = (1.0 + (sys.size - 1) * 0.35) *
          (sizeScale * 0.42).clamp(1.6, 5.2) *
          twinkle;
      if (dimmed) r *= 0.75;

      final alpha = dimmed ? (sys.visited ? 0.45 : 0.28) : 1.0;
      final color = baseColor.withOpacity(alpha);

      // Halo glow.
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
      // Core.
      canvas.drawCircle(pos, r, Paint()..color = color);
      canvas.drawCircle(
          pos, r * 0.45, Paint()..color = Colors.white.withOpacity(alpha));

      // Current system: expanding pulse rings.
      if (isCurrent) {
        for (var k = 0; k < 2; k++) {
          final phase = ((t * 0.6 + k * 0.5) % 1.0);
          final pr = r + 4 + phase * 16;
          canvas.drawCircle(
              pos,
              pr,
              Paint()
                ..color = cs.primary.withOpacity(0.5 * (1 - phase))
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.3);
        }
      }

      // Wormhole exit: steady violet ring.
      if (isWormholeExit) {
        canvas.drawCircle(
            pos,
            r + 5,
            Paint()
              ..color = const Color(0xFFa78bfa).withOpacity(0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      }

      // Quest target: pulsing gold diamond beacon.
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

      // Selection reticle: two counter-rotating arcs.
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

      // Labels: current/selected/quest always; in-range and wormhole when
      // there's room; visited majors only when zoomed in.
      final showLabel = isCurrent ||
          isSelected ||
          isQuestTarget ||
          ((isReachable || isWormholeExit) && sizeScale > 3.0) ||
          (sys.visited && sys.size >= 3 && sizeScale > 7.0);
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
  bool shouldRepaint(StarMapPainter old) => true;
}

extension on Path {
  void moveTo0(Offset p) => moveTo(p.dx, p.dy);
  void lineTo0(Offset p) => lineTo(p.dx, p.dy);
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
