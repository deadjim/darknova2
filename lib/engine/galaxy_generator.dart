// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/enums.dart';
import '../models/government_def.dart';
import '../models/solar_system.dart';
import '../models/trade_item_def.dart';
import 'sphere.dart';

class GalaxyGenerator {
  static const int _systemCount = 400;
  static const int _wormholeCount = 12; // was 6
  static const int _clusterCount = 10;

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

  // Procedural frontier-name syllable pools (see spec §2.4/§2.6).
  static const List<String> _onsets = [
    'K', 'V', 'Th', 'Dr', 'S', 'M', 'R', 'Az', 'Bel', 'Cor',
    'Dal', 'Er', 'Gr', 'Hal', 'J', 'L', 'N', 'Or', 'P', 'T',
    'Vy', 'Z', 'Qu', 'X',
  ];
  static const List<String> _mids = [
    'a', 'e', 'i', 'o', 'u', 'ae', 'ia', 'or', 'ar', 'un',
    'el', 'ir', 'os', 'ur', 'an',
  ];
  static const List<String> _ends = [
    'ris', 'mar', 'dun', 'th', 'ka', 'von', 'das', 'x',
    'nia', 'rus', 'tis', 'gol', 'ph', 'met', 'zar', 'din',
  ];
  static const List<String> _frontierSuffixes = [
    'Reach', 'Deep', 'Gate', 'Verge', 'Anchorage', 'Drift',
  ];
  static const List<String> _regionSuffixes = [
    'Reach', 'Expanse', 'Verge', 'Cluster', 'Gulf', 'Chain', 'Rim', 'Spur',
    'Corridor', 'Shoals',
  ];

