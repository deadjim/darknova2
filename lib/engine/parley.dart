// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/enums.dart';
import '../models/game_event.dart';
import '../models/game_state.dart';
import '../models/government_def.dart';
import '../models/rival.dart';
import 'combat.dart';
import 'events.dart';
import 'rivals.dart';

/// What the player can say once a channel is open.
enum ParleyOption {
  payOff, // pirate tribute / police bribe
  bluff, // lie about cargo, escorts, credentials
  threaten, // scare them off with reputation and guns
  plead, // throw yourself on their mercy
  tradeInfo, // sell what you know
  comply, // submit to inspection / sign off politely
}

/// An open comm channel: the hail, the running transcript, and what the
/// player may still say. Stakes (like a pirate's tribute demand) are
/// locked when the channel opens — talking reveals outcomes, it doesn't
/// reroll them into existence.
class ParleySession {
  final EncounterType encounterType;
  final String? rivalId;
  final String? captainName;
  final List<String> transcript; // hail first, then exchanges
  final List<ParleyOption> options;
  final int demandCredits; // pirate tribute, locked at open (0 if n/a)

  const ParleySession({
    required this.encounterType,
    required this.transcript,
    required this.options,
    this.rivalId,
    this.captainName,
    this.demandCredits = 0,
  });

  ParleySession copyWith({
    List<String>? transcript,
    List<ParleyOption>? options,
  }) {
    return ParleySession(
      encounterType: encounterType,
      rivalId: rivalId,
      captainName: captainName,
      transcript: transcript ?? this.transcript,
      options: options ?? this.options,
      demandCredits: demandCredits,
    );
  }

  ParleySession say(String line) =>
      copyWith(transcript: [...transcript, line]);

  ParleySession withoutOption(ParleyOption option) => copyWith(
      options: options.where((o) => o != option).toList());
}

/// The outcome of one parley exchange. The engine is authoritative:
/// resolution and escalation both round-trip through [CombatState] and
/// [GameState] — prose is garnish.
class ParleyResult {
  final ParleySession session;
  final CombatState combat;
  final GameState game;
  final bool escalated; // channel closed, the fight is on

  const ParleyResult(this.session, this.combat, this.game,
      {this.escalated = false});

  /// The encounter ended in talk.
  bool get resolved => combat.isOver;

  /// The channel is closed one way or the other.
  bool get over => resolved || escalated;
}

/// Deterministic hailing/dialogue during encounters. Canned prose today;
/// the LLM layer will later rewrite the same lines — never the outcomes.
class ParleyDirector {
  ParleyDirector._();

  // --- hailability ---

  /// Not everyone picks up. Monsters can't talk, ambushers already said
  /// everything with their weapons lock, nobody chats mid-firefight, and
  /// a rival past boiling point is done with words.
  static bool canHail(CombatState c, GameState game) {
    if (c.isOver) return false;
    if (c.encounterType == EncounterType.monster) return false;
    // Shots fired (or an ambush opening line): the time for talk is over.
    if (c.log.isNotEmpty) return false;
    // A ship running for its life doesn't answer hails.
    if (c.npcFleeing) return false;
    final rival = _rival(c, game);
    if (rival != null && rival.grudge >= 6) return false;
    return true;
  }

  // --- opening the channel ---

  static ParleySession open(CombatState c, GameState game, Random rng) {
    switch (c.encounterType) {
      case EncounterType.pirate:
        return _openPirate(c, game, rng);
      case EncounterType.police:
        return _openPolice(c, game, rng);
      case EncounterType.trader:
        return _openTrader(c, game, rng);
      case EncounterType.monster:
        throw StateError('Monsters do not answer hails.');
    }
  }

