import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darknova2/engine/galaxy_generator.dart';
import 'package:darknova2/engine/game_engine.dart';
import 'package:darknova2/engine/sphere.dart';
import 'package:darknova2/models/enums.dart';
import 'package:darknova2/providers/game_provider.dart';
import 'package:darknova2/screens/galaxy_map_screen.dart';
import 'package:darknova2/ui/globe_camera.dart';

void main() {
  group('SphereGeo', () {
    test('distance is symmetric, zero at self, capped at half circumference',
        () {
      final game = GameEngine.newGame('T', DifficultyLevel.normal);
      final a = game.solarSystems[0];
      final b = game.solarSystems[50];
      // acos(dot ≈ 1.0) carries sub-microparsec float noise.
      expect(SphereGeo.distance(a, a), closeTo(0, 1e-4));
      expect(SphereGeo.distance(a, b), SphereGeo.distance(b, a));
      for (final s in game.solarSystems) {
        final d = SphereGeo.distance(a, s);
        expect(d, lessThanOrEqualTo(SphereGeo.maxDistance + 1e-9));
        expect(d, greaterThanOrEqualTo(0));
      }
    });

    test('antipodal points are half a circumference apart', () {
      // (x=0, y=55) is (lon 0, lat 0); (x=75, y=55) is (lon π, lat 0).
      final angle = SphereGeo.angleBetween(0, 55, 75, 55);
      expect(angle, closeTo(pi, 1e-6));
    });

    test('chartOf inverts lonOf/latOf', () {
      const x = 42.0, y = 77.0;
      final (cx, cy) = SphereGeo.chartOf(SphereGeo.lonOf(x), SphereGeo.latOf(y));
      expect(cx, closeTo(x, 1e-6));
      expect(cy, closeTo(y, 1e-6));
    });
  });

  group('Spherical galaxy generation', () {
    test('120 systems, Sol at 92, coordinates in chart bounds', () {
      final systems = GalaxyGenerator.generate(1234, DifficultyLevel.normal);
      expect(systems.length, 120);
      expect(systems[GalaxyGenerator.solIndex].name, 'Sol');
      for (final s in systems) {
        expect(s.x, inInclusiveRange(0, 149));
        expect(s.y, inInclusiveRange(1, 109));
      }
    });

    test('systems keep reasonable angular spacing (no pile-ups)', () {
      final systems = GalaxyGenerator.generate(777, DifficultyLevel.normal);
      // Fibonacci lattice spacing for 120 points is ~0.32 rad; with
      // jitter and grid rounding, nothing should sit closer than ~0.05.
      var minAngle = double.infinity;
      for (var i = 0; i < systems.length; i++) {
        for (var j = i + 1; j < systems.length; j++) {
          final a = SphereGeo.angleBetween(
              systems[i].x, systems[i].y, systems[j].x, systems[j].y);
          minAngle = min(minAngle, a);
        }
      }
      expect(minAngle, greaterThan(0.05));
    });

    test('every system can reach a neighbor on a full tank', () {
      final game = GameEngine.newGame('T', DifficultyLevel.normal);
      const fullTankRange = 28.0; // 14 fuel × 2 pc
      for (final s in game.solarSystems) {
        final nearest = game.solarSystems
            .where((o) => o != s)
            .map((o) => SphereGeo.distance(s, o))
            .reduce(min);
        expect(nearest, lessThan(fullTankRange),
            reason: '${s.name} would be stranded');
      }
    });
  });

  group('GlobeCamera', () {
    GlobeCamera makeCamera() =>
        GlobeCamera(yaw: 0.4, pitch: -0.2, radiusPx: 280)
          ..viewport = const Size(400, 700);

    test('faceAngles centers the point on the front of the globe', () {
      final cam = makeCamera();
      for (final (x, y) in [(10.0, 20.0), (75.0, 55.0), (140.0, 100.0)]) {
        final (yaw, pitch) = GlobeCamera.faceAngles(x, y);
        cam
          ..yaw = yaw
          ..pitch = pitch;
        final p = cam.projectChart(x, y);
        expect(p.front, isTrue);
        expect((p.screen - cam.center).distance, lessThan(1.0));
        expect(p.z, closeTo(1.0, 1e-6));
      }
    });

    test('rotation preserves front/back split roughly in half', () {
      final cam = makeCamera();
      final game = GameEngine.newGame('T', DifficultyLevel.normal);
      final front = game.solarSystems
          .where((s) => cam.projectChart(s.x, s.y).front)
          .length;
      expect(front, greaterThan(30));
      expect(front, lessThan(90));
    });

    test('dragBy spins the globe and clamps pitch', () {
      final cam = makeCamera();
      final yawBefore = cam.yaw;
      cam.dragBy(const Offset(140, 0));
      expect(cam.yaw, isNot(closeTo(yawBefore, 1e-6)));
      cam.dragBy(const Offset(0, 100000));
      expect(cam.pitch.abs(), lessThanOrEqualTo(GlobeCamera.maxPitch));
    });

    test('lerpYaw takes the short way around the wrap', () {
      final mid = GlobeCamera.lerpYaw(3.0, -3.0, 0.5);
      // Short path from 3.0 to −3.0 crosses ±π, not zero.
      expect(mid.abs(), greaterThan(3.0));
    });
  });

  group('Threat levels', () {
    test('every system maps to a tier and anarchy reads hostile', () {
      final game = GameEngine.newGame('T', DifficultyLevel.normal);
      for (final sys in game.solarSystems) {
        expect(threatLevel(sys), isA<ThreatLevel>());
        if (sys.government == GovernmentType.anarchy) {
          expect(threatLevel(sys), ThreatLevel.hostile);
        }
      }
    });
  });

  group('Map widget', () {
    testWidgets('renders, animates, and survives taps', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(gameProvider.notifier)
          .newGame('Tester', DifficultyLevel.normal);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: GalaxyMapScreen()),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 90));
      }
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(120, 420));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });
}