  /// Generate a deterministic galaxy given a seed and difficulty.
  ///
  /// Systems are distributed on the galactic sphere via a Fibonacci
  /// lattice (near-uniform by construction) with seeded jitter, then
  /// pulled toward 10 cluster centers for dramatic "named reach" grouping,
  /// then repaired so no system is stranded, then stored as chart
  /// coordinates (x = longitude 0..150, y = latitude 0..110) — see
  /// [SphereGeo].
  static List<SolarSystem> generate(int seed, DifficultyLevel difficulty) {
    final rng = Random(seed);

    // ---------------------------------------------------------------
    // 1. Fibonacci-lattice base layout (unchanged from the 120-system
    //    generator) — yields jittered (lat, lon) per system index.
    // ---------------------------------------------------------------
    const goldenAngle = 2.39996322972865332; // π(3 − √5)
    final spinOffset = rng.nextDouble() * 2 * pi;
    final angles = <(double, double)>[]; // (lat, lon) per system
    for (var i = 0; i < _systemCount; i++) {
      // Avoid exact poles: bias the endpoints inward.
      final v = (i + 0.5) / _systemCount; // (0..1)
      var lat = asin(1 - 2 * v); // uniform in sin(lat)
      var lon = (i * goldenAngle + spinOffset) % (2 * pi);
      // Jitter: up to ~35% of the lattice spacing, seeded.
      final jitter = 0.35 * sqrt(4 * pi / _systemCount);
      lat = (lat + (rng.nextDouble() - 0.5) * jitter)
          .clamp(-pi / 2 * 0.98, pi / 2 * 0.98);
      lon = (lon + (rng.nextDouble() - 0.5) * jitter) % (2 * pi);
      angles.add((lat, lon));
    }

    // ---------------------------------------------------------------
    // 2. Cluster centers: a small Fibonacci lattice of its own, spun by
    //    a fresh seeded draw taken AFTER the base-layout draws above so
    //    the draw order stays fixed for a given seed.
    // ---------------------------------------------------------------
    final clusterSpin = rng.nextDouble() * 2 * pi;
    final clusterCenters = <(double, double, double)>[];
    for (var c = 0; c < _clusterCount; c++) {
      final v = (c + 0.5) / _clusterCount;
      final lat = asin(1 - 2 * v);
      final lon = (c * goldenAngle + clusterSpin) % (2 * pi);
      clusterCenters.add(_unitFromAngles(lat, lon));
    }

    // ---------------------------------------------------------------
    // 3. Cluster pull: bend each system toward its nearest cluster
    //    center, strongly near the center and ~0 far away, then convert
    //    to chart ints.
    // ---------------------------------------------------------------
    final positions = <_Point>[];
    final nearestCluster = <int>[];
    for (var i = 0; i < _systemCount; i++) {
      final (lat, lon) = angles[i];
      final p = _unitFromAngles(lat, lon);

      var bestDot = -2.0;
      var bestC = 0;
      for (var c = 0; c < clusterCenters.length; c++) {
        final center = clusterCenters[c];
        final dot = p.$1 * center.$1 + p.$2 * center.$2 + p.$3 * center.$3;
        if (dot > bestDot) {
          bestDot = dot;
          bestC = c;
        }
      }
      nearestCluster.add(bestC);

      final theta = acos(bestDot.clamp(-1.0, 1.0));
      final pull = 0.45 * exp(-pow(theta / 0.55, 2));
      final pulled = _slerp(p, clusterCenters[bestC], pull);
      final normalized = _normalize(pulled);

      final lon2 = _lonFromUnit(normalized);
      final lat2 = _latFromUnit(normalized);
      final (cx, cy) = SphereGeo.chartOf(lon2, lat2);
      positions.add(_Point(cx.round().clamp(0, 149), cy.round().clamp(1, 109)));
    }

    // ---------------------------------------------------------------
    // 4. Stranding repair pass: nudge any system whose nearest neighbor
    //    is >= 27pc away closer to that neighbor, up to 5 passes.
    // ---------------------------------------------------------------
    for (var pass = 0; pass < 5; pass++) {
      var changed = false;
      for (var i = 0; i < _systemCount; i++) {
        var minD = double.infinity;
        var nearestJ = -1;
        for (var j = 0; j < _systemCount; j++) {
          if (j == i) continue;
          final d = SphereGeo.angleBetween(
                  positions[i].x, positions[i].y, positions[j].x, positions[j].y) *
              SphereGeo.radius;
          if (d < minD) {
            minD = d;
            nearestJ = j;
          }
        }
        if (minD >= 27.0) {
          changed = true;
          final a = SphereGeo.unitOf(positions[i].x, positions[i].y);
          final b =
              SphereGeo.unitOf(positions[nearestJ].x, positions[nearestJ].y);
          final angle = acos(
              (a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3).clamp(-1.0, 1.0));
          if (angle < 1e-6) {
            // Identical points: slerp is a no-op, nudge the grid cell.
            positions[i] = _Point((positions[i].x + 1) % 150, positions[i].y);
          } else {
            final moved = _slerp(a, b, 0.4);
            final lon2 = _lonFromUnit(moved);
            final lat2 = _latFromUnit(moved);
            final (cx, cy) = SphereGeo.chartOf(lon2, lat2);
            positions[i] =
                _Point(cx.round().clamp(0, 149), cy.round().clamp(1, 109));
          }
        }
      }
      if (!changed) break;
    }

    // ---------------------------------------------------------------
    // 5. Region (cluster) names — 10 procedural names with a forced,
    //    deterministic suffix per cluster index.
    // ---------------------------------------------------------------
    final regionNames = <String>[
      for (var c = 0; c < _clusterCount; c++)
        '${_frontierBase(rng)} ${_regionSuffixes[c]}',
    ];

    // ---------------------------------------------------------------
    // 6. Roll attributes and build systems (placeholder names — real
    //    names are assigned afterward once desirability is known).
    // ---------------------------------------------------------------
    final systems = <SolarSystem>[];
    for (int i = 0; i < _systemCount; i++) {
      final pos = positions[i];
      final region = regionNames[nearestCluster[i]];

      if (i == solIndex) {
        final sys = _buildSolarSystem(
          name: '',
          x: pos.x,
          y: pos.y,
          techLevel: 7,
          government: GovernmentType.democracy,
          status: SystemStatus.uneventful,
          specialResource: SpecialResource.nothingSpecial,
          size: 5,
          region: region,
          startVisited: true,
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
        name: '',
        x: pos.x,
        y: pos.y,
        techLevel: techLevel,
        government: government,
        status: status,
        specialResource: resource,
        size: size,
        region: region,
        startVisited: false,
        rng: rng,
      );
      systems.add(sys);
    }

    // ---------------------------------------------------------------
    // 7. Names: the 119 non-Sol canonical names go to the most
    //    desirable systems (tech*10+size, descending); Sol always gets
    //    'Sol'; everyone else gets a procedural frontier name.
    // ---------------------------------------------------------------
    final desirabilityOrder = List<int>.generate(_systemCount, (i) => i)
      ..remove(solIndex);
    desirabilityOrder.sort((a, b) {
      final da = systems[a].techLevel * 10 + systems[a].size;
      final db = systems[b].techLevel * 10 + systems[b].size;
      return db.compareTo(da);
    });
    final top119 = desirabilityOrder.take(119).toList();
    final remainder = desirabilityOrder.skip(119).toList();

    final canonicalNames = List<String>.from(_systemNames)..remove('Sol');
    canonicalNames.shuffle(rng);

    final names = List<String>.filled(_systemCount, '');
    final usedNames = <String>{'Sol'};
    names[solIndex] = 'Sol';
    for (var k = 0; k < top119.length; k++) {
      final name = canonicalNames[k];
      names[top119[k]] = name;
      usedNames.add(name);
    }
    for (final idx in remainder) {
      String name;
      do {
        name = _frontierName(rng);
      } while (usedNames.contains(name));
      names[idx] = name;
      usedNames.add(name);
    }

    final named = <SolarSystem>[
      for (var i = 0; i < _systemCount; i++)
        systems[i].copyWith(name: names[i]),
    ];

    // ---------------------------------------------------------------
    // 8. Wormholes: pairs prefer a great-circle span >= 60pc (voids,
    //    not neighbors); redraw up to 200 attempts, then accept whatever.
    // ---------------------------------------------------------------
    final updated = List<SolarSystem>.from(named);
    final usedWormholeIndices = <int>{};
    for (var p = 0; p < _wormholeCount; p++) {
      var a = -1;
      var b = -1;
      for (var attempt = 0; attempt < 200; attempt++) {
        final ca = rng.nextInt(_systemCount);
        final cb = rng.nextInt(_systemCount);
        if (ca == cb ||
            usedWormholeIndices.contains(ca) ||
            usedWormholeIndices.contains(cb)) {
          continue;
        }
        a = ca;
        b = cb;
        final d = SphereGeo.distance(named[ca], named[cb]);
        if (d >= 60.0) break;
      }
      if (a == -1 || b == -1) continue; // ran out of unique candidates
      usedWormholeIndices.add(a);
      usedWormholeIndices.add(b);
      updated[a] = updated[a].copyWith(specialEvent: 1000 + b);
      updated[b] = updated[b].copyWith(specialEvent: 1000 + a);
    }

    return updated;
  }

  /// Spherical linear interpolation between two unit vectors.
  static (double, double, double) _slerp(
    (double, double, double) a,
    (double, double, double) b,
    double t,
  ) {
    final dot = (a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3).clamp(-1.0, 1.0);
    final omega = acos(dot);
    if (omega < 1e-6) return a;
    final sinOmega = sin(omega);
    final sa = sin((1 - t) * omega) / sinOmega;
    final sb = sin(t * omega) / sinOmega;
    return (
      a.$1 * sa + b.$1 * sb,
      a.$2 * sa + b.$2 * sb,
      a.$3 * sa + b.$3 * sb,
    );
  }

  static (double, double, double) _normalize((double, double, double) v) {
    final len = sqrt(v.$1 * v.$1 + v.$2 * v.$2 + v.$3 * v.$3);
    if (len < 1e-12) return (1.0, 0.0, 0.0);
    return (v.$1 / len, v.$2 / len, v.$3 / len);
  }

  static (double, double, double) _unitFromAngles(double lat, double lon) => (
        cos(lat) * cos(lon),
        sin(lat),
        cos(lat) * sin(lon),
      );

  static double _lonFromUnit((double, double, double) v) {
    var lon = atan2(v.$3, v.$1);
    if (lon < 0) lon += 2 * pi;
    return lon;
  }

  static double _latFromUnit((double, double, double) v) =>
      asin(v.$2.clamp(-1.0, 1.0));

  /// Onset+mid+end procedural syllable base (no suffix).
  static String _frontierBase(Random rng) {
    final onset = _onsets[rng.nextInt(_onsets.length)];
    final mid = _mids[rng.nextInt(_mids.length)];
    final end = _ends[rng.nextInt(_ends.length)];
    return '$onset$mid$end';
  }

  /// Procedural frontier system name, e.g. 'Korris', 'Vaeldun Reach'.
  static String _frontierName(Random rng) {
    var name = _frontierBase(rng);
    if (rng.nextInt(5) == 0) {
      name += ' ${_frontierSuffixes[rng.nextInt(_frontierSuffixes.length)]}';
    }
    return name;
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
    required String region,
    required bool startVisited,
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
      visited: startVisited,
      region: region,
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
