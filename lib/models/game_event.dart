// Pure Dart — no Flutter imports

/// Kinds of things the galaxy might (or might not) find out about.
enum GameEventType {
  pirateDestroyed,
  policeDestroyed,
  traderDestroyed,
  monsterDestroyed,
  playerShipLost, // escape pod used
  surrenderedToPirates,
  inspectionBusted,
  inspectionClean,
  policeBribed,
  fledCombat, // the player ran — and was seen running
  enemyEscaped, // an opponent got away to tell the tale
  rivalSpared, // a named rival escaped or was let go
  rivalDefeated,
  questAccepted,
  questCompleted,
  questFailed,
  rescuePerformed, // answered a mayday — heroism, witnessed
  maydayIgnored, // jumped past a distress call and someone lived to say so
  derelictSalvaged, // quiet salvage, no one watching
  cargoSeized, // handed quest cargo to an interdictor
}

/// One entry in the galaxy's event ledger.
///
/// [witnessed] is the load-bearing bit: only witnessed events are public —
/// they can appear in the news, shape how NPCs treat the player, and feed
/// quest triggers. Unwitnessed events are the player's secrets.
class GameEvent {
  final int day;
  final GameEventType type;
  final int systemIndex;
  final bool witnessed;
  final String? rivalId;
  final String? detail; // short free-text used by news/quest generators

  const GameEvent({
    required this.day,
    required this.type,
    required this.systemIndex,
    required this.witnessed,
    this.rivalId,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'type': type.index,
        'systemIndex': systemIndex,
        'witnessed': witnessed,
        'rivalId': rivalId,
        'detail': detail,
      };

  factory GameEvent.fromJson(Map<String, dynamic> json) => GameEvent(
        day: json['day'] as int,
        type: GameEventType.values[json['type'] as int],
        systemIndex: json['systemIndex'] as int,
        witnessed: json['witnessed'] as bool,
        rivalId: json['rivalId'] as String?,
        detail: json['detail'] as String?,
      );
}
