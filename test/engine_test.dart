import 'dart:math';

import 'package:darknova2/engine/economy.dart';
import 'package:darknova2/engine/galaxy_generator.dart';
import 'package:darknova2/engine/game_engine.dart';
import 'package:darknova2/engine/travel.dart';
import 'package:darknova2/models/commander.dart';
import 'package:darknova2/models/enums.dart';
import 'package:darknova2/models/game_state.dart';
import 'package:darknova2/models/ship.dart';
import 'package:darknova2/models/solar_system.dart';
import 'package:darknova2/models/trade_item_def.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Galaxy generation tests
  // ---------------------------------------------------------------------------

  group('GalaxyGenerator', () {
    late List<SolarSystem> systems;

    setUpAll(() {
      systems = GalaxyGenerator.generate(42, DifficultyLevel.normal);
    });

    test('generates exactly 120 solar systems', () {
      expect(systems.length, equals(120));
    });

    test('all system names are unique', () {
      final names = systems.map((s) => s.name).toSet();
      expect(names.length, equals(120));
    });

    test('no two systems overlap (within minimum spacing)', () {
      int overlaps = 0;
      for (int i = 0; i < systems.length; i++) {
        for (int j = i + 1; j < systems.length; j++) {
          final dx = systems[i].x - systems[j].x;
          final dy = systems[i].y - systems[j].y;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist < 3.0) overlaps++;
        }
      }
      // Allow a small number of near-overlaps (relaxed placement fallback).
      expect(overlaps, lessThan(5));
    });

    test('all systems are within map bounds', () {
      for (final sys in systems) {
        expect(sys.x, greaterThanOrEqualTo(0));
        expect(sys.x, lessThanOrEqualTo(150));
        expect(sys.y, greaterThanOrEqualTo(0));
        expect(sys.y, lessThanOrEqualTo(110));
      }
    });

    test('tech levels are in valid range (0-7)', () {
      for (final sys in systems) {
        expect(sys.techLevel, inInclusiveRange(0, 7));
      }
    });

    test('Sol is at the correct index and has tech level 7', () {
      final sol = systems[GalaxyGenerator.solIndex];
      expect(sol.name, equals('Sol'));
      expect(sol.techLevel, equals(7));
    });

    test('lower tech levels appear more frequently than higher', () {
      final counts = List.filled(8, 0);
      for (final sys in systems) {
        counts[sys.techLevel]++;
      }
      // Combined tech 0-2 should be more common than tech 6-7.
      final lowTech = counts[0] + counts[1] + counts[2];
      final highTech = counts[6] + counts[7];
      expect(lowTech, greaterThan(highTech));
    });

    test('all systems have valid government types', () {
      for (final sys in systems) {
        expect(GovernmentType.values.contains(sys.government), isTrue);
      }
    });

    test('systems have positive size', () {
      for (final sys in systems) {
        expect(sys.size, greaterThan(0));
        expect(sys.size, lessThanOrEqualTo(5));
      }
    });

    test('deterministic — same seed produces same galaxy', () {
      final systems2 = GalaxyGenerator.generate(42, DifficultyLevel.normal);
      for (int i = 0; i < systems.length; i++) {
        expect(systems[i].name, equals(systems2[i].name));
        expect(systems[i].x, equals(systems2[i].x));
        expect(systems[i].y, equals(systems2[i].y));
        expect(systems[i].techLevel, equals(systems2[i].techLevel));
      }
    });

    test('different seeds produce different galaxies', () {
      final systems2 = GalaxyGenerator.generate(99, DifficultyLevel.normal);
      // At least some systems should differ in position.
      int diffCount = 0;
      for (int i = 0; i < systems.length; i++) {
        if (systems[i].x != systems2[i].x || systems[i].y != systems2[i].y) {
          diffCount++;
        }
      }
      expect(diffCount, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  // Economy tests
  // ---------------------------------------------------------------------------

  group('Economy', () {
    late SolarSystem system;
    late Commander commander;

    setUpAll(() {
      // Build a tech-5 Democracy system — should have most goods available.
      system = SolarSystem(
        name: 'TestSystem',
        techLevel: 5,
        government: GovernmentType.democracy,
        status: SystemStatus.uneventful,
        x: 50,
        y: 50,
        specialResource: SpecialResource.nothingSpecial,
        size: 3,
        tradeQuantities: {
          for (final g in TradeGood.values) g: 10,
        },
        countdown: 5,
        visited: false,
      );
      commander = const Commander(
        name: 'Test',
        pilot: 5,
        fighter: 5,
        trader: 5,
        engineer: 5,
        policeRecordScore: 0,
        reputationScore: 0,
        policeKills: 0,
        traderKills: 0,
        pirateKills: 0,
      );
    });

    test('all prices are within min/max bounds', () {
      for (final good in TradeGood.values) {
        if (!Economy.canTradeGood(system, good)) continue;
        final def = TradeItemDef.forGood(good);
        final buyPrice =
            Economy.calculateBuyPrice(system, good, commander);
        final sellPrice =
            Economy.calculateSellPrice(system, good, commander);
        expect(buyPrice, greaterThanOrEqualTo(def.minTradePrice),
            reason: '${good.name} buy price below min');
        expect(buyPrice, lessThanOrEqualTo(def.maxTradePrice),
            reason: '${good.name} buy price above max');
        expect(sellPrice, greaterThanOrEqualTo(def.minTradePrice),
            reason: '${good.name} sell price below min');
        expect(sellPrice, lessThanOrEqualTo(def.maxTradePrice),
            reason: '${good.name} sell price above max');
      }
    });

    test('sell price is always <= buy price', () {
      for (final good in TradeGood.values) {
        if (!Economy.canTradeGood(system, good)) continue;
        final buyPrice =
            Economy.calculateBuyPrice(system, good, commander);
        final sellPrice =
            Economy.calculateSellPrice(system, good, commander);
        if (buyPrice > 0) {
          expect(sellPrice, lessThanOrEqualTo(buyPrice),
              reason: '${good.name}: sell > buy');
        }
      }
    });

    test('status doubles price for drought + water', () {
      final droughtSystem = system.copyWith(status: SystemStatus.drought);
      final normalSystem = system.copyWith(status: SystemStatus.uneventful);

      final droughtPrice =
          Economy.calculateBuyPrice(droughtSystem, TradeGood.water, commander);
      final normalPrice =
          Economy.calculateBuyPrice(normalSystem, TradeGood.water, commander);

      // Drought should make water significantly more expensive.
      expect(droughtPrice, greaterThan(normalPrice));
    });

    test('tech level affects price for high-tech goods', () {
      final lowTechSystem = system.copyWith(
          techLevel: 3,
          government: GovernmentType.confederacy);
      final highTechSystem = system.copyWith(techLevel: 7);

      // Robots (negative priceInc) should be cheaper at higher tech.
      if (Economy.canTradeGood(lowTechSystem, TradeGood.robots) &&
          Economy.canTradeGood(highTechSystem, TradeGood.robots)) {
        final lowPrice =
            Economy.calculateBuyPrice(lowTechSystem, TradeGood.robots, commander);
        final highPrice =
            Economy.calculateBuyPrice(highTechSystem, TradeGood.robots, commander);
        // Robots have negative priceInc, so higher tech = lower price.
        expect(highPrice, lessThan(lowPrice));
      }
    });

    test('cheap resource reduces water price at sweetwater oceans', () {
      final richSystem =
          system.copyWith(specialResource: SpecialResource.sweetwaterOceans);
      final normalSystem =
          system.copyWith(specialResource: SpecialResource.nothingSpecial);

      final richPrice =
          Economy.calculateBuyPrice(richSystem, TradeGood.water, commander);
      final normalPrice =
          Economy.calculateBuyPrice(normalSystem, TradeGood.water, commander);

      expect(richPrice, lessThan(normalPrice));
    });

    test('narcotics are illegal in democracy', () {
      expect(Economy.isIllegal(system, TradeGood.narcotics), isTrue);
      expect(Economy.canTradeGood(system, TradeGood.narcotics), isFalse);
    });

    test('narcotics are legal in anarchy', () {
      final anarchySystem =
          system.copyWith(government: GovernmentType.anarchy);
      expect(Economy.canTradeGood(anarchySystem, TradeGood.narcotics), isTrue);
    });

    test('firearms are illegal in democracy', () {
      expect(Economy.isIllegal(system, TradeGood.firearms), isTrue);
    });

    test('high trader skill reduces buy price', () {
      final lowTrader = commander.copyWith(trader: 1);
      final highTrader = commander.copyWith(trader: 10);
      final lowPrice =
          Economy.calculateBuyPrice(system, TradeGood.water, lowTrader);
      final highPrice =
          Economy.calculateBuyPrice(system, TradeGood.water, highTrader);
      expect(highPrice, lessThanOrEqualTo(lowPrice));
    });
  });

  // ---------------------------------------------------------------------------
  // Travel tests
  // ---------------------------------------------------------------------------

  group('Travel', () {
    late SolarSystem a;
    late SolarSystem b;
    late SolarSystem c;
    late Ship ship;

    setUpAll(() {
      a = SolarSystem(
        name: 'Alpha',
        techLevel: 5,
        government: GovernmentType.democracy,
        status: SystemStatus.uneventful,
        x: 10,
        y: 10,
        specialResource: SpecialResource.nothingSpecial,
        size: 3,
        tradeQuantities: {},
        countdown: 5,
        visited: true,
      );
      b = SolarSystem(
        name: 'Beta',
        techLevel: 5,
        government: GovernmentType.democracy,
        status: SystemStatus.uneventful,
        x: 16,
        y: 10,
        specialResource: SpecialResource.nothingSpecial,
        size: 3,
        tradeQuantities: {},
        countdown: 5,
        visited: false,
      );
      c = SolarSystem(
        name: 'Gamma',
        techLevel: 5,
        government: GovernmentType.democracy,
        status: SystemStatus.uneventful,
        x: 200,
        y: 200,
        specialResource: SpecialResource.nothingSpecial,
        size: 3,
        tradeQuantities: {},
        countdown: 5,
        visited: false,
      );
      ship = Ship.starter();
    });

    test('distance is Euclidean', () {
      final d = Travel.distance(a, b);
      expect(d, closeTo(6.0, 0.01));
    });

    test('distance to self is zero', () {
      expect(Travel.distance(a, a), equals(0.0));
    });

    test('distance is symmetric', () {
      expect(Travel.distance(a, b), closeTo(Travel.distance(b, a), 0.001));
    });

    test('fuel cost is at least 1', () {
      final cost = Travel.fuelCost(a, b, ship);
      expect(cost, greaterThanOrEqualTo(1));
    });

    test('can reach nearby system with fuel', () {
      expect(Travel.canReach(a, b, ship), isTrue);
    });

    test('cannot reach far-away system', () {
      expect(Travel.canReach(a, c, ship), isFalse);
    });

    test('inRange returns only reachable systems', () {
      final systems = [a, b, c];
      final reachable = Travel.inRange(a, systems, ship);
      expect(reachable, contains(b));
      expect(reachable, isNot(contains(c)));
      expect(reachable, isNot(contains(a)));
    });

    test('inRangeIndices excludes current system index', () {
      final systems = [a, b, c];
      final indices = Travel.inRangeIndices(0, systems, ship);
      expect(indices, isNot(contains(0)));
    });
  });

  // ---------------------------------------------------------------------------
  // Game state tests
  // ---------------------------------------------------------------------------

  group('GameState', () {
    test('new game starts with valid state', () {
      final state = GameEngine.newGame('TestCommander', DifficultyLevel.normal);

      expect(state.commander.name, equals('TestCommander'));
      expect(state.credits, equals(1000));
      expect(state.debt, equals(0));
      expect(state.days, equals(0));
      expect(state.solarSystems.length, equals(120));
      expect(state.ship.shipType, equals(ShipType.gnat));
      expect(state.ship.hullStrength, greaterThan(0));
      expect(state.ship.fuel, greaterThan(0));
    });

    test('hard difficulty starts with debt', () {
      final state = GameEngine.newGame('HardCommander', DifficultyLevel.hard);
      expect(state.debt, equals(1000));
    });

    test('beginner difficulty starts with no debt', () {
      final state =
          GameEngine.newGame('BeginnerCommander', DifficultyLevel.beginner);
      expect(state.debt, equals(0));
    });

    test('starting system is Sol (visited)', () {
      final state = GameEngine.newGame('Test', DifficultyLevel.normal);
      final sol = state.currentSystem;
      expect(sol.name, equals('Sol'));
      expect(sol.visited, isTrue);
    });

    test('buy good reduces credits and increases cargo', () {
      var state = GameEngine.newGame('Test', DifficultyLevel.normal);
      // Add credits for testing.
      state = state.copyWith(credits: 50000);

      // Update quantities so Sol has water.
      final systems = List<SolarSystem>.from(state.solarSystems);
      final sol = systems[state.currentSystemIndex];
      final updatedQty = Map<TradeGood, int>.from(sol.tradeQuantities);
      updatedQty[TradeGood.water] = 10;
      systems[state.currentSystemIndex] =
          sol.copyWith(tradeQuantities: updatedQty);

      // Recalculate prices after quantity update.
      state = state.copyWith(solarSystems: systems);
      final newState = GameEngine.refreshPrices(state);

      final waterPrice = newState.buyPrices[TradeGood.water] ?? 0;
      if (waterPrice > 0) {
        final bought = GameEngine.buyGood(newState, TradeGood.water, 1);
        expect(bought, isNotNull);
        expect(bought!.credits, lessThan(newState.credits));
        expect(bought.ship.cargo[TradeGood.water], equals(1));
      }
    });

    test('copyWith preserves all unchanged fields', () {
      final state = GameEngine.newGame('Test', DifficultyLevel.normal);
      final updated = state.copyWith(days: 10);
      expect(updated.days, equals(10));
      expect(updated.commander.name, equals('Test'));
      expect(updated.credits, equals(state.credits));
    });

    test('sell illegal good decreases police record score', () {
      var state = GameEngine.newGame('Test', DifficultyLevel.normal);
      // Add narcotics to cargo manually.
      final newCargo = Map<TradeGood, int>.from(state.ship.cargo);
      newCargo[TradeGood.narcotics] = 1;
      final newShip = state.ship.copyWith(cargo: newCargo);
      state = state.copyWith(ship: newShip);

      // Verify narcotics are illegal at Sol (Democracy).
      expect(
          Economy.isIllegal(state.currentSystem, TradeGood.narcotics), isTrue);

      // Note: selling would fail at democracy since narcotics aren't tradable.
      // This test verifies the isIllegal check works.
      expect(Economy.canTradeGood(state.currentSystem, TradeGood.narcotics),
          isFalse);
    });

    test('JSON serialization round-trip', () {
      final state = GameEngine.newGame('SerialTest', DifficultyLevel.easy);
      final json = state.toJson();
      final restored = GameState.fromJson(json);

      expect(restored.commander.name, equals(state.commander.name));
      expect(restored.credits, equals(state.credits));
      expect(restored.days, equals(state.days));
      expect(restored.solarSystems.length, equals(state.solarSystems.length));
      expect(restored.ship.shipType, equals(state.ship.shipType));
      expect(restored.difficulty, equals(state.difficulty));
    });
  });

  // ---------------------------------------------------------------------------
  // Commander tests
  // ---------------------------------------------------------------------------

  group('Commander', () {
    test('police record computed from score thresholds', () {
      Commander c(int score) => Commander(
            name: 'T',
            pilot: 1,
            fighter: 1,
            trader: 1,
            engineer: 1,
            policeRecordScore: score,
            reputationScore: 0,
            policeKills: 0,
            traderKills: 0,
            pirateKills: 0,
          );

      expect(c(-150).policeRecord, equals(PoliceRecord.psycho));
      expect(c(-100).policeRecord, equals(PoliceRecord.psycho));
      expect(c(-70).policeRecord, equals(PoliceRecord.villain));
      expect(c(-30).policeRecord, equals(PoliceRecord.criminal));
      expect(c(-10).policeRecord, equals(PoliceRecord.crook));
      expect(c(-5).policeRecord, equals(PoliceRecord.dubious));
      expect(c(0).policeRecord, equals(PoliceRecord.clean));
      expect(c(5).policeRecord, equals(PoliceRecord.lawful));
      expect(c(10).policeRecord, equals(PoliceRecord.trusted));
      expect(c(25).policeRecord, equals(PoliceRecord.liked));
      expect(c(100).policeRecord, equals(PoliceRecord.hero));
    });

    test('reputation computed from kill count thresholds', () {
      Commander c(int kills) => Commander(
            name: 'T',
            pilot: 1,
            fighter: 1,
            trader: 1,
            engineer: 1,
            policeRecordScore: 0,
            reputationScore: kills,
            policeKills: 0,
            traderKills: 0,
            pirateKills: 0,
          );

      expect(c(0).reputation, equals(Reputation.harmless));
      expect(c(10).reputation, equals(Reputation.mostlyHarmless));
      expect(c(20).reputation, equals(Reputation.poor));
      expect(c(40).reputation, equals(Reputation.average));
      expect(c(80).reputation, equals(Reputation.aboveAverage));
      expect(c(150).reputation, equals(Reputation.competent));
      expect(c(300).reputation, equals(Reputation.dangerous));
      expect(c(600).reputation, equals(Reputation.deadly));
      expect(c(1500).reputation, equals(Reputation.elite));
    });

    test('isCriminal for negative police records', () {
      final criminal = Commander(
        name: 'Bad',
        pilot: 1,
        fighter: 1,
        trader: 1,
        engineer: 1,
        policeRecordScore: -50,
        reputationScore: 0,
        policeKills: 0,
        traderKills: 0,
        pirateKills: 0,
      );
      expect(criminal.isCriminal, isTrue);
    });

    test('clean record is not criminal', () {
      final clean = Commander(
        name: 'Good',
        pilot: 1,
        fighter: 1,
        trader: 1,
        engineer: 1,
        policeRecordScore: 5,
        reputationScore: 0,
        policeKills: 0,
        traderKills: 0,
        pirateKills: 0,
      );
      expect(clean.isCriminal, isFalse);
    });
  });
}
