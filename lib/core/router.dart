import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:protein_calculator/core/home_shell.dart';
import 'package:protein_calculator/features/entry_form/entry_form_page.dart';
import 'package:protein_calculator/features/entry_form/entry_form_state.dart';
import 'package:protein_calculator/features/history/day_detail_page.dart';
import 'package:protein_calculator/features/history/history_page.dart';
import 'package:protein_calculator/features/menu/info_pages.dart';
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

  /// New entry prefilled with a product.
  static String newEntryFrom(int productId) => '$newEntry?productId=$productId';

  static String editEntry(int entryId) => '/entries/$entryId';

  static String historyDay(int dayKey) => '$history/$dayKey';

  static const dataPrivacy = '$menu/data';
  static const about = '$menu/about';

  static const newProduct = '/products/new';

  static String editProduct(int productId) => '$products/$productId';
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
                routes: [
                  GoRoute(
                    path: ':dayKey',
                    builder: (context, state) => DayDetailPage(
                      dayKey: int.parse(state.pathParameters['dayKey']!),
                    ),
                  ),
                ],
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
                routes: [
                  GoRoute(
                    path: 'data',
                    builder: (context, state) => const DataPrivacyPage(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full screen, above the tab bar.
      GoRoute(
        path: AppRoutes.newEntry,
        builder: (context, state) => EntryFormPage(
          args: EntryFormArgs.newEntry(
            productId: int.tryParse(
              state.uri.queryParameters['productId'] ?? '',
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.newProduct,
        builder: (context, state) =>
            const EntryFormPage(args: EntryFormArgs.newProduct()),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (context, state) => EntryFormPage(
          args: EntryFormArgs.editProduct(
            int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: '/entries/:id',
        builder: (context, state) => EntryFormPage(
          args: EntryFormArgs.editEntry(int.parse(state.pathParameters['id']!)),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
