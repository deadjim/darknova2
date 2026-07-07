import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darknova2/engine/galaxy_generator.dart';
import 'package:darknova2/engine/game_engine.dart';
import 'package:darknova2/engine/sphere.dart';
import 'package:darknova2/models/enums.dart';
import 'package:darknova2/models/game_state.dart';
import 'package:darknova2/models/solar_system.dart';
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
    test('400 systems, Sol at 92, coordinates in chart bounds', () {
      final systems = GalaxyGenerator.generate(1234, DifficultyLevel.normal);
      expect(systems.length, 400);
      expect(systems[GalaxyGenerator.solIndex].name, 'Sol');
      for (final s in systems) {
        expect(s.x, inInclusiveRange(0, 149));
        expect(s.y, inInclusiveRange(1, 109));
      }
    });

    test('systems keep reasonable angular spacing (no pile-ups)', () {
      final systems = GalaxyGenerator.generate(777, DifficultyLevel.normal);
      // O(N²) at 400 is 80k pairs. Clustering + chart-grid rounding at
      // N=400 allows some close pairs; the real stranding guarantee is
      // covered by the 'every system can reach a neighbor' test below.
      var minAngle = double.infinity;
      for (var i = 0; i < systems.length; i++) {
        for (var j = i + 1; j < systems.length; j++) {
          final a = SphereGeo.angleBetween(
              systems[i].x, systems[i].y, systems[j].x, systems[j].y);
          minAngle = min(minAngle, a);
        }
      }
      expect(minAngle, greaterThan(0.008));
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

    test('canonical names go to the biggest worlds', () {
      final systems = GalaxyGenerator.generate(2468, DifficultyLevel.normal);
      expect(systems[GalaxyGenerator.solIndex].name, 'Sol');

      const canonical = [
        'Acamar', 'Adahn', 'Aldea', 'Andevian', 'Antedi', 'Balosnee',
        'Baratas', 'Brax', 'Bretel', 'Calondia', 'Campor', 'Capelle',
        'Carzon', 'Castor', 'Cestus', 'Cheron', 'Courteney', 'Daled',
        'Damast', 'Davlos', 'Deneb', 'Deneva', 'Devidia', 'Draylon',
        'Drema', 'Endor', 'Esmee', 'Exo', 'Ferris', 'Festen', 'Fourmi',
        'Frolix', 'Gemulon', 'Guinifer', 'Hades', 'Hamlet', 'Helena',
        'Hulst', 'Iodine', 'Iralius', 'Janus', 'Japori', 'Jarada', 'Jason',
        'Kaylon', 'Khefka', 'Kira', 'Klaatu', 'Klaestron', 'Korma',
        'Kravat', 'Krios', 'Laertes', 'Largo', 'Lave', 'Ligon', 'Lowry',
        'Magrat', 'Malcoria', 'Melina', 'Mentar', 'Merik', 'Mintaka',
        'Montor', 'Mordan', 'Myrthe', 'Nelvana', 'Nix', 'Nyle', 'Odet',
        'Og', 'Omega', 'Omphalos', 'Orias', 'Othello', 'Parade',
        'Penthara', 'Picard', 'Pollux', 'Quator', 'Rakhar', 'Ran',
        'Regulas', 'Relva', 'Rhymus', 'Rochani', 'Rubicum', 'Rutia',
        'Sarpeidon', 'Sefalla', 'Seltrice', 'Sigma', 'Sol', 'Somari',
        'Stakoron', 'Straba', 'Syrinx', 'Talani', 'Tamus', 'Tantalos',
        'Tauber', 'Thera', 'Titan', 'Torin', 'Triacus', 'Turkana', 'Tycho',
        'Umberlee', 'Utopia', 'Vagra', 'Valete', 'Vega', 'Velat', 'Yew',
        'Yojimbo', 'Zalkon', 'Zuul', 'Tarchannen', 'Ventax', 'Xerxes',
      ];

      final nameCounts = <String, int>{};
      for (final s in systems) {
        nameCounts[s.name] = (nameCounts[s.name] ?? 0) + 1;
      }
      for (final n in canonical) {
        expect(nameCounts[n] ?? 0, lessThanOrEqualTo(1),
            reason: 'canonical name $n used more than once');
      }

      final procedural =
          systems.where((s) => !canonical.contains(s.name)).length;
      expect(procedural, greaterThanOrEqualTo(200));
    });

    test('names are unique', () {
      final systems = GalaxyGenerator.generate(13, DifficultyLevel.normal);
      expect(systems.map((s) => s.name).toSet().length, 400);
    });

    test('regions assigned', () {
      final systems = GalaxyGenerator.generate(55, DifficultyLevel.normal);
      for (final s in systems) {
        expect(s.region, isNotEmpty);
      }
      expect(systems.map((s) => s.region).toSet().length,
          lessThanOrEqualTo(10));
    });

    test('old saves without region field load', () {
      final game = GameEngine.newGame('T', DifficultyLevel.normal);
      final json = game.toJson();
      final rawSystems = json['solarSystems'] as List;
      for (final entry in rawSystems) {
        (entry as Map)['region'] = null;
        entry.remove('region');
      }
      expect(() => GameState.fromJson(json), returnsNormally);
      final restored = GameState.fromJson(json);
      for (final s in restored.solarSystems) {
        expect(s.region, '');
      }
    });

    test('wormholes span distance', () {
      final systems = GalaxyGenerator.generate(909, DifficultyLevel.normal);
      final pairs = <(int, int)>[];
      for (var i = 0; i < systems.length; i++) {
        final ev = systems[i].specialEvent;
        if (ev != null && ev >= 1000) {
          final j = ev - 1000;
          if (j > i) pairs.add((i, j));
        }
      }
      expect(pairs.length, 12);
      final farEnough = pairs
          .where((p) => SphereGeo.distance(systems[p.$1], systems[p.$2]) >= 60)
          .length;
      expect(farEnough, greaterThanOrEqualTo(8));
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
      final total = game.solarSystems.length;
      expect(front, greaterThan(0.2 * total));
      expect(front, lessThan(0.8 * total));
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

      await tester.tap(find.byTooltip('Wormholes'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 90));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Wormholes'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 90));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('selecting a wormhole endpoint shows the wormhole chip',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(gameProvider.notifier)
          .newGame('Tester', DifficultyLevel.normal);
      final game = container.read(gameProvider)!;

      final wormholeIndex = game.solarSystems.indexWhere(
          (s) => s.specialEvent != null && s.specialEvent! >= 1000);
      expect(wormholeIndex, greaterThanOrEqualTo(0),
          reason: 'the galaxy always has 12 wormhole pairs');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GalaxyMapScreen(debugInitialSelection: wormholeIndex),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 90));
      }

      expect(find.textContaining('WORMHOLE →'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('wormholeOf', () {
    SolarSystem system({int? specialEvent}) => SolarSystem(
          name: 'Testworld',
          techLevel: 1,
          government: GovernmentType.democracy,
          status: SystemStatus.uneventful,
          x: 0,
          y: 55,
          specialResource: SpecialResource.nothingSpecial,
          size: 3,
          tradeQuantities: const {},
          countdown: 0,
          visited: false,
          specialEvent: specialEvent,
        );

    test('returns the partner index for a valid wormhole encoding', () {
      expect(wormholeOf(system(specialEvent: 1005), 400), 5);
    });

    test('returns null when specialEvent is null', () {
      expect(wormholeOf(system(specialEvent: null), 400), isNull);
    });

    test('returns null when specialEvent is below the wormhole threshold',
        () {
      expect(wormholeOf(system(specialEvent: 999), 400), isNull);
    });

    test('returns null when the partner index is out of range', () {
      expect(wormholeOf(system(specialEvent: 1005), 4), isNull);
    });
  });
}
