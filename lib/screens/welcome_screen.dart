import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/game_provider.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSaveAsync = ref.watch(hasSaveProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF050810),
              cs.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    // Star field decoration
                    _StarField(),
                    const SizedBox(height: 32),
                    // Title
                    Text(
                      'DARK NOVA',
                      style: tt.displayMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 12,
                        fontSize: 40,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '][',
                      style: tt.headlineLarge?.copyWith(
                        color: cs.secondary,
                        letterSpacing: 8,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'A SPACE TRADING ADVENTURE',
                      style: tt.labelSmall?.copyWith(
                        letterSpacing: 4,
                        color: cs.onSurface.withOpacity(0.5),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(flex: 2),
                    // Buttons
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/new-game'),
                        child: const Text('NEW COMMANDER'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    hasSaveAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (hasSave) => hasSave
                          ? SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () async {
                                  final notifier = ref.read(
                                      gameProvider.notifier);
                                  final loaded = await notifier.loadGame();
                                  if (loaded && context.mounted) {
                                    context.go('/game');
                                  }
                                },
                                child: const Text('CONTINUE'),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const Spacer(),
                    Text(
                      'Based on Space Trader by Pieter Spronck',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withOpacity(0.25),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 80,
      child: CustomPaint(painter: _StarPainter()),
    );
  }
}

class _StarPainter extends CustomPainter {
  static const _stars = [
    (0.1, 0.2, 1.5), (0.3, 0.5, 1.0), (0.7, 0.1, 2.0), (0.9, 0.4, 1.2),
    (0.5, 0.8, 1.8), (0.2, 0.9, 1.0), (0.8, 0.7, 1.5), (0.6, 0.3, 1.2),
    (0.4, 0.6, 2.0), (0.15, 0.55, 1.0), (0.75, 0.9, 1.2), (0.95, 0.15, 1.5),
    (0.45, 0.2, 1.0), (0.85, 0.5, 1.8), (0.55, 0.75, 1.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final (rx, ry, r) in _stars) {
      final brightness = (r / 2.0).clamp(0.3, 1.0);
      paint.color = Colors.white.withOpacity(brightness);
      canvas.drawCircle(
          Offset(rx * size.width, ry * size.height), r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}
