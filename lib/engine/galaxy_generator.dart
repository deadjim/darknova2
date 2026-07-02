// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/enums.dart';
import '../models/government_def.dart';
import '../models/solar_system.dart';
import '../models/trade_item_def.dart';

class GalaxyGenerator {
  static const int _mapWidth = 150;
  static const int _mapHeight = 110;
  static const int _systemCount = 120;
  static const int _minSpacing = 6;
  static const int _wormholeCount = 6;

  static const List<String> _systemNames = [
    'Acamar', 'Adahn', 'Aldea', 'Andevian', 'Antedi', 'Balosnee', 'Baratas',
    'Brax', 'Bretel', 'Calondia', 'Campor', 'Capelle', 'Carzon', 'Castor',
    'Cestus', 'Cheron', 'Courteney', 'Daled', 'Damast', 'Davlos', 'Deneb',
    'Deneva', 'Devidia', 'Draylon', 'Drema', 'Endor', 'Esmee', 'Exo',
    'Ferris', 'Festen', 'Fourmi', 'Frolix', 'Gemulon', 'Guinifer', 'Hades',
    'Hamlet', 'Helena', 'Hulst', 'Iodine', 'Iralius', 'Janus', 'Japori',
    'Jarada', 'Jason', 'Kaylon', 'Khefka', 'Kira', 'Klaatu', 'Klaestron',
    'Korma', 'Kravat', 'Krios', 'Laertes', 'Largo', 'Lave', 'Ligon',
    'Lowry', 'Magrat', 'Malcoria', 'Melina', 'Mentar', 'Merik', 'Mintaka',
    'Montor', 'Mordan', 'Myrthe', 'Nelvana', 'Nix', 'Nyle', 'Odet', 'Og',
    'Omega', 'Omphalos', 'Orias', 'Othello', 'Parade', 'Penthara', 'Picard',
    'Pollux', 'Quator', 'Rakhar', 'Ran', 'Regulas', 'Relva', 'Rhymus',
    'Rochani', 'Rubicum', 'Rutia', 'Sarpeidon', 'Sefalla', 'Seltrice',
    'Sigma', 'Sol', 'Somari', 'Stakoron', 'Straba', 'Syrinx', 'Talani',
    'Tamus', 'Tantalos', 'Tauber', 'Thera', 'Titan', 'Torin', 'Triacus',
    'Turkana', 'Tycho', 'Umberlee', 'Utopia', 'Vagra', 'Valete', 'Vega',
    'Velat', 'Yew', 'Yojimbo', 'Zalkon', 'Zuul', 'Tarchannen', 'Ventax',
    'Xerxes',
  ];

  /// Sol is at index 92 (0-based position in the names list).
  static const int solIndex = 92;

  /// Generate a deterministic galaxy given a seed and difficulty.
  static List<SolarSystem> generate(int seed, DifficultyLevel difficulty) {
    final rng = Random(seed);
    final positions = <_Point>[];
    final systems = <SolarSystem>[];

    // Place systems with minimum spacing constraint.
    int attempts = 0;
    while (positions.length < _systemCount && attempts < 50000) {
      attempts++;
      final x = rng.nextInt(_mapWidth - 4) + 2;
      final y = rng.nextInt(_mapHeight - 4) + 2;
      if (_isFarEnough(x, y, positions)) {
        positions.add(_Point(x, y));
      }
    }

    // If we couldn't place all systems with strict spacing, relax slightly.
    if (positions.length < _systemCount) {
      while (positions.length < _systemCount) {
        final x = rng.nextInt(_mapWidth - 4) + 2;
        final y = rng.nextInt(_mapHeight - 4) + 2;
        positions.add(_Point(x, y));
      }
    }

    // Build systems using the shuffled name list (names are already indexed).
    for (int i = 0; i < _systemCount; i++) {
      final pos = positions[i];
      final name = _systemNames[i];

      // Sol gets fixed properties.
      if (i == solIndex) {
        final sys = _buildSolarSystem(
          name: name,
          x: pos.x,
          y: pos.y,
          techLevel: 7,
          government: GovernmentType.democracy,
          status: SystemStatus.uneventful,
          specialResource: SpecialResource.nothingSpecial,
          size: 5,
          rng: rng,
        );
        systems.add(sys);
        continue;
      }

      final techLevel = _randomTechLevel(rng);
      final government = _randomGovernment(rng, techLevel);
      final status = _randomStatus(rng);
      final resource = _randomResource(rng);
      final size = rng.nextInt(5) + 1;

      final sys = _buildSolarSystem(
        name: name,
        x: pos.x,
        y: pos.y,
        techLevel: techLevel,
        government: government,
        status: status,
        specialResource: resource,
        size: size,
        rng: rng,
      );
      systems.add(sys);
    }

    // Place wormholes by marking certain systems with specialEvent.
    final wormholeIndices = <int>[];
    while (wormholeIndices.length < _wormholeCount * 2) {
      final idx = rng.nextInt(_systemCount);
      if (!wormholeIndices.contains(idx)) {
        wormholeIndices.add(idx);
      }
    }
    // Wormholes come in pairs.
    final updated = List<SolarSystem>.from(systems);
    for (int i = 0; i < _wormholeCount; i++) {
      final a = wormholeIndices[i * 2];
      final b = wormholeIndices[i * 2 + 1];
      updated[a] = updated[a].copyWith(specialEvent: 1000 + b);
      updated[b] = updated[b].copyWith(specialEvent: 1000 + a);
    }

    return updated;
  }

