import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../engine/combat.dart';
import '../models/enums.dart';
import '../providers/game_provider.dart';

class EncounterScreen extends ConsumerWidget {
  const EncounterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combat = ref.watch(encounterProvider);
    final game = ref.watch(gameProvider);
    final cs = Theme.of(context).colorScheme;

    if (combat == null || game == null) {
      // No active encounter — bounce back to the hub.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/game');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final notifier = ref.read(encounterProvider.notifier);

    return PopScope(
      canPop: false, // no backing out of an encounter
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_title(combat)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ShipStatusCard(
                  label: 'YOUR SHIP — ${game.ship.def.displayName}',
                  hull: game.ship.hullStrength,
                  maxHull: game.ship.maxHullStrength,
                  shield: combat.playerShieldHp,
                  maxShield: combat.playerMaxShieldHp,
                  color: cs.primary,
                ),
                const SizedBox(height: 8),
                _ShipStatusCard(
                  label: combat.captainName != null
                      ? '${combat.captainName!.toUpperCase()} — ${combat.npcDef.displayName}'
                      : '${_faction(combat.encounterType)} — ${combat.npcDef.displayName}',
                  hull: combat.npcHull.clamp(0, combat.npcMaxHull),
                  maxHull: combat.npcMaxHull,
                  shield: combat.npcShieldHp,
                  maxShield: combat.npcMaxShieldHp,
                  color: cs.error,
                ),
                const SizedBox(height: 12),
                Expanded(child: _CombatLog(combat: combat)),
                const SizedBox(height: 12),
                if (combat.isOver)
                  _ContinueButton(combat: combat)
                else
                  _ActionBar(combat: combat, notifier: notifier),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title(CombatState c) {
    if (c.captainName != null) return 'RIVAL: ${c.captainName!.toUpperCase()}';
    switch (c.encounterType) {
      case EncounterType.police:
        return 'POLICE INSPECTION';
      case EncounterType.pirate:
        return 'PIRATE ATTACK';
      case EncounterType.trader:
        return 'TRADER ENCOUNTER';
      case EncounterType.monster:
        return 'SPACE MONSTER';
    }
  }

  String _faction(EncounterType t) {
    switch (t) {
      case EncounterType.police:
        return 'POLICE';
      case EncounterType.pirate:
        return 'PIRATE';
      case EncounterType.trader:
        return 'TRADER';
      case EncounterType.monster:
        return 'MONSTER';
    }
  }
}

class _ShipStatusCard extends StatelessWidget {
  final String label;
  final int hull;
  final int maxHull;
  final int shield;
  final int maxShield;
  final Color color;

  const _ShipStatusCard({
    required this.label,
    required this.hull,
    required this.maxHull,
    required this.shield,
    required this.maxShield,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.titleSmall?.copyWith(color: color)),
            const SizedBox(height: 8),
            _bar(context, 'HULL', hull, maxHull, color),
            if (maxShield > 0) ...[
              const SizedBox(height: 4),
              _bar(context, 'SHLD', shield, maxShield,
                  Theme.of(context).colorScheme.secondary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bar(
      BuildContext context, String tag, int value, int max, Color color) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(width: 40, child: Text(tag, style: text.labelSmall)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: max > 0 ? value / max : 0,
              minHeight: 8,
              backgroundColor: const Color(0xFF1a2235),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$value/$max', style: text.labelSmall),
      ],
    );
  }
}

class _CombatLog extends StatelessWidget {
  final CombatState combat;

  const _CombatLog({required this.combat});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final entries = combat.log.isEmpty
        ? [_openingLine(combat.encounterType, combat.npcFleeing)]
        : combat.log;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView.builder(
          reverse: true,
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[entries.length - 1 - i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('> $entry', style: text.bodyMedium),
            );
          },
        ),
      ),
    );
  }

  String _openingLine(EncounterType type, bool fleeing) {
    if (fleeing) return 'The other ship is trying to get away.';
    switch (type) {
      case EncounterType.police:
        return 'The police hail you and demand to inspect your cargo.';
      case EncounterType.pirate:
        return 'A pirate vessel locks weapons on your ship!';
      case EncounterType.trader:
        return 'A trader passes within hailing distance.';
      case EncounterType.monster:
        return 'Something vast and hungry drifts out of the black.';
    }
  }
}

class _ActionBar extends StatelessWidget {
  final CombatState combat;
  final EncounterNotifier notifier;

  const _ActionBar({required this.combat, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      ElevatedButton(
        onPressed: notifier.attack,
        child: const Text('ATTACK'),
      ),
      OutlinedButton(
        onPressed: notifier.flee,
        child: const Text('FLEE'),
      ),
    ];

    if (combat.encounterType == EncounterType.police && !combat.npcHostile) {
      actions.add(OutlinedButton(
        onPressed: notifier.submit,
        child: const Text('SUBMIT'),
      ));
      actions.add(OutlinedButton(
        onPressed: notifier.bribe,
        child: const Text('BRIBE'),
      ));
    }
    if (combat.encounterType == EncounterType.pirate) {
      actions.add(OutlinedButton(
        onPressed: notifier.surrender,
        child: const Text('SURRENDER'),
      ));
    }
    if ((combat.encounterType == EncounterType.trader &&
            !combat.npcHostile) ||
        combat.npcFleeing) {
      actions.add(OutlinedButton(
        onPressed: notifier.depart,
        child: const Text('IGNORE'),
      ));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: actions,
    );
  }
}

class _ContinueButton extends ConsumerWidget {
  final CombatState combat;

  const _ContinueButton({required this.combat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameOver = combat.outcome == CombatOutcome.playerDestroyedGameOver;
    return ElevatedButton(
      onPressed: () async {
        ref.read(encounterProvider.notifier).clear();
        if (gameOver) {
          await ref.read(gameProvider.notifier).deleteSave();
          if (context.mounted) context.go('/');
        } else {
          context.go('/game');
        }
      },
      style: gameOver
          ? ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error)
          : null,
      child: Text(gameOver ? 'GAME OVER' : 'CONTINUE'),
    );
  }
}
