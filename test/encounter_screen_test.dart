import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darknova2/engine/encounter.dart';
import 'package:darknova2/models/enums.dart';
import 'package:darknova2/models/ship_type_def.dart';
import 'package:darknova2/providers/game_provider.dart';
import 'package:darknova2/screens/encounter_screen.dart';

EncounterResult pirateEncounter() {
  final def = ShipTypeDef.forType(ShipType.gnat);
  return EncounterResult(
    type: EncounterType.pirate,
    npcShip: NpcShip(
      shipType: ShipType.gnat,
      weapons: const [WeaponType.pulseLaser],
      shields: const [],
      hullStrength: def.hullStrength,
      currentHull: def.hullStrength,
      cargo: const {},
      credits: 100,
    ),
    npcFleeing: false,
  );
}

void main() {
  testWidgets('encounter screen shows pirate actions and resolves attacks',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(gameProvider.notifier).newGame(
        'Tester', DifficultyLevel.beginner);
    final game = container.read(gameProvider)!;
    container.read(encounterProvider.notifier).begin(
        pirateEncounter(), game.ship);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EncounterScreen()),
      ),
    );

    expect(find.text('PIRATE ATTACK'), findsOneWidget);
    expect(find.text('ATTACK'), findsOneWidget);
    expect(find.text('FLEE'), findsOneWidget);
    expect(find.text('SURRENDER'), findsOneWidget);
    // Police-only actions must not appear.
    expect(find.text('SUBMIT'), findsNothing);
    expect(find.text('BRIBE'), findsNothing);

    // Fight until the encounter resolves one way or the other.
    for (var i = 0; i < 300; i++) {
      final combat = container.read(encounterProvider);
      if (combat == null || combat.isOver) break;
      await tester.tap(find.text('ATTACK'));
      await tester.pump();
    }

    final combat = container.read(encounterProvider)!;
    expect(combat.isOver, isTrue);
    expect(combat.log, isNotEmpty);
    expect(
      find.text(combat.outcome.toString() ==
              'CombatOutcome.playerDestroyedGameOver'
          ? 'GAME OVER'
          : 'CONTINUE'),
      findsOneWidget,
    );
  });

  testWidgets('police encounter offers submit and bribe', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(gameProvider.notifier).newGame(
        'Tester', DifficultyLevel.beginner);
    final game = container.read(gameProvider)!;
    final def = ShipTypeDef.forType(ShipType.hornet);
    container.read(encounterProvider.notifier).begin(
          EncounterResult(
            type: EncounterType.police,
            npcShip: NpcShip(
              shipType: ShipType.hornet,
              weapons: const [WeaponType.beamLaser],
              shields: const [],
              hullStrength: def.hullStrength,
              currentHull: def.hullStrength,
              cargo: const {},
              credits: 0,
            ),
            npcFleeing: false,
          ),
          game.ship,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EncounterScreen()),
      ),
    );

    expect(find.text('POLICE INSPECTION'), findsOneWidget);
    expect(find.text('SUBMIT'), findsOneWidget);
    expect(find.text('BRIBE'), findsOneWidget);

    // Submitting with clean cargo ends the inspection.
    await tester.tap(find.text('SUBMIT'));
    await tester.pump();
    expect(container.read(encounterProvider)!.isOver, isTrue);
    expect(find.text('CONTINUE'), findsOneWidget);
  });
}
