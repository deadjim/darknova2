// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/commander.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/ship.dart';
import '../models/ship_type_def.dart';
import '../models/solar_system.dart';
import 'economy.dart';
import 'encounter.dart';
import 'galaxy_generator.dart';
import 'rivals.dart';
import 'travel.dart';

class GameEngine {
  const GameEngine._();

  /// Create a new game with the given commander name and difficulty.
  static GameState newGame(String commanderName, DifficultyLevel difficulty) {
    // Distribute skill points.
    final skillPoints = difficulty.startingSkillPoints;
    // Default distribution: even spread, remainder to pilot.
    final base = skillPoints ~/ 4;
    final extra = skillPoints - base * 4;
    final commander = Commander.starter(
      commanderName,
      base + extra, // pilot gets extras
      base,
      base,
      base,
    );

    final ship = Ship.starter();
    final seed = Random().nextInt(1 << 30);
    final systems = GalaxyGenerator.generate(seed, difficulty);

    final startIndex = GalaxyGenerator.solIndex;
    final startSystem = systems[startIndex];

    // Mark Sol as visited.
    final updatedSystems = List<SolarSystem>.from(systems);
    updatedSystems[startIndex] =
        updatedSystems[startIndex].copyWith(visited: true);

    final buyPrices = Economy.systemBuyPrices(startSystem, commander);
    final sellPrices = Economy.systemSellPrices(startSystem, commander);

    return GameState(
      commander: commander,
      ship: ship,
      credits: difficulty.startingCredits,
      debt: difficulty.startingDebt,
      days: 0,
      currentSystemIndex: startIndex,
      galaxySeed: seed,
      difficulty: difficulty,
      solarSystems: updatedSystems,
      buyPrices: buyPrices,
      sellPrices: sellPrices,
      escapePod: false,
      insurance: false,
      noClaim: 0,
      rivals: RivalSystem.generate(seed),
    );
  }

  /// Warp to a target system.
  static GameState warpTo(GameState state, int targetIndex) {
    return Travel.warpTo(state, targetIndex);
  }

  /// Roll for an encounter at the current system (call after a warp).
  /// Returns null when the trip is uneventful. Pirate encounters are
  /// sometimes promoted into named-rival encounters.
  static EncounterResult? rollEncounter(GameState state, [Random? random]) {
    final rng = random ?? Random();
    final type = Encounter.rollEncounter(
        state.currentSystem, state.commander, state.difficulty);
    if (type == null) return null;

    if (type == EncounterType.pirate) {
      final rival = RivalSystem.pickRival(state, rng);
      if (rival != null) {
        return Encounter.generateEncounter(
          type,
          state.currentSystem,
          state.difficulty,
          forceShipType: RivalSystem.escalatedHull(rival),
          rivalId: rival.id,
          captainName: rival.name,
        );
      }
    }
    return Encounter.generateEncounter(
        type, state.currentSystem, state.difficulty);
  }

  /// Buy a trade good. Returns updated state or null if transaction invalid.
  static GameState? buyGood(GameState state, TradeGood good, int quantity) {
    final system = state.currentSystem;
    if (!Economy.canTradeGood(system, good)) return null;

    final priceEach = state.buyPrices[good] ?? 0;
    if (priceEach == 0) return null;

    final totalCost = priceEach * quantity;
    if (state.credits < totalCost) return null;
    if (state.ship.availableCargoBays < quantity) return null;

    final available = system.tradeQuantities[good] ?? 0;
    if (available < quantity) return null;

    // Update ship cargo.
    final newCargo = Map<TradeGood, int>.from(state.ship.cargo);
    newCargo[good] = (newCargo[good] ?? 0) + quantity;
    final newShip = state.ship.copyWith(cargo: newCargo);

    // Update system quantities.
    final updatedSystems = List<SolarSystem>.from(state.solarSystems);
    final idx = state.currentSystemIndex;
    final currentQty = Map<TradeGood, int>.from(
        updatedSystems[idx].tradeQuantities);
    currentQty[good] = (currentQty[good] ?? 0) - quantity;
    updatedSystems[idx] =
        updatedSystems[idx].copyWith(tradeQuantities: currentQty);

    return state.copyWith(
      ship: newShip,
      credits: state.credits - totalCost,
      solarSystems: updatedSystems,
    );
  }

