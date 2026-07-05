// Pure Dart — no Flutter imports
import 'dart:math';

import '../models/enums.dart';
import '../models/game_event.dart';
import '../models/game_state.dart';
import '../models/government_def.dart';
import '../models/ship.dart';
import '../models/ship_type_def.dart';
import 'encounter.dart';
import 'events.dart';
import 'rivals.dart';

/// How a combat encounter ended (or hasn't yet).
enum CombatOutcome {
  ongoing,
  playerFled,
  npcFled,
  npcDestroyed,
  playerDestroyedEscaped, // escape pod used — game continues in a Flea
  playerDestroyedGameOver,
  surrendered, // gave cargo/credits to pirates
  bribed, // paid off the police
  inspectionClean, // submitted, nothing illegal found
  inspectionBusted, // submitted, contraband confiscated + fine
  departed, // both parties went their way
}

/// Transient state of an active encounter. Not persisted — an encounter
/// interrupted by quitting the app is simply skipped (as in classic
/// Space Trader's "auto-flee on load" behavior).
class CombatState {
  final EncounterType encounterType;
  final ShipType npcShipType;
  final int npcWeaponPower;
  final int npcHull;
  final int npcMaxHull;
  final int npcShieldHp;
  final int npcMaxShieldHp;
  final bool npcFleeing;
  final bool npcHostile; // becomes true if the player attacks police/traders
  final Map<TradeGood, int> npcCargo;
  final int npcCredits;
  final int playerShieldHp;
  final int playerMaxShieldHp;
  final CombatOutcome outcome;
  final List<String> log;
  final String? rivalId;
  final String? captainName;

  const CombatState({
    required this.encounterType,
    required this.npcShipType,
    required this.npcWeaponPower,
    required this.npcHull,
    required this.npcMaxHull,
    required this.npcShieldHp,
    required this.npcMaxShieldHp,
    required this.npcFleeing,
    required this.npcHostile,
    required this.npcCargo,
    required this.npcCredits,
    required this.playerShieldHp,
    required this.playerMaxShieldHp,
    required this.outcome,
    required this.log,
    this.rivalId,
    this.captainName,
  });

  factory CombatState.begin(EncounterResult encounter, Ship playerShip) {
    final npc = encounter.npcShip;
    final npcShields = npc.totalShieldStrength;
    final playerShields = playerShip.totalShieldStrength;
    return CombatState(
      encounterType: encounter.type,
      npcShipType: npc.shipType,
      npcWeaponPower: npc.totalWeaponPower,
      npcHull: npc.currentHull,
      npcMaxHull: npc.hullStrength,
      npcShieldHp: npcShields,
      npcMaxShieldHp: npcShields,
      npcFleeing: encounter.npcFleeing,
      // Pirates and monsters attack on sight; police/traders start neutral.
      npcHostile: encounter.type == EncounterType.pirate ||
          encounter.type == EncounterType.monster,
      npcCargo: Map.of(npc.cargo),
      npcCredits: npc.credits,
      playerShieldHp: playerShields,
      playerMaxShieldHp: playerShields,
      outcome: CombatOutcome.ongoing,
      log: const [],
      rivalId: encounter.rivalId,
      captainName: encounter.captainName,
    );
  }

  ShipTypeDef get npcDef => ShipTypeDef.forType(npcShipType);

  bool get isOver => outcome != CombatOutcome.ongoing;

  CombatState copyWith({
    int? npcHull,
    int? npcShieldHp,
    bool? npcFleeing,
    bool? npcHostile,
    Map<TradeGood, int>? npcCargo,
    int? npcCredits,
    int? playerShieldHp,
    CombatOutcome? outcome,
    List<String>? log,
  }) {
    return CombatState(
      encounterType: encounterType,
      npcShipType: npcShipType,
      npcWeaponPower: npcWeaponPower,
      npcHull: npcHull ?? this.npcHull,
      npcMaxHull: npcMaxHull,
      npcShieldHp: npcShieldHp ?? this.npcShieldHp,
      npcMaxShieldHp: npcMaxShieldHp,
      npcFleeing: npcFleeing ?? this.npcFleeing,
      npcHostile: npcHostile ?? this.npcHostile,
      npcCargo: npcCargo ?? this.npcCargo,
      npcCredits: npcCredits ?? this.npcCredits,
      playerShieldHp: playerShieldHp ?? this.playerShieldHp,
      playerMaxShieldHp: playerMaxShieldHp,
      outcome: outcome ?? this.outcome,
      log: log ?? this.log,
      rivalId: rivalId,
      captainName: captainName,
    );
  }

