// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/ship.dart';
import '../models/solar_system.dart';
import 'economy.dart';

class Travel {
  Travel._();

  /// Euclidean distance between two systems.
  static double distance(SolarSystem a, SolarSystem b) {
    final dx = (a.x - b.x).toDouble();
    final dy = (a.y - b.y).toDouble();
    return sqrt(dx * dx + dy * dy);
  }

  /// Fuel cost to travel from one system to another.
  /// Cost = ceil(distance / (ship fuelTanks / 2)), minimum 1.
  /// Ships with Navigating System use 10% less fuel.
  static int fuelCost(SolarSystem from, SolarSystem to, Ship ship) {
    final dist = distance(from, to);
    // Each fuel unit covers (fuelTanks) parsecs (tank range for simplicity).
    const double parsecPerFuelUnit = 2.0;
    double multiplier = 1.0;
    if (ship.hasGadget(GadgetType.navigatingSystem)) {
      multiplier = 0.9;
    }
    return max(1, (dist / parsecPerFuelUnit * multiplier).ceil());
  }

  /// Whether the ship has enough fuel to reach the target system.
  static bool canReach(SolarSystem from, SolarSystem to, Ship ship) {
    return ship.fuel >= fuelCost(from, to, ship);
  }

  /// Is [targetIndex] the wormhole partner of [from]? Wormhole transit is
  /// free regardless of distance or fuel.
  static bool isWormholePartner(SolarSystem from, int targetIndex) {
    return from.specialEvent != null &&
        from.specialEvent! >= 1000 &&
        from.specialEvent! - 1000 == targetIndex;
  }

  /// Fuel cost between two systems by index — wormhole-aware.
  static int fuelCostIndexed(
      List<SolarSystem> all, int fromIndex, int toIndex, Ship ship) {
    if (isWormholePartner(all[fromIndex], toIndex)) return 0;
    return fuelCost(all[fromIndex], all[toIndex], ship);
  }

  /// Reachability by index — wormhole-aware.
  static bool canReachIndexed(
      List<SolarSystem> all, int fromIndex, int toIndex, Ship ship) {
    return ship.fuel >= fuelCostIndexed(all, fromIndex, toIndex, ship);
  }

  /// All systems reachable from the given system with current fuel.
  static List<SolarSystem> inRange(
      SolarSystem from, List<SolarSystem> all, Ship ship) {
    return all
        .where((s) => s != from && canReach(from, s, ship))
        .toList();
  }

  /// Indices of reachable systems, including the wormhole partner (free).
  static List<int> inRangeIndices(
      int fromIndex, List<SolarSystem> all, Ship ship) {
    final from = all[fromIndex];
    final result = <int>[];
    for (int i = 0; i < all.length; i++) {
      if (i == fromIndex) continue;
      if (isWormholePartner(from, i) || canReach(from, all[i], ship)) {
        result.add(i);
      }
    }
    return result;
  }

  /// Execute a warp to the target system.
  /// Returns a new GameState with:
  ///   - fuel reduced by travel cost
  ///   - days advanced by 1
  ///   - current system updated
  ///   - target system marked as visited
  ///   - trade quantities updated (slow drift)
  ///   - encounter rolled (stored in state via warpTargetIndex clearing)
  static GameState warpTo(GameState state, int targetIndex) {
    final from = state.currentSystem;
    final ship = state.ship;
    // Wormhole transit is free — check it before the fuel gate, or a
    // partner beyond fuel range would be wrongly unreachable.
    final cost =
        fuelCostIndexed(state.solarSystems, state.currentSystemIndex,
            targetIndex, ship);

    if (ship.fuel < cost) {
      // Not enough fuel — return unchanged.
      return state;
    }

    final newShip = ship.copyWith(fuel: ship.fuel - cost);

    // Mark target visited.
    final updatedSystems = List<SolarSystem>.from(state.solarSystems);
    updatedSystems[targetIndex] =
        updatedSystems[targetIndex].copyWith(visited: true);

    // Update trade quantities (slow drift on all systems).
    final driftedSystems = Economy.updateQuantities(updatedSystems);

    // Auto-repair from Engineer gadget.
    final autoRepaired = _autoRepair(newShip, state.commander.engineer);

    // Advance the day.
    final newDays = state.days + 1;

    // Accrue interest on debt (1% per day).
    final newDebt =
        state.debt > 0 ? (state.debt * 1.01).ceil() : state.debt;

    // Recalculate trade prices for the new system.
    final to = state.solarSystems[targetIndex];
    final newBuyPrices =
        Economy.systemBuyPrices(to, state.commander);
    final newSellPrices =
        Economy.systemSellPrices(to, state.commander);

    return state.copyWith(
      ship: autoRepaired,
      currentSystemIndex: targetIndex,
      days: newDays,
      debt: newDebt,
      solarSystems: driftedSystems,
      warpTargetIndex: null,
      buyPrices: newBuyPrices,
      sellPrices: newSellPrices,
    );
  }

  static Ship _autoRepair(Ship ship, int engineerSkill) {
    if (!ship.hasGadget(GadgetType.autoRepairSystem)) return ship;
    // Repair 1 + engineerSkill/5 hull points per jump.
    final repairAmount = 1 + (engineerSkill / 5).floor();
    final newHull =
        (ship.hullStrength + repairAmount).clamp(0, ship.maxHullStrength);
    return ship.copyWith(hullStrength: newHull);
  }

  /// Maximum range of a ship in parsecs (displayed on map).
  /// A Navigating System stretches each fuel unit 10% further.
  static double maxRange(Ship ship) {
    final base = ship.fuel * 2.0;
    return ship.hasGadget(GadgetType.navigatingSystem) ? base / 0.9 : base;
  }
}