  static ParleySession _openPirate(
      CombatState c, GameState game, Random rng) {
    // Tribute demand: locked at open. Scales with the pirate's hull class
    // and what the player visibly has to lose.
    final demand = _roundTo25(max(
        100, c.npcDef.bounty + game.credits ~/ 5 + rng.nextInt(201)));

    final rival = _rival(c, game);
    final String hail;
    if (rival != null) {
      hail = _rivalHail(rival, game, demand, rng);
    } else {
      hail = _pick(rng, [
        'A voice crackles over the open channel: "Nice ship. Shame about '
            'the escort you don\'t have. $demand credits and you fly on."',
        '"Cut engines, freighter. The toll on this lane is $demand '
            'credits. The alternative costs more."',
        '"You\'ve got two choices, captain: $demand credits, or we open '
            'your hull and count it ourselves."',
        '"Nothing personal. Wire $demand credits and we never met."',
      ]);
    }

    final options = <ParleyOption>[
      if (game.credits >= demand) ParleyOption.payOff,
      ParleyOption.bluff,
      ParleyOption.threaten,
      if (game.ship.cargo.isEmpty ||
          game.commander.reputation.index <= Reputation.mostlyHarmless.index)
        ParleyOption.plead,
    ];

    return ParleySession(
      encounterType: c.encounterType,
      rivalId: c.rivalId,
      captainName: c.captainName,
      transcript: [hail],
      options: options.take(4).toList(),
      demandCredits: demand,
    );
  }

  static String _rivalHail(
      RivalCaptain rival, GameState game, int demand, Random rng) {
    final name = game.commander.name;
    switch (rival.temperament) {
      case RivalTemperament.coldProfessional:
        return '"${rival.name} here. You know how this works, $name. '
            '$demand credits. I won\'t ask twice."';
      case RivalTemperament.theatrical:
        return '"$name! The void keeps throwing us together — it must be '
            'fate. Fate charges $demand credits today."';
      case RivalTemperament.vengeful:
        return '"Remember me, $name? ${rival.name}. I remember you. '
            '$demand credits might — might — buy my patience."';
      case RivalTemperament.honorable:
        return '"${rival.name}, calling the ${game.ship.def.displayName}. '
            'You\'ll get one fair warning, $name: $demand credits, or we '
            'settle this properly."';
      case RivalTemperament.unhinged:
        return '"heh. hehehe. $name. It\'s ${rival.name}. Wire $demand '
            'credits before I change my mind about the talking part."';
    }
  }

  static ParleySession _openPolice(
      CombatState c, GameState game, Random rng) {
    final gov = GovernmentDef.forType(game.currentSystem.government);
    final wanted = game.commander.isWanted;
    final hail = wanted
        ? _pick(rng, [
            '"Vessel, this is customs patrol. Your record precedes you. '
                'Heave to for inspection — and keep your hands where our '
                'scanners can see them."',
            '"Well, well. Patrol control shows priors, captain. Cut thrust '
                'and prepare to be boarded."',
          ])
        : _pick(rng, [
            '"This is customs patrol. Routine cargo inspection. Cut thrust '
                'and stand by for boarding, please."',
            '"Patrol hailing: random manifest check, captain. Comply and '
                'you\'ll be on your way in minutes."',
          ]);

    final options = <ParleyOption>[
      ParleyOption.comply,
      if (gov.bribeLevel > 0 && game.credits > 0) ParleyOption.payOff,
      ParleyOption.bluff,
      if (game.commander.pirateKills > 0) ParleyOption.tradeInfo,
    ];

    return ParleySession(
      encounterType: c.encounterType,
      rivalId: c.rivalId,
      captainName: c.captainName,
      transcript: [hail],
      options: options.take(4).toList(),
    );
  }

  static ParleySession _openTrader(
      CombatState c, GameState game, Random rng) {
    final hail = _pick(rng, [
      '"Ahoy there! ${c.npcDef.displayName} out of the inner lanes. '
          'Quiet stretch, isn\'t it? Got any news worth a credit?"',
      '"Fellow trader on your scope, captain. No trouble wanted — but '
          'we\'ll pay for market gossip if you\'re selling."',
      '"Channel\'s open, friend. Long haul, thin margins, you know how '
          'it is. What do you hear on the wire?"',
    ]);

    return ParleySession(
      encounterType: c.encounterType,
      rivalId: c.rivalId,
      captainName: c.captainName,
      transcript: [hail],
      options: const [
        ParleyOption.tradeInfo,
        ParleyOption.threaten,
        ParleyOption.comply,
      ],
    );
  }

