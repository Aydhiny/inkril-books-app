import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      emoji: '📚',
      title: 'Welcome to Inkril',
      subtitle:
          'Your gamified reading companion. Build habits, track progress, and discover great books.',
      lightBg: Color(0xFFF5F0FF),
      darkBg:  Color(0xFF1A0A2E),
      accent:  AppTheme.primary,
    ),
    _Slide(
      emoji: '🏆',
      title: 'Compete & Grow',
      subtitle:
          'Climb the leaderboard, maintain your daily streak, and challenge friends to read more.',
      lightBg: Color(0xFFFFF7ED),
      darkBg:  Color(0xFF1C1200),
      accent:  Color(0xFFF59E0B),
    ),
    _Slide(
      emoji: '🔖',
      title: 'Bookmark Moments',
      subtitle:
          'Highlight passages that move you. Review your saved quotes anytime in your Reading Hub.',
      lightBg: Color(0xFFF0FDF4),
      darkBg:  Color(0xFF071A0B),
      accent:  Color(0xFF16A34A),
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'has_seen_welcome', value: 'true');
    if (mounted) context.go('/auth/login');
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slide  = _slides[_page];
    final bg     = isDark ? slide.darkBg : slide.lightBg;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: slide.accent.withValues(alpha: isDark ? 0.8 : 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _SlidePage(slide: _slides[i], isDark: isDark),
              ),
            ),

            // Dots + CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? slide.accent
                              : slide.accent.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: slide.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: slide.accent.withValues(alpha: 0.5),
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Text(
                        _page == _slides.length - 1
                            ? 'Get Started →'
                            : 'Continue →',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  final bool isDark;
  const _SlidePage({required this.slide, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Emoji container: white card in light mode, slightly lighter than bg in dark mode
    final cardColor = isDark
        ? Color.lerp(isDark ? slide.darkBg : slide.lightBg, Colors.white, 0.08)!
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji in a large rounded container
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: slide.accent.withValues(alpha: isDark ? 0.5 : 0.3),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: slide.accent.withValues(alpha: isDark ? 0.25 : 0.15),
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                slide.emoji,
                style: const TextStyle(fontSize: 64),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              // In dark mode, lighten the accent so it's legible on a dark bg
              color: isDark
                  ? Color.lerp(slide.accent, Colors.white, 0.35)
                  : slide.accent,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.65)
                  : slide.accent.withValues(alpha: 0.7),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final String emoji;
  final String title;
  final String subtitle;
  final Color lightBg;
  final Color darkBg;
  final Color accent;
  const _Slide({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.lightBg,
    required this.darkBg,
    required this.accent,
  });
}
