import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../library/presentation/providers/library_provider.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final bookBookmarksProvider =
    FutureProvider.family<List<dynamic>, String>((ref, bookId) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/api/bookmarks', queryParameters: {'bookId': bookId});
  return res.data as List<dynamic>;
});

// ── Screen ─────────────────────────────────────────────────────────────────

class ReadingHubScreen extends ConsumerWidget {
  const ReadingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(userLibraryProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: libraryAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          error: (_, __) => _EmptyState(onBrowse: () => context.go('/library')),
          data: (books) {
            final sorted = [...books]..sort((a, b) {
                final aDate =
                    DateTime.tryParse(a['lastReadAt'] as String? ?? '') ??
                        DateTime(0);
                final bDate =
                    DateTime.tryParse(b['lastReadAt'] as String? ?? '') ??
                        DateTime(0);
                return bDate.compareTo(aDate);
              });

            final current = sorted.firstOrNull;
            if (current == null) {
              return _EmptyState(onBrowse: () => context.go('/library'));
            }
            return _ReadingBody(book: current);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body when a book is in progress
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingBody extends ConsumerWidget {
  final Map<String, dynamic> book;
  const _ReadingBody({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookId = book['bookId'] as String? ?? book['id'] as String? ?? '';
    final title = book['title'] as String? ?? 'Unknown';
    final author = book['author'] as String? ?? '';
    final progress =
        ((book['readingProgressPercent'] as num?)?.toDouble() ?? 0) / 100;
    final coverUrl = book['coverImageUrl'] as String?;

    final bookmarksAsync = ref.watch(bookBookmarksProvider(bookId));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Text(
            'Currently Reading',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          // ── Book card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.borderPurpleMid, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x146B21A8),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _BookCover(coverUrl: coverUrl, title: title),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      author,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                  fontSize: 12, color: context.textSecondary),
                            ),
                            Text(
                              '${(progress * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: context.borderPurple,
                            valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/reader/$bookId'),
                        icon: const Icon(Icons.menu_book_rounded, size: 18),
                        label: const Text(
                          'Continue Reading',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          // ── Bookmarks section ────────────────────────────────────────
          bookmarksAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (bookmarks) {
              if (bookmarks.isEmpty) {
                return _NoBookmarksHint(
                    onRead: () => context.push('/reader/$bookId'));
              }
              return _BookmarksList(
                  bookmarks: bookmarks,
                  onTap: (page) => context.push('/reader/$bookId'));
            },
          ),

          const SizedBox(height: 20),

          OutlinedButton.icon(
            onPressed: () => context.go('/library'),
            icon: const Icon(Icons.grid_view_rounded, size: 16),
            label: const Text('Browse Library'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 2.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Book cover
// ─────────────────────────────────────────────────────────────────────────────

class _BookCover extends StatelessWidget {
  final String? coverUrl;
  final String title;
  const _BookCover({required this.coverUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9333EA), width: 3),
      ),
      child: coverUrl != null && coverUrl!.isNotEmpty
          ? Image.network(
              coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _CoverFallback(title: title),
            )
          : _CoverFallback(title: title),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  final String title;
  const _CoverFallback({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.primarySurface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bookmarks list
// ─────────────────────────────────────────────────────────────────────────────

class _BookmarksList extends StatelessWidget {
  final List<dynamic> bookmarks;
  final void Function(int page) onTap;
  const _BookmarksList({required this.bookmarks, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Bookmarks (${bookmarks.length})',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: context.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 12),
      ...bookmarks.take(10).map((b) {
        final bm = b as Map;
        final page = (bm['pageNumber'] as num?)?.toInt() ?? 0;
        final highlighted = bm['highlightedText'] as String?;
        final note = bm['note'] as String?;

        return GestureDetector(
          onTap: () => onTap(page),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderPurpleMid, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x0A6B21A8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bookmark_rounded,
                    color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Page $page',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      if (highlighted != null && highlighted.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '"$highlighted"',
                            style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF92400E),
                              height: 1.5,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (note != null && note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          note,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ]),
              ),
            ]),
          ),
        );
      }),
    ]);
  }
}

class _NoBookmarksHint extends StatelessWidget {
  final VoidCallback onRead;
  const _NoBookmarksHint({required this.onRead});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRead,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.primarySurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.bookmark_border_rounded,
              color: AppTheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No bookmarks yet — open the reader and highlight text to save passages.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.primary,
                height: 1.4,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyState({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.primarySurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            'Nothing to read yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a book from the library to start your reading journey.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.grid_view_rounded, size: 18),
            label: const Text('Browse Library',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ]),
      ),
    );
  }
}
