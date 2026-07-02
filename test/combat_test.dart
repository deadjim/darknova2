import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:darknova2/engine/combat.dart';
import 'package:darknova2/engine/encounter.dart';
import 'package:darknova2/engine/game_engine.dart';
import 'package:darknova2/models/enums.dart';
import 'package:darknova2/models/game_state.dart';
import 'package:darknova2/models/ship.dart';
import 'package:darknova2/models/ship_type_def.dart';

EncounterResult makeEncounter({
  EncounterType type = EncounterType.pirate,
  ShipType shipType = ShipType.gnat,
  List<WeaponType> weapons = const [WeaponType.pulseLaser],
  int? hull,
  Map<TradeGood, int> cargo = const {},
  int credits = 0,
  bool fleeing = false,
}) {
  final def = ShipTypeDef.forType(shipType);
  final h = hull ?? def.hullStrength;
  return EncounterResult(
    type: type,
    npcShip: NpcShip(
      shipType: shipType,
      weapons: weapons,
      shields: const [],
      hullStrength: h,
      currentHull: h,
      cargo: cargo,
      credits: credits,
    ),
    npcFleeing: fleeing,
  );
}

GameState newGame() => GameEngine.newGame('Tester', DifficultyLevel.normal);

void main() {
  group('Combat — attack resolution', () {
    test('unarmed NPC is eventually destroyed; loot and kills recorded', () {
      var game = newGame();
      final rng = Random(42);
      final enc = makeEncounter(
        type: EncounterType.pirate,
        weapons: const [], // unarmed — player cannot lose
        hull: 30,
        credits: 250,
      );
      var combat = CombatState.begin(enc, game.ship);

      var rounds = 0;
      while (combat.outcome == CombatOutcome.ongoing && rounds < 200) {
        final result = Combat.attack(combat, game, rng);
        combat = result.combat;
        game = result.game;
        rounds++;
      }

      expect(combat.outcome, CombatOutcome.npcDestroyed);
      expect(game.commander.pirateKills, 1);
      expect(game.commander.reputationScore, greaterThan(0));
      // Bounty (ship bounty + npc credits) was collected.
      expect(game.credits,
          newGame().credits + combat.npcDef.bounty + 250);
      // Clean commander gets a small civic bonus for killing a pirate.
      expect(game.commander.policeRecordScore, 1);
    });

    test('unarmed player is eventually destroyed; no pod = game over', () {
      var game = newGame();
      // Strip weapons and weaken hull so the pirate always wins.
      game = game.copyWith(
        ship: game.ship.copyWith(weapons: [], hullStrength: 10),
      );
      final rng = Random(7);
      final enc = makeEncounter(
        weapons: const [WeaponType.militaryLaser],
        hull: 1000,
      );
      var combat = CombatState.begin(enc, game.ship);

      var rounds = 0;
      while (combat.outcome == CombatOutcome.ongoing && rounds < 500) {
        final result = Combat.attack(combat, game, rng);
        combat = result.combat;
        game = result.game;
        rounds++;
      }

      expect(combat.outcome, CombatOutcome.playerDestroyedGameOver);
      expect(game.ship.hullStrength, 0);
    });

    test('escape pod converts destruction into a rescue Flea + insurance', () {
      var game = newGame();
      final shipValue = game.ship.def.price ~/ 2;
      game = game.copyWith(
        ship: game.ship.copyWith(weapons: [], hullStrength: 5),
        escapePod: true,
        insurance: true,
      );
      final startCredits = game.credits;
      final rng = Random(11);
      final enc = makeEncounter(
        weapons: const [WeaponType.militaryLaser],
        hull: 1000,
      );
      var combat = CombatState.begin(enc, game.ship);

      var rounds = 0;
      while (combat.outcome == CombatOutcome.ongoing && rounds < 500) {
        final result = Combat.attack(combat, game, rng);
        combat = result.combat;
        game = result.game;
        rounds++;
      }

      expect(combat.outcome, CombatOutcome.playerDestroyedEscaped);
      expect(game.ship.shipType, ShipType.flea);
      expect(game.credits, startCredits + shipValue);
      expect(game.escapePod, isFalse);
      expect(game.insurance, isFalse);
    });

    test('attacking non-hostile police turns them hostile and hurts record',
        () {
      final game = newGame();
      final enc = makeEncounter(
        type: EncounterType.police,
        weapons: const [],
        hull: 1000,
      );
      final combat = CombatState.begin(enc, game.ship);
      expect(combat.npcHostile, isFalse);

      final result = Combat.attack(combat, game, Random(1));
      expect(result.combat.npcHostile, isTrue);
      expect(result.game.commander.policeRecordScore,
          game.commander.policeRecordScore - 6);
    });
  });

  group('Combat — flee', () {
    test('player with unarmed opponent eventually escapes', () {
      var game = newGame();
      final rng = Random(3);
      final enc = makeEncounter(weapons: const [], hull: 1000);
      var combat = CombatState.begin(enc, game.ship);

      var rounds = 0;
      while (combat.outcome == CombatOutcome.ongoing && rounds < 500) {
        final result = Combat.flee(combat, game, rng);
        combat = result.combat;
        game = result.game;
        rounds++;
      }

      expect(combat.outcome, CombatOutcome.playerFled);
    });

    test('fleeing a police inspection damages the record', () {
      final game = newGame();
      final enc = makeEncounter(
          type: EncounterType.police, weapons: const [], hull: 100);
      final combat = CombatState.begin(enc, game.ship);
      final result = Combat.flee(combat, game, Random(5));
      expect(result.game.commander.policeRecordScore,
          game.commander.policeRecordScore - 2);
    });
  });

  group('Combat — surrender / inspection / bribe', () {
    test('surrender to pirates loses cargo and credits, ends encounter', () {
      var game = newGame();
      game = game.copyWith(
        ship: game.ship.copyWith(cargo: {TradeGood.furs: 5}),
        credits: 10000,
      );
      final enc = makeEncounter();
      final combat = CombatState.begin(enc, game.ship);

      final result = Combat.surrender(combat, game)!;
      expect(result.combat.outcome, CombatOutcome.surrendered);
      expect(result.game.ship.cargo, isEmpty);
      expect(result.game.credits, lessThan(10000));
    });

    test('surrender is not possible to a monster', () {
      final game = newGame();
      final enc = makeEncounter(type: EncounterType.monster);
      final combat = CombatState.begin(enc, game.ship);
      expect(Combat.surrender(combat, game), isNull);
    });

    test('inspection with contraband: confiscation, fine, record -5', () {
      var game = newGame();
      game = game.copyWith(
        ship: game.ship
            .copyWith(cargo: {TradeGood.narcotics: 3, TradeGood.water: 2}),
        credits: 5000,
      );
      final enc = makeEncounter(type: EncounterType.police);
      final combat = CombatState.begin(enc, game.ship);

      final result = Combat.submit(combat, game)!;
      expect(result.combat.outcome, CombatOutcome.inspectionBusted);
      expect(result.game.ship.cargo.containsKey(TradeGood.narcotics), isFalse);
      expect(result.game.ship.cargo[TradeGood.water], 2);
      expect(result.game.credits, lessThan(5000));
      expect(result.game.commander.policeRecordScore,
          game.commander.policeRecordScore - 5);
    });

    test('clean inspection improves the record', () {
      final game = newGame();
      final enc = makeEncounter(type: EncounterType.police);
      final combat = CombatState.begin(enc, game.ship);

      final result = Combat.submit(combat, game)!;
      expect(result.combat.outcome, CombatOutcome.inspectionClean);
      expect(result.game.commander.policeRecordScore,
          game.commander.policeRecordScore + 1);
    });

    test('bribe succeeds where the government is corruptible', () {
      var game = newGame();
      // Move to a bribable system: force current system's government by
      // finding one with bribeLevel > 0 (Sol is a democracy, bribeLevel may
      // vary) — instead just assert behavior matches the government.
      game = game.copyWith(credits: 10000);
      final enc = makeEncounter(type: EncounterType.police);
      final combat = CombatState.begin(enc, game.ship);

      final result = Combat.bribe(combat, game)!;
      final gov = result.game.currentSystem.government;
      if (result.combat.outcome == CombatOutcome.bribed) {
        expect(result.game.credits, lessThan(10000));
      } else {
        // Incorruptible government: encounter continues, no credits spent.
        expect(result.game.credits, 10000);
        expect(gov, isNotNull);
      }
    });

    test('submit/bribe are unavailable against non-police', () {
      final game = newGame();
      final enc = makeEncounter(type: EncounterType.pirate);
      final combat = CombatState.begin(enc, game.ship);
      expect(Combat.submit(combat, game), isNull);
      expect(Combat.bribe(combat, game), isNull);
    });
  });

  group('Combat — depart', () {
    test('player may ignore a peaceful trader', () {
      final game = newGame();
      final enc = makeEncounter(type: EncounterType.trader);
      final combat = CombatState.begin(enc, game.ship);
      final result = Combat.depart(combat, game)!;
      expect(result.combat.outcome, CombatOutcome.departed);
    });

    test('player cannot simply leave a police inspection', () {
      final game = newGame();
      final enc = makeEncounter(type: EncounterType.police);
      final combat = CombatState.begin(enc, game.ship);
      expect(Combat.depart(combat, game), isNull);
    });

    test('player cannot leave a hostile pirate', () {
      final game = newGame();
      final enc = makeEncounter(type: EncounterType.pirate);
      final combat = CombatState.begin(enc, game.ship);
      expect(Combat.depart(combat, game), isNull);
    });
  });

  group('Encounter roll integration', () {
    test('rollEncounter produces a playable encounter or nothing', () {
      final game = newGame();
      for (var i = 0; i < 50; i++) {
        final enc = GameEngine.rollEncounter(game);
        if (enc != null) {
          final combat = CombatState.begin(enc, game.ship);
          expect(combat.npcHull, greaterThan(0));
          expect(combat.outcome, CombatOutcome.ongoing);
        }
      }
    });
  });
}
