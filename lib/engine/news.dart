// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/enums.dart';
import '../models/game_event.dart';
import '../models/game_state.dart';
import 'travel.dart';

/// The Galactic News Network.
///
/// Headlines are built exclusively from *public* information: witnessed
/// ledger events and current system statuses. Unwitnessed deeds never
/// make the feed — that's the whole point.
///
/// Today the copy is canned templates; the LLM layer will rewrite the same
/// inputs into livelier prose. The information model doesn't change.
class NewsEngine {
  NewsEngine._();

  static const int maxHeadlines = 5;

  /// Game-balance note: the wire must be a *lead generator*, not a market
  /// scanner. If it reliably listed every nearby crisis, it would replace
  /// exploration as the way to find good trades. So crisis coverage is:
  ///   * capped at [maxCrisisHeadlines] per day,
  ///   * probabilistic, with odds that fall off with distance
  ///     (a plague two jumps away usually makes the feed; one across the
  ///     galaxy rarely does),
  ///   * deterministic per (galaxySeed, day), so the feed doesn't reroll
  ///     on every widget rebuild — it changes when the day does.
  /// Filler headlines pad the feed so the player can't infer "no crisis
  /// line = no crisis nearby".
  static const int maxCrisisHeadlines = 2;

  static const List<String> _filler = [
    'GALACTIC SENATE DEBATES FREIGHT TARIFF REFORM; NOTHING DECIDED',
    'CELEBRITY GNAT RACER ANNOUNCES RETIREMENT. AGAIN.',
    'STUDY: WORMHOLE TRANSIT "PROBABLY SAFE", SCIENTISTS SHRUG',
    'FUEL PRICES STEADY AS REFINERS DENY COLLUSION',
    'MISS GALAXY PAGEANT MARRED BY TRIBBLE INCIDENT',
    'INSURERS WARN: ESCAPE POD SALES OUTPACING COMMON SENSE',
    'DOCKWORKERS UNION THREATENS THIRD STRIKE THIS QUARTER',
    'ARCHAEOLOGISTS FIND ANCIENT VENDING MACHINE; STILL STOCKED',
    'POLL: 6 IN 10 SPACERS ADMIT NAPPING THROUGH WARP',
    'FASHION WIRE: MAGNETIC BOOTS ARE BACK',
  ];

  static List<String> headlines(GameState state) {
    final items = <String>[];
    // Stable within a day, fresh each day.
    final rng = Random(state.galaxySeed ^ (state.days * 0x9E3779B9));

    // Recent public events involving the player (newest first).
    final public = state.events
        .where((e) => e.witnessed && state.days - e.day <= 14)
        .toList()
        .reversed;
    for (final event in public) {
      final line = _eventHeadline(state, event);
      if (line != null) items.add(line);
      if (items.length >= 3) break;
    }

    // Galaxy status wire: a sample of nearby crises, not a scan.
    final here = state.currentSystem;
    final inCrisis = state.solarSystems
        .where((s) =>
            s.status != SystemStatus.uneventful && s != here)
        .toList()
      ..sort((a, b) => Travel.distance(here, a)
          .compareTo(Travel.distance(here, b)));
    var crisisCount = 0;
    for (final system in inCrisis) {
      if (crisisCount >= maxCrisisHeadlines ||
          items.length >= maxHeadlines) {
        break;
      }
      final dist = Travel.distance(here, system);
      // ~75% coverage next door, fading to a floor of 10% far away.
      final coverage = max(10, 75 - (dist * 1.5).round());
      if (rng.nextInt(100) >= coverage) continue;
      final line = _statusHeadline(system.name, system.status);
      if (line != null) {
        items.add(line);
        crisisCount++;
      }
    }

    // Pad with filler so a short feed doesn't leak information.
    final filler = List<String>.from(_filler)..shuffle(rng);
    for (final line in filler) {
      if (items.length >= maxHeadlines) break;
      items.add(line);
    }
    return items.take(maxHeadlines).toList();
  }

