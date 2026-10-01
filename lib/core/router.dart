import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protein_calculator/core/home_shell.dart';
import 'package:protein_calculator/features/entry_form/entry_form_page.dart';
import 'package:protein_calculator/features/history/history_page.dart';
import 'package:protein_calculator/features/menu/menu_page.dart';
import 'package:protein_calculator/features/onboarding/onboarding_page.dart';
import 'package:protein_calculator/features/products/products_page.dart';
import 'package:protein_calculator/features/today/today_page.dart';

abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const today = '/today';
  static const history = '/history';
  static const products = '/products';
  static const menu = '/menu';
  static const newEntry = '/entries/new';
}

/// First page shown: the first launch screen until a daily goal is saved.
/// Overridden in `main` once the settings are read.
final initialLocationProvider = Provider<String>((ref) => AppRoutes.today);

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: ref.watch(initialLocationProvider),
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.today,
                builder: (context, state) => const TodayPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.products,
                builder: (context, state) => const ProductsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.menu,
                builder: (context, state) => const MenuPage(),
              ),
            ],
          ),
        ],
      ),
      // Full screen, above the tab bar.
      GoRoute(
        path: AppRoutes.newEntry,
        builder: (context, state) => const EntryFormPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
