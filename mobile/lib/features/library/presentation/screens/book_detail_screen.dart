import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_config.dart';
import '../providers/library_provider.dart';

class BookDetailScreen extends ConsumerWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookDetailProvider(bookId));
    final reviewsAsync = ref.watch(bookReviewsProvider(bookId));

    return Scaffold(
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (book) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  book['title'] as String? ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
                background: book['coverImageUrl'] != null
                    ? CachedNetworkImage(
                        imageUrl: '${AppConfig.apiBaseUrl}${book['coverImageUrl']}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const _CoverPlaceholder(),
                      )
                    : const _CoverPlaceholder(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.menu_book),
                  tooltip: 'Read',
                  onPressed: () => context.push('/reader/$bookId'),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['author'] as String? ?? '',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text('${(book['averageRating'] as num?)?.toStringAsFixed(1) ?? '—'}'
                          ' (${book['ratingCount'] ?? 0} reviews)'),
                      const SizedBox(width: 16),
                      const Icon(Icons.menu_book_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text('${book['totalPages'] ?? 0} pages'),
                    ]),
                    const SizedBox(height: 8),
                    if ((book['genres'] as List?)?.isNotEmpty == true)
                      Wrap(
                        spacing: 6,
                        children: (book['genres'] as List)
                            .map((g) => Chip(label: Text(g as String), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))
                            .toList(),
                      ),
                    if (book['readingProgressPercent'] != null) ...[
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Reading progress'),
                        Text('${book['readingProgressPercent']}%'),
                      ]),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: (book['readingProgressPercent'] as num).toDouble() / 100,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.menu_book),
                          label: Text(book['readingProgressPercent'] != null ? 'Continue Reading' : 'Start Reading'),
                          onPressed: () => context.push('/reader/$bookId'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.library_add_outlined),
                        label: const Text('Add to Library'),
                        onPressed: () => _addToLibrary(context, ref),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    if (book['description'] != null && (book['description'] as String).isNotEmpty) ...[
                      Text('About', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(book['description'] as String),
                      const SizedBox(height: 24),
                    ],
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Reviews', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => _showReviewDialog(context, ref),
                        child: const Text('Write a review'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            reviewsAsync.when(
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (reviews) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final r = reviews[i] as Map;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Row(children: [
                        Text(r['userName'] as String? ?? ''),
                        const Spacer(),
                        ...List.generate(5, (s) => Icon(
                          s < (r['rating'] as int? ?? 0) ? Icons.star : Icons.star_border,
                          size: 14,
                          color: Colors.amber,
                        )),
                      ]),
                      subtitle: r['comment'] != null ? Text(r['comment'] as String) : null,
                    );
                  },
                  childCount: reviews.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Future<void> _addToLibrary(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/user-books', data: {'bookId': bookId});
      ref.invalidate(userLibraryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to your library.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already in your library or an error occurred.')),
        );
      }
    }
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref) {
    int rating = 5;
    final commentCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Write a Review'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(
              icon: Icon(i < rating ? Icons.star : Icons.star_border, color: Colors.amber),
              onPressed: () => setState(() => rating = i + 1),
            ))),
            const SizedBox(height: 8),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(labelText: 'Comment (optional)'),
              maxLines: 3,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final dio = ref.read(dioProvider);
                  await dio.post('/api/books/$bookId/reviews', data: {
                    'bookId': bookId,
                    'rating': rating,
                    'comment': commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
                  });
                  ref.invalidate(bookDetailProvider(bookId));
                  ref.invalidate(bookReviewsProvider(bookId));
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Review submitted.')),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
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
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: const Center(child: Icon(Icons.book, size: 80)),
    );
  }
}
