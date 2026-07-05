// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/commander.dart';
import '../models/enums.dart';
import '../models/government_def.dart';
import '../models/ship_type_def.dart';
import '../models/solar_system.dart';

class EncounterResult {
  final EncounterType type;
  final NpcShip npcShip;
  final bool npcFleeing;
  final String? rivalId; // set when this encounter is a named rival
  final String? captainName;

  const EncounterResult({
    required this.type,
    required this.npcShip,
    required this.npcFleeing,
    this.rivalId,
    this.captainName,
  });
}

class NpcShip {
  final ShipType shipType;
  final List<WeaponType> weapons;
  final List<ShieldType> shields;
  final int hullStrength;
  final int currentHull;
  final Map<TradeGood, int> cargo; // what it carries (loot if destroyed)
  final int credits; // bounty / credits if boarded

  const NpcShip({
    required this.shipType,
    required this.weapons,
    required this.shields,
    required this.hullStrength,
    required this.currentHull,
    required this.cargo,
    required this.credits,
  });

  ShipTypeDef get def => ShipTypeDef.forType(shipType);

  int get totalWeaponPower {
    int total = 0;
    for (final w in weapons) {
      total += w.power;
    }
    return total;
  }

  int get totalShieldStrength {
    int total = 0;
    for (final s in shields) {
      total += s.strength;
    }
    return total;
  }
}

class Encounter {
  Encounter._();

  /// Roll for an encounter. Returns null if no encounter occurs.
  static EncounterType? rollEncounter(
    SolarSystem system,
    Commander commander,
    DifficultyLevel difficulty,
  ) {
    final rng = Random();
    final govDef = GovernmentDef.forType(system.government);

    // Base encounter chance scales with difficulty.
    final diffMod = _difficultyModifier(difficulty);

    // Roll for each encounter type independently.
    final policeChance = (govDef.policeStrength * 5 + diffMod).clamp(0, 80);
    final pirateChance = _pirateChance(govDef, commander, diffMod);
    final traderChance = (govDef.traderStrength * 4).clamp(0, 60);

    // Collect which encounters triggered.
    final possible = <EncounterType>[];
    if (rng.nextInt(100) < policeChance) possible.add(EncounterType.police);
    if (rng.nextInt(100) < pirateChance) possible.add(EncounterType.pirate);
    if (rng.nextInt(100) < traderChance) possible.add(EncounterType.trader);

    // Rare monster encounter (1-2% chance, harder difficulties).
    final monsterChance = difficulty.index * 2;
    if (rng.nextInt(100) < monsterChance) {
      possible.add(EncounterType.monster);
    }

    if (possible.isEmpty) return null;

    // If criminal, police are likely; if bad reputation, pirates are aggressive.
    if (commander.isCriminal && possible.contains(EncounterType.police)) {
      return EncounterType.police;
    }

    return possible[rng.nextInt(possible.length)];
  }

  static int _difficultyModifier(DifficultyLevel difficulty) {
    switch (difficulty) {
      case DifficultyLevel.beginner:
        return -10;
      case DifficultyLevel.easy:
        return -5;
      case DifficultyLevel.normal:
        return 0;
      case DifficultyLevel.hard:
        return 10;
      case DifficultyLevel.impossible:
        return 20;
    }
  }

  static int _pirateChance(
      GovernmentDef govDef, Commander commander, int diffMod) {
    int chance = govDef.pirateStrength * 5 + diffMod;
    // High reputation makes pirates more aggressive (they want the bounty).
    switch (commander.reputation) {
      case Reputation.dangerous:
        chance += 5;
      case Reputation.deadly:
        chance += 10;
      case Reputation.elite:
        chance += 15;
      default:
        break;
    }
    return chance.clamp(0, 90);
  }

