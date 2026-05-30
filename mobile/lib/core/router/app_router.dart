import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
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
import '../../features/settings/presentation/screens/legal_screen.dart';
import '../../features/settings/presentation/screens/account_settings_screen.dart';
import '../../features/welcome/presentation/screens/welcome_screen.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../../features/reading/presentation/screens/reading_stats_screen.dart';
import '../../features/challenges/presentation/screens/challenges_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Welcome-seen flag — read once at startup
// ─────────────────────────────────────────────────────────────────────────────

final hasSeenWelcomeProvider = FutureProvider<bool>((ref) async {
  const storage = FlutterSecureStorage();
  return await storage.read(key: 'has_seen_welcome') == 'true';
});

// ─────────────────────────────────────────────────────────────────────────────
// Router notifier — bridges Riverpod → GoRouter Listenable
// ─────────────────────────────────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  late bool _isLoggedIn;
  late String _role;

  _RouterNotifier(this._ref) {
    _isLoggedIn = _ref.read(isAuthenticatedProvider);
    _role       = _ref.read(userRoleProvider);
    _ref.listen<bool>(isAuthenticatedProvider, (_, next) {
      _isLoggedIn = next;
      notifyListeners();
    });
    _ref.listen<String>(userRoleProvider, (_, next) {
      _role = next;
      notifyListeners();
    });
  }

  String? redirect(GoRouterState state) {
    final loc         = state.matchedLocation;
    final isAuthRoute = loc.startsWith('/auth');
    final isWelcome   = loc == '/welcome';
    final isAdminLock = loc == '/admin-access';

    if (!_isLoggedIn && !isAuthRoute && !isWelcome) return '/auth/login';

    if (_isLoggedIn) {
      // Desktop/admin accounts must not use the mobile app.
      if (_role == 'desktop') {
        return isAdminLock ? null : '/admin-access';
      }
      if (isAuthRoute || isWelcome) return '/library';
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transition helpers — eliminates default iOS/Android swipe animations.
// All navigation uses one of: fade (tab switches), slide (detail pushes),
// or slide-up (reader full-screen overlay).
// ─────────────────────────────────────────────────────────────────────────────

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
    );

CustomTransitionPage<void> _slide(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );

CustomTransitionPage<void> _slideUp(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
          child: child,
        );
      },
    );