  // --- dialogue resolution ---

  static ParleyResult choose(ParleySession s, CombatState c, GameState game,
      ParleyOption option, Random rng) {
    assert(s.options.contains(option), 'option not offered');
    switch (c.encounterType) {
      case EncounterType.pirate:
        return _choosePirate(s, c, game, option, rng);
      case EncounterType.police:
        return _choosePolice(s, c, game, option, rng);
      case EncounterType.trader:
        return _chooseTrader(s, c, game, option, rng);
      case EncounterType.monster:
        throw StateError('Monsters do not parley.');
    }
  }

  static ParleyResult _choosePirate(ParleySession s, CombatState c,
      GameState game, ParleyOption option, Random rng) {
    final npcSkill = _npcSkill(c, game.difficulty);
    final rival = _rival(c, game);

    switch (option) {
      case ParleyOption.payOff:
        var session = s
            .say('You wire the tribute: ${s.demandCredits} credits.')
            .say('"Pleasure doing business. Fly safe — lanes are '
                'dangerous."');
        var state = game.copyWith(credits: game.credits - s.demandCredits);
        // Paid tribute is a story the pirates are happy to spread.
        state = EventLedger.record(state, GameEventType.surrenderedToPirates,
            witnessed: true, rivalId: c.rivalId, detail: 'tribute');
        if (c.rivalId != null) {
          state = RivalSystem.updateRival(state, c.rivalId!,
              (r) => r.copyWith(grudge: r.grudge - 1));
        }
        final combat = c
            .addLog('You pay ${s.demandCredits} credits in tribute. '
                'The pirates break off.')
            .copyWith(outcome: CombatOutcome.bribed);
        return ParleyResult(session, combat, state);

      case ParleyOption.bluff:
        final success = _check(rng,
            skill: game.commander.trader, against: npcSkill + 2);
        if (success) {
          final session = s
              .say('You lie, fluently: the hold is empty, the ship is '
                  'bonded, and a naval escort is two minutes out.')
              .say('"...Not worth it. Consider this your lucky day."');
          // They leave believing there was nothing to take. No attacker
          // to name — the story isn't news.
          var state = EventLedger.record(game, GameEventType.enemyEscaped,
              witnessed: false, rivalId: c.rivalId, detail: 'bluffed');
          final combat = c
              .addLog('Your bluff lands. The '
                  '${c.npcDef.displayName} peels away.')
              .copyWith(outcome: CombatOutcome.departed);
          return ParleyResult(session, combat, state);
        }
        final session = s
            .say('You lie about escorts and empty holds.')
            .say('"Escort, huh? Funny — our scope says you\'re alone. '
                'Wrong answer."');
        return _escalate(session, c, game, rng,
            closing: 'They see through the bluff. Comms cut — '
                'weapons hot.');

      case ParleyOption.threaten:
        final repBonus = game.commander.reputation.index;
        final success = _check(rng,
            skill: game.commander.fighter + repBonus, against: npcSkill + 3);
        if (success) {
          final session = s
              .say('You read them your kill tally and charge your '
                  'forward battery, slowly, on an open channel.')
              .say('"...We\'ll find easier cargo. This isn\'t over."');
          var state = game;
          if (c.rivalId != null) {
            // Being backed down in public stings a rival's pride.
            state = RivalSystem.updateRival(state, c.rivalId!,
                (r) => r.copyWith(grudge: r.grudge + 1));
          }
          // They turn to run: back to the encounter, where letting them
          // go (or gunning them down) uses the normal combat machinery.
          final combat = c
              .addLog('Your threat lands. The ${c.npcDef.displayName} '
                  'breaks off and runs!')
              .copyWith(npcFleeing: true);
          return ParleyResult(session, combat, state, escalated: true);
        }
        final session = s
            .say('You read them your kill tally.')
            .say('"Big words for a ${game.ship.def.displayName}. '
                'Let\'s test them."');
        var state = game;
        if (c.rivalId != null) {
          state = RivalSystem.updateRival(state, c.rivalId!,
              (r) => r.copyWith(grudge: r.grudge + 1));
        }
        return _escalate(session, c, state, rng,
            closing: 'The threat backfires. Comms cut — weapons hot.');

      case ParleyOption.plead:
        final honorable = rival?.temperament == RivalTemperament.honorable;
        final pity = 2 +
            (honorable ? 4 : 0) +
            (game.ship.cargo.isEmpty ? 3 : 0) -
            game.difficulty.index;
        if (rng.nextInt(10) < pity) {
          final session = s
              .say('You lay it out plainly: thin hold, thinner margins, '
                  'a debt collector at every dock.')
              .say(honorable
                  ? '"There\'s no sport in this. Keep your credits, '
                      'captain. Next time, carry something worth taking."'
                  : '"Ugh. You\'re not even worth the fuel. Get out of '
                      'here."');
          var state = game;
          if (c.rivalId != null && honorable) {
            state = RivalSystem.updateRival(state, c.rivalId!,
                (r) => r.copyWith(grudge: r.grudge - 1));
          }
          state = EventLedger.record(state, GameEventType.enemyEscaped,
              witnessed: false, rivalId: c.rivalId, detail: 'pitied');
          final combat = c
              .addLog('They take pity — or lose interest. The '
                  '${c.npcDef.displayName} moves off.')
              .copyWith(outcome: CombatOutcome.departed);
          return ParleyResult(session, combat, state);
        }
        // The channel stays open — but begging is off the table now.
        final session = s
            .say('You plead poverty.')
            .say('"Everybody\'s broke, captain. The demand stands."')
            .withoutOption(ParleyOption.plead);
        return ParleyResult(session, c, game);

      case ParleyOption.tradeInfo:
      case ParleyOption.comply:
        // Not offered to pirates; assert in choose() guards this.
        return ParleyResult(s, c, game);
    }
  }

