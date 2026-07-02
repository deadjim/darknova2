import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../engine/economy.dart';
import '../models/commander.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/solar_system.dart';
import '../models/trade_item_def.dart';
import '../providers/game_provider.dart';

class TradeScreen extends ConsumerStatefulWidget {
  const TradeScreen({super.key});

  @override
  ConsumerState<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends ConsumerState<TradeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameProvider);
    if (game == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final system = game.currentSystem;

    return Scaffold(
      appBar: AppBar(
        title: Text('TRADE — ${system.name.toUpperCase()}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/game'),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withOpacity(0.5),
          indicatorColor: cs.primary,
          tabs: const [
            Tab(text: 'BUY'),
            Tab(text: 'SELL'),
          ],
        ),
      ),
      body: Column(
        children: [
          _CargoBar(game: game),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TradeList(
                  game: game,
                  isBuying: true,
                  onTransact: (good, qty) => _buyGood(game, good, qty),
                ),
                _TradeList(
                  game: game,
                  isBuying: false,
                  onTransact: (good, qty) => _sellGood(game, good, qty),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _buyGood(GameState game, TradeGood good, int qty) {
    final success = ref.read(gameProvider.notifier).buyGood(good, qty);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_buyFailReason(game, good, qty)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bought $qty ${good.displayName}.'),
        ),
      );
    }
  }

  void _sellGood(GameState game, TradeGood good, int qty) {
    final success = ref.read(gameProvider.notifier).sellGood(good, qty);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot sell that here.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sold $qty ${good.displayName}.')),
      );
    }
  }

  String _buyFailReason(GameState game, TradeGood good, int qty) {
    final system = game.currentSystem;
    if (!Economy.canTradeGood(system, good)) return 'That good is unavailable here.';
    final price = game.buyPrices[good] ?? 0;
    if (game.credits < price * qty) return 'Insufficient credits.';
    if (game.ship.availableCargoBays < qty) return 'Insufficient cargo space.';
    final avail = system.tradeQuantities[good] ?? 0;
    if (avail < qty) return 'Not enough available in this system.';
    return 'Transaction failed.';
  }
}

class _CargoBar extends StatelessWidget {
  final GameState game;
  const _CargoBar({required this.game});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ship = game.ship;
    final used = ship.totalCargoUsed;
    final total = ship.totalCargoBays;
    final pct = total > 0 ? used / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.surface,
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 14, color: cs.primary.withOpacity(0.6)),
          const SizedBox(width: 8),
          Text('CARGO', style: tt.labelSmall?.copyWith(fontSize: 9, letterSpacing: 2)),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: cs.primary.withOpacity(0.1),
                color: pct > 0.9 ? cs.error : cs.primary,
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$used / $total bays',
            style: tt.labelMedium?.copyWith(color: cs.primary),
          ),
          const SizedBox(width: 16),
          Icon(Icons.monetization_on_outlined,
              size: 14, color: cs.secondary.withOpacity(0.6)),
          const SizedBox(width: 6),
          Text(
            '${game.credits} cr',
            style: tt.labelMedium?.copyWith(
                color: cs.secondary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TradeList extends StatelessWidget {
  final GameState game;
  final bool isBuying;
  final void Function(TradeGood, int) onTransact;

  const _TradeList({
    required this.game,
    required this.isBuying,
    required this.onTransact,
  });

  @override
  Widget build(BuildContext context) {
    final system = game.currentSystem;
    final goods = TradeGood.values;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: goods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final good = goods[i];
        return _TradeRow(
          good: good,
          game: game,
          system: system,
          isBuying: isBuying,
          onTransact: onTransact,
        );
      },
    );
  }
}

class _TradeRow extends StatefulWidget {
  final TradeGood good;
  final GameState game;
  final SolarSystem system;
  final bool isBuying;
  final void Function(TradeGood, int) onTransact;

  const _TradeRow({
    required this.good,
    required this.game,
    required this.system,
    required this.isBuying,
    required this.onTransact,
  });

  @override
  State<_TradeRow> createState() => _TradeRowState();
}

