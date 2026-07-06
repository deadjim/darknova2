import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../engine/arrival.dart';
import '../providers/game_provider.dart';

class VignetteScreen extends ConsumerWidget {
  const VignetteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vignette = ref.watch(vignetteProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (vignette == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/game');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final notifier = ref.read(vignetteProvider.notifier);
    final resolved = vignette.resultText != null;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(vignette.event.title),
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
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(vignette.event.body,
                                    style: tt.bodyLarge),
                              ),
                            ),
                            if (vignette.event.hint != null) ...[
                              const SizedBox(height: 12),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'SENSORS: ${vignette.event.hint}',
                                    style: tt.bodyMedium
                                        ?.copyWith(color: cs.secondary),
                                  ),
                                ),
                              ),
                            ],
                            if (resolved) ...[
                              const SizedBox(height: 12),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(vignette.resultText!,
                                      style: tt.bodyLarge
                                          ?.copyWith(color: cs.primary)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (resolved)
                      ElevatedButton(
                        onPressed: () {
                          final toCombat = vignette.toCombat;
                          notifier.clear();
                          context.go(toCombat ? '/encounter' : '/game');
                        },
                        child:
                            Text(vignette.toCombat ? 'ENGAGE' : 'CONTINUE'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final choice in vignette.event.choices)
                            _choiceButton(choice, notifier),
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

  Widget _choiceButton(VignetteChoice choice, VignetteNotifier notifier) {
    final (label, primary) = switch (choice) {
      VignetteChoice.respond => ('RESPOND', true),
      VignetteChoice.scan => ('SCAN FIRST', false),
      VignetteChoice.jumpAway => ('JUMP AWAY', false),
      VignetteChoice.board => ('BOARD', true),
      VignetteChoice.leave => ('LEAVE IT', false),
      VignetteChoice.surrenderCargo => ('JETTISON CARGO', false),
      VignetteChoice.fight => ('FIGHT', true),
      VignetteChoice.evade => ('RUN THE LANE', false),
    };
    return primary
        ? ElevatedButton(
            onPressed: () => notifier.choose(choice), child: Text(label))
        : OutlinedButton(
            onPressed: () => notifier.choose(choice), child: Text(label));
  }
}
