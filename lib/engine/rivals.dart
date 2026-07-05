// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/rival.dart';

class RivalSystem {
  RivalSystem._();

  static const int rivalCount = 8;

  static const List<String> _names = [
    'Vex Marrow',
    'Callista Brand',
    'Ondrej "Hollowpoint" Kesh',
    'Mirelle Vance',
    'Dredgen Tycho',
    'Sable Okonkwo',
    'Ratchet Faulke',
    'Ilsa Vray',
    'Corvus Nine',
    'Amara Deshai',
    'Bloodless Roan',
    'Petra Wilde',
    'The Cartographer',
    'Juno Ashfall',
    'Kellan Mott',
    'Widow Sarn',
  ];

  static const List<ShipType> _starterHulls = [
    ShipType.gnat,
    ShipType.firefly,
    ShipType.mosquito,
    ShipType.bumblebee,
  ];

  /// Deterministically seed a galaxy's cast of rival captains.
  static List<RivalCaptain> generate(int galaxySeed) {
    final rng = Random(galaxySeed ^ 0x5152);
    final names = List<String>.from(_names)..shuffle(rng);
    return List.generate(rivalCount, (i) {
      return RivalCaptain(
        id: 'rival_$i',
        name: names[i],
        shipType: _starterHulls[rng.nextInt(_starterHulls.length)],
        temperament: RivalTemperament
            .values[rng.nextInt(RivalTemperament.values.length)],
        timesMet: 0,
        timesSpared: 0,
        grudge: 0,
        alive: true,
        lastSeenDay: 0,
      );
    });
  }

  /// Spared rivals come back meaner: hull class escalates with each escape.
  static ShipType escalatedHull(RivalCaptain rival) {
    final idx = min(rival.shipType.index + rival.timesSpared,
        ShipType.values.length - 1);
    return ShipType.values[idx];
  }

  /// Maybe promote a pirate encounter into a rival encounter.
  /// Grudge-bearing rivals hunt the player harder.
  static RivalCaptain? pickRival(GameState state, Random rng) {
    final living = state.rivals.where((r) => r.alive).toList();
    if (living.isEmpty) return null;
    // Base 30% chance, +5% per point of the angriest grudge (cap 60%).
    final maxGrudge =
        living.map((r) => r.grudge).reduce(max).clamp(0, 6).toInt();
    final chance = 30 + maxGrudge * 5;
    if (rng.nextInt(100) >= chance) return null;
    // Weight selection toward grudge-holders.
    final weights = living.map((r) => 1 + max(0, r.grudge)).toList()
        .cast<int>();
    final total = weights.reduce((a, b) => a + b);
    var roll = rng.nextInt(total);
    for (var i = 0; i < living.length; i++) {
      roll -= weights[i];
      if (roll < 0) return living[i];
    }
    return living.last;
  }

  static GameState updateRival(
      GameState state, String rivalId, RivalCaptain Function(RivalCaptain) fn) {
    final rivals = state.rivals
        .map((r) => r.id == rivalId ? fn(r) : r)
        .toList();
    return state.copyWith(rivals: rivals);
  }

  /// Bookkeeping when an encounter with a rival begins.
  static GameState markMet(GameState state, String rivalId) {
    return updateRival(
        state,
        rivalId,
        (r) => r.copyWith(
            timesMet: r.timesMet + 1, lastSeenDay: state.days));
  }
}
