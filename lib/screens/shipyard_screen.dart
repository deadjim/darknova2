import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/ship_type_def.dart';
import '../providers/game_provider.dart';

class ShipyardScreen extends ConsumerWidget {
  const ShipyardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameProvider);
    if (game == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('SHIPYARD — ${game.currentSystem.name.toUpperCase()}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/game'),
          ),
          bottom: TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            indicatorColor: Theme.of(context).colorScheme.primary,
            isScrollable: true,
            tabs: const [
              Tab(text: 'MY SHIP'),
              Tab(text: 'SHIPS'),
              Tab(text: 'WEAPONS & SHIELDS'),
              Tab(text: 'GADGETS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MyShipTab(game: game, ref: ref),
            _ShipsTab(game: game, ref: ref),
            _WeaponsTab(game: game, ref: ref),
            _GadgetsTab(game: game, ref: ref),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// My Ship tab
// ---------------------------------------------------------------------------

class _MyShipTab extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _MyShipTab({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ship = game.ship;
    final def = ship.def;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('CURRENT VESSEL'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(def.displayName.toUpperCase(),
                        style: tt.headlineMedium?.copyWith(
                            color: cs.primary, letterSpacing: 2)),
                    Text('${def.price} cr',
                        style: tt.titleMedium?.copyWith(
                            color: cs.secondary)),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                _ShipStatsGrid(def: def, ship: ship),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                _SectionLabel('HULL'),
                const SizedBox(height: 8),
                _RepairRow(game: game, ref: ref),
                const SizedBox(height: 16),
                _SectionLabel('FUEL'),
                const SizedBox(height: 8),
                _FuelRow(game: game, ref: ref),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel('LOADOUT'),
          const SizedBox(height: 12),
          _LoadoutSection(game: game, ref: ref),
          const SizedBox(height: 24),
          _SectionLabel('EQUIPMENT'),
          const SizedBox(height: 12),
          _EscapePodRow(game: game, ref: ref),
        ],
      ),
    );
  }
}

class _ShipStatsGrid extends StatelessWidget {
  final ShipTypeDef def;
  final dynamic ship;
  const _ShipStatsGrid({required this.def, required this.ship});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        _StatChip('Cargo', '${def.cargoBays} bays'),
        _StatChip('Weapons', '${def.weaponSlots} slots'),
        _StatChip('Shields', '${def.shieldSlots} slots'),
        _StatChip('Gadgets', '${def.gadgetSlots} slots'),
        _StatChip('Fuel Tanks', '${def.fuelTanks}'),
        _StatChip('Hull', '${def.hullStrength}'),
        _StatChip('Min Tech', '${def.minTechLevel}'),
        _StatChip('Size', '${def.size}'),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: tt.labelSmall),
        Text(value,
            style:
                tt.titleSmall?.copyWith(color: cs.primary)),
      ],
    );
  }
}

class _RepairRow extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _RepairRow({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ship = game.ship;
    final needed = ship.maxHullStrength - ship.hullStrength;
    final costPer = ship.def.repairCosts;
    final totalCost = needed * costPer;
    final pct = ship.hullPercent;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: cs.error.withOpacity(0.15),
                  color: pct > 0.6
                      ? cs.primary
                      : pct > 0.3
                          ? cs.secondary
                          : cs.error,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${ship.hullStrength} / ${ship.maxHullStrength} HP',
                style: tt.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (needed > 0) ...[
          Text('$costPer cr/pt', style: tt.bodySmall),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: game.credits >= totalCost
                ? () {
                    final success =
                        ref.read(gameProvider.notifier).repairHull(needed);
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cannot repair.')),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: Text('REPAIR ALL\n$totalCost cr',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10)),
          ),
        ] else
          Text('HULL INTACT',
              style: tt.labelSmall
                  ?.copyWith(color: cs.primary.withOpacity(0.6))),
      ],
    );
  }
}

