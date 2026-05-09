import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/library/presentation/screens/book_detail_screen.dart';
import '../../features/reader/presentation/screens/reader_screen.dart';
import '../../features/reading/presentation/screens/reading_hub_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/friend_profile_screen.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

// Bridges Riverpod state changes to GoRouter's Listenable interface.
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
          GoRoute(path: '/reading', builder: (_, __) => const ReadingHubScreen()),
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
          // /profile/edit MUST come before /profile/:userId — GoRouter matches
          // in declaration order, so the literal segment wins over the parameter.
          GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
          GoRoute(
            path: '/profile/:userId',
            builder: (_, s) => FriendProfileScreen(userId: s.pathParameters['userId']!),
          ),
          GoRoute(path: '/friends', builder: (_, __) => const FriendsScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

// ─────────────────────────────────────────────────────────────────────────────
// App shell — wraps every authenticated screen with the bottom nav
// ─────────────────────────────────────────────────────────────────────────────

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final idx = _selectedIndex(context);
    return Scaffold(
      body: Stack(
        children: [
          child,
          // Subtle book-pattern texture overlay — 5% opacity, non-interactive
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.045,
                child: CustomPaint(
                  painter: _BookPatternPainter(),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomNav(selectedIndex: idx),
    );
  }

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/reading') || loc.startsWith('/reader')) return 1;
    if (loc.startsWith('/leaderboard')) return 2;
    if (loc.startsWith('/settings')) return 3;
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Book-pattern background painter
// Draws a tilted repeating grid of small open-book silhouettes at 45° offset
// ─────────────────────────────────────────────────────────────────────────────

class _BookPatternPainter extends CustomPainter {
  static const _color = Color(0xFF6B21A8);

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = _color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;

    final spinePaint = Paint()
      ..color = _color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const double col = 64;  // horizontal spacing
    const double row = 80;  // vertical spacing
    const double bW = 22.0; // book width
    const double bH = 30.0; // book height

    // Odd columns are offset by half a row to create a brick pattern
    for (double xi = 0; xi * col < size.width + col * 2; xi++) {
      final double xBase = xi * col - col * 0.5;
      final double yOffset = (xi % 2 == 0) ? 0 : row * 0.5;
      for (double yi = 0; yi * row < size.height + row * 2; yi++) {
        final double cx = xBase;
        final double cy = yi * row - row * 0.5 + yOffset;

        final rect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: bW,
          height: bH,
        );
        // Book body
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2.5)),
          bodyPaint,
        );
        // Spine (slightly left of center, full height)
        final double spineX = cx - bW * 0.18;
        canvas.drawLine(
          Offset(spineX, cy - bH / 2 + 2),
          Offset(spineX, cy + bH / 2 - 2),
          spinePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom bottom nav — no labels, large colorful icons
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  const _BottomNav({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Extra height so icons don't press against the top border strip
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE9D5FF), width: 2.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A6B21A8),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          // Clear space between the top border and the icon containers
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                color: AppTheme.primary,
                bgColor: AppTheme.primarySurface,
                isSelected: selectedIndex == 0,
                onTap: () => context.go('/library'),
              ),
              _NavItem(
                icon: Icons.menu_book_rounded,
                color: const Color(0xFFEC4899),
                bgColor: const Color(0xFFFCE7F3),
                isSelected: selectedIndex == 1,
                onTap: () => context.go('/reading'),
              ),
              _NavItem(
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFEF3C7),
                isSelected: selectedIndex == 2,
                onTap: () => context.go('/leaderboard'),
              ),
              _NavItem(
                icon: Icons.settings_rounded,
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFDBEAFE),
                isSelected: selectedIndex == 3,
                onTap: () => context.go('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool isSelected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 56,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: isSelected ? 52 : 44,
            height: isSelected ? 52 : 44,
            decoration: isSelected
                ? BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  )
                : null,
            child: Icon(
              icon,
              size: isSelected ? 30 : 26,
              color: isSelected ? color : const Color(0xFFD1D5DB),
            ),
          ),
        ),
      ),
    );
  }
}
