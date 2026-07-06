// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/enums.dart';
import '../models/game_event.dart';
import '../models/game_state.dart';
import '../models/quest.dart';
import '../models/trade_item_def.dart';
import 'events.dart';
import 'travel.dart';

/// Trigger-table quest generation and lifecycle.
///
/// Design contract:
///  * Quests spawn from *conditions* over game state (plus dice), so the
///    galaxy appears to react to the player's situation.
///  * Stakes are locked at generation time — reward and failure penalties
///    live on the Quest object and never change afterwards.
///  * The narrative fields are canned templates today; the LLM layer will
///    generate them later from the same trigger context. Nothing in the
///    engine reads them.
class QuestSystem {
  QuestSystem._();

  /// Relief good demanded by each crisis status.
  static const Map<SystemStatus, TradeGood> reliefGood = {
    SystemStatus.plague: TradeGood.medicine,
    SystemStatus.drought: TradeGood.water,
    SystemStatus.cropFailure: TradeGood.food,
    SystemStatus.war: TradeGood.food,
    SystemStatus.cold: TradeGood.furs,
  };

  static const List<String> _giverNames = [
    'Dr. Imara Sel',
    'Broker Quent',
    'Sister Halloway',
    'Magistrate Voss',
    'Old Tenner',
    'The Dispatcher',
    'Captain Reyes',
    'Fixer Lume',
  ];

  /// Evaluate the trigger table on arrival at a system. Returns an updated
  /// state carrying a quest offer, or the state unchanged.
  ///
  /// Density rule: one story quest active at a time, one offer pending.
  static GameState evaluateTriggers(GameState state, Random rng) {
    if (state.activeQuest != null || state.questOffer != null) return state;

    // Drama director: the longer nothing has happened, the harder the
    // dice push toward *something* happening.
    final quietDays = EventLedger.daysSinceLastEvent(state);
    final pressure = min(30, quietDays * 3); // up to +30%

    // Trigger 1 — relief run: a reachable system is in crisis and the
    // matching relief good is buyable right here.
    final relief = _rollReliefRun(state, rng, pressure);
    if (relief != null) return state.copyWith(questOffer: relief);

    // Trigger 2 — the fixer: the player is wanted and their troubles have
    // been in the news. Dirty delivery, record laundered on success.
    final fixer = _rollFixerJob(state, rng, pressure);
    if (fixer != null) return state.copyWith(questOffer: fixer);

    // Trigger 3 — plain freight contract, mostly under drama pressure.
    final freight = _rollFreightContract(state, rng, pressure);
    if (freight != null) return state.copyWith(questOffer: freight);

    return state;
  }

  static Quest? _rollReliefRun(GameState state, Random rng, int pressure) {
    if (rng.nextInt(100) >= 45 + pressure) return null;

    final here = state.currentSystem;
    for (final entry in reliefGood.entries) {
      final good = entry.value;
      // The relief good must be buyable here (in stock, tradeable).
      if ((here.tradeQuantities[good] ?? 0) < 3) continue;
      final target = _findSystemWithStatus(state, entry.key, rng);
      if (target == null) continue;

      final qty = 3 + rng.nextInt(5);
      final def = TradeItemDef.forGood(good);
      final dist = Travel.distance(here, state.solarSystems[target]);
      final reward = _clampReward(
          qty * def.priceLowTech * 3 + (dist * 25).round() + 500);
      final deadline = state.days + _travelBudgetDays(dist) + 4;
      final targetName = state.solarSystems[target].name;
      final giver = _giverNames[rng.nextInt(_giverNames.length)];

      return Quest(
        id: 'q${state.days}_${rng.nextInt(1 << 20)}',
        template: QuestTemplate.delivery,
        status: QuestStatus.offered,
        title: 'MERCY RUN TO ${targetName.toUpperCase()}',
        hook: '$giver corners you at the docks: "${targetName} is dying of '
            '${entry.key.name} and the relief convoys won\'t touch the '
            'route. Get $qty units of ${good.displayName} there '
            'and you\'ll be paid — and remembered."',
        giverName: giver,
        successText: 'Dock workers unload your ${good.displayName} to '
            'cheers. $giver wires the payment.',
        failureText: 'The deadline passes. Whatever happened on '
            '$targetName, you weren\'t part of the answer.',
        good: good,
        qty: qty,
        targetSystemIndex: target,
        deadlineDay: deadline,
        rewardCredits: reward,
        rewardRecordBonus: 2, // aid work polishes your reputation with law
        failRecordPenalty: 0,
        failReputationPenalty: 2,
      );
    }
    return null;
  }

