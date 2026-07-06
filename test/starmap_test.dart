import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darknova2/engine/game_engine.dart';
import 'package:darknova2/models/enums.dart';
import 'package:darknova2/providers/game_provider.dart';
import 'package:darknova2/screens/galaxy_map_screen.dart';
import 'package:darknova2/ui/starmap_camera.dart';

void main() {
  StarMapCamera makeCamera() =>
      StarMapCamera(targetX: 75, targetZ: 55, zoom: 6)
        ..viewport = const Size(400, 700);

  group('StarMapCamera', () {
    test('project/unproject round-trips across the chart', () {
      final cam = makeCamera();
      for (final (x, z) in [(75.0, 55.0), (10.0, 10.0), (140.0, 100.0), (75.0, 5.0)]) {
        final screen = cam.project(x, z);
        final (bx, bz) = cam.unproject(screen);
        expect(bx, closeTo(x, 0.05));
        expect(bz, closeTo(z, 0.05));
      }
    });

    test('nearer rows (larger z) render larger than farther rows', () {
      final cam = makeCamera();
      expect(cam.perspectiveAt(90), greaterThan(cam.perspectiveAt(20)));
    });

    test('screen distance grows monotonically with plane distance', () {
      final cam = makeCamera();
      final origin = cam.project(75, 55);
      final near = (cam.project(80, 55) - origin).distance;
      final far = (cam.project(90, 55) - origin).distance;
      expect(far, greaterThan(near));
    });

    test('zoomAt keeps the anchored plane point under the pointer', () {
      final cam = makeCamera();
      const anchor = Offset(120, 300);
      final (bx, bz) = cam.unproject(anchor);
      cam.zoomAt(anchor, 1.8, 1.0, 20.0);
      final after = cam.project(bx, bz);
      expect((after - anchor).distance, lessThan(1.5));
    });

    test('panScreen moves the view opposite the drag', () {
      final cam = makeCamera();
      final before = cam.project(75, 55);
      cam.panScreen(const Offset(50, 0)); // drag right → world moves right
      final after = cam.project(75, 55);
      expect(after.dx - before.dx, closeTo(50, 1.5));
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
      // Let the intro fly-to and twinkle animations run some real frames.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 90));
      }
      expect(find.byType(CustomPaint), findsWidgets);

      // Tap around the canvas — selection either hits a star or clears.
      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(120, 420));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });
  });
}
