import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/library_provider.dart';

class BookDetailScreen extends ConsumerWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookDetailProvider(bookId));
    final reviewsAsync = ref.watch(bookReviewsProvider(bookId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            Text('$e', style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(bookDetailProvider(bookId)),
              child: const Text('Retry'),
            ),
          ]),
        ),
        data: (book) => SafeArea(
          child: CustomScrollView(
            slivers: [
              // ── Sticky title bar ──────────────────────────────────
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFFF8F5FF),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.primary, size: 22),
                  onPressed: () => context.pop(),
                ),
                title: const Text(
                  'Book Overview',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                centerTitle: true,
              ),
              SliverToBoxAdapter(
                child: _BookBody(
                  book: book,
                  bookId: bookId,
                  reviewsAsync: reviewsAsync,
                  ref: ref,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookBody extends StatelessWidget {
  final Map<String, dynamic> book;
  final String bookId;
  final AsyncValue reviewsAsync;
  final WidgetRef ref;

  const _BookBody({
    required this.book,
    required this.bookId,
    required this.reviewsAsync,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final title = book['title'] as String? ?? '';
    final author = book['author'] as String? ?? '';
    final avgRating = (book['averageRating'] as num? ?? 0.0).toDouble();
    final ratingCount = book['ratingCount'] as int? ?? 0;
    final totalPages = book['totalPages'] as int? ?? 0;
    final fileSizeBytes = book['fileSizeBytes'] as int? ?? 0;
    final progress = book['readingProgressPercent'] as num?;
    final lastReadAt = book['lastReadAt'] as String?;
    final description = book['description'] as String? ?? '';
    final genres = book['genres'] as List? ?? [];
    final coverUrl = book['coverImageUrl'] as String?;

    final fileSizeMb = fileSizeBytes > 0
        ? '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB'
        : '—';

    String? lastReadStr;
    if (lastReadAt != null) {
      final dt = DateTime.tryParse(lastReadAt);
      if (dt != null) {
        lastReadStr = DateFormat("MMM d'th' yyyy HH:mm").format(dt.toLocal());
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover ────────────────────────────────────────────────
          Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 260, maxHeight: 360),
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    if (coverUrl != null)
                      CachedNetworkImage(
                        imageUrl: '${AppConfig.apiBaseUrl}$coverUrl',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 360,
                        errorWidget: (_, __, ___) => const _CoverPlaceholder(),
                      )
                    else
                      const SizedBox(height: 360, child: _CoverPlaceholder()),
                    // Progress overlay (if reading)
                    if (progress != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.75),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Progress:',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  Text('${progress.toInt()}%',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress.toDouble() / 100,
                                  minHeight: 6,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.3),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          AppTheme.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Stars ─────────────────────────────────────────────────
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                if (i < avgRating.floor()) {
                  return const Icon(Icons.star_rounded,
                      color: AppTheme.primary, size: 32);
                } else if (i < avgRating.ceil() &&
                    avgRating - avgRating.floor() >= 0.5) {
                  return const Icon(Icons.star_half_rounded,
                      color: AppTheme.primary, size: 32);
                } else {
                  return const Icon(Icons.star_outline_rounded,
                      color: AppTheme.primary, size: 32);
                }
              }),
            ),
          ),
          const SizedBox(height: 12),

          // ── Title + author ────────────────────────────────────────
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A0A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            author,
            style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),

          // ── Progress line + file info ─────────────────────────────
          if (progress != null || lastReadStr != null)
            Text(
              [
                if (progress != null) '${progress.toInt()}%',
                if (lastReadStr != null) lastReadStr,
              ].join(', '),
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280)),
            ),
          const SizedBox(height: 4),
          Text(
            'PDF, $fileSizeMb, Files: 1',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A0A2E),
            ),
          ),
          const SizedBox(height: 14),

          // ── Genres ────────────────────────────────────────────────
          if (genres.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: genres
                  .map((g) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFD8B4FE), width: 1),
                        ),
                        child: Text(g as String,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            )),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),

          // ── Action buttons ────────────────────────────────────────
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: Text(progress != null
                    ? 'Continue Reading'
                    : 'Start Reading'),
                onPressed: () => context.push('/reader/$bookId'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => _addToLibrary(context, ref),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(52, 52),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Icon(Icons.library_add_outlined,
                  color: AppTheme.primary),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Description ───────────────────────────────────────────
          if (description.isNotEmpty) ...[
            const Text('About this book',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A0A2E))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
              ),
              child: Text(
                description,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                    height: 1.6),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Reviews header ────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Reviews',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A0A2E))),
            TextButton(
              onPressed: () => _showReviewDialog(context, ref),
              child: const Text('+ Write a review',
                  style: TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),

          // ── Reviews list ──────────────────────────────────────────
          reviewsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (reviews) {
              if ((reviews as List).isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('No reviews yet. Be the first!',
                      style: TextStyle(color: Color(0xFF9CA3AF))),
                );
              }
              return Column(
                children: [
                  for (final r in reviews) _ReviewCard(review: r as Map),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _addToLibrary(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/user-books', data: {'bookId': bookId});
      ref.invalidate(userLibraryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Added to your library!'),
          backgroundColor: AppTheme.progressGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Already in your library.')));
      }
    }
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref) {
    int rating = 5;
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Write a Review',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (i) => IconButton(
                        icon: Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppTheme.goldMedal,
                          size: 32,
                        ),
                        onPressed: () => setS(() => rating = i + 1),
                      )),
            ),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(
                  labelText: 'Comment (optional)'),
              maxLines: 3,
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final dio = ref.read(dioProvider);
                  await dio.post('/api/books/$bookId/reviews', data: {
                    'bookId': bookId,
                    'rating': rating,
                    'comment': commentCtrl.text.trim().isEmpty
                        ? null
                        : commentCtrl.text.trim(),
                  });
                  ref.invalidate(bookDetailProvider(bookId));
                  ref.invalidate(bookReviewsProvider(bookId));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Review submitted!'),
                      backgroundColor: AppTheme.progressGreen,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Submit'),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6B21A8), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, size: 80, color: Colors.white54),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final userName = review['userName'] as String? ?? 'Anonymous';
    final rating = review['rating'] as int? ?? 0;
    final comment = review['comment'] as String?;
    final initial =
        userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.primarySurface,
          child: Text(initial,
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(userName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF1A0A2E))),
              Row(
                  children: List.generate(
                      5,
                      (i) => Icon(
                            i < rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 13,
                            color: AppTheme.goldMedal,
                          ))),
            ]),
            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(comment,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4B5563),
                      height: 1.4)),
            ],
          ]),
        ),
      ]),
    );
  }
}
