import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/combat.dart';
import '../engine/economy.dart';
import '../engine/encounter.dart';
import '../engine/game_engine.dart';
import '../engine/travel.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/ship.dart';
import '../models/solar_system.dart';

const String _saveKey = 'darknova2_save';

class GameStateNotifier extends StateNotifier<GameState?> {
  GameStateNotifier(this._ref) : super(null);

  final Ref _ref;

  /// Replace the game state directly (used by the encounter flow).
  void applyGameState(GameState newState) {
    state = newState;
    saveGame();
  }

  // ---------------------------------------------------------------------------
  // Game lifecycle
  // ---------------------------------------------------------------------------

  void newGame(String commanderName, DifficultyLevel difficulty) {
    state = GameEngine.newGame(commanderName, difficulty);
  }

  /// Override skill distribution after newGame — called from new game screen.
  void applySkills(
      String name, int pilot, int fighter, int trader, int engineer) {
    final current = state;
    if (current == null) return;
    final newCommander = current.commander.copyWith(
      name: name,
      pilot: pilot,
      fighter: fighter,
      trader: trader,
      engineer: engineer,
    );
    state = current.copyWith(commander: newCommander);
  }

  Future<bool> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_saveKey);
      if (json == null) return false;
      final map = jsonDecode(json) as Map<String, dynamic>;
      state = GameState.fromJson(map);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveGame() async {
    final current = state;
    if (current == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_saveKey, jsonEncode(current.toJson()));
    } catch (_) {
      // Silently ignore save errors — game continues.
    }
  }

  Future<void> deleteSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
  }

  // ---------------------------------------------------------------------------
  // Travel
  // ---------------------------------------------------------------------------

  /// Warp to a system. Returns true if an encounter interrupts the trip
  /// (the caller should route to the encounter screen).
  bool warpTo(int targetIndex) {
    final current = state;
    if (current == null) return false;
    final couldWarp = Travel.canReach(current.currentSystem,
        current.solarSystems[targetIndex], current.ship);
    state = GameEngine.warpTo(current, targetIndex);
    saveGame();
    if (!couldWarp) return false;
    final encounter = GameEngine.rollEncounter(state!);
    if (encounter == null) return false;
    _ref.read(encounterProvider.notifier).begin(encounter, state!.ship);
    return true;
  }

  void selectWarpTarget(int? index) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(warpTargetIndex: index);
  }

  // ---------------------------------------------------------------------------
  // Trade
  // ---------------------------------------------------------------------------

  bool buyGood(TradeGood good, int quantity) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.buyGood(current, good, quantity);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  bool sellGood(TradeGood good, int quantity) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.sellGood(current, good, quantity);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Shipyard
  // ---------------------------------------------------------------------------

  bool buyShip(ShipType shipType) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.buyShip(current, shipType);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  bool buyWeapon(WeaponType weapon) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.buyWeapon(current, weapon);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  bool sellWeapon(WeaponType weapon) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.sellWeapon(current, weapon);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  bool buyShield(ShieldType shield) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.buyShield(current, shield);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  bool sellShield(ShieldType shield) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.sellShield(current, shield);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  bool buyGadget(GadgetType gadget) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.buyGadget(current, gadget);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  bool sellGadget(GadgetType gadget) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.sellGadget(current, gadget);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Fuel & Repairs
  // ---------------------------------------------------------------------------

  bool buyFuel(int units) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.buyFuel(current, units);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  bool repairHull(int points) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.repairHull(current, points);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Finance
  // ---------------------------------------------------------------------------

  bool payDebt(int amount) {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.payDebt(current, amount);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  bool buyEscapePod() {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.buyEscapePod(current);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }

  bool buyInsurance() {
    final current = state;
    if (current == null) return false;
    final next = GameEngine.buyInsurance(current);
    if (next == null) return false;
    state = next;
    saveGame();
    return true;
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final gameProvider =
    StateNotifierProvider<GameStateNotifier, GameState?>(
  (ref) => GameStateNotifier(ref),
);

// ---------------------------------------------------------------------------
// Encounters
// ---------------------------------------------------------------------------

/// Drives an active encounter. Combat actions mutate both the transient
/// [CombatState] here and the persistent [GameState] via [gameProvider].
class EncounterNotifier extends StateNotifier<CombatState?> {
  EncounterNotifier(this._ref) : super(null);

  final Ref _ref;
  final Random _rng = Random();

  void begin(EncounterResult encounter, Ship playerShip) {
    state = CombatState.begin(encounter, playerShip);
  }

  void clear() => state = null;

  void _apply(CombatResult? result) {
    if (result == null) return;
    state = result.combat;
    _ref.read(gameProvider.notifier).applyGameState(result.game);
  }

  void attack() {
    final c = state;
    final game = _ref.read(gameProvider);
    if (c == null || game == null || c.isOver) return;
    _apply(Combat.attack(c, game, _rng));
  }

  void flee() {
    final c = state;
    final game = _ref.read(gameProvider);
    if (c == null || game == null || c.isOver) return;
    _apply(Combat.flee(c, game, _rng));
  }

  void surrender() {
    final c = state;
    final game = _ref.read(gameProvider);
    if (c == null || game == null || c.isOver) return;
    _apply(Combat.surrender(c, game));
  }

  void submit() {
    final c = state;
    final game = _ref.read(gameProvider);
    if (c == null || game == null || c.isOver) return;
    _apply(Combat.submit(c, game));
  }

  void bribe() {
    final c = state;
    final game = _ref.read(gameProvider);
    if (c == null || game == null || c.isOver) return;
    _apply(Combat.bribe(c, game));
  }

  void depart() {
    final c = state;
    final game = _ref.read(gameProvider);
    if (c == null || game == null || c.isOver) return;
    _apply(Combat.depart(c, game));
  }
}

final encounterProvider =
    StateNotifierProvider<EncounterNotifier, CombatState?>(
  (ref) => EncounterNotifier(ref),
);

/// The current solar system (non-null only when game is active).
final currentSystemProvider = Provider<SolarSystem?>((ref) {
  final game = ref.watch(gameProvider);
  return game?.currentSystem;
});

/// List of system indices reachable from the current location.
final reachableSystemsProvider = Provider<List<int>>((ref) {
  final game = ref.watch(gameProvider);
  if (game == null) return [];
  return Travel.inRangeIndices(
      game.currentSystemIndex, game.solarSystems, game.ship);
});

/// Current buy prices (empty map if no game).
final buyPricesProvider = Provider<Map<TradeGood, int>>((ref) {
  final game = ref.watch(gameProvider);
  return game?.buyPrices ?? {};
});

/// Current sell prices (empty map if no game).
final sellPricesProvider = Provider<Map<TradeGood, int>>((ref) {
  final game = ref.watch(gameProvider);
  return game?.sellPrices ?? {};
});

/// All systems visible on the galaxy map with their data.
final galaxySystemsProvider = Provider<List<SolarSystem>>((ref) {
  final game = ref.watch(gameProvider);
  return game?.solarSystems ?? [];
});

/// Whether there is a saved game.
final hasSaveProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_saveKey);
});