class _FuelRow extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _FuelRow({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ship = game.ship;
    final needed = ship.maxFuel - ship.fuel;
    final costPer = ship.def.costOfFuel;
    final totalCost = needed * costPer;
    final pct = ship.maxFuel > 0 ? ship.fuel / ship.maxFuel : 0.0;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: cs.secondary.withOpacity(0.1),
                  color: cs.secondary,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${ship.fuel} / ${ship.maxFuel} units',
                style: tt.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (needed > 0) ...[
          Text('$costPer cr/unit', style: tt.bodySmall),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: game.credits >= totalCost
                ? () {
                    ref.read(gameProvider.notifier).buyFuel(needed);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              backgroundColor: cs.secondary,
            ),
            child: Text('FILL TANK\n$totalCost cr',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10)),
          ),
        ] else
          Text('TANK FULL',
              style: tt.labelSmall
                  ?.copyWith(color: cs.secondary.withOpacity(0.6))),
      ],
    );
  }
}

class _LoadoutSection extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _LoadoutSection({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ship = game.ship;
    final def = ship.def;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Weapons
        _LoadoutSlotList(
          label: 'WEAPONS',
          count: ship.weapons.length,
          maxCount: def.weaponSlots,
          items: ship.weapons.map((w) => w.displayName).toList(),
          prices: ship.weapons.map((w) => w.price).toList(),
          onSell: (i) {
            ref
                .read(gameProvider.notifier)
                .sellWeapon(ship.weapons[i]);
          },
        ),
        const SizedBox(height: 12),
        // Shields
        _LoadoutSlotList(
          label: 'SHIELDS',
          count: ship.shields.length,
          maxCount: def.shieldSlots,
          items: ship.shields.map((s) => s.displayName).toList(),
          prices: ship.shields.map((s) => s.price).toList(),
          onSell: (i) {
            ref
                .read(gameProvider.notifier)
                .sellShield(ship.shields[i]);
          },
        ),
        const SizedBox(height: 12),
        // Gadgets
        _LoadoutSlotList(
          label: 'GADGETS',
          count: ship.gadgets.length,
          maxCount: def.gadgetSlots,
          items: ship.gadgets.map((g) => g.displayName).toList(),
          prices: ship.gadgets.map((g) => g.price).toList(),
          onSell: (i) {
            ref
                .read(gameProvider.notifier)
                .sellGadget(ship.gadgets[i]);
          },
        ),
      ],
    );
  }
}

class _LoadoutSlotList extends StatelessWidget {
  final String label;
  final int count;
  final int maxCount;
  final List<String> items;
  final List<int> prices;
  final void Function(int) onSell;

