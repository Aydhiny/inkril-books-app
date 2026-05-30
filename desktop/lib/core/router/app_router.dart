import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/users/presentation/screens/users_screen.dart';
import '../../features/books/presentation/screens/books_screen.dart';
import '../../features/genres/presentation/screens/genres_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Router notifier — bridges Riverpod → GoRouter Listenable
// ─────────────────────────────────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  late bool _isLoggedIn;

  _RouterNotifier(this._ref) {
    _isLoggedIn = _ref.read(isAuthenticatedProvider);
    _ref.listen<bool>(isAuthenticatedProvider, (_, next) {
      _isLoggedIn = next;
      notifyListeners();
    });
  }

  String? redirect(GoRouterState state) {
    final isLogin = state.matchedLocation == '/login';
    if (!_isLoggedIn && !isLogin) return '/login';
    if (_isLoggedIn && isLogin) return '/dashboard';
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  final router = GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: notifier,
    redirect: (_, state) => notifier.redirect(state),
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => _AdminShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/users',     builder: (_, __) => const UsersScreen()),
          GoRoute(path: '/books',     builder: (_, __) => const BooksScreen()),
          GoRoute(path: '/genres',    builder: (_, __) => const GenresScreen()),
          GoRoute(path: '/reports',   builder: (_, __) => const ReportsScreen()),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

// ─────────────────────────────────────────────────────────────────────────────
// Admin shell — side navigation rail
// ─────────────────────────────────────────────────────────────────────────────

class _AdminShell extends StatelessWidget {
  final Widget child;
  const _AdminShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 200,
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard')),
              NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Users')),
              NavigationRailDestination(
                  icon: Icon(Icons.library_books_outlined),
                  selectedIcon: Icon(Icons.library_books),
                  label: Text('Books')),
              NavigationRailDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category),
                  label: Text('Genres')),
              NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('Reports')),
            ],
            selectedIndex: _selectedIndex(context),
            onDestinationSelected: (i) => _navigate(context, i),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/users'))   return 1;
    if (loc.startsWith('/books'))   return 2;
    if (loc.startsWith('/genres'))  return 3;
    if (loc.startsWith('/reports')) return 4;
    return 0;
  }

  void _navigate(BuildContext context, int i) {
    switch (i) {
      case 0: context.go('/dashboard');
      case 1: context.go('/users');
      case 2: context.go('/books');
      case 3: context.go('/genres');
      case 4: context.go('/reports');
    }
  }
}
