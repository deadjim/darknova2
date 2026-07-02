// Basic smoke test: the app builds and shows the welcome screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:darknova2/main.dart';

void main() {
  testWidgets('App builds and shows the welcome screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DarkNovaApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('DARK NOVA'), findsWidgets);
  });
}
