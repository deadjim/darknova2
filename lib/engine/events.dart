// Pure Dart — no Flutter imports
import '../models/game_event.dart';
import '../models/game_state.dart';

class EventLedger {
  EventLedger._();

  /// Keep the ledger bounded so save files stay small.
  static const int maxEvents = 200;

  /// Append an event to the ledger, trimming the oldest past the cap.
  static GameState record(
    GameState state,
    GameEventType type, {
    required bool witnessed,
    String? rivalId,
    String? detail,
  }) {
    final event = GameEvent(
      day: state.days,
      type: type,
      systemIndex: state.currentSystemIndex,
      witnessed: witnessed,
      rivalId: rivalId,
      detail: detail,
    );
    var events = [...state.events, event];
    if (events.length > maxEvents) {
      events = events.sublist(events.length - maxEvents);
    }
    return state.copyWith(events: events);
  }

  /// What the galaxy knows: witnessed events only, newest first.
  static List<GameEvent> publicEvents(GameState state) =>
      state.events.where((e) => e.witnessed).toList().reversed.toList();

  /// Days since anything at all landed in the ledger (drama-director input).
  static int daysSinceLastEvent(GameState state) => state.events.isEmpty
      ? state.days
      : state.days - state.events.last.day;
}
