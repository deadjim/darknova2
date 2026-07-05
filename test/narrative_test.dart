import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:darknova2/engine/combat.dart';
import 'package:darknova2/engine/encounter.dart';
import 'package:darknova2/engine/events.dart';
import 'package:darknova2/engine/game_engine.dart';
import 'package:darknova2/engine/news.dart';
import 'package:darknova2/engine/quests.dart';
import 'package:darknova2/engine/rivals.dart';
import 'package:darknova2/models/enums.dart';
import 'package:darknova2/models/game_event.dart';
import 'package:darknova2/models/game_state.dart';
import 'package:darknova2/models/quest.dart';
import 'package:darknova2/models/ship_type_def.dart';

GameState newGame() => GameEngine.newGame('Tester', DifficultyLevel.normal);

EncounterResult makeEncounter({
  EncounterType type = EncounterType.pirate,
  ShipType shipType = ShipType.gnat,
  List<WeaponType> weapons = const [WeaponType.pulseLaser],
  int? hull,
  bool fleeing = false,
  String? rivalId,
  String? captainName,
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
      cargo: const {},
      credits: 0,
    ),
    npcFleeing: fleeing,
    rivalId: rivalId,
    captainName: captainName,
  );
}

void main() {
  group('Event ledger', () {
    test('records events and caps the ledger', () {
      var state = newGame();
      for (var i = 0; i < EventLedger.maxEvents + 50; i++) {
        state = EventLedger.record(state, GameEventType.inspectionClean,
            witnessed: true);
      }
      expect(state.events.length, EventLedger.maxEvents);
    });

    test('publicEvents filters out unwitnessed deeds', () {
      var state = newGame();
      state = EventLedger.record(state, GameEventType.pirateDestroyed,
          witnessed: false);
      state = EventLedger.record(state, GameEventType.enemyEscaped,
          witnessed: true);
      final public = EventLedger.publicEvents(state);
      expect(public.length, 1);
      expect(public.first.type, GameEventType.enemyEscaped);
    });
  });

  group('Witness mechanic', () {
    test('destroying a ship leaves no witnesses', () {
      var game = newGame();
      final rng = Random(42);
      var combat =
          CombatState.begin(makeEncounter(weapons: const [], hull: 20), game.ship);
      var rounds = 0;
      while (combat.outcome == CombatOutcome.ongoing && rounds < 200) {
        final r = Combat.attack(combat, game, rng);
        combat = r.combat;
        game = r.game;
        rounds++;
      }
      expect(combat.outcome, CombatOutcome.npcDestroyed);
      expect(game.events, isNotEmpty);
      expect(game.events.every((e) => !e.witnessed), isTrue);
    });

    test('fleeing the fight is seen — and reported', () {
      var game = newGame();
      final rng = Random(3);
      var combat = CombatState.begin(
          makeEncounter(weapons: const [], hull: 1000), game.ship);
      var rounds = 0;
      while (combat.outcome == CombatOutcome.ongoing && rounds < 500) {
        final r = Combat.flee(combat, game, rng);
        combat = r.combat;
        game = r.game;
        rounds++;
      }
      expect(combat.outcome, CombatOutcome.playerFled);
      expect(
          game.events.any(
              (e) => e.type == GameEventType.fledCombat && e.witnessed),
          isTrue);
    });
  });

  group('Rivals', () {
    test('generation is deterministic per seed and distinct across seeds', () {
      final a = RivalSystem.generate(1234);
      final b = RivalSystem.generate(1234);
      final c = RivalSystem.generate(9999);
      expect(a.length, RivalSystem.rivalCount);
      expect(a.map((r) => r.name), b.map((r) => r.name));
      expect(a.map((r) => r.name).toList(),
          isNot(equals(c.map((r) => r.name).toList())));
    });

    test('new games carry a living cast of rivals', () {
      final game = newGame();
      expect(game.rivals.length, RivalSystem.rivalCount);
      expect(game.rivals.every((r) => r.alive), isTrue);
    });

    test('spared rivals escalate their hulls', () {
      final rival = RivalSystem.generate(1)[0];
      final grown = rival.copyWith(timesSpared: 3);
      expect(RivalSystem.escalatedHull(grown).index,
          greaterThan(rival.shipType.index));
    });

    test('killing a rival marks them dead — unwitnessed', () {
      var game = newGame();
      final rival = game.rivals.first;
      final rng = Random(42);
      var combat = CombatState.begin(
        makeEncounter(
            weapons: const [],
            hull: 20,
            rivalId: rival.id,
            captainName: rival.name),
        game.ship,
      );
      var rounds = 0;
      while (combat.outcome == CombatOutcome.ongoing && rounds < 200) {
        final r = Combat.attack(combat, game, rng);
        combat = r.combat;
        game = r.game;
        rounds++;
      }
      expect(combat.outcome, CombatOutcome.npcDestroyed);
      final dead = game.rivals.firstWhere((r) => r.id == rival.id);
      expect(dead.alive, isFalse);
      expect(
          game.events.any((e) =>
              e.type == GameEventType.rivalDefeated && !e.witnessed),
          isTrue);
    });

    test('letting a beaten rival limp away breeds a grudge', () {
      var game = newGame();
      final rival = game.rivals.first;
      var combat = CombatState.begin(
        makeEncounter(
            hull: 1000, rivalId: rival.id, captainName: rival.name),
        game.ship,
      );
      // Simulate: hostile pirate rival now fleeing, player departs.
      combat = combat.copyWith(npcFleeing: true);
      final result = Combat.depart(combat, game)!;
      expect(result.combat.outcome, CombatOutcome.departed);
      final spared =
          result.game.rivals.firstWhere((r) => r.id == rival.id);
      expect(spared.timesSpared, 1);
      expect(spared.grudge, 2);
      expect(
          result.game.events.any(
              (e) => e.type == GameEventType.rivalSpared && e.witnessed),
          isTrue);
    });

    test('pickRival returns nothing when the cast is dead', () {
      var game = newGame();
      game = game.copyWith(
          rivals:
              game.rivals.map((r) => r.copyWith(alive: false)).toList());
      expect(RivalSystem.pickRival(game, Random(1)), isNull);
    });
  });

  group('Quests', () {
    GameState riggedForRelief(GameState game) {
      // Force: a plague system elsewhere + medicine in stock here + long
      // quiet spell (drama pressure).
      final systems = List.of(game.solarSystems);
      final target = (game.currentSystemIndex + 1) % systems.length;
      systems[target] = systems[target].copyWith(status: SystemStatus.plague);
      final here = systems[game.currentSystemIndex];
      final qty = Map<TradeGood, int>.from(here.tradeQuantities);
      qty[TradeGood.medicine] = 10;
      systems[game.currentSystemIndex] = here.copyWith(tradeQuantities: qty);
      return game.copyWith(solarSystems: systems, days: 15, events: []);
    }

    test('relief trigger produces a valid, locked-stakes offer', () {
      final base = riggedForRelief(newGame());
      GameState state = base;
      // Trigger is dice-gated; try a handful of seeds.
      for (var seed = 0; seed < 40 && state.questOffer == null; seed++) {
        state = QuestSystem.evaluateTriggers(base, Random(seed));
      }
      final offer = state.questOffer;
      expect(offer, isNotNull);
      expect(offer!.template, QuestTemplate.delivery);
      expect(offer.status, QuestStatus.offered);
      expect(offer.targetSystemIndex, isNot(state.currentSystemIndex));
      expect(offer.rewardCredits, greaterThan(0));
      expect(offer.deadlineDay, greaterThan(state.days));
    });

    test('no new offers while a quest is active', () {
      final base = riggedForRelief(newGame());
      GameState state = base;
      for (var seed = 0; seed < 40 && state.questOffer == null; seed++) {
        state = QuestSystem.evaluateTriggers(base, Random(seed));
      }
      state = QuestSystem.accept(state);
      expect(state.activeQuest, isNotNull);
      expect(state.questOffer, isNull);
      final again = QuestSystem.evaluateTriggers(state, Random(1));
      expect(again.questOffer, isNull);
    });

    test('delivery completes on arrival with the goods', () {
      var state = newGame();
      final quest = Quest(
        id: 'q_test',
        template: QuestTemplate.delivery,
        status: QuestStatus.active,
        title: 'TEST RUN',
        hook: '',
        giverName: 'Tester',
        successText: 'done',
        failureText: 'failed',
        good: TradeGood.water,
        qty: 3,
        targetSystemIndex: state.currentSystemIndex, // already there
        deadlineDay: state.days + 5,
        rewardCredits: 1000,
        rewardRecordBonus: 2,
        failRecordPenalty: 1,
        failReputationPenalty: 1,
      );
      state = state.copyWith(
        activeQuest: quest,
        ship: state.ship.copyWith(cargo: {TradeGood.water: 5}),
      );
      final before = state.credits;
      final (next, resolved) = QuestSystem.checkProgress(state);
      expect(resolved?.status, QuestStatus.completed);
      expect(next.activeQuest, isNull);
      expect(next.credits, before + 1000);
      expect(next.ship.cargo[TradeGood.water], 2);
      expect(next.commander.policeRecordScore, 2);
      expect(
          next.events.any(
              (e) => e.type == GameEventType.questCompleted && e.witnessed),
          isTrue);
    });

    test('missing the deadline fails the quest and applies penalties', () {
      var state = newGame();
      final quest = Quest(
        id: 'q_test2',
        template: QuestTemplate.delivery,
        status: QuestStatus.active,
        title: 'LATE RUN',
        hook: '',
        giverName: 'Tester',
        successText: 'done',
        failureText: 'failed',
        good: TradeGood.water,
        qty: 3,
        targetSystemIndex:
            (state.currentSystemIndex + 1) % state.solarSystems.length,
        deadlineDay: 2,
        rewardCredits: 1000,
        failRecordPenalty: 3,
        failReputationPenalty: 2,
      );
      state = state.copyWith(activeQuest: quest, days: 10);
      final (next, resolved) = QuestSystem.checkProgress(state);
      expect(resolved?.status, QuestStatus.failed);
      expect(next.activeQuest, isNull);
      expect(next.commander.policeRecordScore, -3);
      expect(
          next.events
              .any((e) => e.type == GameEventType.questFailed && e.witnessed),
          isTrue);
    });

    test('offers expire when you leave the system', () {
      final base = riggedForRelief(newGame());
      GameState state = base;
      for (var seed = 0; seed < 40 && state.questOffer == null; seed++) {
        state = QuestSystem.evaluateTriggers(base, Random(seed));
      }
      expect(state.questOffer, isNotNull);
      final (next, _) = QuestSystem.checkProgress(state);
      expect(next.questOffer, isNull);
    });
  });

  group('GNN news', () {
    test('crisis statuses make the wire', () {
      var state = newGame();
      // Quiet galaxy with exactly one crisis.
      final systems = state.solarSystems
          .map((s) => s.copyWith(status: SystemStatus.uneventful))
          .toList();
      final idx = (state.currentSystemIndex + 1) % systems.length;
      systems[idx] = systems[idx].copyWith(status: SystemStatus.plague);
      state = state.copyWith(solarSystems: systems);
      final lines = NewsEngine.headlines(state);
      expect(
          lines.any((l) =>
              l.contains('PLAGUE') &&
              l.contains(systems[idx].name.toUpperCase())),
          isTrue);
    });

    test('witnessed deeds are reported; unwitnessed kills are not', () {
      var state = newGame();
      state = EventLedger.record(state, GameEventType.pirateDestroyed,
          witnessed: false);
      state = EventLedger.record(state, GameEventType.enemyEscaped,
          witnessed: true);
      final lines = NewsEngine.headlines(state).join(' ');
      expect(lines.contains('NAMES'), isTrue); // attacker named
      expect(lines.contains('TESTER'), isTrue);
    });
  });

  group('Persistence', () {
    test('events, rivals, and quests survive a JSON round-trip', () {
      var state = newGame();
      state = EventLedger.record(state, GameEventType.enemyEscaped,
          witnessed: true, rivalId: state.rivals.first.id, detail: 'pirate');
      state = state.copyWith(
        activeQuest: Quest(
          id: 'q_rt',
          template: QuestTemplate.delivery,
          status: QuestStatus.active,
          title: 'ROUND TRIP',
          hook: 'h',
          giverName: 'g',
          successText: 's',
          failureText: 'f',
          good: TradeGood.furs,
          qty: 2,
          targetSystemIndex: 1,
          deadlineDay: 9,
          rewardCredits: 500,
          rewardRecordBonus: 1,
          failRecordPenalty: 1,
          failReputationPenalty: 1,
        ),
      );
      final restored = GameState.fromJson(state.toJson());
      expect(restored.events.length, state.events.length);
      expect(restored.events.last.rivalId, state.rivals.first.id);
      expect(restored.rivals.map((r) => r.name),
          state.rivals.map((r) => r.name));
      expect(restored.activeQuest?.title, 'ROUND TRIP');
      expect(restored.activeQuest?.rewardCredits, 500);
    });

    test('old saves without narrative fields still load', () {
      final json = newGame().toJson()
        ..remove('events')
        ..remove('rivals')
        ..remove('activeQuest')
        ..remove('questOffer');
      final restored = GameState.fromJson(json);
      expect(restored.events, isEmpty);
      expect(restored.rivals, isEmpty);
      expect(restored.activeQuest, isNull);
    });
  });
}