  static Quest? _rollFixerJob(GameState state, Random rng, int pressure) {
    if (state.commander.policeRecordScore > -10) return null;
    // Your troubles must be public knowledge for the fixer to find you.
    final publicTrouble = state.events.any((e) =>
        e.witnessed &&
        (e.type == GameEventType.inspectionBusted ||
            e.type == GameEventType.fledCombat ||
            e.type == GameEventType.playerShipLost));
    if (!publicTrouble) return null;
    if (rng.nextInt(100) >= 35 + pressure) return null;

    final here = state.currentSystem;
    final contraband =
        (here.tradeQuantities[TradeGood.firearms] ?? 0) >= 3
            ? TradeGood.firearms
            : (here.tradeQuantities[TradeGood.narcotics] ?? 0) >= 3
                ? TradeGood.narcotics
                : null;
    if (contraband == null) return null;

    final target = _findLawlessSystem(state, rng);
    if (target == null) return null;

    final qty = 3 + rng.nextInt(4);
    final def = TradeItemDef.forGood(contraband);
    final dist = Travel.distance(here, state.solarSystems[target]);
    final reward =
        _clampReward(qty * def.priceLowTech * 5 + (dist * 40).round() + 1500);
    final targetName = state.solarSystems[target].name;

    return Quest(
      id: 'q${state.days}_${rng.nextInt(1 << 20)}',
      template: QuestTemplate.delivery,
      status: QuestStatus.offered,
      title: 'THE FIXER\'S ERRAND',
      hook: 'A voice from a shadowed booth: "You\'ve made the feeds, friend '
          '— for all the wrong reasons. Run $qty units of '
          '${contraband.displayName} to $targetName, no questions, and '
          'I\'ll see certain records... misplaced."',
      giverName: 'Fixer Lume',
      successText: 'The cargo vanishes into the underworld of '
          '$targetName. Days later, your file is mysteriously thinner.',
      failureText: 'The fixer\'s people don\'t send reminders. They just '
          'stop answering — and start talking.',
      good: contraband,
      qty: qty,
      targetSystemIndex: target,
      deadlineDay: state.days + _travelBudgetDays(dist) + 3,
      rewardCredits: reward,
      rewardRecordBonus: 8, // the record laundering is the real payment
      failRecordPenalty: 3, // they leak what you did
      failReputationPenalty: 0,
    );
  }

  static Quest? _rollFreightContract(GameState state, Random rng, int pressure) {
    if (rng.nextInt(100) >= 15 + pressure) return null;
    return freightContract(state, rng);
  }

  /// A plain freight contract with no dice gate — also used as the quest
  /// seeded by a derelict's recovered manifest.
  static Quest? freightContract(GameState state, Random rng) {
    final here = state.currentSystem;
    // Pick a good that's actually in stock here.
    final stocked = TradeGood.values
        .where((g) => (here.tradeQuantities[g] ?? 0) >= 4)
        .toList();
    if (stocked.isEmpty) return null;
    final good = stocked[rng.nextInt(stocked.length)];

    final target = _randomOtherSystem(state, rng);
    if (target == null) return null;

    final qty = 4 + rng.nextInt(5);
    final def = TradeItemDef.forGood(good);
    final dist = Travel.distance(here, state.solarSystems[target]);
    final reward =
        _clampReward(qty * def.priceLowTech * 2 + (dist * 20).round() + 300);
    final targetName = state.solarSystems[target].name;
    final giver = _giverNames[rng.nextInt(_giverNames.length)];

    return Quest(
      id: 'q${state.days}_${rng.nextInt(1 << 20)}',
      template: QuestTemplate.delivery,
      status: QuestStatus.offered,
      title: 'FREIGHT CONTRACT: ${targetName.toUpperCase()}',
      hook: '$giver needs $qty units of ${good.displayName} moved to '
          '$targetName, and the usual haulers are booked solid. '
          'Standard rates, standard deadline, no drama. Probably.',
      giverName: giver,
      successText: 'Cargo delivered, manifest signed, credits transferred. '
          'Clean work.',
      failureText: 'The contract lapses. $giver quietly blacklists you '
          'with the freight guild.',
      good: good,
      qty: qty,
      targetSystemIndex: target,
      deadlineDay: state.days + _travelBudgetDays(dist) + 4,
      rewardCredits: reward,
      failRecordPenalty: 0,
      failReputationPenalty: 1,
    );
  }

  // --- lifecycle ---

