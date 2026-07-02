// Pure Dart — no Flutter imports
import 'enums.dart';

class ShipTypeDef {
  final ShipType shipType;
  final int cargoBays;
  final int weaponSlots;
  final int shieldSlots;
  final int gadgetSlots;
  final int crewQuarters;
  final int fuelTanks;
  final int minTechLevel;
  final int costOfFuel;
  final int price;
  final int bounty;
  final int occurrence; // relative frequency for NPC generation (0-10)
  final int hullStrength;
  final int policeLevel;  // 0 = no police fly this, higher = more likely
  final int pirateLevel;
  final int traderLevel;
  final int repairCosts; // cost per hull point to repair
  final int size;         // 1-5

  const ShipTypeDef({
    required this.shipType,
    required this.cargoBays,
    required this.weaponSlots,
    required this.shieldSlots,
    required this.gadgetSlots,
    required this.crewQuarters,
    required this.fuelTanks,
    required this.minTechLevel,
    required this.costOfFuel,
    required this.price,
    required this.bounty,
    required this.occurrence,
    required this.hullStrength,
    required this.policeLevel,
    required this.pirateLevel,
    required this.traderLevel,
    required this.repairCosts,
    required this.size,
  });

  String get displayName => shipType.displayName;

  int get maxFuel => fuelTanks * 2; // each tank holds 2 parsecs

  /// All 10 buyable ships as defined in the original Space Trader.
  static const List<ShipTypeDef> all = [
    // Flea — cheapest, smallest
    ShipTypeDef(
      shipType: ShipType.flea,
      cargoBays: 10,
      weaponSlots: 0,
      shieldSlots: 0,
      gadgetSlots: 0,
      crewQuarters: 1,
      fuelTanks: 1,
      minTechLevel: 0,
      costOfFuel: 1,
      price: 2000,
      bounty: 5,
      occurrence: 5,
      hullStrength: 25,
      policeLevel: 0,
      pirateLevel: 1,
      traderLevel: 2,
      repairCosts: 1,
      size: 1,
    ),
    // Gnat
    ShipTypeDef(
      shipType: ShipType.gnat,
      cargoBays: 15,
      weaponSlots: 1,
      shieldSlots: 0,
      gadgetSlots: 1,
      crewQuarters: 1,
      fuelTanks: 14,
      minTechLevel: 0,
      costOfFuel: 2,
      price: 10000,
      bounty: 50,
      occurrence: 8,
      hullStrength: 100,
      policeLevel: 1,
      pirateLevel: 5,
      traderLevel: 7,
      repairCosts: 1,
      size: 1,
    ),
    // Firefly
    ShipTypeDef(
      shipType: ShipType.firefly,
      cargoBays: 20,
      weaponSlots: 1,
      shieldSlots: 1,
      gadgetSlots: 1,
      crewQuarters: 1,
      fuelTanks: 17,
      minTechLevel: 0,
      costOfFuel: 3,
      price: 25000,
      bounty: 75,
      occurrence: 6,
      hullStrength: 100,
      policeLevel: 2,
      pirateLevel: 5,
      traderLevel: 6,
      repairCosts: 2,
      size: 2,
    ),
    // Mosquito
    ShipTypeDef(
      shipType: ShipType.mosquito,
      cargoBays: 15,
      weaponSlots: 2,
      shieldSlots: 1,
      gadgetSlots: 1,
      crewQuarters: 1,
      fuelTanks: 13,
      minTechLevel: 0,
      costOfFuel: 5,
      price: 30000,
      bounty: 100,
      occurrence: 4,
      hullStrength: 100,
      policeLevel: 3,
      pirateLevel: 7,
      traderLevel: 3,
      repairCosts: 3,
      size: 2,
    ),
    // Bumblebee
    ShipTypeDef(
      shipType: ShipType.bumblebee,
      cargoBays: 25,
      weaponSlots: 1,
      shieldSlots: 2,
      gadgetSlots: 2,
      crewQuarters: 2,
      fuelTanks: 15,
      minTechLevel: 1,
      costOfFuel: 7,
      price: 60000,
      bounty: 125,
      occurrence: 3,
      hullStrength: 150,
      policeLevel: 3,
      pirateLevel: 4,
      traderLevel: 5,
      repairCosts: 5,
      size: 3,
    ),
    // Beetle
    ShipTypeDef(
      shipType: ShipType.beetle,
      cargoBays: 50,
      weaponSlots: 0,
      shieldSlots: 1,
      gadgetSlots: 1,
      crewQuarters: 3,
      fuelTanks: 16,
      minTechLevel: 2,
      costOfFuel: 10,
      price: 80000,
      bounty: 0,
      occurrence: 3,
      hullStrength: 150,
      policeLevel: 3,
      pirateLevel: 2,
      traderLevel: 8,
      repairCosts: 10,
      size: 3,
    ),
    // Hornet
    ShipTypeDef(
      shipType: ShipType.hornet,
      cargoBays: 20,
      weaponSlots: 3,
      shieldSlots: 2,
      gadgetSlots: 1,
      crewQuarters: 2,
      fuelTanks: 16,
      minTechLevel: 2,
      costOfFuel: 15,
      price: 100000,
      bounty: 200,
      occurrence: 2,
      hullStrength: 150,
      policeLevel: 6,
      pirateLevel: 8,
      traderLevel: 1,
      repairCosts: 25,
      size: 3,
    ),
    // Grasshopper
    ShipTypeDef(
      shipType: ShipType.grasshopper,
      cargoBays: 30,
      weaponSlots: 2,
      shieldSlots: 2,
      gadgetSlots: 3,
      crewQuarters: 3,
      fuelTanks: 15,
      minTechLevel: 4,
      costOfFuel: 15,
      price: 150000,
      bounty: 300,
      occurrence: 1,
      hullStrength: 200,
      policeLevel: 5,
      pirateLevel: 6,
      traderLevel: 4,
      repairCosts: 50,
      size: 4,
    ),
    // Termite
    ShipTypeDef(
      shipType: ShipType.termite,
      cargoBays: 60,
      weaponSlots: 1,
      shieldSlots: 3,
      gadgetSlots: 2,
      crewQuarters: 3,
      fuelTanks: 13,
      minTechLevel: 5,
      costOfFuel: 20,
      price: 225000,
      bounty: 100,
      occurrence: 1,
      hullStrength: 200,
      policeLevel: 7,
      pirateLevel: 2,
      traderLevel: 9,
      repairCosts: 50,
      size: 4,
    ),
    // Wasp — top-end combat ship
    ShipTypeDef(
      shipType: ShipType.wasp,
      cargoBays: 35,
      weaponSlots: 3,
      shieldSlots: 2,
      gadgetSlots: 3,
      crewQuarters: 3,
      fuelTanks: 14,
      minTechLevel: 5,
      costOfFuel: 20,
      price: 300000,
      bounty: 500,
      occurrence: 1,
      hullStrength: 200,
      policeLevel: 8,
      pirateLevel: 9,
      traderLevel: 2,
      repairCosts: 75,
      size: 5,
    ),
  ];

  static ShipTypeDef forType(ShipType type) {
    return all.firstWhere((d) => d.shipType == type);
  }
}