  CombatState addLog(String entry) => copyWith(log: [...log, entry]);
}

/// Combined result of a combat action: updated encounter + updated game.
class CombatResult {
  final CombatState combat;
  final GameState game;
  const CombatResult(this.combat, this.game);
}

class Combat {
  Combat._();

  /// NPC skill level scales with difficulty and ship class.
  static int _npcSkill(CombatState c, DifficultyLevel difficulty) {
    return 2 + difficulty.index * 2 + c.npcDef.size;
  }

  /// Did the attacker land a hit? Opposed roll: attacker's fighter skill
  /// (+ targeting bonus) vs defender's pilot skill, with larger targets
  /// easier to hit.
  static bool _rollHit(Random rng,
      {required int attackerFighter,
      required int defenderPilot,
      required int defenderSize}) {
    final attack = rng.nextInt(attackerFighter + defenderSize + 5);
    final dodge = rng.nextInt(defenderPilot + 5);
    return attack >= dodge;
  }

  /// Weapon damage roll: half power guaranteed, half variable.
  static int _rollDamage(Random rng, int weaponPower) {
    if (weaponPower <= 0) return 0;
    return weaponPower ~/ 2 + rng.nextInt(weaponPower ~/ 2 + 1);
  }

  /// Player attacks the NPC. Police/trader targets turn hostile and the
  /// police record suffers.
  static CombatResult attack(CombatState c, GameState game, Random rng) {
    var combat = c;
    var state = game;

    // Opening fire on lawful ships has consequences.
    if (!combat.npcHostile) {
      final penalty = switch (combat.encounterType) {
        EncounterType.police => -6,
        EncounterType.trader => -2,
        _ => 0,
      };
      if (penalty != 0) {
        state = state.copyWith(
          commander: state.commander.copyWith(
            policeRecordScore: state.commander.policeRecordScore + penalty,
          ),
        );
      }
      combat = combat
          .copyWith(npcHostile: true, npcFleeing: false)
          .addLog('You open fire! The ${combat.npcDef.displayName} '
              'turns to engage.');
    }

    // Player fires.
    final targeting =
        state.ship.hasGadget(GadgetType.targetingSystem) ? 3 : 0;
    final playerHits = _rollHit(rng,
        attackerFighter: state.commander.fighter + targeting,
        defenderPilot: _npcSkill(combat, state.difficulty),
        defenderSize: combat.npcDef.size);

    if (playerHits) {
      final dmg = _rollDamage(rng, state.ship.totalWeaponPower);
      combat = _applyDamageToNpc(combat, dmg);
      combat = combat.addLog('Direct hit for $dmg damage!');
      if (combat.npcHull <= 0) {
        return _npcDestroyed(combat, state, rng);
      }
    } else {
      combat = combat.addLog('You miss.');
    }

    // A fleeing opponent tries to escape instead of returning fire.
    if (combat.npcFleeing) {
      if (rng.nextInt(10) < 6) {
        combat = combat
            .addLog('The ${combat.npcDef.displayName} escapes into the void.')
            .copyWith(outcome: CombatOutcome.npcFled);
        state = _recordSurvivorEscaped(combat, state);
        return CombatResult(combat, state);
      }
      combat = combat.addLog('It fails to break away!');
      return CombatResult(combat, state);
    }

    // NPC returns fire.
    return _npcFires(combat, state, rng);
  }

  /// Player attempts to flee. Failure gives the opponent a free shot.
  static CombatResult flee(CombatState c, GameState game, Random rng) {
    var combat = c;
    var state = game;

    // Running from a police inspection is an admission of guilt.
    if (combat.encounterType == EncounterType.police && !combat.npcHostile) {
      state = state.copyWith(
        commander: state.commander.copyWith(
          policeRecordScore: state.commander.policeRecordScore - 2,
        ),
      );
    }

    final escape = rng.nextInt(state.commander.pilot + 5) >=
        rng.nextInt(_npcSkill(combat, state.difficulty) + 3);
    if (escape) {
      combat = combat
          .addLog('You slam the throttle and slip away.')
          .copyWith(outcome: CombatOutcome.playerFled);
      // The other ship survived — the story gets out.
      state = EventLedger.record(state, GameEventType.fledCombat,
          witnessed: true,
          rivalId: combat.rivalId,
          detail: combat.encounterType.name);
      if (combat.rivalId != null) {
        state = RivalSystem.updateRival(
            state, combat.rivalId!, (r) => r.copyWith(grudge: r.grudge + 1));
      }
      return CombatResult(combat, state);
    }

    combat = combat
        .copyWith(npcHostile: true)
        .addLog('You fail to get away!');
    return _npcFires(combat, state, rng);
  }