  /// Generate an NPC ship for the encounter. Pass [forceShipType] (and
  /// rival identity) to promote the encounter into a named-rival fight.
  static EncounterResult generateEncounter(
    EncounterType type,
    SolarSystem system,
    DifficultyLevel difficulty, {
    ShipType? forceShipType,
    String? rivalId,
    String? captainName,
  }) {
    final rng = Random();
    final govDef = GovernmentDef.forType(system.government);
    final shipType = forceShipType ??
        _selectNpcShipType(type, govDef, system.techLevel, rng);
    final def = ShipTypeDef.forType(shipType);

    final weapons = _generateWeapons(def, system.techLevel, rng);
    final shields = _generateShields(def, system.techLevel, rng);
    final cargo = _generateCargo(type, system, rng);
    final credits = _generateCredits(type, shipType, rng);

    final npc = NpcShip(
      shipType: shipType,
      weapons: weapons,
      shields: shields,
      hullStrength: def.hullStrength,
      currentHull: def.hullStrength,
      cargo: cargo,
      credits: credits,
    );

    // Traders sometimes flee immediately. Rivals never open by fleeing.
    final fleeing = rivalId == null &&
        type == EncounterType.trader &&
        rng.nextInt(100) < 40;

    return EncounterResult(
      type: type,
      npcShip: npc,
      npcFleeing: fleeing,
      rivalId: rivalId,
      captainName: captainName,
    );
  }

  static ShipType _selectNpcShipType(
    EncounterType type,
    GovernmentDef govDef,
    int techLevel,
    Random rng,
  ) {
    final eligible = ShipTypeDef.all.where((s) {
      if (s.minTechLevel > techLevel) return false;
      switch (type) {
        case EncounterType.police:
          return s.policeLevel > 0;
        case EncounterType.pirate:
          return s.pirateLevel > 0;
        case EncounterType.trader:
          return s.traderLevel > 0;
        case EncounterType.monster:
          return true;
      }
    }).toList();

    if (eligible.isEmpty) return ShipType.gnat;

    // Weighted by the relevant occurrence level.
    int totalWeight = 0;
    for (final s in eligible) {
      totalWeight += _npcWeight(s, type);
    }
    final roll = rng.nextInt(totalWeight.clamp(1, totalWeight));
    int cumulative = 0;
    for (final s in eligible) {
      cumulative += _npcWeight(s, type);
      if (roll < cumulative) return s.shipType;
    }
    return eligible.last.shipType;
  }

  static int _npcWeight(ShipTypeDef def, EncounterType type) {
    switch (type) {
      case EncounterType.police:
        return def.policeLevel;
      case EncounterType.pirate:
        return def.pirateLevel;
      case EncounterType.trader:
        return def.traderLevel;
      case EncounterType.monster:
        return def.occurrence;
    }
  }

  static List<WeaponType> _generateWeapons(
      ShipTypeDef def, int techLevel, Random rng) {
    final slots = def.weaponSlots;
    if (slots == 0) return [];
    final eligible = WeaponType.values
        .where((w) => w.minTechLevel <= techLevel)
        .toList();
    if (eligible.isEmpty) return [];
    final count = rng.nextInt(slots) + 1;
    final weapons = <WeaponType>[];
    for (int i = 0; i < count && i < slots; i++) {
      weapons.add(eligible[rng.nextInt(eligible.length)]);
    }
    return weapons;
  }

  static List<ShieldType> _generateShields(
      ShipTypeDef def, int techLevel, Random rng) {
    final slots = def.shieldSlots;
    if (slots == 0) return [];
    final eligible = ShieldType.values
        .where((s) => s.minTechLevel <= techLevel)
        .toList();
    if (eligible.isEmpty) return [];
    final count = rng.nextInt(slots) + 1;
    final shields = <ShieldType>[];
    for (int i = 0; i < count && i < slots; i++) {
      shields.add(eligible[rng.nextInt(eligible.length)]);
    }
    return shields;
  }

  static Map<TradeGood, int> _generateCargo(
      EncounterType type, SolarSystem system, Random rng) {
    if (type == EncounterType.police || type == EncounterType.monster) {
      return {};
    }
    final cargo = <TradeGood, int>{};
    final goods = TradeGood.values.toList()..shuffle(rng);
    final numGoods = rng.nextInt(3) + 1;
    for (int i = 0; i < numGoods && i < goods.length; i++) {
      cargo[goods[i]] = rng.nextInt(5) + 1;
    }
    return cargo;
  }

  static int _generateCredits(
      EncounterType type, ShipType shipType, Random rng) {
    final def = ShipTypeDef.forType(shipType);
    switch (type) {
      case EncounterType.pirate:
        return def.bounty + rng.nextInt(500);
      case EncounterType.trader:
        return rng.nextInt(1000) + 200;
      case EncounterType.police:
        return def.bounty;
      case EncounterType.monster:
        return rng.nextInt(2000) + 500;
    }
  }
}
