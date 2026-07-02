import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/commander.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';

class CommanderScreen extends ConsumerWidget {
  const CommanderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    if (game == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('COMMANDER STATUS'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/game'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IdentityCard(game: game),
                const SizedBox(height: 16),
                _SkillsCard(commander: game.commander),
                const SizedBox(height: 16),
                _ReputationCard(commander: game.commander),
                const SizedBox(height: 16),
                _FinanceCard(game: game, ref: ref),
                const SizedBox(height: 16),
                _NetWorthCard(game: game),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final GameState game;
  const _IdentityCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final commander = game.commander;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.surface, const Color(0xFF0d1526)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMANDER PROFILE',
            style: tt.labelSmall?.copyWith(
              letterSpacing: 2.5,
              color: cs.primary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            commander.name.toUpperCase(),
            style: tt.headlineLarge?.copyWith(
              color: cs.primary,
              fontSize: 32,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Days Elapsed',
                  value: '${game.days}',
                  icon: Icons.access_time,
                ),
              ),
              Expanded(
                child: _InfoTile(
                  label: 'Difficulty',
                  value: game.difficulty.displayName,
                  icon: Icons.tune,
                ),
              ),
              Expanded(
                child: _InfoTile(
                  label: 'Ship',
                  value: game.ship.def.displayName,
                  icon: Icons.rocket_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoTile(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: cs.primary.withOpacity(0.5)),
            const SizedBox(width: 4),
            Text(label, style: tt.labelSmall),
          ],
        ),
        const SizedBox(height: 3),
        Text(value,
            style: tt.bodyMedium?.copyWith(color: cs.onSurface)),
      ],
    );
  }
}

class _SkillsCard extends StatelessWidget {
  final Commander commander;
  const _SkillsCard({required this.commander});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return _Card(
      title: 'SKILLS',
      child: Column(
        children: [
          _SkillBar('Pilot', commander.pilot,
              'Warp success & evasion', Icons.navigation),
          const SizedBox(height: 12),
          _SkillBar('Fighter', commander.fighter,
              'Combat hit rate & damage', Icons.gps_fixed),
          const SizedBox(height: 12),
          _SkillBar('Trader', commander.trader,
              'Buy/sell price advantage', Icons.show_chart),
          const SizedBox(height: 12),
          _SkillBar('Engineer', commander.engineer,
              'Repair efficiency', Icons.build_outlined),
        ],
      ),
    );
  }
}

