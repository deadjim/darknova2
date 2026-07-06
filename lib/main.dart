import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/game_provider.dart';
import 'screens/commander_screen.dart';
import 'screens/encounter_screen.dart';
import 'screens/vignette_screen.dart';
import 'screens/galaxy_map_screen.dart';
import 'screens/hub_screen.dart';
import 'screens/new_game_screen.dart';
import 'screens/shipyard_screen.dart';
import 'screens/trade_screen.dart';
import 'screens/welcome_screen.dart';

void main() {
  runApp(const ProviderScope(child: DarkNovaApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/new-game',
      builder: (context, state) => const NewGameScreen(),
    ),
    GoRoute(
      path: '/game',
      builder: (context, state) => const HubScreen(),
    ),
    GoRoute(
      path: '/galaxy',
      builder: (context, state) => const GalaxyMapScreen(),
    ),
    GoRoute(
      path: '/trade',
      builder: (context, state) => const TradeScreen(),
    ),
    GoRoute(
      path: '/shipyard',
      builder: (context, state) => const ShipyardScreen(),
    ),
    GoRoute(
      path: '/commander',
      builder: (context, state) => const CommanderScreen(),
    ),
    GoRoute(
      path: '/encounter',
      builder: (context, state) => const EncounterScreen(),
    ),
    GoRoute(
      path: '/vignette',
      builder: (context, state) => const VignetteScreen(),
    ),
  ],
);

class DarkNovaApp extends StatelessWidget {
  const DarkNovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Dark Nova ][',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: _buildTheme(),
    );
  }

  ThemeData _buildTheme() {
    const background = Color(0xFF0a0e1a);
    const surface = Color(0xFF111827);
    const surfaceVariant = Color(0xFF1a2235);
    const primary = Color(0xFF4fc3f7);
    const secondary = Color(0xFFf59e0b);
    const onBackground = Color(0xFFe2e8f0);
    const onSurface = Color(0xFFcbd5e1);
    const error = Color(0xFFf87171);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        background: background,
        surface: surface,
        primary: primary,
        secondary: secondary,
        error: error,
        onBackground: onBackground,
        onSurface: onSurface,
        onPrimary: Color(0xFF0a0e1a),
        onSecondary: Color(0xFF0a0e1a),
        surfaceVariant: surfaceVariant,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onBackground,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: primary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: Color(0xFF1e2d42), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1e2d42),
        thickness: 1,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: onBackground, fontWeight: FontWeight.w300),
        displayMedium: TextStyle(color: onBackground, fontWeight: FontWeight.w300),
        headlineLarge: TextStyle(color: onBackground, fontWeight: FontWeight.w600, letterSpacing: 1.0),
        headlineMedium: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: onBackground, fontWeight: FontWeight.w500),
        titleLarge: TextStyle(color: onBackground, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: onSurface, letterSpacing: 0.8),
        bodyLarge: TextStyle(color: onBackground),
        bodyMedium: TextStyle(color: onSurface),
        bodySmall: TextStyle(color: Color(0xFF64748b)),
        labelLarge: TextStyle(color: primary, fontWeight: FontWeight.w600, letterSpacing: 1.2),
        labelMedium: TextStyle(color: onSurface, letterSpacing: 0.5),
        labelSmall: TextStyle(color: Color(0xFF64748b), letterSpacing: 0.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF1e2d42)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF1e2d42)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF64748b)),
        hintStyle: const TextStyle(color: Color(0xFF475569)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w700, letterSpacing: 1.2),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w600, letterSpacing: 1.0),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: background,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: TextStyle(color: onBackground),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