  /// Surrender to pirates: they take your cargo and a slice of credits.
  /// Returns null if surrender isn't possible for this encounter.
  static CombatResult? surrender(CombatState c, GameState game) {
    if (c.encounterType != EncounterType.pirate) return null;

    final cargoLost = game.ship.totalCargoUsed;
    final creditsLost = min(game.credits, max(500, game.credits ~/ 10));
    final newShip = game.ship.copyWith(cargo: {});
    var state = game.copyWith(
      ship: newShip,
      credits: game.credits - creditsLost,
    );
    state = EventLedger.record(state, GameEventType.surrenderedToPirates,
        witnessed: true, rivalId: c.rivalId);
    if (c.rivalId != null) {
      // A rival who robbed you blind is, briefly, satisfied.
      state = RivalSystem.updateRival(
          state, c.rivalId!, (r) => r.copyWith(grudge: r.grudge - 2));
    }
    final combat = c
        .addLog('The pirates strip your hold of $cargoLost units of cargo '
            'and $creditsLost credits, then let you go.')
        .copyWith(outcome: CombatOutcome.surrendered);
    return CombatResult(combat, state);
  }

  /// Submit to a police inspection.
  /// Returns null unless this is a (non-hostile) police encounter.
  static CombatResult? submit(CombatState c, GameState game) {
    if (c.encounterType != EncounterType.police || c.npcHostile) return null;

    final cargo = Map<TradeGood, int>.from(game.ship.cargo);
    final narcotics = cargo.remove(TradeGood.narcotics) ?? 0;
    final firearms = cargo.remove(TradeGood.firearms) ?? 0;

    if (narcotics > 0 || firearms > 0) {
      final fine = max(100, (game.credits ~/ 10) ~/ 50 * 50);
      var state = game.copyWith(
        ship: game.ship.copyWith(cargo: cargo),
        credits: max(0, game.credits - fine),
        commander: game.commander.copyWith(
          policeRecordScore: game.commander.policeRecordScore - 5,
        ),
      );
      state = EventLedger.record(state, GameEventType.inspectionBusted,
          witnessed: true);
      final combat = c
          .addLog('Contraband found! The police confiscate '
              '${narcotics + firearms} units and fine you $fine credits.')
          .copyWith(outcome: CombatOutcome.inspectionBusted);
      return CombatResult(combat, state);
    }

    var state = game.copyWith(
      commander: game.commander.copyWith(
        policeRecordScore: game.commander.policeRecordScore + 1,
      ),
    );
    state = EventLedger.record(state, GameEventType.inspectionClean,
        witnessed: true);
    final combat = c
        .addLog('The police find nothing illegal and wave you through.')
        .copyWith(outcome: CombatOutcome.inspectionClean);
    return CombatResult(combat, state);
  }

  /// Bribe the police. Returns null unless this is a non-hostile police
  /// encounter. May fail outright in incorruptible governments.
  static CombatResult? bribe(CombatState c, GameState game) {
    if (c.encounterType != EncounterType.police || c.npcHostile) return null;

    final gov = GovernmentDef.forType(game.currentSystem.government);
    if (gov.bribeLevel <= 0) {
      final combat = c.addLog(
          'The officer is offended: "We don\'t take bribes here!"');
      return CombatResult(combat, game);
    }

    final amount = max(100, game.credits ~/ (8 + gov.bribeLevel * 2));
    if (game.credits < amount) {
      final combat =
          c.addLog('You can\'t scrape together enough for a bribe.');
      return CombatResult(combat, game);
    }

    var state = game.copyWith(credits: game.credits - amount);
    // Bribes are quiet — the officer isn't advertising this.
    state = EventLedger.record(state, GameEventType.policeBribed,
        witnessed: false);
    final combat = c
        .addLog('$amount credits change hands. The patrol suddenly '
            'remembers urgent business elsewhere.')
        .copyWith(outcome: CombatOutcome.bribed);
    return CombatResult(combat, state);
  }

