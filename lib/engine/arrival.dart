// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/enums.dart';
import '../models/game_event.dart';
import '../models/game_state.dart';
import '../models/government_def.dart';
import '../models/quest.dart';
import '../models/rival.dart';
import 'encounter.dart';
import 'events.dart';
import 'game_engine.dart';
import 'quests.dart';
import 'rivals.dart';

/// What kind of moment interrupts the warp exit.
enum VignetteKind { distressCall, derelict, questComplication }

/// Engine-resolvable choices. The UI shows buttons for exactly these;
/// resolution is dice + locked stakes, never wording.
enum VignetteChoice {
  respond,
  scan,
  jumpAway,
  board,
  leave,
  surrenderCargo,
  fight,
  evade,
}

/// A vignette with its stakes pre-rolled at creation time. Whether the
/// distress call is a trap is decided *before* the player sees it —
/// scanning reveals information, it doesn't reroll fate.
class ArrivalEvent {
  final VignetteKind kind;
  final String title;
  final String body;
  final String? hint; // set after a scan
  final List<VignetteChoice> choices;
  final bool trap; // distress: pirates baiting the beacon

  const ArrivalEvent({
    required this.kind,
    required this.title,
    required this.body,
    required this.choices,
    this.hint,
    this.trap = false,
  });

  ArrivalEvent withHint(String hint, List<VignetteChoice> choices) {
    return ArrivalEvent(
      kind: kind,
      title: title,
      body: body,
      hint: hint,
      choices: choices,
      trap: trap,
    );
  }
}

/// The result of resolving a vignette choice: updated game state, a line
/// of aftermath text, and optionally a combat handoff.
class VignetteResolution {
  final GameState game;
  final String text;
  final EncounterResult? combat;
  final ArrivalEvent? updated; // scan: same vignette, more information

  const VignetteResolution(this.game, this.text,
      {this.combat, this.updated});
}

/// One roll per warp: either a vignette, an encounter, or nothing.
class ArrivalOutcome {
  final ArrivalEvent? vignette;
  final EncounterResult? encounter;
  const ArrivalOutcome({this.vignette, this.encounter});

  static const nothing = ArrivalOutcome();
}

class ArrivalDirector {
  ArrivalDirector._();

  /// Priority: quest complications > rival ambush > distress/derelict >
  /// ordinary encounter roll. Exactly one interrupt per warp, maximum.
  static ArrivalOutcome roll(GameState state, Random rng) {
    // 1. Quest complication: someone knows what you're hauling.
    final quest = state.activeQuest;
    if (quest != null &&
        quest.template == QuestTemplate.delivery &&
        state.currentSystemIndex != quest.targetSystemIndex &&
        (state.ship.cargo[quest.good] ?? 0) >= quest.qty &&
        rng.nextInt(100) < 18) {
      return ArrivalOutcome(vignette: _complication(state, quest));
    }

    // 2. Rival ambush: a grudge past the boiling point picks its moment.
    final hunter = _angriestHunter(state);
    if (hunter != null && rng.nextInt(100) < 10 + hunter.grudge * 5) {
      return ArrivalOutcome(
        encounter: Encounter.generateEncounter(
          EncounterType.pirate,
          state.currentSystem,
          state.difficulty,
          forceShipType: RivalSystem.escalatedHull(hunter),
          rivalId: hunter.id,
          captainName: hunter.name,
        )._asAmbush(),
      );
    }

    // 3. Wayside vignettes, pushed harder in quiet stretches.
    final pressure = min(30, EventLedger.daysSinceLastEvent(state) * 3);
    if (rng.nextInt(100) < 8 + pressure ~/ 3) {
      return ArrivalOutcome(vignette: _distressCall(state, rng));
    }
    if (rng.nextInt(100) < 6 + pressure ~/ 3) {
      return ArrivalOutcome(vignette: _derelict(state));
    }

    // 4. Ordinary space: the classic encounter roll.
    final encounter = GameEngine.rollEncounter(state, rng);
    return ArrivalOutcome(encounter: encounter);
  }

  static RivalCaptain? _angriestHunter(GameState state) {
    final hunters =
        state.rivals.where((r) => r.alive && r.grudge >= 3).toList();
    if (hunters.isEmpty) return null;
    hunters.sort((a, b) => b.grudge.compareTo(a.grudge));
    return hunters.first;
  }

  // --- vignette construction (stakes locked here) ---

  static ArrivalEvent _distressCall(GameState state, Random rng) {
    final gov = GovernmentDef.forType(state.currentSystem.government);
    // Lawless space baits more beacons.
    final trapChance = 15 + gov.pirateStrength * 6;
    final trap = rng.nextInt(100) < trapChance;
    return ArrivalEvent(
      kind: VignetteKind.distressCall,
      title: 'DISTRESS CALL',
      body: 'You drop out of warp to a repeating mayday: a freighter '
          'venting atmosphere, running lights stuttering. '
          'Its transponder pleads for assistance on all channels.',
      choices: const [
        VignetteChoice.respond,
        VignetteChoice.scan,
        VignetteChoice.jumpAway,
      ],
      trap: trap,
    );
  }

