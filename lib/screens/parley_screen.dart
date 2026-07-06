import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../engine/parley.dart';
import '../models/enums.dart';
import '../providers/game_provider.dart';

class ParleyScreen extends ConsumerWidget {
  const ParleyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parley = ref.watch(parleyProvider);
    final combat = ref.watch(encounterProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (parley == null || combat == null) {
      // No open channel — bounce back to the hub.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/game');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final notifier = ref.read(parleyProvider.notifier);
    final session = parley.session;

    return PopScope(
      canPop: false, // no backing out of an open channel
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_title(session)),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ListView.builder(
                            reverse: true,
                            itemCount: session.transcript.length,
                            itemBuilder: (context, i) {
                              final entry = session.transcript[
                                  session.transcript.length - 1 - i];
                              final isHail = i == session.transcript.length - 1;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  '≈ $entry',
                                  style: isHail
                                      ? tt.bodyLarge
                                          ?.copyWith(color: cs.secondary)
                                      : tt.bodyMedium,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (parley.over)
                      ElevatedButton(
                        onPressed: () {
                          notifier.clear();
                          context.go('/encounter');
                        },
                        style: parley.escalated
                            ? ElevatedButton.styleFrom(
                                backgroundColor: cs.error)
                            : null,
                        child: Text(parley.escalated
                            ? 'BATTLE STATIONS'
                            : 'CLOSE CHANNEL'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final option in session.options)
                            _optionButton(option, session, notifier),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _title(ParleySession s) {
    if (s.captainName != null) {
      return 'CHANNEL OPEN: ${s.captainName!.toUpperCase()}';
    }
    switch (s.encounterType) {
      case EncounterType.police:
        return 'CHANNEL OPEN: PATROL';
      case EncounterType.pirate:
        return 'CHANNEL OPEN: PIRATE VESSEL';
      case EncounterType.trader:
        return 'CHANNEL OPEN: TRADER';
      case EncounterType.monster:
        return 'CHANNEL OPEN';
    }
  }

  Widget _optionButton(
      ParleyOption option, ParleySession session, ParleyNotifier notifier) {
    final (label, primary) = switch (option) {
      ParleyOption.payOff => (
          session.encounterType == EncounterType.pirate
              ? 'PAY ${session.demandCredits} CR'
              : 'OFFER BRIBE',
          false
        ),
      ParleyOption.bluff => ('BLUFF', false),
      ParleyOption.threaten => ('THREATEN', false),
      ParleyOption.plead => ('PLEAD', false),
      ParleyOption.tradeInfo => ('TRADE INFO', false),
      ParleyOption.comply => (
          session.encounterType == EncounterType.police
              ? 'COMPLY'
              : 'SIGN OFF',
          true
        ),
    };
    return primary
        ? ElevatedButton(
            onPressed: () => notifier.choose(option), child: Text(label))
        : OutlinedButton(
            onPressed: () => notifier.choose(option), child: Text(label));
  }
}