  /// Part ways peacefully. Only possible when the other ship isn't hostile
  /// (traders, fleeing ships, police after resolution is not needed here).
  static CombatResult? depart(CombatState c, GameState game) {
    if (c.npcHostile && !c.npcFleeing) return null;
    if (c.encounterType == EncounterType.police && !c.npcHostile) {
      // Police insist on an inspection — submit, bribe, flee, or fight.
      return null;
    }
    var state = game;
    if (c.npcFleeing && c.npcHostile) {
      // Letting a beaten opponent limp away is mercy — and a witness.
      state = _recordSurvivorEscaped(c, state);
    }
    final combat = c
        .addLog('You go your separate ways.')
        .copyWith(outcome: CombatOutcome.departed);
    return CombatResult(combat, state);
  }

  // --- internals ---

  /// An opponent survived an exchange of fire and got away: the galaxy
  /// hears about it. Spared rivals return meaner, in bigger ships.
  static GameState _recordSurvivorEscaped(CombatState c, GameState game) {
    var state = EventLedger.record(
      game,
      c.rivalId != null ? GameEventType.rivalSpared : GameEventType.enemyEscaped,
      witnessed: true,
      rivalId: c.rivalId,
      detail: c.encounterType.name,
    );
    if (c.rivalId != null) {
      state = RivalSystem.updateRival(
          state,
          c.rivalId!,
          (r) => r.copyWith(
              timesSpared: r.timesSpared + 1, grudge: r.grudge + 2));
    }
    return state;
  }

  static CombatState _applyDamageToNpc(CombatState c, int dmg) {
    var remaining = dmg;
    var shields = c.npcShieldHp;
    if (shields > 0) {
      final absorbed = min(shields, remaining);
      shields -= absorbed;
      remaining -= absorbed;
    }
    return c.copyWith(npcShieldHp: shields, npcHull: c.npcHull - remaining);
  }

  static CombatResult _npcFires(CombatState c, GameState game, Random rng) {
    var combat = c;
    var state = game;

    if (combat.npcWeaponPower <= 0) {
      return CombatResult(combat.addLog('The enemy ship is unarmed.'), state);
    }

    final npcHits = _rollHit(rng,
        attackerFighter: _npcSkill(combat, state.difficulty),
        defenderPilot: state.commander.pilot,
        defenderSize: state.ship.def.size);
    if (!npcHits) {
      return CombatResult(
          combat.addLog('Enemy fire streaks past your hull.'), state);
    }

    var dmg = _rollDamage(rng, combat.npcWeaponPower);
    var shields = combat.playerShieldHp;
    if (shields > 0) {
      final absorbed = min(shields, dmg);
      shields -= absorbed;
      dmg -= absorbed;
      combat = combat.copyWith(playerShieldHp: shields);
    }
    final newHull = state.ship.hullStrength - dmg;
    state = state.copyWith(ship: state.ship.copyWith(hullStrength: max(0, newHull)));
    combat = combat.addLog('You take a hit! '
        '${dmg > 0 ? "$dmg hull damage." : "Shields absorb the blast."}');

    if (newHull <= 0) {
      return _playerDestroyed(combat, state);
    }
    return CombatResult(combat, state);
  }

