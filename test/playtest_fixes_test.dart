import 'package:flutter_test/flutter_test.dart';

import 'package:darknova2/engine/game_engine.dart';
import 'package:darknova2/engine/news.dart';
import 'package:darknova2/engine/travel.dart';
import 'package:darknova2/models/enums.dart';
import 'package:darknova2/models/game_state.dart';

GameState newGame() => GameEngine.newGame('Tester', DifficultyLevel.normal);

/// Find a system that has a wormhole and return (index, partnerIndex).
(int, int) findWormhole(GameState state) {
  for (var i = 0; i < state.solarSystems.length; i++) {
    final ev = state.solarSystems[i].specialEvent;
    if (ev != null && ev >= 1000) return (i, ev - 1000);
  }
  fail('galaxy has no wormholes');
}

void main() {
  group('Wormholes', () {
    test('partner transit is free and always in range', () {
      var state = newGame();
      final (from, to) = findWormhole(state);
      state = state.copyWith(
        currentSystemIndex: from,
        ship: state.ship.copyWith(fuel: 0), // tank empty
      );
      expect(
          Travel.fuelCostIndexed(state.solarSystems, from, to, state.ship),
          0);
      expect(
          Travel.canReachIndexed(state.solarSystems, from, to, state.ship),
          isTrue);
      expect(Travel.inRangeIndices(from, state.solarSystems, state.ship),
          contains(to));
    });

    test('warpTo executes a wormhole jump on an empty tank', () {
      var state = newGame();
      final (from, to) = findWormhole(state);
      state = state.copyWith(
        currentSystemIndex: from,
        ship: state.ship.copyWith(fuel: 0),
      );
      final next = Travel.warpTo(state, to);
      expect(next.currentSystemIndex, to);
      expect(next.ship.fuel, 0); // free transit consumed nothing
      expect(next.days, state.days + 1);
    });
  });

  group('Sell all cargo', () {
    test('sells everything sellable, keeps the rest, banks the credits', () {
      var state = newGame();
      // Sol is a democracy: narcotics are contraband and unsellable there.
      state = state.copyWith(
        ship: state.ship.copyWith(
          cargo: {TradeGood.water: 5, TradeGood.narcotics: 2},
        ),
      );
      final (next, gained) = GameEngine.sellAllCargo(state);
      expect(gained, greaterThan(0));
      expect(next.credits, state.credits + gained);
      expect(next.ship.cargo.containsKey(TradeGood.water), isFalse);
      expect(next.ship.cargo[TradeGood.narcotics], 2);
    });

    test('empty hold sells nothing', () {
      final state = newGame();
      final (next, gained) = GameEngine.sellAllCargo(state);
      expect(gained, 0);
      expect(next.credits, state.credits);
    });
  });

  group('News balance', () {
    test('headlines are deterministic within a day and change across days',
        () {
      final state = newGame();
      expect(NewsEngine.headlines(state), NewsEngine.headlines(state));
      final tomorrow = state.copyWith(days: state.days + 1);
      // Different day reshuffles filler — the feeds should diverge.
      expect(NewsEngine.headlines(state),
          isNot(equals(NewsEngine.headlines(tomorrow))));
    });

    test('crisis coverage is capped, not a full scan', () {
      var state = newGame();
      // Put every other system in crisis: an oracle would list them all.
      final systems = state.solarSystems
          .map((s) => s.copyWith(status: SystemStatus.plague))
          .toList();
      systems[state.currentSystemIndex] = systems[state.currentSystemIndex]
          .copyWith(status: SystemStatus.uneventful);
      state = state.copyWith(solarSystems: systems);

      final lines = NewsEngine.headlines(state);
      final crisisLines =
          lines.where((l) => l.contains('PLAGUE')).length;
      expect(crisisLines,
          lessThanOrEqualTo(NewsEngine.maxCrisisHeadlines));
      expect(lines.length, NewsEngine.maxHeadlines); // padded with filler
    });

    test('a nearby crisis is a lead, not a guarantee', () {
      var base = newGame();
      final systems = base.solarSystems
          .map((s) => s.copyWith(status: SystemStatus.uneventful))
          .toList();
      final idx = (base.currentSystemIndex + 1) % systems.length;
      systems[idx] = systems[idx].copyWith(status: SystemStatus.plague);
      base = base.copyWith(solarSystems: systems);

      var covered = 0;
      const daysSampled = 40;
      for (var d = 0; d < daysSampled; d++) {
        final lines =
            NewsEngine.headlines(base.copyWith(days: base.days + d));
        if (lines.any((l) => l.contains('PLAGUE'))) covered++;
      }
      // Reported sometimes (it's news) but not every day (it's not radar).
      expect(covered, greaterThan(0));
      expect(covered, lessThan(daysSampled));
    });
  });
}