class _TradeRowState extends State<_TradeRow> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final game = widget.game;
    final good = widget.good;
    final system = widget.system;

    final canTrade = Economy.canTradeGood(system, good);
    final isIllegal = Economy.isIllegal(system, good);
    final buyPrice = game.buyPrices[good] ?? 0;
    final sellPrice = game.sellPrices[good] ?? 0;
    final price = widget.isBuying ? buyPrice : sellPrice;
    final available = system.tradeQuantities[good] ?? 0;
    final inCargo = game.ship.cargo[good] ?? 0;
    final def = TradeItemDef.forGood(good);

    // For selling: need goods in cargo and market must accept them.
    final canTransact = canTrade &&
        price > 0 &&
        (widget.isBuying
            ? available >= _quantity &&
                game.credits >= price * _quantity &&
                game.ship.availableCargoBays >= _quantity
            : inCargo >= _quantity);

    final maxQty = widget.isBuying
        ? [
            available,
            game.ship.availableCargoBays,
            price > 0 ? game.credits ~/ price : 0,
            99,
          ].reduce((a, b) => a < b ? a : b).clamp(1, 99)
        : inCargo.clamp(1, 99);

    return AnimatedOpacity(
      opacity: (canTrade && price > 0) ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isIllegal
                ? cs.error.withOpacity(0.3)
                : const Color(0xFF1e2d42),
          ),
        ),
        child: Row(
          children: [
            // Good info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(good.displayName,
                          style: tt.titleSmall?.copyWith(
                            color: isIllegal
                                ? cs.error.withOpacity(0.8)
                                : cs.onSurface,
                          )),
                      if (isIllegal) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: cs.error.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('ILLEGAL',
                              style: TextStyle(
                                  color: cs.error,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _SmallStat('Available', '$available'),
                      const SizedBox(width: 12),
                      _SmallStat('In Hold', '$inCargo'),
                      const SizedBox(width: 12),
                      _SmallStat('Min Tech', '${def.techUsage}'),
                    ],
                  ),
                ],
              ),
            ),
            // Price
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    price > 0 ? '${price} cr' : '—',
                    style: tt.titleMedium?.copyWith(
                      color: price > 0
                          ? (widget.isBuying ? cs.secondary : cs.primary)
                          : cs.onSurface.withOpacity(0.3),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (price > 0) ...[
                    const SizedBox(height: 2),
                    _PriceTrend(good: good, system: system),
                  ],
                ],
              ),
            ),
            // Quantity selector + button
            if (canTrade && price > 0) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _quantity > 1
                        ? () => setState(
                            () => _quantity = (_quantity - 1).clamp(1, 99))
                        : null,
                    icon: const Icon(Icons.remove, size: 14),
                    constraints: const BoxConstraints(
                        minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      foregroundColor: cs.primary,
                      disabledForegroundColor:
                          cs.onSurface.withOpacity(0.2),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: tt.titleSmall?.copyWith(
                          color: cs.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: _quantity < maxQty
                        ? () => setState(
                            () => _quantity = (_quantity + 1).clamp(1, 99))
                        : null,
                    icon: const Icon(Icons.add, size: 14),
                    constraints: const BoxConstraints(
                        minWidth: 28, minHeight: 28),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      foregroundColor: cs.primary,
                      disabledForegroundColor:
                          cs.onSurface.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed:
                        canTransact ? () => widget.onTransact(good, _quantity) : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      backgroundColor: widget.isBuying
                          ? cs.secondary
                          : cs.primary,
                      foregroundColor: const Color(0xFF0a0e1a),
                      textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0),
                    ),
                    child: Text(widget.isBuying ? 'BUY' : 'SELL'),
                  ),
                ],
              ),
            ] else ...[
              Text(
                canTrade ? 'NO SUPPLY' : 'UNAVAILABLE',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurface.withOpacity(0.3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  const _SmallStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: tt.labelSmall?.copyWith(fontSize: 9)),
        Text(value,
            style: tt.labelSmall
                ?.copyWith(fontSize: 9, color: cs.onSurface)),
      ],
    );
  }
}

class _PriceTrend extends StatelessWidget {
  final TradeGood good;
  final SolarSystem system;
  const _PriceTrend({required this.good, required this.system});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final def = TradeItemDef.forGood(good);

    // Compare current price to the mid-range of the good.
    final mid = (def.minTradePrice + def.maxTradePrice) / 2;
    final buyPrice = Economy.calculateBuyPrice(
        system, good, _dummyCommander());
    final isHigh = buyPrice > mid;
    final isLow = buyPrice < mid;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isHigh ? Icons.trending_up : isLow ? Icons.trending_down : Icons.trending_flat,
          size: 12,
          color: isHigh
              ? cs.error.withOpacity(0.7)
              : isLow
                  ? const Color(0xFF4ade80)
                  : cs.onSurface.withOpacity(0.3),
        ),
      ],
    );
  }
}

// Local minimal commander for price trend calculations (no skills).
Commander _dummyCommander() => const Commander(
      name: '',
      pilot: 1,
      fighter: 1,
      trader: 1,
      engineer: 1,
      policeRecordScore: 0,
      reputationScore: 0,
      policeKills: 0,
      traderKills: 0,
      pirateKills: 0,
    );