  static bool _isFarEnough(int x, int y, List<_Point> existing) {
    for (final p in existing) {
      final dx = x - p.x;
      final dy = y - p.y;
      if (dx * dx + dy * dy < _minSpacing * _minSpacing) return false;
    }
    return true;
  }

  /// Lower tech levels are more common: weighted toward 0-3.
  static int _randomTechLevel(Random rng) {
    // Weights: 0→20, 1→20, 2→18, 3→16, 4→12, 5→8, 6→4, 7→2
    const weights = [20, 20, 18, 16, 12, 8, 4, 2];
    const total = 100;
    final roll = rng.nextInt(total);
    int cumulative = 0;
    for (int i = 0; i < weights.length; i++) {
      cumulative += weights[i];
      if (roll < cumulative) return i;
    }
    return 7;
  }

  /// Choose a government compatible with the tech level.
  static GovernmentType _randomGovernment(Random rng, int techLevel) {
    final compatible = GovernmentDef.all
        .where((g) =>
            g.minTechLevel <= techLevel && g.maxTechLevel >= techLevel)
        .toList();
    if (compatible.isEmpty) return GovernmentType.anarchy;
    // Anarchy rare: if selected, 30% chance to reroll once.
    final choice = compatible[rng.nextInt(compatible.length)];
    if (choice.type == GovernmentType.anarchy && rng.nextInt(10) < 7) {
      final retry = compatible[rng.nextInt(compatible.length)];
      return retry.type;
    }
    return choice.type;
  }

  static SystemStatus _randomStatus(Random rng) {
    // Uneventful is 50% likely; others split the rest.
    final roll = rng.nextInt(100);
    if (roll < 50) return SystemStatus.uneventful;
    return SystemStatus.values[1 + rng.nextInt(SystemStatus.values.length - 1)];
  }

  static SpecialResource _randomResource(Random rng) {
    // nothingSpecial is 40% likely.
    final roll = rng.nextInt(100);
    if (roll < 40) return SpecialResource.nothingSpecial;
    return SpecialResource
        .values[1 + rng.nextInt(SpecialResource.values.length - 1)];
  }

  static SolarSystem _buildSolarSystem({
    required String name,
    required int x,
    required int y,
    required int techLevel,
    required GovernmentType government,
    required SystemStatus status,
    required SpecialResource specialResource,
    required int size,
    required Random rng,
  }) {
    final govDef = GovernmentDef.forType(government);
    final quantities = _initialQuantities(
        techLevel, govDef, specialResource, status, size, rng);
    final countdown = 3 + rng.nextInt(5); // 3-7 days until next status tick
    return SolarSystem(
      name: name,
      techLevel: techLevel,
      government: government,
      status: status,
      x: x,
      y: y,
      specialResource: specialResource,
      size: size,
      tradeQuantities: quantities,
      countdown: countdown,
      visited: name == 'Sol', // Sol is visited by default (starting location)
    );
  }

  static Map<TradeGood, int> _initialQuantities(
    int techLevel,
    GovernmentDef govDef,
    SpecialResource resource,
    SystemStatus status,
    int size,
    Random rng,
  ) {
    final quantities = <TradeGood, int>{};
    for (final def in TradeItemDef.all) {
      // Basic eligibility: system must meet tech production level.
      if (techLevel < def.techUsage) {
        quantities[def.good] = 0;
        continue;
      }

      // Illegal goods check.
      if (def.good == TradeGood.narcotics && !govDef.drugsOK) {
        quantities[def.good] = 0;
        continue;
      }
      if (def.good == TradeGood.firearms && !govDef.firearmsOK) {
        quantities[def.good] = 0;
        continue;
      }

      // Base quantity from size × tech production factor.
      int baseQty = size * 2;

      // Boost if this system is near the peak production tech level.
      if ((techLevel - def.techTopProduction).abs() <= 1) {
        baseQty += size * 3;
      } else if (techLevel >= def.techProduction) {
        baseQty += size;
      }

      // Resource modifiers.
      if (def.cheapResource != null && resource == def.cheapResource) {
        baseQty = (baseQty * 1.5).round();
      }
      if (def.expensiveResource != null && resource == def.expensiveResource) {
        baseQty = (baseQty * 0.6).round();
      }

      // Status modifiers — scarcity under bad conditions.
      if (def.doublePriceStatus != null && status == def.doublePriceStatus) {
        baseQty = (baseQty * 0.5).round();
      }

      // Random variance ±30%.
      final variance = (baseQty * 0.3).round();
      final qty = (baseQty - variance + rng.nextInt(variance * 2 + 1))
          .clamp(0, 99);
      quantities[def.good] = qty;
    }
    return quantities;
  }
}

class _Point {
  final int x;
  final int y;
  const _Point(this.x, this.y);
}