  /// Sell a trade good. Returns updated state or null if transaction invalid.
  static GameState? sellGood(GameState state, TradeGood good, int quantity) {
    final system = state.currentSystem;
    if (!Economy.canTradeGood(system, good)) return null;

    final inCargo = state.ship.cargo[good] ?? 0;
    if (inCargo < quantity) return null;

    final priceEach = state.sellPrices[good] ?? 0;
    if (priceEach == 0) return null;

    final totalRevenue = priceEach * quantity;

    // Update ship cargo.
    final newCargo = Map<TradeGood, int>.from(state.ship.cargo);
    final newQty = (newCargo[good] ?? 0) - quantity;
    if (newQty <= 0) {
      newCargo.remove(good);
    } else {
      newCargo[good] = newQty;
    }
    final newShip = state.ship.copyWith(cargo: newCargo);

    // Update system quantities.
    final updatedSystems = List<SolarSystem>.from(state.solarSystems);
    final idx = state.currentSystemIndex;
    final currentQty = Map<TradeGood, int>.from(
        updatedSystems[idx].tradeQuantities);
    currentQty[good] = (currentQty[good] ?? 0) + quantity;
    updatedSystems[idx] =
        updatedSystems[idx].copyWith(tradeQuantities: currentQty);

    // Police record penalty for selling illegal goods.
    var newCommander = state.commander;
    if (Economy.isIllegal(system, good)) {
      newCommander = newCommander.copyWith(
        policeRecordScore: newCommander.policeRecordScore - 2,
      );
    }

    return state.copyWith(
      commander: newCommander,
      ship: newShip,
      credits: state.credits + totalRevenue,
      solarSystems: updatedSystems,
    );
  }

  /// Buy a new ship. Returns updated state or null if invalid.
  static GameState? buyShip(GameState state, ShipType shipType) {
    final system = state.currentSystem;
    final def = ShipTypeDef.forType(shipType);

    if (system.techLevel < def.minTechLevel) return null;

    // Trade-in value of current ship = 50% of price minus repairs.
    final currentDef = state.ship.def;
    final tradeIn = currentDef.price ~/ 2;
    final newShipCost = def.price - tradeIn;

    if (state.credits < newShipCost) return null;

    // New ship starts with full fuel and hull; player keeps weapons/shields
    // that fit in the new ship's slots (extras are lost).
    final newWeapons = state.ship.weapons
        .take(def.weaponSlots)
        .toList();
    final newShields = state.ship.shields
        .take(def.shieldSlots)
        .toList();
    final newGadgets = state.ship.gadgets
        .take(def.gadgetSlots)
        .toList();

    // Cargo that doesn't fit is lost (sold at half price).
    int cargoRefund = 0;
    final oldCargo = Map<TradeGood, int>.from(state.ship.cargo);
    final newCargo = <TradeGood, int>{};
    int spaceLeft = def.cargoBays;
    for (final entry in oldCargo.entries) {
      if (spaceLeft >= entry.value) {
        newCargo[entry.key] = entry.value;
        spaceLeft -= entry.value;
      } else if (spaceLeft > 0) {
        newCargo[entry.key] = spaceLeft;
        cargoRefund +=
            (entry.value - spaceLeft) * (state.sellPrices[entry.key] ?? 0) ~/ 2;
        spaceLeft = 0;
      } else {
        cargoRefund +=
            entry.value * (state.sellPrices[entry.key] ?? 0) ~/ 2;
      }
    }

    final newShip = Ship(
      shipType: shipType,
      cargo: newCargo,
      weapons: newWeapons,
      shields: newShields,
      gadgets: newGadgets,
      crew: 0,
      fuel: def.maxFuel,
      hullStrength: def.hullStrength,
      tribbles: state.ship.tribbles,
    );

    return state.copyWith(
      ship: newShip,
      credits: state.credits - newShipCost + cargoRefund,
    );
  }

  /// Buy a weapon. Returns updated state or null if invalid.
  static GameState? buyWeapon(GameState state, WeaponType weapon) {
    if (!state.ship.canAddWeapon()) return null;
    if (state.currentSystem.techLevel < weapon.minTechLevel) return null;
    if (state.credits < weapon.price) return null;

    final newWeapons = List<WeaponType>.from(state.ship.weapons)..add(weapon);
    final newShip = state.ship.copyWith(weapons: newWeapons);
    return state.copyWith(
        ship: newShip, credits: state.credits - weapon.price);
  }

  /// Sell a weapon back for 50% of its price.
  static GameState? sellWeapon(GameState state, WeaponType weapon) {
    final weapons = List<WeaponType>.from(state.ship.weapons);
    if (!weapons.remove(weapon)) return null;
    final newShip = state.ship.copyWith(weapons: weapons);
    return state.copyWith(
        ship: newShip, credits: state.credits + weapon.price ~/ 2);
  }

