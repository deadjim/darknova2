import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:darknova2/engine/arrival.dart';
import 'package:darknova2/engine/game_engine.dart';
import 'package:darknova2/models/enums.dart';
import 'package:darknova2/models/game_event.dart';
import 'package:darknova2/models/game_state.dart';
import 'package:darknova2/models/quest.dart';

GameState newGame() => GameEngine.newGame('Tester', DifficultyLevel.normal);

Quest activeDelivery(GameState state, {int qty = 3}) => Quest(
      id: 'q_v',
      template: QuestTemplate.delivery,
      status: QuestStatus.active,
      title: 'TEST HAUL',
      hook: '',
      giverName: 'Tester',
      successText: 's',
      failureText: 'f',
      good: TradeGood.water,
      qty: qty,
      targetSystemIndex:
          (state.currentSystemIndex + 1) % state.solarSystems.length,
      deadlineDay: state.days + 20,
      rewardCredits: 1000,
      failRecordPenalty: 2,
      failReputationPenalty: 1,
    );

ArrivalEvent distress({required bool trap}) => ArrivalEvent(
      kind: VignetteKind.distressCall,
      title: 'DISTRESS CALL',
      body: 'test',
      choices: const [
        VignetteChoice.respond,
        VignetteChoice.scan,
        VignetteChoice.jumpAway,
      ],
      trap: trap,
    );

