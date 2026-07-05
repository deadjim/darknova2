import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../engine/news.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/quest.dart';
import '../models/ship.dart';
import '../providers/game_provider.dart';

class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    if (game == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DARK NOVA ]['),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save Game',
            onPressed: () {
              ref.read(gameProvider.notifier).saveGame();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Game saved.')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SystemHeader(game: game),
                const SizedBox(height: 16),
                _StatusBar(game: game),
                const SizedBox(height: 24),
                const _QuestPanel(),
                _NavigationGrid(game: game),
                const SizedBox(height: 24),
                _NewsPanel(game: game),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemHeader extends StatelessWidget {
  final GameState game;
  const _SystemHeader({required this.game});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final system = game.currentSystem;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            const Color(0xFF0d1526),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT LOCATION',
                    style: tt.labelSmall?.copyWith(
                      letterSpacing: 2.5,
                      color: cs.primary.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    system.name.toUpperCase(),
                    style: tt.headlineLarge?.copyWith(
                      color: cs.primary,
                      fontSize: 28,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _BadgeChip(system.government.displayName),
                  const SizedBox(height: 6),
                  _BadgeChip(system.status.displayName,
                      color: _statusColor(system.status, cs)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              _SystemStat(
                'Tech Level',
                '${system.techLevel} — ${_techName(system.techLevel)}',
                Icons.memory,
              ),
              _SystemStat(
                'Government',
                system.government.displayName,
                Icons.account_balance,
              ),
              _SystemStat(
                'Resources',
                system.specialResource.displayName,
                Icons.eco,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(SystemStatus status, ColorScheme cs) {
    switch (status) {
      case SystemStatus.uneventful:
        return cs.primary.withOpacity(0.6);
      case SystemStatus.war:
        return const Color(0xFFef4444);
      case SystemStatus.plague:
        return const Color(0xFF8b5cf6);
      case SystemStatus.drought:
        return const Color(0xFFf97316);
      case SystemStatus.boredom:
        return const Color(0xFF6b7280);
      case SystemStatus.cold:
        return const Color(0xFF60a5fa);
      case SystemStatus.cropFailure:
        return const Color(0xFFeab308);
      case SystemStatus.lackOfWorkers:
        return const Color(0xFFf59e0b);
    }
  }

  String _techName(int level) {
    const names = [
      'Pre-Ag', 'Agrarian', 'Medieval', 'Renaissance',
      'Early Ind', 'Industrial', 'Post-Ind', 'Hi-Tech',
    ];
    return names[level.clamp(0, 7)];
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color? color;
  const _BadgeChip(this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface.withOpacity(0.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: c,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SystemStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SystemStat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.primary.withOpacity(0.5)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tt.labelSmall),
                Text(value,
                    style: tt.bodySmall?.copyWith(color: cs.onSurface),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final GameState game;
  const _StatusBar({required this.game});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.monetization_on_outlined,
            label: 'CREDITS',
            value: _formatCredits(game.credits),
            color: cs.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_today_outlined,
            label: 'DAYS',
            value: '${game.days}',
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HullCard(ship: game.ship),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FuelCard(ship: game.ship),
        ),
      ],
    );
  }

  String _formatCredits(int c) {
    if (c >= 1000000) return '${(c / 1000000).toStringAsFixed(1)}M';
    if (c >= 1000) return '${(c / 1000).toStringAsFixed(1)}K';
    return '$c';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1e2d42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text(label, style: tt.labelSmall?.copyWith(fontSize: 9)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: tt.titleMedium?.copyWith(
                  color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HullCard extends StatelessWidget {
  final Ship ship;
  const _HullCard({required this.ship});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = ship.hullPercent;
    final color = pct > 0.6
        ? cs.primary
        : pct > 0.3
            ? cs.secondary
            : const Color(0xFFef4444);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1e2d42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 12, color: color.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text('HULL', style: tt.labelSmall?.copyWith(fontSize: 9)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${ship.hullStrength}/${ship.maxHullStrength}',
            style: tt.titleMedium?.copyWith(
                color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withOpacity(0.1),
              color: color,
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelCard extends StatelessWidget {
  final Ship ship;
  const _FuelCard({required this.ship});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = ship.maxFuel > 0 ? ship.fuel / ship.maxFuel : 0.0;
    final color = pct > 0.3 ? cs.primary : cs.secondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1e2d42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_gas_station_outlined,
                  size: 12, color: color.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text('FUEL', style: tt.labelSmall?.copyWith(fontSize: 9)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${ship.fuel}/${ship.maxFuel}',
            style: tt.titleMedium?.copyWith(
                color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withOpacity(0.1),
              color: color,
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationGrid extends StatelessWidget {
  final GameState game;
  const _NavigationGrid({required this.game});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const items = [
      _NavItem('GALAXY MAP', Icons.map_outlined, '/galaxy',
          'Navigate to new systems'),
      _NavItem('TRADE', Icons.swap_horiz, '/trade', 'Buy and sell cargo'),
      _NavItem('SHIPYARD', Icons.rocket_outlined, '/shipyard',
          'Ships, weapons & upgrades'),
      _NavItem('COMMANDER', Icons.person_outline, '/commander',
          'Status, skills & reputation'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NAVIGATION',
          style: TextStyle(
            color: cs.primary.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: items
              .map((item) => _NavButton(
                    item: item,
                    onTap: () => context.go(item.route),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  final String subtitle;
  const _NavItem(this.label, this.icon, this.route, this.subtitle);
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1e2d42)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(item.icon, color: cs.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.label,
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          fontSize: 11,
                        )),
                    Text(item.subtitle,
                        style: tt.labelSmall?.copyWith(fontSize: 10),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 16,
                  color: cs.primary.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsPanel extends StatelessWidget {
  final GameState game;
  const _NewsPanel({required this.game});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final headlines = [
      ...NewsEngine.headlines(game),
      if (game.debt > 0)
        'FINANCE: Current debt standing at ${game.debt} cr. '
            'Daily interest accruing at 1%.',
      'Day ${game.days}: Commander ${game.commander.name} — '
          '${game.commander.reputation.displayName} — '
          '${game.commander.policeRecord.displayName}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GNN — GALACTIC NEWS NETWORK',
          style: TextStyle(
            color: cs.primary.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1e2d42)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < headlines.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6, right: 10),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(headlines[i], style: tt.bodyMedium),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

}

/// Quest surface: shows the outcome of a just-resolved quest, a pending
/// offer (accept/decline), or progress on the active job.
class _QuestPanel extends ConsumerWidget {
  const _QuestPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    final resolved = ref.watch(resolvedQuestProvider);
    if (game == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final children = <Widget>[];

    if (resolved != null) {
      final success = resolved.status == QuestStatus.completed;
      children.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                success
                    ? 'CONTRACT FULFILLED — ${resolved.title}'
                    : 'CONTRACT FAILED — ${resolved.title}',
                style: tt.titleSmall?.copyWith(
                    color: success ? cs.primary : cs.error),
              ),
              const SizedBox(height: 6),
              Text(success ? resolved.successText : resolved.failureText,
                  style: tt.bodyMedium),
              if (success) ...[
                const SizedBox(height: 6),
                Text('+${resolved.rewardCredits} cr',
                    style: tt.labelLarge),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      ref.read(resolvedQuestProvider.notifier).state = null,
                  child: const Text('DISMISS'),
                ),
              ),
            ],
          ),
        ),
      ));
      children.add(const SizedBox(height: 16));
    }

    final offer = game.questOffer;
    if (offer != null) {
      children.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(offer.title,
                  style: tt.titleSmall?.copyWith(color: cs.secondary)),
              const SizedBox(height: 6),
              Text(offer.hook, style: tt.bodyMedium),
              const SizedBox(height: 8),
              Text(
                'Deliver ${offer.qty} × ${offer.good.displayName} to '
                '${game.solarSystems[offer.targetSystemIndex].name} '
                'by day ${offer.deadlineDay} — ${offer.rewardCredits} cr',
                style: tt.labelMedium,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        ref.read(gameProvider.notifier).declineQuest(),
                    child: const Text('DECLINE'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(gameProvider.notifier).acceptQuest(),
                    child: const Text('ACCEPT'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ));
      children.add(const SizedBox(height: 16));
    }

    final active = game.activeQuest;
    if (active != null) {
      final carrying = game.ship.cargo[active.good] ?? 0;
      children.add(Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACTIVE — ${active.title}',
                  style: tt.titleSmall?.copyWith(color: cs.primary)),
              const SizedBox(height: 6),
              Text(
                'Deliver ${active.qty} × ${active.good.displayName} to '
                '${game.solarSystems[active.targetSystemIndex].name} '
                'by day ${active.deadlineDay} '
                '(carrying $carrying/${active.qty}) — '
                '${active.rewardCredits} cr on completion',
                style: tt.bodyMedium,
              ),
            ],
          ),
        ),
      ));
      children.add(const SizedBox(height: 16));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