  const _LoadoutSlotList({
    required this.label,
    required this.count,
    required this.maxCount,
    required this.items,
    required this.prices,
    required this.onSell,
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
              Text(label,
                  style: tt.labelSmall
                      ?.copyWith(letterSpacing: 2, fontSize: 9)),
              const Spacer(),
              Text('$count/$maxCount',
                  style: tt.labelSmall?.copyWith(
                      color: cs.primary, fontSize: 9)),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (int i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.remove_circle_outline,
                        size: 12,
                        color: cs.primary.withOpacity(0.4)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(items[i], style: tt.bodyMedium)),
                    TextButton(
                      onPressed: () => onSell(i),
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                      child: Text('SELL (${prices[i] ~/ 2} cr)',
                          style: const TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ),
          ] else ...[
            const SizedBox(height: 8),
            Text(maxCount == 0 ? 'No slots' : 'Empty',
                style: tt.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _EscapePodRow extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _EscapePodRow({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1e2d42)),
      ),
      child: Row(
        children: [
          Icon(
            game.escapePod
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            color: game.escapePod ? cs.primary : cs.onSurface.withOpacity(0.3),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Escape Pod', style: tt.titleSmall),
                Text('Survive ship destruction — 2,000 cr',
                    style: tt.bodySmall),
              ],
            ),
          ),
          if (!game.escapePod)
            OutlinedButton(
              onPressed: game.credits >= 2000
                  ? () => ref.read(gameProvider.notifier).buyEscapePod()
                  : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
              ),
              child: const Text('BUY'),
            )
          else
            Text('INSTALLED',
                style: tt.labelSmall
                    ?.copyWith(color: cs.primary.withOpacity(0.6))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ships tab
// ---------------------------------------------------------------------------

class _ShipsTab extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _ShipsTab({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final techLevel = game.currentSystem.techLevel;
    final available = ShipTypeDef.all
        .where((s) => s.minTechLevel <= techLevel)
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: available.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _ShipCard(
        def: available[i],
        game: game,
        ref: ref,
      ),
    );
  }
}

class _ShipCard extends StatelessWidget {
  final ShipTypeDef def;
  final GameState game;
  final WidgetRef ref;
  const _ShipCard(
      {required this.def, required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isOwned = game.ship.shipType == def.shipType;
    final tradeIn = game.ship.def.price ~/ 2;
    final netCost = def.price - tradeIn;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOwned ? cs.primary.withOpacity(0.5) : const Color(0xFF1e2d42),
          width: isOwned ? 1.5 : 1,
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
                  Text(def.displayName.toUpperCase(),
                      style: tt.titleLarge?.copyWith(
                          color: isOwned ? cs.primary : cs.onSurface,
                          letterSpacing: 1.5)),
                  if (isOwned)
                    Text('CURRENT SHIP',
                        style: tt.labelSmall?.copyWith(
                            color: cs.primary.withOpacity(0.6),
                            fontSize: 9,
                            letterSpacing: 2)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${def.price} cr',
                      style: tt.titleMedium?.copyWith(
                          color: cs.secondary, fontWeight: FontWeight.w700)),
                  if (!isOwned)
                    Text(
                      'Net: ${netCost > 0 ? '+$netCost' : netCost} cr',
                      style: tt.labelSmall?.copyWith(
                        color: netCost > 0
                            ? cs.error.withOpacity(0.7)
                            : const Color(0xFF4ade80),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _StatChip('Cargo', '${def.cargoBays}'),
              _StatChip('Weapons', '${def.weaponSlots}'),
              _StatChip('Shields', '${def.shieldSlots}'),
              _StatChip('Gadgets', '${def.gadgetSlots}'),
              _StatChip('Hull', '${def.hullStrength}'),
              _StatChip('Fuel', '${def.maxFuel}'),
              _StatChip('Size', '${def.size}'),
            ],
          ),
          if (!isOwned) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: game.credits >= netCost
                    ? () {
                        _confirmBuy(context, def, netCost);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text('BUY ${def.displayName.toUpperCase()}'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmBuy(BuildContext context, ShipTypeDef def, int cost) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Buy ${def.displayName}?'),
        content: Text(
          'Trade in your ${game.ship.def.displayName} and pay $cost cr net?\n\n'
          'Equipment that doesn\'t fit in the new ship will be sold at 50%.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final success =
                  ref.read(gameProvider.notifier).buyShip(def.shipType);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchase failed.')),
                );
              }
            },
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weapons & Shields tab
// ---------------------------------------------------------------------------

class _WeaponsTab extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _WeaponsTab({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final techLevel = game.currentSystem.techLevel;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('WEAPONS'),
          const SizedBox(height: 12),
          ...WeaponType.values.where((w) => w.minTechLevel <= techLevel).map(
                (w) => _EquipCard(
              label: w.displayName,
              subtitle: 'Power: ${w.power}',
              price: w.price,
              onBuy: game.ship.canAddWeapon() && game.credits >= w.price
                  ? () => ref.read(gameProvider.notifier).buyWeapon(w)
                  : null,
              canBuy: game.ship.canAddWeapon(),
              credits: game.credits,
            ),
              ),
          const SizedBox(height: 24),
          _SectionLabel('SHIELDS'),
          const SizedBox(height: 12),
          ...ShieldType.values.where((s) => s.minTechLevel <= techLevel).map(
                (s) => _EquipCard(
              label: s.displayName,
              subtitle: 'Strength: ${s.strength}',
              price: s.price,
              onBuy: game.ship.canAddShield() && game.credits >= s.price
                  ? () => ref.read(gameProvider.notifier).buyShield(s)
                  : null,
              canBuy: game.ship.canAddShield(),
              credits: game.credits,
            ),
              ),
        ],
      ),
    );
  }
}

class _EquipCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final int price;
  final VoidCallback? onBuy;
  final bool canBuy;
  final int credits;

  const _EquipCard({
    required this.label,
    required this.subtitle,
    required this.price,
    required this.onBuy,
    required this.canBuy,
    required this.credits,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1e2d42)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tt.titleSmall),
                Text(subtitle, style: tt.bodySmall),
              ],
            ),
          ),
          Text('$price cr',
              style: tt.titleSmall
                  ?.copyWith(color: cs.secondary)),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onBuy,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
            ),
            child: Text(
              !canBuy ? 'NO SLOT' : credits < price ? 'NO CR' : 'BUY',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Gadgets tab
// ---------------------------------------------------------------------------

class _GadgetsTab extends StatelessWidget {
  final GameState game;
  final WidgetRef ref;
  const _GadgetsTab({required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final techLevel = game.currentSystem.techLevel;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('GADGETS'),
          const SizedBox(height: 12),
          ...GadgetType.values
              .where((g) => g.minTechLevel <= techLevel)
              .map((g) => _GadgetCard(gadget: g, game: game, ref: ref)),
        ],
      ),
    );
  }
}

