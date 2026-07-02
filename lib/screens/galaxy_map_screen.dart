import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/solar_system.dart';
import '../providers/game_provider.dart';

class GalaxyMapScreen extends ConsumerStatefulWidget {
  const GalaxyMapScreen({super.key});

  @override
  ConsumerState<GalaxyMapScreen> createState() => _GalaxyMapScreenState();
}

class _GalaxyMapScreenState extends ConsumerState<GalaxyMapScreen> {
  int? _selectedIndex;
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
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
                'FUEL: ${game.ship.fuel}/${game.ship.maxFuel}',
                style: tt.labelMedium?.copyWith(color: cs.secondary),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.5,
              maxScale: 4.0,
              child: GestureDetector(
                onTapUp: (details) =>
                    _handleTap(details, game, reachable, context),
                child: CustomPaint(
                  size: const Size(double.infinity, double.infinity),
                  painter: GalaxyPainter(
                    systems: game.solarSystems,
                    currentIndex: game.currentSystemIndex,
                    selectedIndex: _selectedIndex,
                    reachableIndices: reachable,
                    cs: cs,
                  ),
                  child: const SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          ),
          if (_selectedIndex != null)
            _SystemInfoCard(
              system: game.solarSystems[_selectedIndex!],
              game: game,
              isReachable: reachable.contains(_selectedIndex),
              selectedIndex: _selectedIndex!,
              onWarp: () {
                final encounter = ref
                    .read(gameProvider.notifier)
                    .warpTo(_selectedIndex!);
                setState(() => _selectedIndex = null);
                context.go(encounter ? '/encounter' : '/game');
              },
              onClose: () => setState(() => _selectedIndex = null),
            ),
        ],
      ),
    );
  }

  void _handleTap(
    TapUpDetails details,
    GameState game,
    List<int> reachable,
    BuildContext context,
  ) {
    final size = context.size ?? Size.zero;
    const mapW = 150.0;
    const mapH = 110.0;
    final scaleX = size.width / mapW;
    final scaleY = size.height / mapH;

    // Account for InteractiveViewer transform.
    final transform = _transformController.value;
    final local = MatrixUtils.transformPoint(
      Matrix4.inverted(transform),
      details.localPosition,
    );

    final systemX = local.dx / scaleX;
    final systemY = local.dy / scaleY;

    int? closest;
    double closestDist = double.infinity;
    for (int i = 0; i < game.solarSystems.length; i++) {
      final sys = game.solarSystems[i];
      final dx = (sys.x.toDouble() - systemX);
      final dy = (sys.y.toDouble() - systemY);
      final d = sqrt(dx * dx + dy * dy);
      if (d < closestDist && d < 4.0) {
        closestDist = d;
        closest = i;
      }
    }

    if (closest != null && closest != game.currentSystemIndex) {
      setState(() => _selectedIndex = closest);
    } else {
      setState(() => _selectedIndex = null);
    }
  }
}

class GalaxyPainter extends CustomPainter {
  final List<SolarSystem> systems;
  final int currentIndex;
  final int? selectedIndex;
  final List<int> reachableIndices;
  final ColorScheme cs;