  static String? _eventHeadline(GameState state, GameEvent event) {
    final where = state.solarSystems[event.systemIndex].name.toUpperCase();
    final who = state.commander.name.toUpperCase();
    String? rival;
    if (event.rivalId != null) {
      for (final r in state.rivals) {
        if (r.id == event.rivalId) {
          rival = r.name.toUpperCase();
          break;
        }
      }
    }

    switch (event.type) {
      case GameEventType.enemyEscaped:
        return 'SHIP LIMPS INTO $where DOCK, CAPTAIN NAMES '
            '"$who" AS ATTACKER';
      case GameEventType.rivalSpared:
        return '${rival ?? "NOTORIOUS CAPTAIN"} SURVIVES CLASH NEAR $where '
            '— VOWS IT ISN\'T OVER';
      case GameEventType.fledCombat:
        return 'FREIGHTER "$who" SEEN FLEEING ENGAGEMENT NEAR $where';
      case GameEventType.surrenderedToPirates:
        return 'PIRATES STRIP TRADING VESSEL NEAR $where; '
            'CREW RELEASED UNHARMED';
      case GameEventType.inspectionBusted:
        return 'CUSTOMS SEIZE CONTRABAND AT $where; '
            'TRADER FINED, RECORD MARKED';
      case GameEventType.inspectionClean:
        return null; // routine inspections aren't news
      case GameEventType.playerShipLost:
        return 'RESCUE BEACON RECOVERED NEAR $where — '
            'CAPTAIN $who SURVIVES SHIP LOSS';
      case GameEventType.questCompleted:
        return 'GOOD NEWS WIRE: ${event.detail ?? "CONTRACT"} — FULFILLED';
      case GameEventType.questFailed:
        return 'CONTRACT DEFAULT REPORTED: ${event.detail ?? "UNNAMED JOB"}';
      case GameEventType.rescuePerformed:
        return 'HERO OF THE SPACEWAYS: CAPTAIN $who ANSWERS MAYDAY '
            'NEAR $where';
      case GameEventType.maydayIgnored:
        return 'SURVIVORS SPEAK: PASSING SHIP "$who" IGNORED MAYDAY '
            'NEAR $where';
      case GameEventType.cargoSeized:
        return 'INTERDICTION NEAR $where: CONTRACT CARGO SEIZED '
            'FROM FREIGHTER';
      // Unwitnessed-only types never reach here, but keep the switch total.
      case GameEventType.pirateDestroyed:
      case GameEventType.policeDestroyed:
      case GameEventType.traderDestroyed:
      case GameEventType.monsterDestroyed:
      case GameEventType.rivalDefeated:
      case GameEventType.policeBribed:
      case GameEventType.questAccepted:
      case GameEventType.derelictSalvaged:
        return null;
    }
  }

  static String? _statusHeadline(String system, SystemStatus status) {
    final name = system.toUpperCase();
    switch (status) {
      case SystemStatus.war:
        return 'FIGHTING INTENSIFIES AT $name — FOOD AND ARMS SCARCE';
      case SystemStatus.plague:
        return 'PLAGUE DECLARED ON $name; MEDICINE PRICES SOAR';
      case SystemStatus.drought:
        return 'DROUGHT GRIPS $name — WATER FUTURES CLIMB';
      case SystemStatus.cropFailure:
        return 'HARVEST FAILS ON $name; FOOD IMPORTS URGENT';
      case SystemStatus.cold:
        return 'BRUTAL WINTER ON $name DRIVES DEMAND FOR FURS';
      case SystemStatus.lackOfWorkers:
        return 'LABOR SHORTAGE ON $name; WAGES AND ROBOT SALES UP';
      case SystemStatus.boredom:
        return '$name DECLARES ENTERTAINMENT EMERGENCY; GAMES SELL OUT';
      case SystemStatus.uneventful:
        return null;
    }
  }
}