  static CombatResult _npcDestroyed(
      CombatState c, GameState game, Random rng) {
    var combat = c.addLog('The ${c.npcDef.displayName} explodes!');
    var state = game;
    var commander = state.commander;

    // Kill tallies, reputation, and police record.
    final repGain = 1 + combat.npcDef.size * combat.npcDef.size;
    switch (combat.encounterType) {
      case EncounterType.police:
        commander = commander.copyWith(
          policeKills: commander.policeKills + 1,
          reputationScore: commander.reputationScore + repGain,
          policeRecordScore: commander.policeRecordScore - 30,
        );
      case EncounterType.trader:
        commander = commander.copyWith(
          traderKills: commander.traderKills + 1,
          reputationScore: commander.reputationScore + repGain,
          policeRecordScore: commander.policeRecordScore - 10,
        );
      case EncounterType.pirate:
        commander = commander.copyWith(
          pirateKills: commander.pirateKills + 1,
          reputationScore: commander.reputationScore + repGain,
          // Killing pirates is civic-minded — unless you're already wanted.
          policeRecordScore: commander.isWanted
              ? commander.policeRecordScore
              : commander.policeRecordScore + 1,
        );
      case EncounterType.monster:
        commander = commander.copyWith(
          reputationScore: commander.reputationScore + repGain * 2,
        );
    }

    // Loot: bounty credits, plus whatever cargo survives and fits.
    var credits = state.credits;
    final bounty = combat.encounterType == EncounterType.pirate ||
            combat.encounterType == EncounterType.monster
        ? combat.npcDef.bounty + combat.npcCredits
        : 0;
    if (bounty > 0) {
      credits += bounty;
      combat = combat.addLog('You collect a bounty of $bounty credits.');
    }

    var ship = state.ship;
    if (combat.npcCargo.isNotEmpty) {
      final salvage = <TradeGood, int>{};
      var space = ship.availableCargoBays;
      var salvaged = 0;
      for (final entry in combat.npcCargo.entries) {
        if (space <= 0) break;
        // Half the cargo survives the explosion, at best.
        final surviving = rng.nextInt(entry.value + 1);
        final taken = min(surviving, space);
        if (taken > 0) {
          salvage[entry.key] = taken;
          space -= taken;
          salvaged += taken;
        }
      }
      if (salvaged > 0) {
        final newCargo = Map<TradeGood, int>.from(ship.cargo);
        salvage.forEach((good, qty) {
          newCargo[good] = (newCargo[good] ?? 0) + qty;
        });
        ship = ship.copyWith(cargo: newCargo);
        combat = combat
            .addLog('You salvage $salvaged units of cargo from the wreck.');
      }
    }

    state = state.copyWith(commander: commander, credits: credits, ship: ship);

    // Dead ships tell no tales: an unwitnessed kill stays off the record.
    final eventType = switch (combat.encounterType) {
      EncounterType.police => GameEventType.policeDestroyed,
      EncounterType.pirate => GameEventType.pirateDestroyed,
      EncounterType.trader => GameEventType.traderDestroyed,
      EncounterType.monster => GameEventType.monsterDestroyed,
    };
    state = EventLedger.record(state, eventType,
        witnessed: false, rivalId: combat.rivalId);
    if (combat.rivalId != null) {
      state = RivalSystem.updateRival(
          state, combat.rivalId!, (r) => r.copyWith(alive: false));
      state = EventLedger.record(state, GameEventType.rivalDefeated,
          witnessed: false, rivalId: combat.rivalId);
      combat = combat
          .addLog('${combat.captainName} will trouble you no more.');
    }

    combat = combat.copyWith(outcome: CombatOutcome.npcDestroyed);
    return CombatResult(combat, state);
  }

  static CombatResult _playerDestroyed(CombatState c, GameState game) {
    var combat = c.addLog('Your ship breaks apart!');

    if (!game.escapePod) {
      combat = combat.copyWith(outcome: CombatOutcome.playerDestroyedGameOver);
      return CombatResult(combat, game);
    }

    // Escape pod: survive with a Flea. Insurance pays out the lost hull.
    final payout =
        game.insurance ? game.ship.def.price ~/ 2 : 0;
    final fleaDef = ShipTypeDef.forType(ShipType.flea);
    final flea = Ship(
      shipType: ShipType.flea,
      cargo: const {},
      weapons: const [],
      shields: const [],
      gadgets: const [],
      crew: 0,
      fuel: fleaDef.maxFuel,
      hullStrength: fleaDef.hullStrength,
      tribbles: 0,
    );
    var state = game.copyWith(
      ship: flea,
      credits: game.credits + payout,
      escapePod: false,
      insurance: false,
      noClaim: 0,
    );
    // Rescue beacons are public record — everyone hears you lost your ship.
    state = EventLedger.record(state, GameEventType.playerShipLost,
        witnessed: true, rivalId: combat.rivalId);
    combat = combat
        .addLog('Your escape pod jettisons. '
            '${payout > 0 ? "Insurance pays out $payout credits. " : ""}'
            'You limp on in a rescue Flea.')
        .copyWith(outcome: CombatOutcome.playerDestroyedEscaped);
    return CombatResult(combat, state);
  }
}
