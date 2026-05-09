import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/library/presentation/screens/book_detail_screen.dart';
import '../../features/reader/presentation/screens/reader_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/friend_profile_screen.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../providers/auth_provider.dart';

// Bridges Riverpod state changes to GoRouter's Listenable interface.
// When isAuthenticatedProvider flips, notifyListeners() triggers GoRouter
// to re-run its redirect callback — without recreating the router.
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
    final isAuthRoute = state.matchedLocation.startsWith('/auth');
    if (!_isLoggedIn && !isAuthRoute) return '/auth/login';
    if (_isLoggedIn && isAuthRoute) return '/library';
    return null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  final router = GoRouter(
    initialLocation: '/library',
    refreshListenable: notifier,
    redirect: (_, state) => notifier.redirect(state),
    routes: [
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),

      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
          GoRoute(
            path: '/books/:id',
            builder: (_, s) => BookDetailScreen(bookId: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/reader/:bookId',
            builder: (_, s) => ReaderScreen(bookId: s.pathParameters['bookId']!),
          ),
          GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(
            path: '/profile/:userId',
            builder: (_, s) => FriendProfileScreen(userId: s.pathParameters['userId']!),
          ),
          GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
          GoRoute(path: '/friends', builder: (_, __) => const FriendsScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Notifications'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (i) => _navigate(context, i),
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/leaderboard')) return 1;
    if (loc.startsWith('/notifications')) return 2;
    if (loc.startsWith('/profile')) return 3;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/library');
      case 1: context.go('/leaderboard');
      case 2: context.go('/notifications');
      case 3: context.go('/profile');
    }
  }
}