  static ArrivalEvent _derelict(GameState state) {
    return ArrivalEvent(
      kind: VignetteKind.derelict,
      title: 'DERELICT',
      body: 'A dead ship hangs in the black — hull cold, reactor dark, '
          'no transponder. Whatever happened here happened fast. '
          'The airlock is intact.',
      choices: const [VignetteChoice.board, VignetteChoice.leave],
    );
  }

  static ArrivalEvent _complication(GameState state, Quest quest) {
    return ArrivalEvent(
      kind: VignetteKind.questComplication,
      title: 'INTERDICTION',
      body: 'A ship slides out of the shipping lane shadow and paints you '
          'with targeting lasers. The comm crackles: "We know what '
          'you\'re hauling for ${quest.giverName}. Jettison the '
          '${quest.good.displayName} and fly on, or we take it '
          'from the wreck."',
      choices: const [
        VignetteChoice.surrenderCargo,
        VignetteChoice.fight,
        VignetteChoice.evade,
      ],
    );
  }

  // --- resolution ---

  static VignetteResolution resolve(
      ArrivalEvent event, GameState state, VignetteChoice choice, Random rng) {
    switch (event.kind) {
      case VignetteKind.distressCall:
        return _resolveDistress(event, state, choice, rng);
      case VignetteKind.derelict:
        return _resolveDerelict(event, state, choice, rng);
      case VignetteKind.questComplication:
        return _resolveComplication(event, state, choice, rng);
    }
  }

  static VignetteResolution _resolveDistress(
      ArrivalEvent event, GameState state, VignetteChoice choice, Random rng) {
    switch (choice) {
      case VignetteChoice.scan:
        // Pilot skill reads the signal. High skill = reliable read.
        final accurate = rng.nextInt(10) < 4 + state.commander.pilot;
        final read = accurate ? event.trap : !event.trap;
        final hint = read
            ? 'Your sensors flag it: the distress pattern repeats a little '
                'too regularly, and the "venting" is cold. This smells '
                'like bait.'
            : 'Sensor sweep reads a genuine hull breach and live crew '
                'signatures aboard.';
        return VignetteResolution(
          state,
          '',
          updated: event.withHint(
              hint, const [VignetteChoice.respond, VignetteChoice.jumpAway]),
        );

      case VignetteChoice.respond:
        if (event.trap) {
          final pirates = Encounter.generateEncounter(
            EncounterType.pirate,
            state.currentSystem,
            state.difficulty,
          )._asAmbush();
          return VignetteResolution(
            state,
            'The "freighter" powers up clean and hot. The mayday dies '
                'mid-loop. It was bait — and you took it.',
            combat: pirates,
          );
        }
        final gratitude = 200 + rng.nextInt(600);
        var next = state.copyWith(
          credits: state.credits + gratitude,
          commander: state.commander.copyWith(
            policeRecordScore: state.commander.policeRecordScore + 1,
          ),
        );
        next = EventLedger.record(next, GameEventType.rescuePerformed,
            witnessed: true);
        return VignetteResolution(
          next,
          'You pull six crew out of a dying hull. The captain wires you '
              '$gratitude credits and your name goes out on the wire — '
              'the good way, for once.',
        );

      case VignetteChoice.jumpAway:
        if (event.trap) {
          // Nothing to feel bad about — and no one to tell.
          return VignetteResolution(
              state,
              'You burn past without answering. The beacon loops on '
                  'behind you, patient as a spider.');
        }
        // Real people. The engine rolls whether anyone survives to talk.
        final survivors = rng.nextInt(100) < 50;
        final next = EventLedger.record(
          state,
          GameEventType.maydayIgnored,
          witnessed: survivors,
        );
        return VignetteResolution(
          next,
          survivors
              ? 'You burn past without answering. Someone aboard that '
                  'wreck lives — and remembers your silhouette.'
              : 'You burn past without answering. The mayday fades to '
                  'static behind you. No one will ever know.',
        );

      default:
        return VignetteResolution(state, 'You move on.');
    }
  }