  static ParleyResult _choosePolice(ParleySession s, CombatState c,
      GameState game, ParleyOption option, Random rng) {
    final gov = GovernmentDef.forType(game.currentSystem.government);
    final npcSkill = _npcSkill(c, game.difficulty);

    switch (option) {
      case ParleyOption.comply:
        // Round-trips through the real inspection machinery: real cargo
        // map, real fines, real record changes.
        final result = Combat.submit(c, game)!;
        final busted =
            result.combat.outcome == CombatOutcome.inspectionBusted;
        final session = s.say('You cut thrust and open the airlock.').say(
            busted
                ? '"Well, what have we here. This is going on your '
                    'record, captain."'
                : '"All clear. Appreciate the cooperation — safe '
                    'travels."');
        return ParleyResult(session, result.combat, result.game);

      case ParleyOption.payOff:
        // Round-trips through the real bribery rules (government
        // corruptibility, amounts, quiet ledger entry).
        final result = Combat.bribe(c, game)!;
        if (result.combat.outcome == CombatOutcome.bribed) {
          final session = s
              .say('You suggest, delicately, that paperwork has a price.')
              .say('"...Inspection complete. Nothing to report."');
          return ParleyResult(session, result.combat, result.game);
        }
        // Incorruptible government or empty pockets: channel stays open.
        final session = s
            .say('You suggest, delicately, that paperwork has a price.')
            .say(gov.bribeLevel <= 0
                ? '"Attempted bribery is a separate offense here, '
                    'captain. Don\'t make me file it."'
                : '"With what credits? Stand by for inspection."')
            .withoutOption(ParleyOption.payOff);
        return ParleyResult(session, result.combat, result.game);

      case ParleyOption.bluff:
        final success = _check(rng,
            skill: game.commander.trader,
            against: npcSkill + gov.illegalReaction);
        if (success) {
          final session = s
              .say('You transmit a forged diplomatic manifest: sealed '
                  'cargo, government seal, no inspection authority.')
              .say('"...Checks out. Apologies for the delay, captain. '
                  'You\'re free to go."');
          final combat = c
              .addLog('The patrol waves you through on forged papers.')
              .copyWith(outcome: CombatOutcome.departed);
          return ParleyResult(session, combat, game);
        }
        final state = game.copyWith(
          commander: game.commander.copyWith(
            policeRecordScore: game.commander.policeRecordScore - 2,
          ),
        );
        final session = s
            .say('You transmit a forged diplomatic manifest.')
            .say('"This seal is six years expired. That\'s going in the '
                'report. NOW cut thrust and stand by for boarding."')
            .withoutOption(ParleyOption.bluff);
        return ParleyResult(session, c, state);

      case ParleyOption.tradeInfo:
        // Verifiable good citizenship: kill tallies are on file.
        final kills = game.commander.pirateKills;
        final state = game.copyWith(
          commander: game.commander.copyWith(
            policeRecordScore: game.commander.policeRecordScore + 1,
          ),
        );
        final session = s
            .say('You hand over your combat logs: pirate contacts, '
                'vectors, hull signatures.')
            .say('"$kills confirmed pirate kill${kills == 1 ? '' : 's'} '
                'on record. We could use more captains like you. '
                'Inspection waived — carry on."');
        final combat = c
            .addLog('The patrol logs your intel and waves you through.')
            .copyWith(outcome: CombatOutcome.departed);
        return ParleyResult(session, combat, state);

      case ParleyOption.threaten:
      case ParleyOption.plead:
        return ParleyResult(s, c, game);
    }
  }