  const GalaxyPainter({
    required this.systems,
    required this.currentIndex,
    required this.selectedIndex,
    required this.reachableIndices,
    required this.cs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const mapW = 150.0;
    const mapH = 110.0;
    final scaleX = size.width / mapW;
    final scaleY = size.height / mapH;

    // Background.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF050810),
    );

    // Draw nebula-like background noise.
    _drawNebulae(canvas, size);

    // Draw wormhole connections.
    for (int i = 0; i < systems.length; i++) {
      final sys = systems[i];
      if (sys.specialEvent != null &&
          sys.specialEvent! >= 1000 &&
          sys.specialEvent! - 1000 < systems.length) {
        final targetIdx = sys.specialEvent! - 1000;
        if (targetIdx > i) {
          // Draw only once per pair.
          final target = systems[targetIdx];
          final p1 = Offset(sys.x * scaleX, sys.y * scaleY);
          final p2 = Offset(target.x * scaleX, target.y * scaleY);
          final paint = Paint()
            ..color = const Color(0xFF7c3aed).withOpacity(0.4)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;
          _drawDottedLine(canvas, p1, p2, paint);
        }
      }
    }

    // Draw reachable range circle around current system.
    final currentSys = systems[currentIndex];
    final currentPos = Offset(
        currentSys.x * scaleX, currentSys.y * scaleY);

    // Draw range overlay (approx circle showing fuel reach).
    // Use the farthest reachable system as radius hint.
    if (reachableIndices.isNotEmpty) {
      double maxDist = 0;
      for (final idx in reachableIndices) {
        final sys = systems[idx];
        final dx = (sys.x - currentSys.x) * scaleX;
        final dy = (sys.y - currentSys.y) * scaleY;
        final d = sqrt(dx * dx + dy * dy);
        if (d > maxDist) maxDist = d;
      }
      canvas.drawCircle(
        currentPos,
        maxDist,
        Paint()
          ..color = cs.primary.withOpacity(0.05)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        currentPos,
        maxDist,
        Paint()
          ..color = cs.primary.withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // Draw systems.
    for (int i = 0; i < systems.length; i++) {
      final sys = systems[i];
      final pos = Offset(sys.x * scaleX, sys.y * scaleY);
      final isCurrentSystem = i == currentIndex;
      final isSelected = i == selectedIndex;
      final isReachable = reachableIndices.contains(i);
      final isVisited = sys.visited;

      final baseColor = _systemColor(sys.government, cs);
      final radius = 1.5 + (sys.size - 1) * 0.4;

      if (isCurrentSystem) {
        // Current system: bright with pulse rings.
        canvas.drawCircle(pos, radius + 5,
            Paint()..color = cs.primary.withOpacity(0.08));
        canvas.drawCircle(pos, radius + 3,
            Paint()..color = cs.primary.withOpacity(0.15));
        canvas.drawCircle(pos, radius,
            Paint()..color = cs.primary);
        // Crosshair.
        final crossPaint = Paint()
          ..color = cs.primary.withOpacity(0.5)
          ..strokeWidth = 0.5;
        canvas.drawLine(
            pos + const Offset(-8, 0), pos + const Offset(-3, 0), crossPaint);
        canvas.drawLine(
            pos + const Offset(8, 0), pos + const Offset(3, 0), crossPaint);
        canvas.drawLine(
            pos + const Offset(0, -8), pos + const Offset(0, -3), crossPaint);
        canvas.drawLine(
            pos + const Offset(0, 8), pos + const Offset(0, 3), crossPaint);
      } else if (isSelected) {
        canvas.drawCircle(
            pos, radius + 4,
            Paint()
              ..color = cs.secondary.withOpacity(0.2)
              ..style = PaintingStyle.fill);
        canvas.drawCircle(
            pos, radius + 4,
            Paint()
              ..color = cs.secondary.withOpacity(0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0);
        canvas.drawCircle(pos, radius, Paint()..color = cs.secondary);
      } else if (isReachable) {
        canvas.drawCircle(
            pos, radius + 2,
            Paint()
              ..color = const Color(0xFF4fc3f7).withOpacity(0.15)
              ..style = PaintingStyle.fill);
        canvas.drawCircle(pos, radius,
            Paint()..color = const Color(0xFF4fc3f7).withOpacity(0.8));
      } else if (isVisited) {
        canvas.drawCircle(pos, radius,
            Paint()..color = baseColor.withOpacity(0.8));
      } else {
        // Unvisited, out of range: dim.
        canvas.drawCircle(pos, radius,
            Paint()..color = baseColor.withOpacity(0.3));
      }

      // System name for visited or selected/current/reachable.
      if (isCurrentSystem || isSelected || (isVisited && sys.size >= 3)) {
        final tp = TextPainter(
          text: TextSpan(
            text: sys.name,
            style: TextStyle(
              color: isCurrentSystem
                  ? cs.primary
                  : isSelected
                      ? cs.secondary
                      : cs.onSurface.withOpacity(0.5),
              fontSize: 7,
              fontWeight: (isCurrentSystem || isSelected)
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas,
            pos +
                Offset(radius + 2,
                    -tp.height / 2));
      }
    }
  }

  void _drawNebulae(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const nebulaPoints = [
      (0.2, 0.3, 80.0, 0xFF0f172a),
      (0.7, 0.6, 100.0, 0xFF0c1a2e),
      (0.5, 0.2, 60.0, 0xFF0a1628),
      (0.85, 0.85, 70.0, 0xFF0d1b30),
    ];
    for (final (rx, ry, r, color) in nebulaPoints) {
      paint.color = Color(color);
      final rect = Rect.fromCenter(
        center: Offset(rx * size.width, ry * size.height),
        width: r * 2,
        height: r,
      );
      canvas.drawOval(rect, paint);
    }
  }

  void _drawDottedLine(
      Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 4.0;
    const gapLen = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final nx = dx / dist;
    final ny = dy / dist;
    double traveled = 0;
    bool drawing = true;
    while (traveled < dist) {
      final segLen = drawing ? dashLen : gapLen;
      final end = (traveled + segLen).clamp(0.0, dist);
      if (drawing) {
        canvas.drawLine(
          p1 + Offset(nx * traveled, ny * traveled),
          p1 + Offset(nx * end, ny * end),
          paint,
        );
      }
      traveled = end;
      drawing = !drawing;
    }
  }

  Color _systemColor(GovernmentType gov, ColorScheme cs) {
    switch (gov) {
      case GovernmentType.anarchy:
      case GovernmentType.feudalState:
        return const Color(0xFFef4444);
      case GovernmentType.democracy:
      case GovernmentType.confederacy:
        return const Color(0xFF4fc3f7);
      case GovernmentType.technocracy:
      case GovernmentType.cyberneticState:
        return const Color(0xFF34d399);
      case GovernmentType.militaryState:
      case GovernmentType.fascistState:
        return const Color(0xFFf87171);
      case GovernmentType.communistState:
      case GovernmentType.socialistState:
        return const Color(0xFFfb923c);
      case GovernmentType.capitalistState:
      case GovernmentType.corporateState:
        return const Color(0xFFf59e0b);
      case GovernmentType.monarchy:
      case GovernmentType.dictatorship:
        return const Color(0xFFa78bfa);
      case GovernmentType.pacifistState:
      case GovernmentType.stateOfSatori:
        return const Color(0xFF86efac);
      case GovernmentType.theocracy:
        return const Color(0xFFfde68a);
    }
  }

  @override
  bool shouldRepaint(GalaxyPainter old) =>
      old.currentIndex != currentIndex ||
      old.selectedIndex != selectedIndex ||
      old.reachableIndices != reachableIndices;
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
                  Text(system.name.toUpperCase(),
                      style: tt.titleLarge?.copyWith(
                          color: cs.primary, letterSpacing: 2)),
                  const SizedBox(height: 4),
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
}
