// Pure Dart — no Flutter imports
import 'package:equatable/equatable.dart';

import 'commander.dart';
import 'enums.dart';
import 'game_event.dart';
import 'quest.dart';
import 'rival.dart';
import 'ship.dart';
import 'solar_system.dart';

class GameState extends Equatable {
  final Commander commander;
  final Ship ship;
  final int credits;
  final int debt;
  final int days;
  final int currentSystemIndex;
  final int galaxySeed;
  final DifficultyLevel difficulty;
  final List<SolarSystem> solarSystems;
  final int? warpTargetIndex;
  final Map<TradeGood, int> buyPrices;
  final Map<TradeGood, int> sellPrices;
  final bool escapePod;
  final bool insurance;
  final int noClaim; // days since last insurance claim
  final List<GameEvent> events; // the galaxy's ledger (capped)
  final List<RivalCaptain> rivals;
  final Quest? activeQuest;
  final Quest? questOffer;

  const GameState({
    required this.commander,
    required this.ship,
    required this.credits,
    required this.debt,
    required this.days,
    required this.currentSystemIndex,
    required this.galaxySeed,
    required this.difficulty,
    required this.solarSystems,
    this.warpTargetIndex,
    required this.buyPrices,
    required this.sellPrices,
    required this.escapePod,
    required this.insurance,
    required this.noClaim,
    this.events = const [],
    this.rivals = const [],
    this.activeQuest,
    this.questOffer,
  });

  SolarSystem get currentSystem => solarSystems[currentSystemIndex];

  int get netWorth {
    // credits + ship trade-in value (50% of price) + cargo approx - debt
    final shipValue = ship.def.price ~/ 2;
    final cargoApprox = ship.totalCargoUsed * 100;
    return credits + shipValue + cargoApprox - debt;
  }

  GameState copyWith({
    Commander? commander,
    Ship? ship,
    int? credits,
    int? debt,
    int? days,
    int? currentSystemIndex,
    int? galaxySeed,
    DifficultyLevel? difficulty,
    List<SolarSystem>? solarSystems,
    Object? warpTargetIndex = _sentinel,
    Map<TradeGood, int>? buyPrices,
    Map<TradeGood, int>? sellPrices,
    bool? escapePod,
    bool? insurance,
    int? noClaim,
    List<GameEvent>? events,
    List<RivalCaptain>? rivals,
    Object? activeQuest = _sentinel,
    Object? questOffer = _sentinel,
  }) {
    return GameState(
      commander: commander ?? this.commander,
      ship: ship ?? this.ship,
      credits: credits ?? this.credits,
      debt: debt ?? this.debt,
      days: days ?? this.days,
      currentSystemIndex: currentSystemIndex ?? this.currentSystemIndex,
      galaxySeed: galaxySeed ?? this.galaxySeed,
      difficulty: difficulty ?? this.difficulty,
      solarSystems: solarSystems ?? List.from(this.solarSystems),
      warpTargetIndex: warpTargetIndex == _sentinel
          ? this.warpTargetIndex
          : warpTargetIndex as int?,
      buyPrices: buyPrices ?? Map.from(this.buyPrices),
      sellPrices: sellPrices ?? Map.from(this.sellPrices),
      escapePod: escapePod ?? this.escapePod,
      insurance: insurance ?? this.insurance,
      noClaim: noClaim ?? this.noClaim,
      events: events ?? this.events,
      rivals: rivals ?? this.rivals,
      activeQuest:
          activeQuest == _sentinel ? this.activeQuest : activeQuest as Quest?,
      questOffer:
          questOffer == _sentinel ? this.questOffer : questOffer as Quest?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'commander': commander.toJson(),
      'ship': ship.toJson(),
      'credits': credits,
      'debt': debt,
      'days': days,
      'currentSystemIndex': currentSystemIndex,
      'galaxySeed': galaxySeed,
      'difficulty': difficulty.index,
      'solarSystems': solarSystems.map((s) => s.toJson()).toList(),
      'warpTargetIndex': warpTargetIndex,
      'buyPrices': buyPrices.map((k, v) => MapEntry(k.index.toString(), v)),
      'sellPrices': sellPrices.map((k, v) => MapEntry(k.index.toString(), v)),
      'escapePod': escapePod,
      'insurance': insurance,
      'noClaim': noClaim,
      'events': events.map((e) => e.toJson()).toList(),
      'rivals': rivals.map((r) => r.toJson()).toList(),
      'activeQuest': activeQuest?.toJson(),
      'questOffer': questOffer?.toJson(),
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    final rawBuy = json['buyPrices'] as Map<String, dynamic>;
    final rawSell = json['sellPrices'] as Map<String, dynamic>;
    final buyPrices = <TradeGood, int>{};
    final sellPrices = <TradeGood, int>{};
    rawBuy.forEach((k, v) => buyPrices[TradeGood.values[int.parse(k)]] = v as int);
    rawSell.forEach((k, v) => sellPrices[TradeGood.values[int.parse(k)]] = v as int);
    return GameState(
      commander: Commander.fromJson(json['commander'] as Map<String, dynamic>),
      ship: Ship.fromJson(json['ship'] as Map<String, dynamic>),
      credits: json['credits'] as int,
      debt: json['debt'] as int,
      days: json['days'] as int,
      currentSystemIndex: json['currentSystemIndex'] as int,
      galaxySeed: json['galaxySeed'] as int,
      difficulty: DifficultyLevel.values[json['difficulty'] as int],
      solarSystems: (json['solarSystems'] as List)
          .map((s) => SolarSystem.fromJson(s as Map<String, dynamic>))
          .toList(),
      warpTargetIndex: json['warpTargetIndex'] as int?,
      buyPrices: buyPrices,
      sellPrices: sellPrices,
      escapePod: json['escapePod'] as bool,
      insurance: json['insurance'] as bool,
      noClaim: json['noClaim'] as int,
      events: (json['events'] as List? ?? const [])
          .map((e) => GameEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      rivals: (json['rivals'] as List? ?? const [])
          .map((r) => RivalCaptain.fromJson(r as Map<String, dynamic>))
          .toList(),
      activeQuest: json['activeQuest'] == null
          ? null
          : Quest.fromJson(json['activeQuest'] as Map<String, dynamic>),
      questOffer: json['questOffer'] == null
          ? null
          : Quest.fromJson(json['questOffer'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [
        commander,
        ship,
        credits,
        debt,
        days,
        currentSystemIndex,
        galaxySeed,
        difficulty,
        warpTargetIndex,
        escapePod,
        insurance,
        noClaim,
        events,
        rivals,
        activeQuest,
        questOffer,
      ];
}

const Object _sentinel = Object();