// Takes initialLocation so main.dart can pass '/welcome' on first launch
// or '/library' on subsequent launches without an async redirect flicker.
final routerProvider = Provider.family<GoRouter, String>((ref, initialLocation) {
  final notifier = _RouterNotifier(ref);

  final router = GoRouter(
    initialLocation: initialLocation,
    refreshListenable: notifier,
    redirect: (_, state) => notifier.redirect(state),
    routes: [
      GoRoute(path: '/admin-access',  pageBuilder: (_, s) => _fade(s, const _AdminAccessScreen())),
      GoRoute(path: '/welcome',       pageBuilder: (_, s) => _fade(s, const WelcomeScreen())),
      GoRoute(path: '/auth/login',    pageBuilder: (_, s) => _fade(s, const LoginScreen())),
      GoRoute(path: '/auth/register', pageBuilder: (_, s) => _fade(s, const RegisterScreen())),
      GoRoute(path: '/auth/forgot-password', pageBuilder: (_, s) => _slide(s, const ForgotPasswordScreen())),
      GoRoute(
        path: '/auth/reset-password',
        pageBuilder: (_, s) => _slide(s, ResetPasswordScreen(email: s.extra as String? ?? '')),
      ),
      GoRoute(
        path: '/auth/verify-email',
        pageBuilder: (_, s) => _slide(s, VerifyEmailScreen(email: s.extra as String? ?? '')),
      ),

      // Reader lives outside the ShellRoute so the bottom nav bar is not
      // rendered while reading. This also prevents the "Incorrect use of
      // ParentDataWidget" errors caused by the reader's Positioned widgets
      // conflicting with the shell Scaffold's bottomNavigationBar.
      GoRoute(
        path: '/reader/:bookId',
        pageBuilder: (_, s) => _slideUp(s, ReaderScreen(bookId: s.pathParameters['bookId']!)),
      ),

      ShellRoute(
        pageBuilder: (context, state, child) => _fade(state, _AppShell(child: child)),
        routes: [
          GoRoute(path: '/library', pageBuilder: (_, s) => _fade(s, const LibraryScreen())),
          GoRoute(path: '/reading', pageBuilder: (_, s) => _fade(s, const ReadingHubScreen())),
          GoRoute(
            path: '/books/:id',
            pageBuilder: (_, s) => _slide(s, BookDetailScreen(bookId: s.pathParameters['id']!)),
          ),
          GoRoute(path: '/leaderboard', pageBuilder: (_, s) => _fade(s, const LeaderboardScreen())),
          GoRoute(path: '/profile',     pageBuilder: (_, s) => _slide(s, const ProfileScreen())),
          // /profile/edit MUST come before /profile/:userId
          GoRoute(path: '/profile/edit', pageBuilder: (_, s) => _slide(s, const EditProfileScreen())),
          GoRoute(
            path: '/profile/:userId',
            pageBuilder: (_, s) => _slide(s, FriendProfileScreen(userId: s.pathParameters['userId']!)),
          ),
          GoRoute(path: '/friends',       pageBuilder: (_, s) => _slide(s, const FriendsScreen())),
          GoRoute(path: '/notifications', pageBuilder: (_, s) => _slide(s, const NotificationsScreen())),
          GoRoute(path: '/settings',      pageBuilder: (_, s) => _slide(s, const SettingsScreen())),
          GoRoute(
            path: '/legal/:type',
            pageBuilder: (_, s) => _slide(s, LegalScreen(type: s.pathParameters['type']!)),
          ),
          GoRoute(
            path: '/account-settings',
            pageBuilder: (_, s) => _slide(s, const AccountSettingsScreen()),
          ),
          GoRoute(path: '/reading-stats', pageBuilder: (_, s) => _slide(s, const ReadingStatsScreen())),
          GoRoute(path: '/challenges',    pageBuilder: (_, s) => _slide(s, const ChallengesScreen())),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

// ─────────────────────────────────────────────────────────────────────────────
// App shell — wraps every authenticated screen with a subtle gradient + nav
// ─────────────────────────────────────────────────────────────────────────────

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final idx = _selectedIndex(context);
    // MediaQuery.orientationOf subscribes only to orientation changes —
    // cheaper than MediaQuery.of(context) which rebuilds on any media change.
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final bgContent = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [context.shellGradientTop, context.shellGradientBottom],
          stops: const [0.0, 1.0],
        ),
      ),
      child: child,
    );

    // In landscape: side rail replaces the bottom nav bar so the full screen
    // height is available for content. This matters most on phones in landscape
    // (e.g. while reading) where an 80 px bottom bar is a significant loss.
    if (isLandscape) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: Row(
          children: [
            _SideNav(selectedIndex: idx),
            Expanded(child: bgContent),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: bgContent,
      bottomNavigationBar: _BottomNav(selectedIndex: idx),
    );
  }

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    // Sub-pages of the reading hub keep tab 1 highlighted.
    if (loc.startsWith('/reading') || loc.startsWith('/reader') ||
        loc.startsWith('/reading-stats') || loc.startsWith('/challenges')) return 1;
    if (loc.startsWith('/leaderboard')) return 2;
    if (loc.startsWith('/settings'))   return 3;
    // Everything else (/library, /books/:id, /profile, /friends,
    // /notifications) is rooted in the library tab.
    return 0;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Side navigation rail — shown in landscape instead of the bottom bar.
// Reuses _NavItem so colour/animation logic lives in exactly one place.
// ─────────────────────────────────────────────────────────────────────────────

class _SideNav extends StatelessWidget {
  final int selectedIndex;
  const _SideNav({required this.selectedIndex});

  // Each entry: (icon, activeColor, activeBg, route)
  static const _items = [
    (Icons.home_rounded,          AppTheme.primary,           AppTheme.primarySurface,   '/library'),
    (Icons.menu_book_rounded,     Color(0xFFEC4899),           Color(0xFFFCE7F3),         '/reading'),
    (Icons.emoji_events_rounded,  Color(0xFFF59E0B),           Color(0xFFFEF3C7),         '/leaderboard'),
    (Icons.settings_rounded,      Color(0xFF3B82F6),           Color(0xFFDBEAFE),         '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: context.navBg,
        border: Border(
          right: BorderSide(color: context.navBorder, width: 2.5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A6B21A8),
            blurRadius: 12,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_items.length, (i) {
            final (icon, color, bgColor, route) = _items[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _NavItem(
                icon: icon,
                color: color,
                bgColor: bgColor,
                isSelected: selectedIndex == i,
                onTap: () => context.go(route),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom bottom nav
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  const _BottomNav({required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // No hardcoded height — SafeArea + 56 px icons determine the correct
      // size on every device. A fixed 80 px caused icons to squish after
      // returning from the reader because the system nav bar bottom inset
      // (24–36 px) was added *inside* the fixed box, leaving < 30 px for the
      // 56 px NavItems.
      decoration: BoxDecoration(
        color: context.navBg,
        border: Border(
          top: BorderSide(color: context.navBorder, width: 2.5),
        ),
        boxShadow: const [
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
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
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
              color: isSelected ? color : context.textHint,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin-access block screen — shown when a desktop/admin account logs into
// the mobile app. Admins must use the Inkril Admin desktop application.
// ─────────────────────────────────────────────────────────────────────────────

class _AdminAccessScreen extends ConsumerWidget {
  const _AdminAccessScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Admin account',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This account is for administrators only. '
                'Please use the Inkril Admin desktop application to manage the platform.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      ref.read(authNotifierProvider.notifier).logout(),
                  child: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
