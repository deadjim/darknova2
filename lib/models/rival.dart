// Pure Dart — no Flutter imports
import 'enums.dart';

/// How a rival captain carries themselves — flavors dialogue and, later,
/// the LLM's characterization. Engine-side it nudges behavior slightly.
enum RivalTemperament {
  coldProfessional,
  theatrical,
  vengeful,
  honorable,
  unhinged,
}

/// A named captain who persists across encounters. Rivals remember.
class RivalCaptain {
  final String id;
  final String name;
  final ShipType shipType;
  final RivalTemperament temperament;
  final int timesMet;
  final int timesSpared; // player let them live / they escaped
  final int grudge; // >0 they hate you, <0 they owe you
  final bool alive;
  final int lastSeenDay;

  const RivalCaptain({
    required this.id,
    required this.name,
    required this.shipType,
    required this.temperament,
    required this.timesMet,
    required this.timesSpared,
    required this.grudge,
    required this.alive,
    required this.lastSeenDay,
  });

  RivalCaptain copyWith({
    ShipType? shipType,
    int? timesMet,
    int? timesSpared,
    int? grudge,
    bool? alive,
    int? lastSeenDay,
  }) {
    return RivalCaptain(
      id: id,
      name: name,
      shipType: shipType ?? this.shipType,
      temperament: temperament,
      timesMet: timesMet ?? this.timesMet,
      timesSpared: timesSpared ?? this.timesSpared,
      grudge: grudge ?? this.grudge,
      alive: alive ?? this.alive,
      lastSeenDay: lastSeenDay ?? this.lastSeenDay,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shipType': shipType.index,
        'temperament': temperament.index,
        'timesMet': timesMet,
        'timesSpared': timesSpared,
        'grudge': grudge,
        'alive': alive,
        'lastSeenDay': lastSeenDay,
      };

  factory RivalCaptain.fromJson(Map<String, dynamic> json) => RivalCaptain(
        id: json['id'] as String,
        name: json['name'] as String,
        shipType: ShipType.values[json['shipType'] as int],
        temperament: RivalTemperament.values[json['temperament'] as int],
        timesMet: json['timesMet'] as int,
        timesSpared: json['timesSpared'] as int,
        grudge: json['grudge'] as int,
        alive: json['alive'] as bool,
        lastSeenDay: json['lastSeenDay'] as int,
      );
}
