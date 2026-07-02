// Pure Dart — no Flutter imports
import 'enums.dart';

class TradeItemDef {
  final TradeGood good;
  final int techProduction; // min tech level to produce
  final int techUsage;      // min tech level to use/buy
  final int techTopProduction; // tech level with highest production
  final int priceLowTech;  // base price at tech level 0
  final int priceInc;      // price increase per tech level
  final int variance;      // max % variance
  final SystemStatus? doublePriceStatus; // status that doubles price
  final SpecialResource? cheapResource;   // resource that halves price
  final SpecialResource? expensiveResource; // resource that raises price
  final int minTradePrice;
  final int maxTradePrice;
  final int roundOff;

  const TradeItemDef({
    required this.good,
    required this.techProduction,
    required this.techUsage,
    required this.techTopProduction,
    required this.priceLowTech,
    required this.priceInc,
    required this.variance,
    this.doublePriceStatus,
    this.cheapResource,
    this.expensiveResource,
    required this.minTradePrice,
    required this.maxTradePrice,
    required this.roundOff,
  });

  /// All 10 trade goods as defined in the original Space Trader.
  static const List<TradeItemDef> all = [
    // Water
    TradeItemDef(
      good: TradeGood.water,
      techProduction: 0,
      techUsage: 0,
      techTopProduction: 2,
      priceLowTech: 30,
      priceInc: 3,
      variance: 4,
      doublePriceStatus: SystemStatus.drought,
      cheapResource: SpecialResource.sweetwaterOceans,
      expensiveResource: SpecialResource.desert,
      minTradePrice: 30,
      maxTradePrice: 300,
      roundOff: 3,
    ),
    // Furs
    TradeItemDef(
      good: TradeGood.furs,
      techProduction: 0,
      techUsage: 0,
      techTopProduction: 0,
      priceLowTech: 250,
      priceInc: 10,
      variance: 10,
      doublePriceStatus: SystemStatus.cold,
      cheapResource: SpecialResource.richFauna,
      expensiveResource: SpecialResource.lifeless,
      minTradePrice: 100,
      maxTradePrice: 800,
      roundOff: 10,
    ),
    // Food
    TradeItemDef(
      good: TradeGood.food,
      techProduction: 1,
      techUsage: 0,
      techTopProduction: 1,
      priceLowTech: 100,
      priceInc: 5,
      variance: 5,
      doublePriceStatus: SystemStatus.cropFailure,
      cheapResource: SpecialResource.richSoil,
      expensiveResource: SpecialResource.poorSoil,
      minTradePrice: 90,
      maxTradePrice: 600,
      roundOff: 5,
    ),
    // Ore
    TradeItemDef(
      good: TradeGood.ore,
      techProduction: 2,
      techUsage: 2,
      techTopProduction: 3,
      priceLowTech: 350,
      priceInc: 20,
      variance: 10,
      doublePriceStatus: SystemStatus.war,
      cheapResource: SpecialResource.mineralRich,
      expensiveResource: SpecialResource.mineralPoor,
      minTradePrice: 350,
      maxTradePrice: 800,
      roundOff: 20,
    ),
    // Games
    TradeItemDef(
      good: TradeGood.games,
      techProduction: 3,
      techUsage: 1,
      techTopProduction: 6,
      priceLowTech: 250,
      priceInc: -10,
      variance: 5,
      doublePriceStatus: SystemStatus.boredom,
      cheapResource: SpecialResource.artisticPopulace,
      expensiveResource: null,
      minTradePrice: 160,
      maxTradePrice: 300,
      roundOff: 5,
    ),
    // Firearms
    TradeItemDef(
      good: TradeGood.firearms,
      techProduction: 3,
      techUsage: 1,
      techTopProduction: 5,
      priceLowTech: 1250,
      priceInc: -75,
      variance: 100,
      doublePriceStatus: SystemStatus.war,
      cheapResource: SpecialResource.warlikePopulace,
      expensiveResource: null,
      minTradePrice: 600,
      maxTradePrice: 1300,
      roundOff: 25,
    ),
    // Medicine
    TradeItemDef(
      good: TradeGood.medicine,
      techProduction: 4,
      techUsage: 1,
      techTopProduction: 6,
      priceLowTech: 650,
      priceInc: -20,
      variance: 10,
      doublePriceStatus: SystemStatus.plague,
      cheapResource: SpecialResource.weirdMushrooms,
      expensiveResource: SpecialResource.lifeless,
      minTradePrice: 400,
      maxTradePrice: 700,
      roundOff: 10,
    ),
    // Machines
    TradeItemDef(
      good: TradeGood.machines,
      techProduction: 4,
      techUsage: 3,
      techTopProduction: 5,
      priceLowTech: 900,
      priceInc: -30,
      variance: 5,
      doublePriceStatus: SystemStatus.lackOfWorkers,
      cheapResource: null,
      expensiveResource: null,
      minTradePrice: 600,
      maxTradePrice: 1100,
      roundOff: 10,
    ),
    // Narcotics
    TradeItemDef(
      good: TradeGood.narcotics,
      techProduction: 5,
      techUsage: 0,
      techTopProduction: 5,
      priceLowTech: 3500,
      priceInc: -125,
      variance: 150,
      doublePriceStatus: SystemStatus.boredom,
      cheapResource: SpecialResource.weirdMushrooms,
      expensiveResource: SpecialResource.lifeless,
      minTradePrice: 2000,
      maxTradePrice: 3000,
      roundOff: 25,
    ),
    // Robots
    TradeItemDef(
      good: TradeGood.robots,
      techProduction: 6,
      techUsage: 4,
      techTopProduction: 7,
      priceLowTech: 5000,
      priceInc: -150,
      variance: 100,
      doublePriceStatus: SystemStatus.lackOfWorkers,
      cheapResource: null,
      expensiveResource: null,
      minTradePrice: 3500,
      maxTradePrice: 5000,
      roundOff: 100,
    ),
  ];

  static TradeItemDef forGood(TradeGood good) {
    return all.firstWhere((d) => d.good == good);
  }
}
