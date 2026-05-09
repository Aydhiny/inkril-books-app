import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/library_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicBooksAsync = ref.watch(publicBooksProvider);
    final userLibraryAsync = ref.watch(userLibraryProvider);
    final profileAsync = ref.watch(myProfileProvider);

    // Last-read book for "Continue reading" button
    final lastReadBook = userLibraryAsync.valueOrNull
        ?.where((b) => b['lastReadAt'] != null)
        .fold<Map<String, dynamic>?>(null, (prev, b) {
      if (prev == null) return b;
      final prevTime = DateTime.tryParse(prev['lastReadAt'] as String? ?? '');
      final bTime = DateTime.tryParse(b['lastReadAt'] as String? ?? '');
      if (bTime == null) return prev;
      if (prevTime == null) return b;
      return bTime.isAfter(prevTime) ? b : prev;
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            ref.invalidate(publicBooksProvider);
            ref.invalidate(userLibraryProvider);
            ref.invalidate(myProfileProvider);
          },
          child: CustomScrollView(
            slivers: [
              // ── Stats top bar ───────────────────────────────────────
              SliverToBoxAdapter(
                child: _StatsTopBar(profileAsync: profileAsync),
              ),
              // ── Search + Upload ────────────────────────────────────
              SliverToBoxAdapter(
                child: _SearchUploadRow(ref: ref),
              ),
              // ── My book library ────────────────────────────────────
              const SliverToBoxAdapter(
                child: _SectionTitle(title: 'My book library'),
              ),
              SliverToBoxAdapter(
                child: _MyLibraryScroll(userLibraryAsync: userLibraryAsync),
              ),
              // ── Public library ────────────────────────────────────
              const SliverToBoxAdapter(
                child: _SectionTitle(title: 'Public library'),
              ),
              SliverToBoxAdapter(
                child: _PublicLibraryScroll(publicBooksAsync: publicBooksAsync),
              ),
              // ── Today's Quote ─────────────────────────────────────
              const SliverToBoxAdapter(child: _TodaysQuoteSection()),
              // ── Continue reading CTA ──────────────────────────────
              SliverToBoxAdapter(
                child: _ContinueReadingButton(lastReadBook: lastReadBook),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats top bar: avatar | 🔥 streak | ⏱ reading time | 🔔 bell
// ─────────────────────────────────────────────────────────────────────────────

class _StatsTopBar extends StatelessWidget {
  final AsyncValue profileAsync;
  const _StatsTopBar({required this.profileAsync});

  @override
  Widget build(BuildContext context) {
    final profile = profileAsync.valueOrNull as Map<String, dynamic>?;
    final streak = profile?['currentStreak'] as int? ?? 0;
    final weeklyStats = profile?['weeklyStats'] as List? ?? [];
    final todayMinutes = weeklyStats.isNotEmpty
        ? (weeklyStats.last as Map)['minutesRead'] as int? ?? 0
        : 0;
    final timeDisplay =
        todayMinutes >= 60 ? '${(todayMinutes / 60).round()}h' : '${todayMinutes}m';
    final initials = _initials(profile);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          // Avatar — tapping opens the profile
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primary,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Streak
          _TopBadge(emoji: '🔥', value: '$streak', color: AppTheme.streakOrange),
          const SizedBox(width: 10),
          // Daily reading time
          _TopBadge(emoji: '⏱', value: timeDisplay, color: const Color(0xFFEF4444)),
          const SizedBox(width: 10),
          // Notifications bell
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFFFDE68A), width: 1.5),
              ),
              child: const Center(
                child: Text('🔔', style: TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(Map<String, dynamic>? profile) {
    if (profile == null) return '?';
    final first = profile['firstName'] as String? ?? '';
    final last = profile['lastName'] as String? ?? '';
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    final user = profile['userName'] as String? ?? '';
    return user.isNotEmpty ? user[0].toUpperCase() : '?';
  }
}

class _TopBadge extends StatelessWidget {
  final String emoji;
  final String value;
  final Color color;
  const _TopBadge(
      {required this.emoji, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar + Upload Book button
// ─────────────────────────────────────────────────────────────────────────────

class _SearchUploadRow extends StatelessWidget {
  final WidgetRef ref;
  const _SearchUploadRow({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => showSearch(
                context: context, delegate: _BookSearchDelegate()),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD8B4FE), width: 2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const Row(children: [
                Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                SizedBox(width: 8),
                Text('Search books...',
                    style:
                        TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                Spacer(),
                Icon(Icons.tune_rounded,
                    color: Color(0xFF9CA3AF), size: 18),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => _showUploadDialog(context),
          icon: const Icon(Icons.upload_rounded, size: 18),
          label: const Text('Upload Book',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.primary, width: 2.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            minimumSize: const Size(0, 50),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          ),
        ),
      ]),
    );
  }

  void _showUploadDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Upload Book',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: authorCtrl,
            decoration: const InputDecoration(labelText: 'Author'),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final dio = ref.read(dioProvider);
                await dio.post('/api/books', data: {
                  'title': titleCtrl.text.trim(),
                  'author': authorCtrl.text.trim(),
                  'totalPages': 0,
                  'isPublic': true,
                });
                ref.invalidate(publicBooksProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Book uploaded!'),
                      backgroundColor: AppTheme.progressGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Upload failed — check permissions.')),
                  );
                }
              }
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section title
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Color(0xFF1A0A2E),
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My library — large cards with progress overlay
// ─────────────────────────────────────────────────────────────────────────────

class _MyLibraryScroll extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> userLibraryAsync;
  const _MyLibraryScroll({required this.userLibraryAsync});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: userLibraryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Could not load your books')),
        data: (books) {
          if (books.isEmpty) {
            return Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_add_outlined,
                        size: 44,
                        color: AppTheme.primary.withValues(alpha: 0.35)),
                    const SizedBox(height: 10),
                    const Text('Your library is empty',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 14)),
                    const SizedBox(height: 6),
                    TextButton(
                        onPressed: () {},
                        child: const Text('Browse public books →')),
                  ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                _LibraryBookCard(book: books[i], showProgress: true),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public library scroll
// ─────────────────────────────────────────────────────────────────────────────

class _PublicLibraryScroll extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> publicBooksAsync;
  const _PublicLibraryScroll({required this.publicBooksAsync});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: publicBooksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load: $e')),
        data: (books) => ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: books.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) =>
              _LibraryBookCard(book: books[i], showProgress: false),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Large book card — used by both sections
// ─────────────────────────────────────────────────────────────────────────────

class _LibraryBookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final bool showProgress;
  const _LibraryBookCard(
      {required this.book, required this.showProgress});

  @override
  Widget build(BuildContext context) {
    final bookId = book['bookId'] as String? ?? book['id'] as String? ?? '';
    final progress =
        (book['readingProgressPercent'] as num? ?? 0).toDouble();
    final coverUrl = book['coverImageUrl'] as String?;

    return GestureDetector(
      onTap: () => context.push('/books/$bookId'),
      child: Container(
        width: 165,
        decoration: BoxDecoration(
          color: Colors.white,
          // Slightly rounded outer container, but cover image itself is sharp
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF9333EA), width: 3.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Cover — sharp corners, fills most of the card
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: coverUrl != null
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
                      )
                    : const _CoverPlaceholder(),
              ),
            ),
            // Progress strip
            if (showProgress)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progress:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        Text(
                          '${progress.toInt()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        minHeight: 7,
                        backgroundColor: const Color(0xFFE9D5FF),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary),
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

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primarySurface,
      child: const Center(
        child: Icon(Icons.menu_book_rounded,
            size: 48, color: AppTheme.primary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Continue reading CTA
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueReadingButton extends StatelessWidget {
  final Map<String, dynamic>? lastReadBook;
  const _ContinueReadingButton({required this.lastReadBook});

  @override
  Widget build(BuildContext context) {
    if (lastReadBook == null) return const SizedBox(height: 8);

    final bookId =
        lastReadBook!['bookId'] as String? ?? lastReadBook!['id'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: OutlinedButton(
        onPressed: () => context.push('/reader/$bookId'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          side: const BorderSide(color: AppTheme.primary, width: 3),
          minimumSize: const Size(double.infinity, 58),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          backgroundColor: AppTheme.primarySurface,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue reading ',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's Quote section
// ─────────────────────────────────────────────────────────────────────────────

class _TodaysQuoteSection extends StatelessWidget {
  const _TodaysQuoteSection();

  // Rotates daily using day-of-year index.
  // Explicit type so Dart infers List<(String,String)>, enabling .$1 / .$2.
  static const List<(String, String)> _quotes = [
    (
      '"It is not our abilities that show what we truly are. It is our choices."',
      'Moby Dick',
    ),
    (
      '"I\'m unpredictable, I never know where I\'m going until I get there, I\'m so random."',
      'Pride and Prejudice',
    ),
    (
      '"It does not do to dwell on dreams and forget to live."',
      'The Great Gatsby',
    ),
    (
      '"The person, be it gentleman or lady, who has not pleasure in a good novel, must be intolerably stupid."',
      'Pride and Prejudice',
    ),
    (
      '"I must not fear. Fear is the mind-killer."',
      'Dune',
    ),
    (
      '"So we beat on, boats against the current, borne back ceaselessly into the past."',
      'The Great Gatsby',
    ),
    (
      '"War is peace. Freedom is slavery. Ignorance is strength."',
      '1984',
    ),
    (
      '"Call me Ishmael. Some years ago—never mind how long precisely—I thought I would sail about a little."',
      'Moby Dick',
    ),
    (
      '"It was a bright cold day in April, and the clocks were striking thirteen."',
      '1984',
    ),
    (
      '"It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife."',
      'Pride and Prejudice',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dayIndex = DateTime.now().difference(DateTime(2024)).inDays;
    final quote = _quotes[dayIndex % _quotes.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Quote",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD8B4FE), width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A6B21A8),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.$1,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF374151),
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '— ${quote.$2}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('📖', style: TextStyle(fontSize: 32)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search delegate (placeholder)
// ─────────────────────────────────────────────────────────────────────────────

class _BookSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions();

  Widget _buildSuggestions() {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Search for books or authors'));
    }
    return const Center(child: Text('Search results coming soon'));
  }
}