  static VignetteResolution _resolveDerelict(
      ArrivalEvent event, GameState state, VignetteChoice choice, Random rng) {
    if (choice != VignetteChoice.board) {
      return VignetteResolution(
          state,
          'You leave the dead ship to the dark. Some questions aren\'t '
              'worth the answers.');
    }

    final roll = rng.nextInt(100);
    // Quiet salvage: nobody sees any of this.
    if (roll < 30) {
      final credits = 300 + rng.nextInt(1200);
      var next = EventLedger.record(
          state.copyWith(credits: state.credits + credits),
          GameEventType.derelictSalvaged,
          witnessed: false);
      return VignetteResolution(
          next,
          'The crew lockers give up $credits credits in hard currency. '
              'The log is wiped. You take it and don\'t look back.');
    }
    if (roll < 50) {
      final goods = TradeGood.values[rng.nextInt(TradeGood.values.length)];
      final qty = min(2 + rng.nextInt(5), state.ship.availableCargoBays);
      if (qty > 0) {
        final cargo = Map<TradeGood, int>.from(state.ship.cargo);
        cargo[goods] = (cargo[goods] ?? 0) + qty;
        var next = EventLedger.record(
            state.copyWith(ship: state.ship.copyWith(cargo: cargo)),
            GameEventType.derelictSalvaged,
            witnessed: false);
        return VignetteResolution(next,
            'The hold still carries $qty units of ${goods.displayName}. '
            'Yours now.');
      }
      return VignetteResolution(
          state,
          'The hold is full of cargo — and yours is full too. '
              'You leave a fortune floating.');
    }
    if (roll < 65) {
      // Hazard: something in there bites.
      final dmg = max(1, state.ship.hullStrength ~/ 5);
      final next = state.copyWith(
          ship: state.ship
              .copyWith(hullStrength: max(1, state.ship.hullStrength - dmg)));
      return VignetteResolution(
          next,
          'A pressure door lets go as you cycle the lock — the blowout '
              'slams your ship against the derelict\'s hull for $dmg damage. '
              'Whatever\'s left inside, it can keep.');
    }
    if (roll < 80 &&
        state.activeQuest == null &&
        state.questOffer == null) {
      final contract = QuestSystem.freightContract(state, rng);
      if (contract != null) {
        final next = state.copyWith(questOffer: contract);
        return VignetteResolution(
            next,
            'The flight recorder survived. Its manifest points to an '
                'undelivered contract — one that still pays. The details '
                'are waiting in your quarters.');
      }
    }
    return VignetteResolution(
        state,
        'Picked clean, long ago. Scorch marks on the inner hull tell '
            'the rest of the story.');
  }

  static VignetteResolution _resolveComplication(
      ArrivalEvent event, GameState state, VignetteChoice choice, Random rng) {
    final quest = state.activeQuest;
    if (quest == null) {
      return VignetteResolution(state, 'The interdictor loses interest.');
    }

    switch (choice) {
      case VignetteChoice.surrenderCargo:
        final cargo = Map<TradeGood, int>.from(state.ship.cargo);
        final remaining = (cargo[quest.good] ?? 0) - quest.qty;
        if (remaining <= 0) {
          cargo.remove(quest.good);
        } else {
          cargo[quest.good] = remaining;
        }
        var next = state.copyWith(
          ship: state.ship.copyWith(cargo: cargo),
          activeQuest: null,
          commander: state.commander.copyWith(
            policeRecordScore:
                state.commander.policeRecordScore - quest.failRecordPenalty,
            reputationScore: max(0,
                state.commander.reputationScore - quest.failReputationPenalty),
          ),
        );
        next = EventLedger.record(next, GameEventType.cargoSeized,
            witnessed: true, detail: quest.title);
        next = EventLedger.record(next, GameEventType.questFailed,
            witnessed: true, detail: quest.title);
        return VignetteResolution(
            next,
            'You jettison the ${quest.good.displayName} and watch them '
                'reel it in. The contract is dead — and word will travel.');

      case VignetteChoice.fight:
        final pirates = Encounter.generateEncounter(
          EncounterType.pirate,
          state.currentSystem,
          state.difficulty,
        );
        return VignetteResolution(
          state,
          'You answer with your weapons array. They wanted the cargo — '
              'now they\'ll have to earn it.',
          combat: pirates,
        );

      case VignetteChoice.evade:
        final escaped = rng.nextInt(state.commander.pilot + 5) >=
            rng.nextInt(6 + state.difficulty.index * 2);
        if (escaped) {
          return VignetteResolution(
              state,
              'You firewall the throttle and thread the traffic lane. '
                  'Their targeting solution dissolves behind you.');
        }
        final pirates = Encounter.generateEncounter(
          EncounterType.pirate,
          state.currentSystem,
          state.difficulty,
        )._asAmbush();
        return VignetteResolution(
          state,
          'Not fast enough. They cut the angle and open fire.',
          combat: pirates,
        );

      default:
        return VignetteResolution(state, 'You hold your course.');
    }
  }
}

extension on EncounterResult {
  EncounterResult _asAmbush() => EncounterResult(
        type: type,
        npcShip: npcShip,
        npcFleeing: false,
        rivalId: rivalId,
        captainName: captainName,
        ambush: true,
      );
}
