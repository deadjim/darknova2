// Pure Dart — no Flutter imports
import 'enums.dart';

class Commander {
  final String name;
  final int pilot;
  final int fighter;
  final int trader;
  final int engineer;
  final int policeRecordScore;
  final int reputationScore; // total kills weighted
  final int policeKills;
  final int traderKills;
  final int pirateKills;

  const Commander({
    required this.name,
    required this.pilot,
    required this.fighter,
    required this.trader,
    required this.engineer,
    required this.policeRecordScore,
    required this.reputationScore,
    required this.policeKills,
    required this.traderKills,
    required this.pirateKills,
  });

  /// Police record based on score thresholds from original Space Trader.
  /// Psycho ≤ -100, Villain ≤ -70, Criminal ≤ -30, Crook ≤ -10,
  /// Dubious ≤ -5, Clean ≤ 0, Lawful ≤ 5, Trusted ≤ 10,
  /// Liked ≤ 25, Hero > 25.
  PoliceRecord get policeRecord {
    final s = policeRecordScore;
    if (s <= -100) return PoliceRecord.psycho;
    if (s <= -70) return PoliceRecord.villain;
    if (s <= -30) return PoliceRecord.criminal;
    if (s <= -10) return PoliceRecord.crook;
    if (s <= -5) return PoliceRecord.dubious;
    if (s <= 0) return PoliceRecord.clean;
    if (s <= 5) return PoliceRecord.lawful;
    if (s <= 10) return PoliceRecord.trusted;
    if (s <= 25) return PoliceRecord.liked;
    return PoliceRecord.hero;
  }

  /// Reputation based on total kills from original Space Trader.
  /// Harmless 0, MostlyHarmless ≥10, Poor ≥20, Average ≥40,
  /// AboveAverage ≥80, Competent ≥150, Dangerous ≥300,
  /// Deadly ≥600, Elite ≥1500.
  Reputation get reputation {
    final k = reputationScore;
    if (k >= 1500) return Reputation.elite;
    if (k >= 600) return Reputation.deadly;
    if (k >= 300) return Reputation.dangerous;
    if (k >= 150) return Reputation.competent;
    if (k >= 80) return Reputation.aboveAverage;
    if (k >= 40) return Reputation.average;
    if (k >= 20) return Reputation.poor;
    if (k >= 10) return Reputation.mostlyHarmless;
    return Reputation.harmless;
  }

  int get totalKills => policeKills + traderKills + pirateKills;

  bool get isCriminal =>
      policeRecord == PoliceRecord.psycho ||
      policeRecord == PoliceRecord.villain ||
      policeRecord == PoliceRecord.criminal ||
      policeRecord == PoliceRecord.crook;

  bool get isWanted => policeRecordScore < 0;

  Commander copyWith({
    String? name,
    int? pilot,
    int? fighter,
    int? trader,
    int? engineer,
    int? policeRecordScore,
    int? reputationScore,
    int? policeKills,
    int? traderKills,
    int? pirateKills,
  }) {
    return Commander(
      name: name ?? this.name,
      pilot: pilot ?? this.pilot,
      fighter: fighter ?? this.fighter,
      trader: trader ?? this.trader,
      engineer: engineer ?? this.engineer,
      policeRecordScore: policeRecordScore ?? this.policeRecordScore,
      reputationScore: reputationScore ?? this.reputationScore,
      policeKills: policeKills ?? this.policeKills,
      traderKills: traderKills ?? this.traderKills,
      pirateKills: pirateKills ?? this.pirateKills,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'pilot': pilot,
      'fighter': fighter,
      'trader': trader,
      'engineer': engineer,
      'policeRecordScore': policeRecordScore,
      'reputationScore': reputationScore,
      'policeKills': policeKills,
      'traderKills': traderKills,
      'pirateKills': pirateKills,
    };
  }

  factory Commander.fromJson(Map<String, dynamic> json) {
    return Commander(
      name: json['name'] as String,
      pilot: json['pilot'] as int,
      fighter: json['fighter'] as int,
      trader: json['trader'] as int,
      engineer: json['engineer'] as int,
      policeRecordScore: json['policeRecordScore'] as int,
      reputationScore: json['reputationScore'] as int,
      policeKills: json['policeKills'] as int,
      traderKills: json['traderKills'] as int,
      pirateKills: json['pirateKills'] as int,
    );
  }

  /// Create a starting commander with skill points to distribute.
  factory Commander.starter(
      String name, int pilot, int fighter, int trader, int engineer) {
    return Commander(
      name: name,
      pilot: pilot,
      fighter: fighter,
      trader: trader,
      engineer: engineer,
      policeRecordScore: 0,
      reputationScore: 0,
      policeKills: 0,
      traderKills: 0,
      pirateKills: 0,
    );
  }
}