  static GameState accept(GameState state) {
    final offer = state.questOffer;
    if (offer == null) return state;
    var next = state.copyWith(
      activeQuest: offer.copyWith(status: QuestStatus.active),
      questOffer: null,
    );
    next = EventLedger.record(next, GameEventType.questAccepted,
        witnessed: false, detail: offer.title);
    return next;
  }

  static GameState decline(GameState state) =>
      state.copyWith(questOffer: null);

  /// Call on every arrival: resolves completion, deadline failure, and
  /// expires stale offers. Returns state + the resolved quest (for UI).
  static (GameState, Quest?) checkProgress(GameState state) {
    var next = state;
    Quest? resolved;

    // Offers don't follow you off-world.
    if (next.questOffer != null) {
      next = next.copyWith(questOffer: null);
    }

    final quest = next.activeQuest;
    if (quest == null) return (next, null);

    final delivered = next.currentSystemIndex == quest.targetSystemIndex &&
        (next.ship.cargo[quest.good] ?? 0) >= quest.qty;

    if (delivered && next.days <= quest.deadlineDay) {
      final cargo = Map<TradeGood, int>.from(next.ship.cargo);
      final remaining = cargo[quest.good]! - quest.qty;
      if (remaining <= 0) {
        cargo.remove(quest.good);
      } else {
        cargo[quest.good] = remaining;
      }
      next = next.copyWith(
        ship: next.ship.copyWith(cargo: cargo),
        credits: next.credits + quest.rewardCredits,
        commander: next.commander.copyWith(
          policeRecordScore:
              next.commander.policeRecordScore + quest.rewardRecordBonus,
        ),
        activeQuest: null,
      );
      next = EventLedger.record(next, GameEventType.questCompleted,
          witnessed: true, detail: quest.title);
      resolved = quest.copyWith(status: QuestStatus.completed);
    } else if (next.days > quest.deadlineDay) {
      next = next.copyWith(
        commander: next.commander.copyWith(
          policeRecordScore:
              next.commander.policeRecordScore - quest.failRecordPenalty,
          reputationScore: max(0,
              next.commander.reputationScore - quest.failReputationPenalty),
        ),
        activeQuest: null,
      );
      next = EventLedger.record(next, GameEventType.questFailed,
          witnessed: true, detail: quest.title);
      resolved = quest.copyWith(status: QuestStatus.failed);
    }

    return (next, resolved);
  }

  // --- helpers ---

  static int _travelBudgetDays(double dist) =>
      max(3, (dist / 15).ceil() * 2 + 2);

  static int _clampReward(int reward) => reward.clamp(200, 25000);

  static int? _findSystemWithStatus(
      GameState state, SystemStatus status, Random rng) {
    final candidates = <int>[];
    for (var i = 0; i < state.solarSystems.length; i++) {
      if (i == state.currentSystemIndex) continue;
      if (state.solarSystems[i].status == status) candidates.add(i);
    }
    if (candidates.isEmpty) return null;
    // Prefer somewhere near-ish so deadlines feel fair.
    candidates.sort((a, b) => Travel.distance(
            state.currentSystem, state.solarSystems[a])
        .compareTo(
            Travel.distance(state.currentSystem, state.solarSystems[b])));
    final pool = candidates.take(4).toList();
    return pool[rng.nextInt(pool.length)];
  }

  static int? _findLawlessSystem(GameState state, Random rng) {
    final candidates = <int>[];
    for (var i = 0; i < state.solarSystems.length; i++) {
      if (i == state.currentSystemIndex) continue;
      final gov = state.solarSystems[i].government;
      if (gov == GovernmentType.anarchy ||
          gov == GovernmentType.feudalState ||
          gov == GovernmentType.dictatorship) {
        candidates.add(i);
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => Travel.distance(
            state.currentSystem, state.solarSystems[a])
        .compareTo(
            Travel.distance(state.currentSystem, state.solarSystems[b])));
    final pool = candidates.take(4).toList();
    return pool[rng.nextInt(pool.length)];
  }

  static int? _randomOtherSystem(GameState state, Random rng) {
    // A near-ish random destination (within the closest 15).
    final indices = List<int>.generate(state.solarSystems.length, (i) => i)
      ..remove(state.currentSystemIndex)
      ..sort((a, b) => Travel.distance(
              state.currentSystem, state.solarSystems[a])
          .compareTo(
              Travel.distance(state.currentSystem, state.solarSystems[b])));
    final pool = indices.take(15).toList();
    if (pool.isEmpty) return null;
    return pool[rng.nextInt(pool.length)];
  }
}
