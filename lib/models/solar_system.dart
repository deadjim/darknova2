// Pure Dart — no Flutter imports
import 'enums.dart';

class SolarSystem {
  final String name;
  final int techLevel;        // 0-7
  final GovernmentType government;
  final SystemStatus status;
  final int x;
  final int y;
  final SpecialResource specialResource;
  final int size;             // 1-5
  final Map<TradeGood, int> tradeQuantities; // units available per good
  final int countdown;        // days until status change
  final bool visited;
  final int? specialEvent;    // index into special events list, null if none

  const SolarSystem({
    required this.name,
    required this.techLevel,
    required this.government,
    required this.status,
    required this.x,
    required this.y,
    required this.specialResource,
    required this.size,
    required this.tradeQuantities,
    required this.countdown,
    required this.visited,
    this.specialEvent,
  });

  SolarSystem copyWith({
    String? name,
    int? techLevel,
    GovernmentType? government,
    SystemStatus? status,
    int? x,
    int? y,
    SpecialResource? specialResource,
    int? size,
    Map<TradeGood, int>? tradeQuantities,
    int? countdown,
    bool? visited,
    Object? specialEvent = _sentinel,
  }) {
    return SolarSystem(
      name: name ?? this.name,
      techLevel: techLevel ?? this.techLevel,
      government: government ?? this.government,
      status: status ?? this.status,
      x: x ?? this.x,
      y: y ?? this.y,
      specialResource: specialResource ?? this.specialResource,
      size: size ?? this.size,
      tradeQuantities: tradeQuantities ?? Map.from(this.tradeQuantities),
      countdown: countdown ?? this.countdown,
      visited: visited ?? this.visited,
      specialEvent:
          specialEvent == _sentinel ? this.specialEvent : specialEvent as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'techLevel': techLevel,
      'government': government.index,
      'status': status.index,
      'x': x,
      'y': y,
      'specialResource': specialResource.index,
      'size': size,
      'tradeQuantities': tradeQuantities
          .map((k, v) => MapEntry(k.index.toString(), v)),
      'countdown': countdown,
      'visited': visited,
      'specialEvent': specialEvent,
    };
  }

  factory SolarSystem.fromJson(Map<String, dynamic> json) {
    final rawQty = json['tradeQuantities'] as Map<String, dynamic>;
    final tradeQuantities = <TradeGood, int>{};
    rawQty.forEach((k, v) {
      final idx = int.parse(k);
      tradeQuantities[TradeGood.values[idx]] = v as int;
    });
    return SolarSystem(
      name: json['name'] as String,
      techLevel: json['techLevel'] as int,
      government: GovernmentType.values[json['government'] as int],
      status: SystemStatus.values[json['status'] as int],
      x: json['x'] as int,
      y: json['y'] as int,
      specialResource:
          SpecialResource.values[json['specialResource'] as int],
      size: json['size'] as int,
      tradeQuantities: tradeQuantities,
      countdown: json['countdown'] as int,
      visited: json['visited'] as bool,
      specialEvent: json['specialEvent'] as int?,
    );
  }

  @override
  String toString() => 'SolarSystem($name, tech=$techLevel, '
      'gov=${government.name}, status=${status.name})';
}

// Sentinel for copyWith null-passthrough on nullable fields.
const Object _sentinel = Object();
