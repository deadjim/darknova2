import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:darknova2/engine/combat.dart';
import 'package:darknova2/engine/encounter.dart';
import 'package:darknova2/engine/game_engine.dart';
import 'package:darknova2/engine/parley.dart';
import 'package:darknova2/engine/rivals.dart';
import 'package:darknova2/models/enums.dart';
import 'package:darknova2/models/game_event.dart';
import 'package:darknova2/models/game_state.dart';
import 'package:darknova2/models/government_def.dart';
import 'package:darknova2/models/rival.dart';
import 'package:darknova2/models/ship_type_def.dart';

EncounterResult makeEncounter({
  EncounterType type = EncounterType.pirate,
  ShipType shipType = ShipType.gnat,
  List<WeaponType> weapons = const [WeaponType.pulseLaser],
  int? hull,
  Map<TradeGood, int> cargo = const {},
  int credits = 0,
  bool fleeing = false,
  bool ambush = false,
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
      cargo: cargo,
      credits: credits,
    ),
    npcFleeing: fleeing,
    ambush: ambush,
    rivalId: rivalId,
    captainName: captainName,
  );
}

GameState newGame() => GameEngine.newGame('Tester', DifficultyLevel.normal);

/// Move the player to a system with the given government property, so
/// government-dependent mechanics are deterministic.
GameState atSystemWhere(GameState game, bool Function(GovernmentDef) pred) {
  final idx = game.solarSystems.indexWhere(
      (s) => pred(GovernmentDef.forType(s.government)));
  expect(idx, greaterThanOrEqualTo(0),
      reason: 'galaxy should contain a matching government');
  return game.copyWith(currentSystemIndex: idx);
}

/// The first rival, dialed to the given grudge, plus a matching encounter.
(GameState, CombatState) rivalEncounter(GameState game,
    {int grudge = 0, RivalTemperament? temperament}) {
  var rival = game.rivals.first.copyWith(grudge: grudge);
  if (temperament != null) {
    rival = RivalCaptain(
      id: rival.id,
      name: rival.name,
      shipType: rival.shipType,
      temperament: temperament,
      timesMet: rival.timesMet,
      timesSpared: rival.timesSpared,
      grudge: rival.grudge,
      alive: rival.alive,
      lastSeenDay: rival.lastSeenDay,
    );
  }
  final state = RivalSystem.updateRival(game, rival.id, (_) => rival);
  final enc = makeEncounter(
      type: EncounterType.pirate, rivalId: rival.id, captainName: rival.name);
  return (state, CombatState.begin(enc, state.ship));
}

/// Find a seed whose full run (open + one choice) satisfies [pred].
int findSeed(bool Function(int seed) pred, {int max = 2000}) {
  for (var seed = 0; seed < max; seed++) {
    if (pred(seed)) return seed;
  }
  fail('no seed under $max produced the wanted outcome');
}

