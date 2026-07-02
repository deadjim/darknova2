// Pure Dart — no Flutter imports
import 'enums.dart';
import 'ship_type_def.dart';

class Ship {
  final ShipType shipType;
  final Map<TradeGood, int> cargo;
  final List<WeaponType> weapons;
  final List<ShieldType> shields;
  final List<GadgetType> gadgets;
  final int crew;          // number of hired crew (not counting commander)
  final int fuel;          // current fuel units
  final int hullStrength;  // current hull points
  final int tribbles;      // number of tribbles on board

  const Ship({
    required this.shipType,
    required this.cargo,
    required this.weapons,
    required this.shields,
    required this.gadgets,
    required this.crew,
    required this.fuel,
    required this.hullStrength,
    required this.tribbles,
  });

  ShipTypeDef get def => ShipTypeDef.forType(shipType);

  int get totalCargoUsed {
    int total = 0;
    for (final qty in cargo.values) {
      total += qty;
    }
    return total;
  }

  int get extraCargoBays {
    return gadgets.where((g) => g == GadgetType.extraCargoBays).length * 5;
  }

  int get availableCargoBays {
    return def.cargoBays + extraCargoBays - totalCargoUsed;
  }

  int get totalCargoBays => def.cargoBays + extraCargoBays;

  bool hasGadget(GadgetType gadget) => gadgets.contains(gadget);

  int get maxFuel => def.maxFuel;

  int get maxHullStrength => def.hullStrength;

  double get hullPercent => hullStrength / maxHullStrength;

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

  int get cargoValue {
    // approximate — actual depends on system prices
    return totalCargoUsed * 100;
  }

  bool canAddWeapon() => weapons.length < def.weaponSlots;
  bool canAddShield() => shields.length < def.shieldSlots;
  bool canAddGadget() => gadgets.length < def.gadgetSlots;

  Ship copyWith({
    ShipType? shipType,
    Map<TradeGood, int>? cargo,
    List<WeaponType>? weapons,
    List<ShieldType>? shields,
    List<GadgetType>? gadgets,
    int? crew,
    int? fuel,
    int? hullStrength,
    int? tribbles,
  }) {
    return Ship(
      shipType: shipType ?? this.shipType,
      cargo: cargo ?? Map.from(this.cargo),
      weapons: weapons ?? List.from(this.weapons),
      shields: shields ?? List.from(this.shields),
      gadgets: gadgets ?? List.from(this.gadgets),
      crew: crew ?? this.crew,
      fuel: fuel ?? this.fuel,
      hullStrength: hullStrength ?? this.hullStrength,
      tribbles: tribbles ?? this.tribbles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipType': shipType.index,
      'cargo': cargo.map((k, v) => MapEntry(k.index.toString(), v)),
      'weapons': weapons.map((w) => w.index).toList(),
      'shields': shields.map((s) => s.index).toList(),
      'gadgets': gadgets.map((g) => g.index).toList(),
      'crew': crew,
      'fuel': fuel,
      'hullStrength': hullStrength,
      'tribbles': tribbles,
    };
  }

  factory Ship.fromJson(Map<String, dynamic> json) {
    final rawCargo = json['cargo'] as Map<String, dynamic>;
    final cargo = <TradeGood, int>{};
    rawCargo.forEach((k, v) {
      cargo[TradeGood.values[int.parse(k)]] = v as int;
    });
    return Ship(
      shipType: ShipType.values[json['shipType'] as int],
      cargo: cargo,
      weapons: (json['weapons'] as List)
          .map((i) => WeaponType.values[i as int])
          .toList(),
      shields: (json['shields'] as List)
          .map((i) => ShieldType.values[i as int])
          .toList(),
      gadgets: (json['gadgets'] as List)
          .map((i) => GadgetType.values[i as int])
          .toList(),
      crew: json['crew'] as int,
      fuel: json['fuel'] as int,
      hullStrength: json['hullStrength'] as int,
      tribbles: json['tribbles'] as int,
    );
  }

  /// Create a fresh starting ship (Gnat).
  factory Ship.starter() {
    final def = ShipTypeDef.forType(ShipType.gnat);
    return Ship(
      shipType: ShipType.gnat,
      cargo: {},
      weapons: [WeaponType.pulseLaser],
      shields: [],
      gadgets: [],
      crew: 0,
      fuel: def.maxFuel,
      hullStrength: def.hullStrength,
      tribbles: 0,
    );
  }
}
