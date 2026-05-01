import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/generation/generation_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/itinerary/itinerary_screen.dart';
import '../../features/settings/settings_screen.dart';

/// Application route paths.
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String generate = '/generate';
  static const String itinerary = '/itinerary/:id';
  static const String history = '/history';
  static const String settings = '/settings';

  /// Build the itinerary detail path for a specific [id].
  static String itineraryDetail(String id) => '/itinerary/$id';
}

// Keys for the navigator shells so the bottom nav state is preserved
// across tab switches while keeping /generate and /itinerary/:id
// outside the shell.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// The top‑level [GoRouter] configuration.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.home,
  routes: [
    // ── Bottom‑nav shell (Home / History / Settings) ───────────────
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => _ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: AppRoutes.history,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HistoryScreen()),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
      ],
    ),

    // ── Routes outside the bottom‑nav shell ────────────────────────
    GoRoute(
      path: AppRoutes.generate,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        final prompt = extra is String ? extra : '';
        return GenerationScreen(prompt: prompt);
      },
    ),
    GoRoute(
      path: AppRoutes.itinerary,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ItineraryScreen(id: id);
      },
    ),
  ],
);

// ──────────────────────────────────────────────────────────────────────
// Bottom Navigation shell
// ──────────────────────────────────────────────────────────────────────

class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.child});

  final Widget child;

  /// Map the current location to the selected tab index.
  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith(AppRoutes.history)) return 1;
    if (location.startsWith(AppRoutes.settings)) return 2;
    return 0; // Home
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
      case 1:
        context.go(AppRoutes.history);
      case 2:
        context.go(AppRoutes.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
