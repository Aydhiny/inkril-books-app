import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_empty_state.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../providers/library_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicBooksAsync = ref.watch(publicBooksProvider);
    final userLibraryAsync = ref.watch(userLibraryProvider);
    final profileAsync = ref.watch(myProfileProvider);

    final _sortedRead = userLibraryAsync.valueOrNull
        ?.where((b) => b['lastReadAt'] != null)
        .toList()
      ?..sort((a, b) {
          final aT = DateTime.tryParse(a['lastReadAt'] as String? ?? '') ?? DateTime(0);
          final bT = DateTime.tryParse(b['lastReadAt'] as String? ?? '') ?? DateTime(0);
          return bT.compareTo(aT);
        });
    final _anyLibBook = userLibraryAsync.valueOrNull?.isNotEmpty == true
        ? userLibraryAsync.valueOrNull!.first
        : null;
    final _firstPublic = publicBooksAsync.valueOrNull?.isNotEmpty == true
        ? publicBooksAsync.valueOrNull!.first
        : null;
    final lastReadBook = (_sortedRead?.isNotEmpty == true
            ? _sortedRead!.first
            : null) ??
        _anyLibBook ??
        _firstPublic;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
              SliverToBoxAdapter(
                child: _StatsTopBar(profileAsync: profileAsync),
              ),
              SliverToBoxAdapter(
                child: _SearchUploadRow(ref: ref),
              ),
              SliverToBoxAdapter(
                child: _ContinueReadingButton(lastReadBook: lastReadBook),
              ),
              SliverToBoxAdapter(
                child: _SectionTitle(title: 'My book library'),
              ),
              SliverToBoxAdapter(
                child: _MyLibraryScroll(userLibraryAsync: userLibraryAsync),
              ),
              SliverToBoxAdapter(
                child: _SectionTitle(title: 'Public library'),
              ),
              SliverToBoxAdapter(
                child: _PublicLibraryScroll(publicBooksAsync: publicBooksAsync),
              ),
              const SliverToBoxAdapter(child: _TodaysQuoteSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats top bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatsTopBar extends StatelessWidget {
  final AsyncValue profileAsync;
  const _StatsTopBar({required this.profileAsync});

  @override
  Widget build(BuildContext context) {
    final profile = profileAsync.valueOrNull as Map<String, dynamic>?;
    final streak = (profile?['currentStreak'] as num?)?.toInt() ?? 0;
    final weeklyStats = profile?['weeklyStats'] as List? ?? [];
    final todayMinutes = weeklyStats.isNotEmpty
        ? ((weeklyStats.last as Map)['minutesRead'] as num?)?.toInt() ?? 0
        : 0;
    final timeDisplay =
        todayMinutes >= 60 ? '${(todayMinutes / 60).round()}h' : '${todayMinutes}m';
    final initials = _initials(profile);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
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
          _TopBadge(emoji: '🔥', value: '$streak', color: AppTheme.streakOrange),
          const SizedBox(width: 10),
          _TopBadge(emoji: '⏱', value: timeDisplay, color: const Color(0xFFEF4444)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
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
  const _TopBadge({required this.emoji, required this.value, required this.color});

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
                color: context.subtleBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderPurpleMid, width: 2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                Icon(Icons.search_rounded, color: context.textHint, size: 20),
                const SizedBox(width: 8),
                Text('Search books...',
                    style: TextStyle(color: context.textHint, fontSize: 14)),
                const Spacer(),
                Icon(Icons.tune_rounded, color: context.textHint, size: 18),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: () => _showUploadSheet(context),
          icon: const Icon(Icons.upload_rounded, size: 18),
          label: const Text('Upload',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.primary, width: 2.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            minimumSize: const Size(0, 50),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          ),
        ),
      ]),
    );
  }

  void _showUploadSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _UploadBookSheet(
        titleCtrl: titleCtrl,
        authorCtrl: authorCtrl,
        onUpload: () async {
          Navigator.pop(sheetCtx);
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
                  content: const Text('Book uploaded! 🎉'),
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
                const SnackBar(content: Text('Upload failed — check permissions.')),
              );
            }
          }
        },
      ),
    );
  }
}