class _GadgetCard extends StatelessWidget {
  final GadgetType gadget;
  final GameState game;
  final WidgetRef ref;
  const _GadgetCard(
      {required this.gadget, required this.game, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final installed = game.ship.hasGadget(gadget);
    final canBuy = game.ship.canAddGadget() && !installed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: installed
              ? cs.primary.withOpacity(0.3)
              : const Color(0xFF1e2d42),
        ),
      ),
      child: Row(
        children: [
          Icon(
            installed
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            color: installed ? cs.primary : cs.onSurface.withOpacity(0.3),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gadget.displayName, style: tt.titleSmall),
                Text(_gadgetDescription(gadget), style: tt.bodySmall),
              ],
            ),
          ),
          Text('${gadget.price} cr',
              style: tt.titleSmall?.copyWith(color: cs.secondary)),
          const SizedBox(width: 12),
          if (installed)
            OutlinedButton(
              onPressed: () => ref
                  .read(gameProvider.notifier)
                  .sellGadget(gadget),
              style: OutlinedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
              child: const Text('SELL', style: TextStyle(fontSize: 11)),
            )
          else
            OutlinedButton(
              onPressed: canBuy && game.credits >= gadget.price
                  ? () => ref.read(gameProvider.notifier).buyGadget(gadget)
                  : null,
              style: OutlinedButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
              child: Text(
                !canBuy ? 'NO SLOT' : game.credits < gadget.price ? 'NO CR' : 'BUY',
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  String _gadgetDescription(GadgetType g) {
    switch (g) {
      case GadgetType.extraCargoBays:
        return '+5 cargo bays';
      case GadgetType.autoRepairSystem:
        return 'Repairs hull each jump';
      case GadgetType.navigatingSystem:
        return '10% fuel efficiency';
      case GadgetType.targetingSystem:
        return '+10% combat hit rate';
      case GadgetType.cloakingDevice:
        return 'Reduces encounter chance';
    }
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        color: cs.primary.withOpacity(0.6),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.5,
      ),
    );
  }
}
