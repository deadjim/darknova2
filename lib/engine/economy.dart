// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/commander.dart';
import '../models/enums.dart';
import '../models/government_def.dart';
import '../models/solar_system.dart';
import '../models/trade_item_def.dart';

class Economy {
  Economy._();

  /// Calculate buy price for a good at a given system.
  /// Formula: base + (techLevel × priceInc) ± variance%
  ///   × 2 if status matches doublePriceStatus
  ///   × 0.5 if resource matches cheapResource
  ///   × 1.25 if resource matches expensiveResource
  /// Then clamped to [minTradePrice, maxTradePrice].
  /// Trader skill reduces buy price by up to 5%.
  static int calculateBuyPrice(
      SolarSystem system, TradeGood good, Commander commander) {
    if (!canTradeGood(system, good)) return 0;
    final def = TradeItemDef.forGood(good);
    final rng = _deterministicRng(system, good, 'buy');

    double price =
        def.priceLowTech.toDouble() + (system.techLevel * def.priceInc);

    // Variance ±variance%.
    if (def.variance > 0) {
      final vRange = (price * def.variance / 100).abs();
      price += rng.nextDouble() * vRange * 2 - vRange;
    }

    // Status doubles price.
    if (def.doublePriceStatus != null &&
        system.status == def.doublePriceStatus) {
      price *= 2.0;
    }

    // Cheap resource halves price.
    if (def.cheapResource != null &&
        system.specialResource == def.cheapResource) {
      price *= 0.5;
    }

    // Expensive resource raises price by 25%.
    if (def.expensiveResource != null &&
        system.specialResource == def.expensiveResource) {
      price *= 1.25;
    }

    // Trader skill reduces buy price (1% per skill point above 1, max 5%).
    final traderBonus = ((commander.trader - 1).clamp(0, 10) * 0.01)
        .clamp(0.0, 0.05);
    price *= (1.0 - traderBonus);

    // Clamp and round to nearest roundOff.
    price = price.clamp(
        def.minTradePrice.toDouble(), def.maxTradePrice.toDouble());
    final rounded = (price / def.roundOff).round() * def.roundOff;
    return rounded.clamp(def.minTradePrice, def.maxTradePrice);
  }

  /// Sell price is slightly lower than buy price.
  /// Trader skill increases sell price by up to 5%.
  static int calculateSellPrice(
      SolarSystem system, TradeGood good, Commander commander) {
    if (!canTradeGood(system, good)) return 0;
    final def = TradeItemDef.forGood(good);

    // Sell price = ~90% of buy price (market spread), then trader bonus.
    final buyPrice = calculateBuyPrice(system, good, commander);
    if (buyPrice == 0) return 0;

    final traderBonus = ((commander.trader - 1).clamp(0, 10) * 0.01)
        .clamp(0.0, 0.05);
    double price = buyPrice * 0.9 * (1.0 + traderBonus);
    price = price.clamp(
        def.minTradePrice.toDouble(), def.maxTradePrice.toDouble());
    final rounded = (price / def.roundOff).round() * def.roundOff;
    return rounded.clamp(def.minTradePrice, def.maxTradePrice);
  }

  /// Can a given good be traded at this system?
  static bool canTradeGood(SolarSystem system, TradeGood good) {
    final def = TradeItemDef.forGood(good);
    final govDef = GovernmentDef.forType(system.government);

    // Tech level check: system must meet minimum usage tech.
    if (system.techLevel < def.techUsage) return false;

    // Illegal goods.
    if (good == TradeGood.narcotics && !govDef.drugsOK) return false;
    if (good == TradeGood.firearms && !govDef.firearmsOK) return false;

    return true;
  }

  /// Check if a good is illegal at a system.
  static bool isIllegal(SolarSystem system, TradeGood good) {
    final govDef = GovernmentDef.forType(system.government);
    if (good == TradeGood.narcotics && !govDef.drugsOK) return true;
    if (good == TradeGood.firearms && !govDef.firearmsOK) return true;
    return false;
  }

  /// Calculate all buy prices for a system.
  static Map<TradeGood, int> systemBuyPrices(
      SolarSystem system, Commander commander) {
    final prices = <TradeGood, int>{};
    for (final good in TradeGood.values) {
      prices[good] = calculateBuyPrice(system, good, commander);
    }
    return prices;
  }

  /// Calculate all sell prices for a system.
  static Map<TradeGood, int> systemSellPrices(
      SolarSystem system, Commander commander) {
    final prices = <TradeGood, int>{};
    for (final good in TradeGood.values) {
      prices[good] = calculateSellPrice(system, good, commander);
    }
    return prices;
  }

  /// Slow drift of trade quantities each time a warp occurs.
  /// Each system slowly regenerates goods and sometimes drops quantities.
  static List<SolarSystem> updateQuantities(List<SolarSystem> systems) {
    final rng = Random();
    return systems.map((system) {
      final govDef = GovernmentDef.forType(system.government);
      final updated = <TradeGood, int>{};
      for (final good in TradeGood.values) {
        final current = system.tradeQuantities[good] ?? 0;
        if (!canTradeGood(system, good)) {
          updated[good] = 0;
          continue;
        }
        // Drift: +1 to +3 restock, sometimes -1 due to local consumption.
        final def = TradeItemDef.forGood(good);
        int qty = current;
        if (rng.nextInt(10) < 7) {
          qty += rng.nextInt(3) + 1; // restock
        } else {
          qty -= rng.nextInt(2); // consumption
        }
        // Cap at size-based maximum.
        final govPenalty =
            (good == govDef.wantedGood) ? system.size * 2 : 0;
        final max = system.size * 10 + govPenalty;
        updated[good] = qty.clamp(0, max);
      }

      // Countdown tick — update status periodically.
      final newCountdown = system.countdown - 1;
      if (newCountdown <= 0) {
        final newStatus = _tickStatus(system.status, rng);
        return system.copyWith(
          tradeQuantities: updated,
          status: newStatus,
          countdown: 3 + rng.nextInt(5),
        );
      }
      return system.copyWith(
          tradeQuantities: updated, countdown: newCountdown);
    }).toList();
  }

  static SystemStatus _tickStatus(SystemStatus current, Random rng) {
    // 60% chance to become uneventful, 40% random new status.
    if (rng.nextInt(10) < 6) return SystemStatus.uneventful;
    return SystemStatus.values[rng.nextInt(SystemStatus.values.length)];
  }

  /// Generate a deterministic-ish RNG for price variance based on system/good.
  /// In a real save we'd store prices; this gives stable prices within a session.
  static Random _deterministicRng(
      SolarSystem system, TradeGood good, String suffix) {
    // Use system coordinates + tech level + good index as seed.
    final seed = system.x * 31 +
        system.y * 17 +
        system.techLevel * 7 +
        good.index * 13 +
        suffix.hashCode;
    return Random(seed);
  }
}
