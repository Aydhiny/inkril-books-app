import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../payments/presentation/providers/payment_provider.dart';
import '../providers/library_provider.dart';

class BookDetailScreen extends ConsumerWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookDetailProvider(bookId));
    final reviewsAsync = ref.watch(bookReviewsProvider(bookId));
    final bookmarksAsync = ref.watch(bookBookmarksProvider(bookId));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
                backgroundColor: context.scaffoldBg,
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
                  bookmarksAsync: bookmarksAsync,
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
  final AsyncValue bookmarksAsync;
  final WidgetRef ref;

  const _BookBody({
    required this.book,
    required this.bookId,
    required this.reviewsAsync,
    required this.bookmarksAsync,
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
    final isPremium = book['isPremium'] as bool? ?? false;
    final price = (book['price'] as num?)?.toDouble();
    final isPurchased = book['isPurchasedByUser'] as bool? ?? false;

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
                // No border radius — sharp Duolingo-style book cover
                border: Border.all(color: const Color(0xFF9333EA), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                  children: [
                    if (coverUrl != null)
                      CachedNetworkImage(
                        // Open Library URLs are already absolute (https://…).
                        // User-uploaded covers are relative (/uploads/…).
                        imageUrl: coverUrl.startsWith('http')
                            ? coverUrl
                            : '${AppConfig.apiBaseUrl}$coverUrl',
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

          // ── Stars + rating count ──────────────────────────────────
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(
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
              if (ratingCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '${avgRating.toStringAsFixed(1)} · $ratingCount ${ratingCount == 1 ? 'review' : 'reviews'}',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),

          // ── Title + author ────────────────────────────────────────
          Text(
            title,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            author,
            style: TextStyle(
                fontSize: 16,
                color: context.textSecondary,
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
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
          const SizedBox(height: 4),
          Text(
            [
              'PDF',
              fileSizeMb,
              if (totalPages > 0) '$totalPages pages',
            ].join(' · '),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
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
                          color: context.primarySurface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFF9333EA), width: 2),
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

          // ── Premium badge ─────────────────────────────────────────
          if (isPremium && !isPurchased)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: Color(0xFF78350F), size: 18),
                const SizedBox(width: 8),
                Text(
                  price != null
                      ? 'Premium · \$${price.toStringAsFixed(2)}'
                      : 'Premium',
                  style: const TextStyle(
                    color: Color(0xFF78350F),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ]),
            ),

          if (isPremium && isPurchased)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                    width: 2),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF16A34A), size: 18),
                SizedBox(width: 8),
                Text(
                  'Purchased',
                  style: TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ]),
            ),

          // ── Action buttons ────────────────────────────────────────
          if (isPremium && !isPurchased)
            // Buy button — full-width, amber/gold tones
            _BuyButton(bookId: bookId, price: price)
          else
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
                  side: const BorderSide(color: AppTheme.primary, width: 2.5),
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
            Text('About this book',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                    letterSpacing: -0.2)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderPurpleMid, width: 2.5),
              ),
              child: Text(
                description,
                style: TextStyle(fontSize: 14, color: context.textBody, height: 1.6),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Bookmarks ─────────────────────────────────────────────
          _BookmarksSection(
            bookId: bookId,
            bookmarksAsync: bookmarksAsync,
            ref: ref,
          ),

          // ── Reviews header ────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Reviews',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                    letterSpacing: -0.2)),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ReviewSheet(
        bookId: bookId,
        onSubmit: (rating, comment) async {
          try {
            final dio = ref.read(dioProvider);
            await dio.post('/api/books/$bookId/reviews', data: {
              'bookId': bookId,
              'rating': rating,
              'comment': comment.isEmpty ? null : comment,
            });
            ref.invalidate(bookDetailProvider(bookId));
            ref.invalidate(bookReviewsProvider(bookId));
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Review submitted! ⭐'),
                backgroundColor: AppTheme.progressGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ));
            }
          } catch (e) {
            if (sheetCtx.mounted) {
              ScaffoldMessenger.of(sheetCtx)
                  .showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buy button — full-width, triggers the Stripe payment sheet
// ─────────────────────────────────────────────────────────────────────────────

class _BuyButton extends ConsumerWidget {
  final String bookId;
  final double? price;

  const _BuyButton({required this.bookId, required this.price});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payState = ref.watch(paymentProvider);
    final isLoading = payState.status == PaymentStatus.loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : () => _buy(context, ref),
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.credit_card_rounded, size: 20),
            label: Text(
              isLoading
                  ? 'Processing…'
                  : price != null
                      ? 'Buy for \$${price!.toStringAsFixed(2)}'
                      : 'Purchase',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF78350F),
              disabledBackgroundColor:
                  const Color(0xFFF59E0B).withValues(alpha: 0.5),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        if (payState.status == PaymentStatus.failure &&
            payState.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            payState.errorMessage!,
            style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 13,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.lock_rounded, size: 13, color: Color(0xFF9CA3AF)),
            SizedBox(width: 4),
            Text(
              'Secure payment · Powered by Stripe',
              style:
                  TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _buy(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(paymentProvider.notifier);
    final success = await notifier.purchaseBook(bookId);
    if (success && context.mounted) {
      // Invalidate book detail so isPurchasedByUser refreshes
      ref.invalidate(bookDetailProvider(bookId));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Purchase successful! You can now read this book.'),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
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
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderPurpleMid, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: context.primarySurface,
          child: Text(initial,
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(userName,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: context.textPrimary)),
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
                  style: TextStyle(
                      fontSize: 13,
                      color: context.textBody,
                      height: 1.4)),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Duolingo-style review bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  final String bookId;
  final Future<void> Function(int rating, String comment) onSubmit;
  const _ReviewSheet({required this.bookId, required this.onSubmit});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  static const _labels = ['Terrible', 'Poor', 'Okay', 'Good', 'Amazing!'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border:
              Border(top: BorderSide(color: context.borderPurpleMid, width: 2)),
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
          const Text('⭐', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text(
            'Write a Review',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How would you rate this book?',
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: 20),
          // Star picker — big tappable stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled
                        ? AppTheme.goldMedal
                        : context.textHint,
                    size: 44,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _labels[_rating - 1],
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.goldMedal,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Share your thoughts (optional)',
              hintStyle: TextStyle(color: context.textHint),
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
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        await widget.onSubmit(
                            _rating, _commentCtrl.text.trim());
                        if (mounted) setState(() => _submitting = false);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Review',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bookmarks section — shows the user's bookmarks for this book inline on
// the detail page, matching spec section 5.2 mockup. Tapping navigates
// to the reader at the bookmarked page.
// ─────────────────────────────────────────────────────────────────────────────

class _BookmarksSection extends StatefulWidget {
  final String bookId;
  final AsyncValue bookmarksAsync;
  final WidgetRef ref;

  const _BookmarksSection({
    required this.bookId,
    required this.bookmarksAsync,
    required this.ref,
  });

  @override
  State<_BookmarksSection> createState() => _BookmarksSectionState();
}

class _BookmarksSectionState extends State<_BookmarksSection> {
  bool _emailSending = false;

  Future<void> _emailHighlights() async {
    setState(() => _emailSending = true);
    try {
      final dio = widget.ref.read(dioProvider);
      await dio.post('/api/bookmarks/export', data: {'bookId': widget.bookId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Highlights emailed to you! 📧'),
          backgroundColor: AppTheme.progressGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to send email. Try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _emailSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = widget.bookmarksAsync.valueOrNull as List?;

    // Don't show the section header if data hasn't resolved yet
    if (widget.bookmarksAsync.isLoading) return const SizedBox.shrink();
    if (widget.bookmarksAsync.hasError) return const SizedBox.shrink();
    if (bookmarks == null) return const SizedBox.shrink();

    final hasHighlights = bookmarks
        .whereType<Map>()
        .any((bm) => (bm['highlightedText'] as String? ?? '').isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(
                'Your Bookmarks',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: context.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (bookmarks.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${bookmarks.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ]),
            if (hasHighlights)
              _emailSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    )
                  : TextButton.icon(
                      onPressed: _emailHighlights,
                      icon: const Icon(Icons.mail_outline_rounded,
                          size: 16, color: AppTheme.primary),
                      label: const Text(
                        'Email Highlights',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
          ],
        ),
        const SizedBox(height: 10),
        if (bookmarks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.subtleBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.borderPurpleMid, width: 1.5),
            ),
            child: Row(children: [
              Text('🔖', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Open the reader to bookmark pages and highlight passages.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ]),
          )
        else
          Column(
            children: [
              for (final bm in bookmarks)
                _BookmarkTile(
                  bookmark: bm as Map,
                  onTap: () => GoRouter.of(context)
                      .push('/reader/${widget.bookId}?page=${bm['pageNumber']}'),
                  onDelete: () => _deleteBookmark(context, bm['id'] as String),
                ),
            ],
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _deleteBookmark(BuildContext context, String bookmarkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete bookmark'),
        content: const Text('Remove this bookmark?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final dio = widget.ref.read(dioProvider);
      await dio.delete('/api/bookmarks/$bookmarkId');
      widget.ref.invalidate(bookBookmarksProvider(widget.bookId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _BookmarkTile extends StatelessWidget {
  final Map bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _BookmarkTile({
    required this.bookmark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final page = bookmark['pageNumber'] as int? ?? 0;
    final highlight = bookmark['highlightedText'] as String?;
    final note = bookmark['note'] as String?;
    final color = bookmark['color'] as String?;

    // Map server color name to a Flutter color
    final accentColor = switch (color) {
      'yellow' => const Color(0xFFFBBF24),
      'green'  => const Color(0xFF34D399),
      'blue'   => const Color(0xFF60A5FA),
      'pink'   => const Color(0xFFF472B6),
      _        => AppTheme.primary,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderPurpleMid, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: accentColor.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Text(
                'p.$page',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (highlight != null && highlight.isNotEmpty)
                    Text(
                      '"$highlight"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textBody,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  if (note != null && note.isNotEmpty) ...[
                    if (highlight != null && highlight.isNotEmpty)
                      const SizedBox(height: 4),
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                  if ((highlight == null || highlight.isEmpty) &&
                      (note == null || note.isEmpty))
                    Text(
                      'Bookmark',
                      style: TextStyle(
                          fontSize: 13, color: context.textSecondary),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18, color: context.textHint),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