  static ParleyResult _chooseTrader(ParleySession s, CombatState c,
      GameState game, ParleyOption option, Random rng) {
    final npcSkill = _npcSkill(c, game.difficulty);

    switch (option) {
      case ParleyOption.tradeInfo:
        final success =
            _check(rng, skill: game.commander.trader, against: npcSkill);
        if (success) {
          final payment = 100 + game.commander.trader * 30 + rng.nextInt(101);
          final session = s
              .say('You sell them the good stuff: price spreads, crisis '
                  'rumors, which patrols take bribes.')
              .say('"Now THAT\'S worth the credits. $payment, wired. '
                  'Pleasure, captain."');
          final state = game.copyWith(credits: game.credits + payment);
          final combat = c
              .addLog('You sell market intel for $payment credits and '
                  'part ways.')
              .copyWith(outcome: CombatOutcome.departed);
          return ParleyResult(session, combat, state);
        }
        final session = s
            .say('You offer up what you\'ve heard on the wire.')
            .say('"Old news, captain. Heard it two systems back. '
                'Anything else?"')
            .withoutOption(ParleyOption.tradeInfo);
        return ParleyResult(session, c, game);

      case ParleyOption.threaten:
        // Extortion: piracy in all but name.
        final repBonus = game.commander.reputation.index;
        final success = _check(rng,
            skill: game.commander.fighter + repBonus, against: npcSkill + 2);
        if (success) {
          // Real cargo and credits change hands.
          var ship = game.ship;
          var space = ship.availableCargoBays;
          var seized = 0;
          final remaining = Map<TradeGood, int>.from(c.npcCargo);
          final newCargo = Map<TradeGood, int>.from(ship.cargo);
          for (final entry in c.npcCargo.entries) {
            if (space <= 0) break;
            final taken = min(entry.value, space);
            newCargo[entry.key] = (newCargo[entry.key] ?? 0) + taken;
            final left = entry.value - taken;
            if (left <= 0) {
              remaining.remove(entry.key);
            } else {
              remaining[entry.key] = left;
            }
            space -= taken;
            seized += taken;
          }
          ship = ship.copyWith(cargo: newCargo);
          var state = game.copyWith(
            ship: ship,
            credits: game.credits + c.npcCredits,
            commander: game.commander.copyWith(
              policeRecordScore: game.commander.policeRecordScore - 3,
            ),
          );
          // They live, they dock, and they name you. Public by design.
          state = EventLedger.record(state, GameEventType.enemyEscaped,
              witnessed: true, detail: 'extortion');
          final session = s
              .say('You paint them with a targeting lock. "Jettison the '
                  'hold and the day stays boring."')
              .say('"Alright! ALRIGHT! Taking it! You\'ll answer for '
                  'this, pirate!"');
          final combat = c
              .addLog('The trader dumps $seized units of cargo and '
                  '${c.npcCredits} credits, then burns hard for the '
                  'jump point.')
              .copyWith(
                npcCargo: remaining,
                npcCredits: 0,
                outcome: CombatOutcome.departed,
              );
          return ParleyResult(session, combat, state);
        }
        final state = game.copyWith(
          commander: game.commander.copyWith(
            policeRecordScore: game.commander.policeRecordScore - 1,
          ),
        );
        final session = s
            .say('You paint them with a targeting lock and make demands.')
            .say('"Pirate! PIRATE ON THE LANE!" — they firewall their '
                'drives and run.');
        final combat = c
            .addLog('The trader bolts, screaming piracy on every channel.')
            .copyWith(npcHostile: true, npcFleeing: true);
        return ParleyResult(session, combat, state, escalated: true);

      case ParleyOption.comply:
        final session = s
            .say('You trade lane conditions and empty pleasantries.')
            .say('"Safe travels, captain. Watch the far beacon — '
                'pirates this month."');
        final combat = c
            .addLog('You exchange news and go your separate ways.')
            .copyWith(outcome: CombatOutcome.departed);
        return ParleyResult(session, combat, game);

      case ParleyOption.payOff:
      case ParleyOption.bluff:
      case ParleyOption.plead:
        return ParleyResult(s, c, game);
    }
  }