class _SkillBar extends StatelessWidget {
  final String name;
  final int value;
  final String description;
  final IconData icon;
  const _SkillBar(this.name, this.value, this.description, this.icon);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 14, color: cs.primary.withOpacity(0.5)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(name, style: tt.titleSmall),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: value / 10.0,
                        backgroundColor: cs.primary.withOpacity(0.1),
                        color: cs.primary,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 20,
                    child: Text('$value',
                        textAlign: TextAlign.right,
                        style: tt.titleSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(description, style: tt.labelSmall?.copyWith(fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReputationCard extends StatelessWidget {
  final Commander commander;
  const _ReputationCard({required this.commander});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final record = commander.policeRecord;
    final rep = commander.reputation;

    return _Card(
      title: 'STANDING',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('POLICE RECORD', style: tt.labelSmall?.copyWith(fontSize: 9, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text(record.displayName,
                        style: tt.headlineSmall?.copyWith(
                          color: _policeColor(record, cs),
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 4),
                    Text('Score: ${commander.policeRecordScore}',
                        style: tt.bodySmall),
                    const SizedBox(height: 8),
                    _PoliceRecordBar(score: commander.policeRecordScore),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 80,
                color: const Color(0xFF1e2d42),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REPUTATION', style: tt.labelSmall?.copyWith(fontSize: 9, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    Text(rep.displayName,
                        style: tt.headlineSmall?.copyWith(
                          color: _repColor(rep, cs),
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _KillStat('Police', commander.policeKills, cs.error),
                        _KillStat('Traders', commander.traderKills, cs.secondary),
                        _KillStat('Pirates', commander.pirateKills, cs.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _policeColor(PoliceRecord record, ColorScheme cs) {
    switch (record) {
      case PoliceRecord.psycho:
      case PoliceRecord.villain:
      case PoliceRecord.criminal:
        return cs.error;
      case PoliceRecord.crook:
      case PoliceRecord.dubious:
        return cs.secondary;
      case PoliceRecord.clean:
        return cs.onSurface;
      case PoliceRecord.lawful:
      case PoliceRecord.trusted:
      case PoliceRecord.liked:
      case PoliceRecord.hero:
        return cs.primary;
    }
  }

  Color _repColor(Reputation rep, ColorScheme cs) {
    switch (rep) {
      case Reputation.harmless:
      case Reputation.mostlyHarmless:
        return cs.onSurface.withOpacity(0.5);
      case Reputation.poor:
      case Reputation.average:
        return cs.onSurface;
      case Reputation.aboveAverage:
      case Reputation.competent:
        return cs.secondary;
      case Reputation.dangerous:
      case Reputation.deadly:
      case Reputation.elite:
        return cs.error;
    }
  }
}

class _PoliceRecordBar extends StatelessWidget {
  final int score;
  const _PoliceRecordBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Score range: -100 to 75. Normalize to 0-1.
    const minScore = -100;
    const maxScore = 75;
    final normalized = ((score - minScore) / (maxScore - minScore)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: normalized,
            backgroundColor: cs.error.withOpacity(0.2),
            color: score < 0 ? cs.error : score < 10 ? cs.secondary : cs.primary,
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Psycho', style: TextStyle(color: cs.error, fontSize: 8)),
            Text('Hero', style: TextStyle(color: cs.primary, fontSize: 8)),
          ],
        ),
      ],
    );
  }
}

class _KillStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _KillStat(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Text('$count',
            style: tt.titleMedium?.copyWith(
                color: color, fontWeight: FontWeight.w700)),
        Text(label, style: tt.labelSmall?.copyWith(fontSize: 9)),
      ],
    );
  }
}

class _FinanceCard extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _FinanceCard({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return _Card(
      title: 'FINANCES',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _FinanceStat('Credits', '${game.credits} cr', cs.secondary),
              _FinanceStat('Debt', '${game.debt} cr', cs.error),
              _FinanceStat(
                  'Net', '${game.credits - game.debt} cr', cs.primary),
            ],
          ),
          if (game.debt > 0) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Debt accrues 1% daily interest. Pay it down to avoid financial ruin.',
                    style: tt.bodySmall,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: game.credits >= 100
                      ? () {
                          final payAmount =
                              [game.debt, game.credits].reduce(
                                  (a, b) => a < b ? a : b);
                          ref
                              .read(gameProvider.notifier)
                              .payDebt(payAmount);
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.error.withOpacity(0.5)),
                    foregroundColor: cs.error,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('PAY ALL',
                      style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
          if (game.insurance) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 14, color: cs.primary.withOpacity(0.6)),
                const SizedBox(width: 8),
                Text('Ship insurance active', style: tt.bodySmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FinanceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinanceStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(label, style: tt.labelSmall?.copyWith(fontSize: 9, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value,
            style: tt.titleMedium?.copyWith(
                color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  final GameState game;
  const _NetWorthCard({required this.game});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final shipValue = game.ship.def.price ~/ 2;
    final cargoValue = game.ship.totalCargoUsed * 100;

    return _Card(
      title: 'NET WORTH',
      child: Column(
        children: [
          _WorthRow('Credits', game.credits, cs.secondary),
          _WorthRow('Ship (trade-in)', shipValue, cs.primary),
          _WorthRow('Cargo (est.)', cargoValue, cs.onSurface),
          _WorthRow('Debt', -game.debt, cs.error),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL', style: tt.titleMedium?.copyWith(letterSpacing: 1)),
              Text(
                '${game.netWorth} cr',
                style: tt.titleLarge?.copyWith(
                  color: game.netWorth >= 0 ? cs.primary : cs.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorthRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _WorthRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: tt.bodyMedium),
          Text(
            '${value >= 0 ? '' : '-'}${value.abs()} cr',
            style: tt.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1e2d42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: cs.primary.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