void main() {
  group('Parley — hailability', () {
    test('a fresh pirate encounter answers a hail', () {
      final game = newGame();
      final combat = CombatState.begin(makeEncounter(), game.ship);
      expect(ParleyDirector.canHail(combat, game), isTrue);
    });

    test('monsters never answer', () {
      final game = newGame();
      final combat = CombatState.begin(
          makeEncounter(type: EncounterType.monster), game.ship);
      expect(ParleyDirector.canHail(combat, game), isFalse);
    });

    test('a fleeing ship does not answer', () {
      final game = newGame();
      final combat = CombatState.begin(
          makeEncounter(type: EncounterType.trader, fleeing: true),
          game.ship);
      expect(ParleyDirector.canHail(combat, game), isFalse);
    });

    test('nobody talks once shots are fired', () {
      var game = newGame();
      var combat = CombatState.begin(makeEncounter(), game.ship);
      final result = Combat.attack(combat, game, Random(1));
      expect(ParleyDirector.canHail(result.combat, result.game), isFalse);
    });

    test('an ambush refuses the hail — they said it with a weapons lock',
        () {
      final game = newGame();
      final combat =
          CombatState.begin(makeEncounter(ambush: true), game.ship);
      expect(ParleyDirector.canHail(combat, game), isFalse);
    });

    test('a rival past boiling point is done with words', () {
      final game = newGame();
      final (hot, hotCombat) = rivalEncounter(game, grudge: 6);
      expect(ParleyDirector.canHail(hotCombat, hot), isFalse);
      final (warm, warmCombat) = rivalEncounter(game, grudge: 3);
      expect(ParleyDirector.canHail(warmCombat, warm), isTrue);
    });

    test('a resolved encounter cannot be hailed', () {
      final game = newGame();
      final combat = CombatState.begin(
              makeEncounter(type: EncounterType.trader), game.ship)
          .copyWith(outcome: CombatOutcome.departed);
      expect(ParleyDirector.canHail(combat, game), isFalse);
    });
  });

  group('Parley — opening the channel', () {
    test('pirate hail states a locked demand and offers 2-4 options', () {
      final game = newGame();
      final combat = CombatState.begin(makeEncounter(), game.ship);
      final session = ParleyDirector.open(combat, game, Random(9));

      expect(session.transcript, hasLength(1));
      expect(session.demandCredits, greaterThanOrEqualTo(100));
      expect(session.transcript.first, contains('${session.demandCredits}'));
      expect(session.options.length, inInclusiveRange(2, 4));
      expect(session.options, contains(ParleyOption.bluff));
      expect(session.options, contains(ParleyOption.threaten));
      // Starter can afford the demand (1000 cr vs a Gnat's toll).
      expect(session.options, contains(ParleyOption.payOff));
    });

    test('a broke captain cannot offer tribute, but may plead', () {
      var game = newGame().copyWith(credits: 0);
      final combat = CombatState.begin(makeEncounter(), game.ship);
      final session = ParleyDirector.open(combat, game, Random(9));
      expect(session.options, isNot(contains(ParleyOption.payOff)));
      expect(session.options, contains(ParleyOption.plead));
    });

    test('rival hail names the player and the captain speaks in character',
        () {
      final game = newGame();
      final (state, combat) = rivalEncounter(game,
          grudge: 2, temperament: RivalTemperament.vengeful);
      final session = ParleyDirector.open(combat, state, Random(4));
      expect(session.transcript.first, contains('Tester'));
      expect(session.transcript.first, contains(state.rivals.first.name));
    });

    test('police offer comply always; bribe only where corruptible', () {
      var game = atSystemWhere(newGame(), (g) => g.bribeLevel > 0);
      var combat = CombatState.begin(
          makeEncounter(type: EncounterType.police), game.ship);
      var session = ParleyDirector.open(combat, game, Random(2));
      expect(session.options, contains(ParleyOption.comply));
      expect(session.options, contains(ParleyOption.payOff));
      expect(session.options, contains(ParleyOption.bluff));
      // No pirate kills on record — nothing to trade.
      expect(session.options, isNot(contains(ParleyOption.tradeInfo)));

      game = atSystemWhere(newGame(), (g) => g.bribeLevel == 0);
      combat = CombatState.begin(
          makeEncounter(type: EncounterType.police), game.ship);
      session = ParleyDirector.open(combat, game, Random(2));
      expect(session.options, isNot(contains(ParleyOption.payOff)));
    });

    test('police accept intel only from captains with pirate kills', () {
      var game = newGame();
      game = game.copyWith(
          commander: game.commander.copyWith(pirateKills: 3));
      final combat = CombatState.begin(
          makeEncounter(type: EncounterType.police), game.ship);
      final session = ParleyDirector.open(combat, game, Random(2));
      expect(session.options, contains(ParleyOption.tradeInfo));
    });

    test('trader offers info, extortion, and a polite sign-off', () {
      final game = newGame();
      final combat = CombatState.begin(
          makeEncounter(type: EncounterType.trader), game.ship);
      final session = ParleyDirector.open(combat, game, Random(2));
      expect(session.options, [
        ParleyOption.tradeInfo,
        ParleyOption.threaten,
        ParleyOption.comply,
      ]);
    });

    test('same seed, same parley: hail and outcomes are deterministic', () {
      final game = newGame();
      final combat = CombatState.begin(makeEncounter(), game.ship);
      final a = ParleyDirector.open(combat, game, Random(77));
      final b = ParleyDirector.open(combat, game, Random(77));
      expect(a.transcript, b.transcript);
      expect(a.options, b.options);
      expect(a.demandCredits, b.demandCredits);

      final ra =
          ParleyDirector.choose(a, combat, game, ParleyOption.bluff, Random(5));
      final rb =
          ParleyDirector.choose(b, combat, game, ParleyOption.bluff, Random(5));
      expect(ra.session.transcript, rb.session.transcript);
      expect(ra.combat.outcome, rb.combat.outcome);
      expect(ra.game.credits, rb.game.credits);
    });
  });

  group('Parley — pirates', () {
    test('paying tribute costs the demand, ends the encounter, makes news',
        () {
      final game = newGame();
      final combat = CombatState.begin(makeEncounter(), game.ship);
      final session = ParleyDirector.open(combat, game, Random(9));
      final result = ParleyDirector.choose(
          session, combat, game, ParleyOption.payOff, Random(1));

      expect(result.resolved, isTrue);
      expect(result.combat.outcome, CombatOutcome.bribed);
      expect(result.game.credits, game.credits - session.demandCredits);
      final event = result.game.events.last;
      expect(event.type, GameEventType.surrenderedToPirates);
      expect(event.witnessed, isTrue);
      expect(event.detail, 'tribute');
    });

    test('tribute soothes a rival grudge', () {
      final game = newGame();
      final (state, combat) = rivalEncounter(game, grudge: 3);
      final session = ParleyDirector.open(combat, state, Random(9));
      final result = ParleyDirector.choose(
          session, combat, state, ParleyOption.payOff, Random(1));
      expect(result.game.rivals.first.grudge, 2);
    });

    test('bluff either talks them down or draws fire — never limbo', () {
      final game = newGame();
      var sawSuccess = false;
      var sawFailure = false;
      for (var seed = 0; seed < 200; seed++) {
        final combat = CombatState.begin(makeEncounter(), game.ship);
        final rng = Random(seed);
        final session = ParleyDirector.open(combat, game, rng);
        final result = ParleyDirector.choose(
            session, combat, game, ParleyOption.bluff, rng);

        expect(result.over, isTrue, reason: 'bluff always closes the channel');
        if (result.resolved) {
          sawSuccess = true;
          expect(result.combat.outcome, CombatOutcome.departed);
          expect(result.game.credits, game.credits);
          // Quiet exit: no witnessed headline.
          expect(result.game.events.last.witnessed, isFalse);
        } else {
          sawFailure = true;
          expect(result.escalated, isTrue);
          expect(result.combat.outcome, CombatOutcome.ongoing);
          expect(result.combat.npcHostile, isTrue);
          // The channel is burnt: no re-hailing mid-fight.
          expect(ParleyDirector.canHail(result.combat, result.game), isFalse);
        }
      }
      expect(sawSuccess, isTrue);
      expect(sawFailure, isTrue);
    });

    test('the free shot after a failed bluff can wound but never kill', () {
      var game = newGame();
      game = game.copyWith(ship: game.ship.copyWith(hullStrength: 2));
      for (var seed = 0; seed < 300; seed++) {
        final combat = CombatState.begin(
            makeEncounter(weapons: const [WeaponType.militaryLaser]),
            game.ship);
        final rng = Random(seed);
        final session = ParleyDirector.open(combat, game, rng);
        final result = ParleyDirector.choose(
            session, combat, game, ParleyOption.bluff, rng);
        expect(result.game.ship.hullStrength, greaterThanOrEqualTo(1));
        expect(result.combat.outcome, isNot(CombatOutcome.playerDestroyedGameOver));
      }
    });

    test('a successful threat sends them running — mercy then flows through '
        'the normal combat machinery', () {
      var game = newGame();
      game = game.copyWith(
          commander: game.commander.copyWith(fighter: 10));

      final seed = findSeed((s) {
        final combat = CombatState.begin(makeEncounter(), game.ship);
        final rng = Random(s);
        final session = ParleyDirector.open(combat, game, rng);
        final r = ParleyDirector.choose(
            session, combat, game, ParleyOption.threaten, rng);
        return r.escalated && r.combat.npcFleeing;
      });

      final combat = CombatState.begin(makeEncounter(), game.ship);
      final rng = Random(seed);
      final session = ParleyDirector.open(combat, game, rng);
      final result = ParleyDirector.choose(
          session, combat, game, ParleyOption.threaten, rng);
      expect(result.combat.npcFleeing, isTrue);
      expect(result.combat.outcome, CombatOutcome.ongoing);

      // Letting them limp away round-trips through Combat.depart: the
      // survivor talks and the ledger hears about it.
      final departed = Combat.depart(result.combat, result.game)!;
      expect(departed.combat.outcome, CombatOutcome.departed);
      expect(departed.game.events.last.type, GameEventType.enemyEscaped);
      expect(departed.game.events.last.witnessed, isTrue);
    });

    test('a failed threat against a rival deepens the grudge', () {
      var game = newGame();
      game = game.copyWith(commander: game.commander.copyWith(fighter: 0));
      final (state, _) = rivalEncounter(game, grudge: 2);

      final seed = findSeed((s) {
        final (st, combat) = rivalEncounter(game, grudge: 2);
        final rng = Random(s);
        final session = ParleyDirector.open(combat, st, rng);
        final r = ParleyDirector.choose(
            session, combat, st, ParleyOption.threaten, rng);
        return r.escalated && !r.combat.npcFleeing;
      });

      final (st, combat) = rivalEncounter(game, grudge: 2);
      final rng = Random(seed);
      final session = ParleyDirector.open(combat, st, rng);
      final result = ParleyDirector.choose(
          session, combat, st, ParleyOption.threaten, rng);
      expect(result.game.rivals.first.grudge, 3);
      expect(state.rivals.first.grudge, 2); // original untouched
    });

    test('a failed plea keeps the channel open but begging is done', () {
      var game = newGame().copyWith(credits: 0);
      final seed = findSeed((s) {
        final combat = CombatState.begin(makeEncounter(), game.ship);
        final rng = Random(s);
        final session = ParleyDirector.open(combat, game, rng);
        final r = ParleyDirector.choose(
            session, combat, game, ParleyOption.plead, rng);
        return !r.over;
      });

      final combat = CombatState.begin(makeEncounter(), game.ship);
      final rng = Random(seed);
      final session = ParleyDirector.open(combat, game, rng);
      final result = ParleyDirector.choose(
          session, combat, game, ParleyOption.plead, rng);
      expect(result.over, isFalse);
      expect(result.session.options, isNot(contains(ParleyOption.plead)));
      expect(result.session.options, isNotEmpty);
      expect(result.session.transcript.length,
          session.transcript.length + 2); // your line + theirs
    });

    test('an honorable rival can be talked out of it entirely', () {
      var game = newGame().copyWith(credits: 0);
      final seed = findSeed((s) {
        final (st, combat) = rivalEncounter(game,
            grudge: 2, temperament: RivalTemperament.honorable);
        final rng = Random(s);
        final session = ParleyDirector.open(combat, st, rng);
        final r = ParleyDirector.choose(
            session, combat, st, ParleyOption.plead, rng);
        return r.resolved;
      });

      final (st, combat) = rivalEncounter(game,
          grudge: 2, temperament: RivalTemperament.honorable);
      final rng = Random(seed);
      final session = ParleyDirector.open(combat, st, rng);
      final result = ParleyDirector.choose(
          session, combat, st, ParleyOption.plead, rng);
      expect(result.combat.outcome, CombatOutcome.departed);
      expect(result.game.rivals.first.grudge, 1); // mercy remembered
    });
  });

  group('Parley — police', () {
    test('comply round-trips through the real inspection: contraband busted',
        () {
      var game = newGame();
      game = game.copyWith(
        ship: game.ship
            .copyWith(cargo: {TradeGood.narcotics: 3, TradeGood.water: 2}),
        credits: 5000,
      );
      final combat = CombatState.begin(
          makeEncounter(type: EncounterType.police), game.ship);
      final session = ParleyDirector.open(combat, game, Random(3));
      final result = ParleyDirector.choose(
          session, combat, game, ParleyOption.comply, Random(3));

      expect(result.combat.outcome, CombatOutcome.inspectionBusted);
      expect(result.game.ship.cargo.containsKey(TradeGood.narcotics), isFalse);
      expect(result.game.ship.cargo[TradeGood.water], 2);
      expect(result.game.credits, lessThan(5000));
      expect(result.game.commander.policeRecordScore,
          game.commander.policeRecordScore - 5);
      expect(result.game.events.last.type, GameEventType.inspectionBusted);
    });

    test('comply with a clean hold improves the record', () {
      final game = newGame();
      final combat = CombatState.begin(
          makeEncounter(type: EncounterType.police), game.ship);
      final session = ParleyDirector.open(combat, game, Random(3));
      final result = ParleyDirector.choose(
          session, combat, game, ParleyOption.comply, Random(3));
      expect(result.combat.outcome, CombatOutcome.inspectionClean);
      expect(result.game.commander.policeRecordScore,
          game.commander.policeRecordScore + 1);
    });

    test('a bribe round-trips through the real bribery rules', () {
      var game = atSystemWhere(newGame(), (g) => g.bribeLevel > 0)
          .copyWith(credits: 10000);
      final combat = CombatState.begin(
          makeEncounter(type: EncounterType.police), game.ship);
      final session = ParleyDirector.open(combat, game, Random(3));
      final result = ParleyDirector.choose(
          session, combat, game, ParleyOption.payOff, Random(3));

      expect(result.combat.outcome, CombatOutcome.bribed);
      expect(result.game.credits, lessThan(10000));
      // Bribes stay off the public record.
      expect(result.game.events.last.type, GameEventType.policeBribed);
      expect(result.game.events.last.witnessed, isFalse);
    });

    test('too broke to bribe: the channel stays open, the option is gone',
        () {
      var game = atSystemWhere(newGame(), (g) => g.bribeLevel > 0)
          .copyWith(credits: 50);
      final combat = CombatState.begin(
          makeEncounter(type: EncounterType.police), game.ship);
      final session = ParleyDirector.open(combat, game, Random(3));
      expect(session.options, contains(ParleyOption.payOff));
      final result = ParleyDirector.choose(
          session, combat, game, ParleyOption.payOff, Random(3));

      expect(result.over, isFalse);
      expect(result.session.options, isNot(contains(ParleyOption.payOff)));
      expect(result.session.options, contains(ParleyOption.comply));
      expect(result.game.credits, 50);
    });

    test('bluffing the patrol: forged papers work or cost you the record',
        () {
      final game = newGame();
      var sawSuccess = false;
      var sawFailure = false;
      for (var seed = 0; seed < 300; seed++) {
        final combat = CombatState.begin(
            makeEncounter(type: EncounterType.police), game.ship);
        final rng = Random(seed);
        final session = ParleyDirector.open(combat, game, rng);
        final result = ParleyDirector.choose(
            session, combat, game, ParleyOption.bluff, rng);

        if (result.resolved) {
          sawSuccess = true;
          expect(result.combat.outcome, CombatOutcome.departed);
          expect(result.game.commander.policeRecordScore,
              game.commander.policeRecordScore);
        } else {
          sawFailure = true;
          expect(result.over, isFalse); // still just an inspection
          expect(result.game.commander.policeRecordScore,
              game.commander.policeRecordScore - 2);
          expect(result.session.options,
              isNot(contains(ParleyOption.bluff)));
          expect(result.session.options, contains(ParleyOption.comply));
        }
      }
      expect(sawSuccess, isTrue);
      expect(sawFailure, isTrue);
    });

    test('trading pirate intel waives the inspection and buffs the record',
        () {
      var game = newGame();
      game = game.copyWith(
          commander: game.commander.copyWith(pirateKills: 3));
      final combat = CombatState.begin(
          makeEncounter(type: EncounterType.police), game.ship);
      final session = ParleyDirector.open(combat, game, Random(3));
      final result = ParleyDirector.choose(
          session, combat, game, ParleyOption.tradeInfo, Random(3));

      expect(result.combat.outcome, CombatOutcome.departed);
      expect(result.game.commander.policeRecordScore,
          game.commander.policeRecordScore + 1);
    });
  });

  group('Parley — traders', () {
    test('a polite sign-off parts ways peacefully', () {
      final game = newGame();
      final combat = CombatState.begin(
          makeEncounter(type: EncounterType.trader), game.ship);
      final session = ParleyDirector.open(combat, game, Random(3));
      final result = ParleyDirector.choose(
          session, combat, game, ParleyOption.comply, Random(3));
      expect(result.combat.outcome, CombatOutcome.departed);
      expect(result.game.credits, game.credits);
    });

    test('selling intel pays when the pitch lands; flops keep talking', () {
      var game = newGame();
      game = game.copyWith(commander: game.commander.copyWith(trader: 5));
      var sawSale = false;
      var sawFlop = false;
      for (var seed = 0; seed < 200; seed++) {
        final combat = CombatState.begin(
            makeEncounter(type: EncounterType.trader), game.ship);
        final rng = Random(seed);
        final session = ParleyDirector.open(combat, game, rng);
        final result = ParleyDirector.choose(
            session, combat, game, ParleyOption.tradeInfo, rng);
        if (result.resolved) {
          sawSale = true;
          expect(result.combat.outcome, CombatOutcome.departed);
          expect(result.game.credits, greaterThan(game.credits));
        } else {
          sawFlop = true;
          expect(result.over, isFalse);
          expect(result.session.options,
              isNot(contains(ParleyOption.tradeInfo)));
        }
      }
      expect(sawSale, isTrue);
      expect(sawFlop, isTrue);
    });

    test('successful extortion seizes real cargo — and the victim talks', () {
      var game = newGame();
      game = game.copyWith(
          commander: game.commander
              .copyWith(fighter: 10, reputationScore: 400));

      final seed = findSeed((s) {
        final combat = CombatState.begin(
            makeEncounter(
                type: EncounterType.trader,
                cargo: {TradeGood.furs: 3},
                credits: 400),
            game.ship);
        final rng = Random(s);
        final session = ParleyDirector.open(combat, game, rng);
        return ParleyDirector.choose(
                session, combat, game, ParleyOption.threaten, rng)
            .resolved;
      });

      final combat = CombatState.begin(
          makeEncounter(
              type: EncounterType.trader,
              cargo: {TradeGood.furs: 3},
              credits: 400),
          game.ship);
      final rng = Random(seed);
      final session = ParleyDirector.open(combat, game, rng);
      final result = ParleyDirector.choose(
          session, combat, game, ParleyOption.threaten, rng);

      expect(result.combat.outcome, CombatOutcome.departed);
      expect(result.game.ship.cargo[TradeGood.furs], 3);
      expect(result.game.credits, game.credits + 400);
      expect(result.combat.npcCargo, isEmpty);
      expect(result.combat.npcCredits, 0);
      // Piracy has a price, even the talking kind.
      expect(result.game.commander.policeRecordScore,
          game.commander.policeRecordScore - 3);
      final event = result.game.events.last;
      expect(event.type, GameEventType.enemyEscaped);
      expect(event.witnessed, isTrue);
      expect(event.detail, 'extortion');
    });

    test('failed extortion sends the trader bolting, hostile and loud', () {
      var game = newGame();
      game = game.copyWith(commander: game.commander.copyWith(fighter: 0));

      final seed = findSeed((s) {
        final combat = CombatState.begin(
            makeEncounter(type: EncounterType.trader), game.ship);
        final rng = Random(s);
        final session = ParleyDirector.open(combat, game, rng);
        return ParleyDirector.choose(
                session, combat, game, ParleyOption.threaten, rng)
            .escalated;
      });

      final combat = CombatState.begin(
          makeEncounter(type: EncounterType.trader), game.ship);
      final rng = Random(seed);
      final session = ParleyDirector.open(combat, game, rng);
      final result = ParleyDirector.choose(
          session, combat, game, ParleyOption.threaten, rng);

      expect(result.combat.npcHostile, isTrue);
      expect(result.combat.npcFleeing, isTrue);
      expect(result.combat.outcome, CombatOutcome.ongoing);
      expect(result.game.commander.policeRecordScore,
          game.commander.policeRecordScore - 1);

      // Round-trip: letting the fleeing witness go records the escape.
      final departed = Combat.depart(result.combat, result.game)!;
      expect(departed.game.events.last.type, GameEventType.enemyEscaped);
      expect(departed.game.events.last.witnessed, isTrue);
    });
  });

  group('Parley — full headless conversations', () {
    test('every option in every session leaves consistent state', () {
      // Drive many complete parleys across all hailable encounter types
      // and assert the engine never wedges: the channel either stays
      // open with options, resolves the combat, or escalates it.
      for (final type in [
        EncounterType.pirate,
        EncounterType.police,
        EncounterType.trader,
      ]) {
        for (var seed = 0; seed < 60; seed++) {
          var game = newGame();
          game = game.copyWith(
              commander: game.commander.copyWith(pirateKills: 1));
          var combat = CombatState.begin(makeEncounter(type: type),
              game.ship);
          final rng = Random(seed);
          var session = ParleyDirector.open(combat, game, rng);

          var turns = 0;
          while (turns < 10) {
            expect(session.options, isNotEmpty);
            final option = session.options[rng.nextInt(
                session.options.length)];
            final result =
                ParleyDirector.choose(session, combat, game, option, rng);
            expect(result.session.transcript.length,
                greaterThan(session.transcript.length));
            session = result.session;
            combat = result.combat;
            game = result.game;
            if (result.over) {
              if (result.resolved) {
                expect(combat.isOver, isTrue);
              } else {
                expect(combat.outcome, CombatOutcome.ongoing);
              }
              break;
            }
            turns++;
          }
          expect(game.credits, greaterThanOrEqualTo(0));
          expect(game.ship.hullStrength, greaterThanOrEqualTo(1));
        }
      }
    });
  });
}