  // --- internals ---

  /// Parley collapses into violence: the other ship gets one free opening
  /// salvo (it can wound, never kill — the ensuing combat can), then the
  /// normal combat machinery takes over.
  static ParleyResult _escalate(
      ParleySession session, CombatState c, GameState game, Random rng,
      {required String closing}) {
    var combat = c.addLog(closing).copyWith(npcHostile: true);
    var state = game;

    if (combat.npcWeaponPower > 0) {
      final hit = rng.nextInt(_npcSkill(combat, state.difficulty) + 5) >=
          rng.nextInt(state.commander.pilot + 5);
      if (hit) {
        var dmg = combat.npcWeaponPower ~/ 2 +
            rng.nextInt(combat.npcWeaponPower ~/ 2 + 1);
        var shields = combat.playerShieldHp;
        if (shields > 0) {
          final absorbed = min(shields, dmg);
          shields -= absorbed;
          dmg -= absorbed;
          combat = combat.copyWith(playerShieldHp: shields);
        }
        // The opening salvo can cripple but not kill.
        dmg = min(dmg, state.ship.hullStrength - 1);
        if (dmg > 0) {
          state = state.copyWith(
              ship: state.ship
                  .copyWith(hullStrength: state.ship.hullStrength - dmg));
        }
        combat = combat.addLog('Their opening salvo connects! '
            '${dmg > 0 ? "$dmg hull damage." : "Shields absorb the blast."}');
      } else {
        combat = combat.addLog('Their opening salvo goes wide.');
      }
    }
    return ParleyResult(session, combat, state, escalated: true);
  }

  static RivalCaptain? _rival(CombatState c, GameState game) {
    if (c.rivalId == null) return null;
    for (final r in game.rivals) {
      if (r.id == c.rivalId) return r;
    }
    return null;
  }

  /// Mirrors the combat engine's NPC skill curve.
  static int _npcSkill(CombatState c, DifficultyLevel difficulty) =>
      2 + difficulty.index * 2 + c.npcDef.size;

  /// Opposed social roll, same shape as combat's hit rolls.
  static bool _check(Random rng, {required int skill, required int against}) {
    return rng.nextInt(skill + 5) >= rng.nextInt(against + 3);
  }

  static int _roundTo25(int value) => (value ~/ 25) * 25;

  static T _pick<T>(Random rng, List<T> items) =>
      items[rng.nextInt(items.length)];
}