  /// Buy a shield. Returns updated state or null if invalid.
  static GameState? buyShield(GameState state, ShieldType shield) {
    if (!state.ship.canAddShield()) return null;
    if (state.currentSystem.techLevel < shield.minTechLevel) return null;
    if (state.credits < shield.price) return null;

    final newShields = List<ShieldType>.from(state.ship.shields)..add(shield);
    final newShip = state.ship.copyWith(shields: newShields);
    return state.copyWith(
        ship: newShip, credits: state.credits - shield.price);
  }

  /// Sell a shield back for 50% of its price.
  static GameState? sellShield(GameState state, ShieldType shield) {
    final shields = List<ShieldType>.from(state.ship.shields);
    if (!shields.remove(shield)) return null;
    final newShip = state.ship.copyWith(shields: shields);
    return state.copyWith(
        ship: newShip, credits: state.credits + shield.price ~/ 2);
  }

  /// Buy a gadget. Returns updated state or null if invalid.
  static GameState? buyGadget(GameState state, GadgetType gadget) {
    if (!state.ship.canAddGadget()) return null;
    if (state.currentSystem.techLevel < gadget.minTechLevel) return null;
    if (state.credits < gadget.price) return null;

    final newGadgets = List<GadgetType>.from(state.ship.gadgets)..add(gadget);
    final newShip = state.ship.copyWith(gadgets: newGadgets);
    return state.copyWith(
        ship: newShip, credits: state.credits - gadget.price);
  }

  /// Sell a gadget back for 50% of its price.
  static GameState? sellGadget(GameState state, GadgetType gadget) {
    final gadgets = List<GadgetType>.from(state.ship.gadgets);
    if (!gadgets.remove(gadget)) return null;
    final newShip = state.ship.copyWith(gadgets: gadgets);
    return state.copyWith(
        ship: newShip, credits: state.credits + gadget.price ~/ 2);
  }

  /// Refuel the ship. Quantity is fuel units to add.
  static GameState? buyFuel(GameState state, int units) {
    final ship = state.ship;
    final fuelNeeded = ship.maxFuel - ship.fuel;
    final actualUnits = units.clamp(0, fuelNeeded);
    if (actualUnits == 0) return null;

    final cost = actualUnits * ship.def.costOfFuel;
    if (state.credits < cost) return null;

    final newShip = ship.copyWith(fuel: ship.fuel + actualUnits);
    return state.copyWith(
        ship: newShip, credits: state.credits - cost);
  }

  /// Repair hull. Cost per point is repairCosts from ship def.
  static GameState? repairHull(GameState state, int points) {
    final ship = state.ship;
    final repairablePoints = ship.maxHullStrength - ship.hullStrength;
    final actualPoints = points.clamp(0, repairablePoints);
    if (actualPoints == 0) return null;

    final cost = actualPoints * ship.def.repairCosts;
    if (state.credits < cost) return null;

    final newShip = ship.copyWith(
        hullStrength: ship.hullStrength + actualPoints);
    return state.copyWith(
        ship: newShip, credits: state.credits - cost);
  }

  /// Pay down some debt.
  static GameState? payDebt(GameState state, int amount) {
    if (amount <= 0) return null;
    if (state.credits < amount) return null;
    final actual = amount.clamp(0, state.debt);
    if (actual == 0) return null;
    return state.copyWith(
      credits: state.credits - actual,
      debt: state.debt - actual,
    );
  }

  /// Buy escape pod.
  static GameState? buyEscapePod(GameState state) {
    const price = 2000;
    if (state.escapePod) return null;
    if (state.credits < price) return null;
    return state.copyWith(
        escapePod: true, credits: state.credits - price);
  }

  /// Buy insurance.
  static GameState? buyInsurance(GameState state) {
    const price = 500;
    if (state.insurance) return null;
    if (!state.escapePod) return null; // need escape pod first
    if (state.credits < price) return null;
    return state.copyWith(
        insurance: true, credits: state.credits - price);
  }

  /// Sell every unit of every sellable good in the hold at current
  /// prices. Returns the new state and the credits gained (0 if nothing
  /// could be sold — untradeable goods stay aboard).
  static (GameState, int) sellAllCargo(GameState state) {
    var next = state;
    for (final entry in Map<TradeGood, int>.from(state.ship.cargo).entries) {
      final sold = sellGood(next, entry.key, entry.value);
      if (sold != null) next = sold;
    }
    return (next, next.credits - state.credits);
  }

  /// Refresh trade prices for the current system (call after visiting).
  static GameState refreshPrices(GameState state) {
    final system = state.currentSystem;
    final buyPrices = Economy.systemBuyPrices(system, state.commander);
    final sellPrices = Economy.systemSellPrices(system, state.commander);
    return state.copyWith(buyPrices: buyPrices, sellPrices: sellPrices);
  }
}