void main() {
  group('Arrival director', () {
    test('one interrupt max; outcome is vignette XOR encounter XOR nothing',
        () {
      final game = newGame();
      for (var seed = 0; seed < 60; seed++) {
        final outcome = ArrivalDirector.roll(game, Random(seed));
        final both = outcome.vignette != null && outcome.encounter != null;
        expect(both, isFalse);
      }
    });

    test('a boiling grudge produces ambushes', () {
      var game = newGame();
      game = game.copyWith(
        rivals: [game.rivals.first.copyWith(grudge: 10)],
      );
      var sawAmbush = false;
      for (var seed = 0; seed < 60 && !sawAmbush; seed++) {
        final outcome = ArrivalDirector.roll(game, Random(seed));
        if (outcome.encounter?.ambush == true) {
          sawAmbush = true;
          expect(outcome.encounter!.rivalId, game.rivals.first.id);
          expect(outcome.encounter!.captainName, game.rivals.first.name);
        }
      }
      expect(sawAmbush, isTrue);
    });

    test('hauling quest cargo invites interdiction', () {
      var game = newGame();
      final quest = activeDelivery(game);
      game = game.copyWith(
        activeQuest: quest,
        ship: game.ship.copyWith(cargo: {TradeGood.water: quest.qty}),
        // No rivals so ambush can't shadow the test.
        rivals: [],
      );
      var sawInterdiction = false;
      for (var seed = 0; seed < 80 && !sawInterdiction; seed++) {
        final outcome = ArrivalDirector.roll(game, Random(seed));
        if (outcome.vignette?.kind == VignetteKind.questComplication) {
          sawInterdiction = true;
        }
      }
      expect(sawInterdiction, isTrue);
    });
  });

  group('Distress call', () {
    test('responding to a genuine mayday pays and makes the news', () {
      final game = newGame();
      final before = game.credits;
      final res = ArrivalDirector.resolve(
          distress(trap: false), game, VignetteChoice.respond, Random(1));
      expect(res.combat, isNull);
      expect(res.game.credits, greaterThan(before));
      expect(res.game.commander.policeRecordScore, 1);
      expect(
          res.game.events.any(
              (e) => e.type == GameEventType.rescuePerformed && e.witnessed),
          isTrue);
    });

    test('responding to bait springs an ambush', () {
      final game = newGame();
      final res = ArrivalDirector.resolve(
          distress(trap: true), game, VignetteChoice.respond, Random(1));
      expect(res.combat, isNotNull);
      expect(res.combat!.ambush, isTrue);
      expect(res.combat!.type, EncounterType.pirate);
    });

    test('ignoring a genuine mayday: survivors make it public', () {
      final game = newGame();
      var sawWitnessed = false;
      var sawSecret = false;
      for (var seed = 0; seed < 40; seed++) {
        final res = ArrivalDirector.resolve(
            distress(trap: false), game, VignetteChoice.jumpAway, Random(seed));
        final event = res.game.events.last;
        expect(event.type, GameEventType.maydayIgnored);
        if (event.witnessed) sawWitnessed = true;
        if (!event.witnessed) sawSecret = true;
      }
      // Both fates occur across seeds: sometimes seen, sometimes secret.
      expect(sawWitnessed, isTrue);
      expect(sawSecret, isTrue);
    });

    test('ignoring bait leaves no trace at all', () {
      final game = newGame();
      final res = ArrivalDirector.resolve(
          distress(trap: true), game, VignetteChoice.jumpAway, Random(1));
      expect(res.game.events, isEmpty);
    });

    test('scanning reveals information without rerolling fate', () {
      final game = newGame();
      final res = ArrivalDirector.resolve(
          distress(trap: true), game, VignetteChoice.scan, Random(1));
      expect(res.updated, isNotNull);
      expect(res.updated!.trap, isTrue); // stakes locked
      expect(res.updated!.hint, isNotNull);
      expect(res.updated!.choices, isNot(contains(VignetteChoice.scan)));
    });
  });

  group('Derelict', () {
    final derelictEvent = const ArrivalEvent(
      kind: VignetteKind.derelict,
      title: 'DERELICT',
      body: 'test',
      choices: [VignetteChoice.board, VignetteChoice.leave],
    );

    test('boarding yields varied outcomes, never death', () {
      final game = newGame();
      var gained = false;
      for (var seed = 0; seed < 60; seed++) {
        final res = ArrivalDirector.resolve(
            derelictEvent, game, VignetteChoice.board, Random(seed));
        expect(res.game.ship.hullStrength, greaterThan(0));
        if (res.game.credits > game.credits ||
            res.game.ship.totalCargoUsed > 0 ||
            res.game.questOffer != null) {
          gained = true;
        }
      }
      expect(gained, isTrue);
    });

    test('salvage stays off the public record', () {
      final game = newGame();
      for (var seed = 0; seed < 60; seed++) {
        final res = ArrivalDirector.resolve(
            derelictEvent, game, VignetteChoice.board, Random(seed));
        for (final e in res.game.events) {
          expect(e.witnessed, isFalse);
        }
      }
    });

    test('leaving costs nothing', () {
      final game = newGame();
      final res = ArrivalDirector.resolve(
          derelictEvent, game, VignetteChoice.leave, Random(1));
      expect(res.game.credits, game.credits);
      expect(res.game.events, isEmpty);
    });
  });

  group('Quest complication', () {
    test('jettisoning the cargo fails the quest at its locked stakes', () {
      var game = newGame();
      final quest = activeDelivery(game);
      game = game.copyWith(
        activeQuest: quest,
        ship: game.ship.copyWith(cargo: {TradeGood.water: quest.qty}),
      );
      final event = ArrivalEvent(
        kind: VignetteKind.questComplication,
        title: 'INTERDICTION',
        body: 'test',
        choices: const [
          VignetteChoice.surrenderCargo,
          VignetteChoice.fight,
          VignetteChoice.evade,
        ],
      );
      final res = ArrivalDirector.resolve(
          event, game, VignetteChoice.surrenderCargo, Random(1));
      expect(res.game.activeQuest, isNull);
      expect(res.game.ship.cargo[TradeGood.water], isNull);
      expect(res.game.commander.policeRecordScore, -quest.failRecordPenalty);
      expect(
          res.game.events
              .any((e) => e.type == GameEventType.cargoSeized && e.witnessed),
          isTrue);
    });

    test('fighting hands off to combat with the cargo intact', () {
      var game = newGame();
      final quest = activeDelivery(game);
      game = game.copyWith(
        activeQuest: quest,
        ship: game.ship.copyWith(cargo: {TradeGood.water: quest.qty}),
      );
      final event = ArrivalEvent(
        kind: VignetteKind.questComplication,
        title: 'INTERDICTION',
        body: 'test',
        choices: const [VignetteChoice.fight],
      );
      final res = ArrivalDirector.resolve(
          event, game, VignetteChoice.fight, Random(1));
      expect(res.combat, isNotNull);
      expect(res.game.activeQuest, isNotNull);
      expect(res.game.ship.cargo[TradeGood.water], quest.qty);
    });
  });
}