// Duolingo-style upload bottom sheet
class _UploadBookSheet extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController authorCtrl;
  final VoidCallback onUpload;
  const _UploadBookSheet({
    required this.titleCtrl,
    required this.authorCtrl,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: context.borderPurpleMid, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.borderPurpleMid,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Icon + title
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('📚', style: TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Upload a Book',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add a new book to the public library',
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: titleCtrl,
            decoration: InputDecoration(
              labelText: 'Book Title',
              prefixIcon: const Icon(Icons.book_outlined, color: AppTheme.primary),
              labelStyle: TextStyle(color: context.textSecondary),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: authorCtrl,
            decoration: InputDecoration(
              labelText: 'Author',
              prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.primary),
              labelStyle: TextStyle(color: context.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.textSecondary,
                  side: BorderSide(color: context.borderGray, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(0, 52),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: const Text('Upload Book',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ]),
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
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: context.textPrimary,
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
        loading: () => const ShimmerBookScroll(),
        error: (_, __) => Center(
            child: Text('Could not load your books',
                style: TextStyle(color: context.textSecondary))),
        data: (books) {
          if (books.isEmpty) {
            return AnimatedEmptyState(
              emoji: '📚',
              title: 'Your library is empty',
              subtitle: 'Browse public books below to get started',
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
        loading: () => const ShimmerBookScroll(),
        error: (e, _) => Center(
            child: Text('Failed to load: $e',
                style: TextStyle(color: context.textSecondary))),
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
// Large book card
// ─────────────────────────────────────────────────────────────────────────────

class _LibraryBookCard extends StatelessWidget {
  final Map<String, dynamic> book;
  final bool showProgress;
  const _LibraryBookCard({required this.book, required this.showProgress});

  @override
  Widget build(BuildContext context) {
    final bookId = book['bookId'] as String? ?? book['id'] as String? ?? '';
    final progress = (book['readingProgressPercent'] as num? ?? 0).toDouble();
    final coverUrl = book['coverImageUrl'] as String?;

    return GestureDetector(
      onTap: () => context.push('/books/$bookId'),
      child: Container(
        width: 165,
        decoration: BoxDecoration(
          color: context.cardBg,
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
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: coverUrl != null
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _CoverPlaceholder(),
                      )
                    : _CoverPlaceholder(),
              ),
            ),
            if (showProgress)
              Container(
                color: context.cardBg,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.textBody,
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
                        backgroundColor: context.borderPurple,
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
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.primarySurface,
      child: const Center(
        child: Icon(Icons.menu_book_rounded, size: 48, color: AppTheme.primary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Continue reading CTA
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueReadingButton extends StatelessWidget {
  final Map<String, dynamic>? lastReadBook;
  bool get _hasProgress =>
      lastReadBook != null &&
      (lastReadBook!['lastReadAt'] != null || lastReadBook!['bookId'] != null);
  const _ContinueReadingButton({required this.lastReadBook});

  @override
  Widget build(BuildContext context) {
    if (lastReadBook == null) return const SizedBox(height: 8);
    final bookId =
        lastReadBook!['bookId'] as String? ?? lastReadBook!['id'] as String? ?? '';
    final title = lastReadBook!['title'] as String? ?? 'Your next read';
    if (bookId.isEmpty) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GestureDetector(
        onTap: () => context.push('/reader/$bookId'),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4C1D95), width: 2.5),
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0A2E), Color(0xFF3B0764), Color(0xFF6B21A8)],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B21A8).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Positioned(top: 12, right: 16,
                  child: Opacity(opacity: 0.15,
                      child: Text('📚', style: TextStyle(fontSize: 36)))),
              const Positioned(bottom: 10, right: 56,
                  child: Opacity(opacity: 0.10,
                      child: Text('📖', style: TextStyle(fontSize: 28)))),
              const Positioned(top: 18, right: 64,
                  child: Opacity(opacity: 0.08,
                      child: Text('📕', style: TextStyle(fontSize: 22)))),
              const Positioned(bottom: 14, right: 16,
                  child: Opacity(opacity: 0.12,
                      child: Text('📗', style: TextStyle(fontSize: 20)))),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 100, 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasProgress ? 'Continue Reading' : 'Start Reading',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _hasProgress
                                ? 'Pick up where you left off'
                                : 'Tap to open the reader',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's Quote
// ─────────────────────────────────────────────────────────────────────────────

class _TodaysQuoteSection extends StatelessWidget {
  const _TodaysQuoteSection();

  static const List<(String, String)> _quotes = [
    ('"It is not our abilities that show what we truly are. It is our choices."', 'Moby Dick'),
    ('"I\'m unpredictable, I never know where I\'m going until I get there."', 'Pride and Prejudice'),
    ('"It does not do to dwell on dreams and forget to live."', 'The Great Gatsby'),
    ('"The person who has not pleasure in a good novel must be intolerably stupid."', 'Pride and Prejudice'),
    ('"I must not fear. Fear is the mind-killer."', 'Dune'),
    ('"So we beat on, boats against the current, borne back ceaselessly into the past."', 'The Great Gatsby'),
    ('"War is peace. Freedom is slavery. Ignorance is strength."', '1984'),
    ('"Call me Ishmael. Some years ago I thought I would sail about a little."', 'Moby Dick'),
    ('"It was a bright cold day in April, and the clocks were striking thirteen."', '1984'),
    ('"It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife."', 'Pride and Prejudice'),
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
          Text(
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
              color: context.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderPurpleMid, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x0A6B21A8),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
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
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textBody,
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
                    color: context.primarySurface,
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
// Search delegate
// ─────────────────────────────────────────────────────────────────────────────

class _BookSearchDelegate extends SearchDelegate<String> {
  @override
  String get searchFieldLabel => 'Search books or authors…';

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
              icon: const Icon(Icons.clear_rounded),
              color: AppTheme.primary,
              onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: AppTheme.primary,
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _SearchResults(query: query);

  @override
  Widget buildSuggestions(BuildContext context) => _SearchResults(query: query);
}

// Uses Consumer so it has access to Riverpod without extending SearchDelegate.
class _SearchResults extends ConsumerWidget {
  final String query;
  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.trim().isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🔍', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('Type to search books or authors',
              style: TextStyle(color: context.textSecondary, fontSize: 14)),
        ]),
      );
    }

    final resultsAsync = ref.watch(searchBooksProvider(query));
    return resultsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (_, __) => Center(
        child: Text('Search failed',
            style: TextStyle(color: context.textSecondary)),
      ),
      data: (books) {
        if (books.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📚', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text('No books found for "$query"',
                  style: TextStyle(color: context.textSecondary)),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: books.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final b = books[i];
            final title   = b['title'] as String? ?? '';
            final author  = b['author'] as String? ?? '';
            final cover   = b['coverImageUrl'] as String?;
            final rating  = (b['averageRating'] as num?)?.toDouble() ?? 0;
            final bookId  = b['id'] as String? ?? '';

            return GestureDetector(
              onTap: () {
                Navigator.of(ctx).pop();
                GoRouter.of(ctx).push('/books/$bookId');
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderPurpleMid, width: 2),
                ),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: cover != null && cover.isNotEmpty
                        ? Image.network(cover,
                            width: 52, height: 72, fit: BoxFit.cover)
                        : Container(
                            width: 52,
                            height: 72,
                            color: context.primarySurface,
                            child: const Center(
                                child: Icon(Icons.book_rounded,
                                    color: AppTheme.primary, size: 24)),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: context.textPrimary,
                              )),
                          const SizedBox(height: 2),
                          Text(author,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary)),
                          if (rating > 0) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFF59E0B), size: 14),
                              const SizedBox(width: 3),
                              Text(rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFF59E0B))),
                            ]),
                          ],
                        ]),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppTheme.primary, size: 20),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}
