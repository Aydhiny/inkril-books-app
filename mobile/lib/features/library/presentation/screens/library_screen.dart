import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/user_settings_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/animated_empty_state.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../providers/library_provider.dart';
import '../providers/recommendations_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
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
              // "Currently Reading" shelf — books with 0 < progress < 100
              SliverToBoxAdapter(
                child: _CurrentlyReadingSection(userLibraryAsync: userLibraryAsync),
              ),
              SliverToBoxAdapter(
                child: _RecommendationsSection(),
              ),
              SliverToBoxAdapter(
                child: _SectionTitle(title: 'My book library'),
              ),
              SliverToBoxAdapter(
                child: _MyLibraryScroll(userLibraryAsync: userLibraryAsync),
              ),
              SliverToBoxAdapter(
                child: _SectionTitle(title: 'Free to Read'),
              ),
              SliverToBoxAdapter(
                child: _PublicLibraryScroll(
                    publicBooksAsync: publicBooksAsync, premiumOnly: false),
              ),
              SliverToBoxAdapter(
                child: _SectionTitle(title: 'Premium Books'),
              ),
              SliverToBoxAdapter(
                child: _PublicLibraryScroll(
                    publicBooksAsync: publicBooksAsync, premiumOnly: true),
              ),
              SliverToBoxAdapter(child: _TodaysQuoteSection()),
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

class _StatsTopBar extends ConsumerWidget {
  final AsyncValue profileAsync;
  const _StatsTopBar({required this.profileAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = profileAsync.valueOrNull as Map<String, dynamic>?;
    final streak = (profile?['currentStreak'] as num?)?.toInt() ?? 0;
    final weeklyStats = profile?['weeklyStats'] as List? ?? [];
    final todayMinutes = weeklyStats.isNotEmpty
        ? ((weeklyStats.last as Map)['minutesRead'] as num?)?.toInt() ?? 0
        : 0;
    final initials = _initials(profile);

    // Settings for daily goal ring — default to plain time badge on error/loading.
    final settingsAsync = ref.watch(userSettingsProvider);
    final goalMinutes =
        (settingsAsync.valueOrNull?['dailyReadingGoalMinutes'] as num?)?.toInt() ?? 0;

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
          // Show a goal progress ring when a daily goal is configured,
          // otherwise fall back to the plain time badge.
          if (goalMinutes > 0)
            _DailyGoalRing(todayMinutes: todayMinutes, goalMinutes: goalMinutes)
          else
            _TopBadge(
              emoji: '⏱',
              value: todayMinutes >= 60
                  ? '${(todayMinutes / 60).round()}h'
                  : '${todayMinutes}m',
              color: const Color(0xFFEF4444),
            ),
          const SizedBox(width: 10),
          _NotificationBell(),
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

// ─────────────────────────────────────────────────────────────────────────────
// Daily goal progress ring
// ─────────────────────────────────────────────────────────────────────────────

class _DailyGoalRing extends StatelessWidget {
  final int todayMinutes;
  final int goalMinutes;
  const _DailyGoalRing({required this.todayMinutes, required this.goalMinutes});

  @override
  Widget build(BuildContext context) {
    final progress = (todayMinutes / goalMinutes).clamp(0.0, 1.0);
    final isComplete = progress >= 1.0;
    final activeColor = isComplete ? AppTheme.progressGreen : AppTheme.primary;
    final displayText = todayMinutes >= 60
        ? '${(todayMinutes / 60).round()}h'
        : '${todayMinutes}m';

    return Container(
      width: 52,
      height: 44,
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: context.borderPurple,
              color: activeColor,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: activeColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
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
          onPressed: () => _showImportSheet(context),
          icon: const Icon(Icons.phone_android_rounded, size: 18),
          label: const Text('Import',
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

  void _showImportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ImportLocalBookSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local book import sheet
// Picks a PDF from device storage, copies it to the app's private documents
// directory (stable across reboots), and creates a backend book record with
// isLocal=true. The file never leaves the device — only the absolute path is
// stored on the backend.
// ─────────────────────────────────────────────────────────────────────────────

class _ImportLocalBookSheet extends ConsumerStatefulWidget {
  const _ImportLocalBookSheet();

  @override
  ConsumerState<_ImportLocalBookSheet> createState() =>
      _ImportLocalBookSheetState();
}

class _ImportLocalBookSheetState
    extends ConsumerState<_ImportLocalBookSheet> {
  final _titleCtrl  = TextEditingController();
  final _authorCtrl = TextEditingController();

  String? _pickedPath;   // absolute path from file_picker
  String? _pickedName;   // filename for display
  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    // Pre-fill title from the filename (strip .pdf, replace underscores/dashes)
    final guessedTitle = file.name
        .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();

    setState(() {
      _pickedPath = file.path;
      _pickedName = file.name;
      _error = null;
      if (_titleCtrl.text.isEmpty) _titleCtrl.text = guessedTitle;
    });
  }

  Future<void> _import() async {
    if (_pickedPath == null) {
      setState(() => _error = 'Please select a PDF file first.');
      return;
    }
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a title.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // ① Copy to app-private storage so the path is stable even if the
      //    user moves or renames the original file.
      final docsDir    = await getApplicationDocumentsDirectory();
      final localBooksDir = Directory('${docsDir.path}/local_books');
      await localBooksDir.create(recursive: true);

      final ts       = DateTime.now().millisecondsSinceEpoch;
      final destPath = '${localBooksDir.path}/${ts}_$_pickedName';
      await File(_pickedPath!).copy(destPath);

      // ② Create the backend record (isLocal=true, path = stable device path)
      final dio = ref.read(dioProvider);
      await dio.post('/api/books', data: {
        'title':    title,
        'author':   _authorCtrl.text.trim().isEmpty
                        ? 'Unknown'
                        : _authorCtrl.text.trim(),
        'filePath': destPath,
        'isLocal':  true,
        'isPublic': false,
      });

      ref.invalidate(userLibraryProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Book imported! 📱'),
            backgroundColor: AppTheme.progressGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      setState(() {
        _loading = false;
        _error   = 'Import failed. Check app storage permissions.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border:
              Border(top: BorderSide(color: context.borderPurpleMid, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: context.borderPurpleMid,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon + heading
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: context.primarySurface, shape: BoxShape.circle),
            child: const Center(
                child: Text('📱', style: TextStyle(fontSize: 28))),
          ),
          const SizedBox(height: 14),
          Text('Import from device',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  color: context.textPrimary)),
          const SizedBox(height: 4),
          Text(
            'Your PDF stays on your device — only the title and path are saved.',
            style: TextStyle(fontSize: 13, color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // File picker row
          GestureDetector(
            onTap: _loading ? null : _pickFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _pickedPath != null
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : context.subtleBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _pickedPath != null
                      ? AppTheme.primary
                      : context.borderPurpleMid,
                  width: 2,
                ),
              ),
              child: Row(children: [
                Icon(
                  _pickedPath != null
                      ? Icons.picture_as_pdf_rounded
                      : Icons.folder_open_rounded,
                  color: _pickedPath != null
                      ? AppTheme.primary
                      : context.textHint,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _pickedName ?? 'Tap to choose a PDF…',
                    style: TextStyle(
                      color: _pickedPath != null
                          ? context.textPrimary
                          : context.textHint,
                      fontSize: 14,
                      fontWeight: _pickedPath != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_pickedPath != null)
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.progressGreen, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 14),

          // Title / Author fields
          TextField(
            controller: _titleCtrl,
            enabled: !_loading,
            decoration: InputDecoration(
              labelText: 'Book Title *',
              prefixIcon: const Icon(Icons.book_outlined, color: AppTheme.primary),
              labelStyle: TextStyle(color: context.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _authorCtrl,
            enabled: !_loading,
            decoration: InputDecoration(
              labelText: 'Author (optional)',
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  color: AppTheme.primary),
              labelStyle: TextStyle(color: context.textSecondary),
            ),
          ),

          // Error text
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13)),
          ],
          const SizedBox(height: 24),

          // Buttons
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
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
                onPressed: _loading ? null : _import,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_done_rounded, size: 18),
                label: Text(_loading ? 'Importing…' : 'Import Book',
                    style:
                        const TextStyle(fontWeight: FontWeight.w700)),
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
// Currently Reading shelf — books with progress > 0 and < 100
// Duolingo pattern: a focused "active tasks" row before the full inventory list
// ─────────────────────────────────────────────────────────────────────────────

class _CurrentlyReadingSection extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> userLibraryAsync;
  const _CurrentlyReadingSection({required this.userLibraryAsync});

  @override
  Widget build(BuildContext context) {
    final all = userLibraryAsync.valueOrNull;
    if (all == null) return const SizedBox.shrink();

    final inProgress = all.where((b) {
      final p = (b['readingProgressPercent'] as num? ?? 0).toDouble();
      return p > 0 && p < 100;
    }).toList()
      ..sort((a, b) {
        final aT = DateTime.tryParse(a['lastReadAt'] as String? ?? '') ?? DateTime(0);
        final bT = DateTime.tryParse(b['lastReadAt'] as String? ?? '') ?? DateTime(0);
        return bT.compareTo(aT); // most recently read first
      });

    if (inProgress.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(children: [
          const Text('📖', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            'Currently Reading',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: context.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${inProgress.length}',
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primary),
            ),
          ),
        ]),
      ),
      SizedBox(
        // Clamp between 140 and 180 dp so the card is comfortable in landscape
        // (where screen height can be as low as 360 dp) and doesn't over-inflate
        // on large tablets.
        height: (MediaQuery.sizeOf(context).height * 0.22).clamp(140.0, 180.0),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: inProgress.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _CurrentlyReadingCard(book: inProgress[i]),
        ),
      ),
      const SizedBox(height: 4),
    ]);
  }
}

class _CurrentlyReadingCard extends StatelessWidget {
  final Map<String, dynamic> book;
  const _CurrentlyReadingCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final bookId   = book['bookId'] as String? ?? book['id'] as String? ?? '';
    final title    = book['title'] as String? ?? 'Untitled';
    final progress = (book['readingProgressPercent'] as num? ?? 0).toDouble();
    final coverUrl = book['coverImageUrl'] as String?;
    final etaMins  = book['estimatedMinutesRemaining'] as int?;

    return GestureDetector(
      onTap: () => context.push('/reader/$bookId'),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.borderPurpleMid, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(children: [
          // Mini cover
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 90,
              child: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      // 128 px = 2× the 64 px logical display size — avoids
                      // decoding the full source image into GPU memory.
                      memCacheWidth: 128,
                      placeholder: (_, __) => _MiniCoverPlaceholder(),
                      errorWidget: (_, __, ___) => _MiniCoverPlaceholder(),
                    )
                  : _MiniCoverPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              // Duolingo-style progress row
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(
                  '${progress.toInt()}% done',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const Icon(Icons.play_circle_fill_rounded,
                    color: AppTheme.primary, size: 20),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress / 100),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: context.borderPurple,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                  ),
                ),
              ),
              // ETA chip — shown once the backend has enough session history
              // to compute a personalised reading speed (avgPagesPerMinute > 0).
              if (etaMins != null) ...[
                const SizedBox(height: 5),
                Row(children: [
                  const Text('⏱', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 3),
                  Text(
                    etaMins < 60
                        ? '~$etaMins min to finish'
                        : '~${etaMins ~/ 60}h ${etaMins % 60}m to finish',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.textHint,
                    ),
                  ),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MiniCoverPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.primarySurface,
    child: const Center(
      child: Icon(Icons.menu_book_rounded, color: AppTheme.primary, size: 24),
    ),
  );
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
    // Proportional to screen height so the shelf feels right in both portrait
    // (tall) and landscape (shallow). Clamped so it never shrinks below 200 dp
    // or expands past 320 dp regardless of device size.
    final listHeight =
        (MediaQuery.sizeOf(context).height * 0.36).clamp(200.0, 320.0);
    return SizedBox(
      height: listHeight,
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
  final bool premiumOnly;
  const _PublicLibraryScroll({
    required this.publicBooksAsync,
    required this.premiumOnly,
  });

  @override
  Widget build(BuildContext context) {
    final listHeight =
        (MediaQuery.sizeOf(context).height * 0.36).clamp(200.0, 320.0);
    return SizedBox(
      height: listHeight,
      child: publicBooksAsync.when(
        loading: () => const ShimmerBookScroll(),
        error: (e, _) => Center(
            child: Text('Failed to load books',
                style: TextStyle(color: context.textSecondary))),
        data: (all) {
          final books = all
              .where((b) => (b['isPremium'] as bool? ?? false) == premiumOnly)
              .toList();
          if (books.isEmpty) {
            return Center(
              child: Text(
                premiumOnly ? 'No premium books yet' : 'No free books yet',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) =>
                _LibraryBookCard(book: books[i], showProgress: false),
          );
        },
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
    final bookId    = book['bookId'] as String? ?? book['id'] as String? ?? '';
    final progress  = (book['readingProgressPercent'] as num? ?? 0).toDouble();
    final coverUrl  = book['coverImageUrl'] as String?;
    final avgRating = (book['averageRating'] as num? ?? 0).toDouble();
    final isPremium = book['isPremium'] as bool? ?? false;
    final price     = (book['price'] as num?)?.toDouble();
    final isLocal   = book['isLocal'] as bool? ?? false;

    return GestureDetector(
      onTap: () => context.push('/books/$bookId'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
        Container(
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fixed-height cover — Expanded can't be used here because the card
            // sits inside a SliverList column with unbounded height constraints.
            SizedBox(
              height: 210,
              child: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      // 330 px = 2× the 165 px card width — saves GPU memory
                      // without sacrificing visible quality.
                      memCacheWidth: 330,
                      placeholder: (_, __) => _CoverPlaceholder(),
                      errorWidget: (_, __, ___) => _CoverPlaceholder(),
                    )
                  : _CoverPlaceholder(),
            ),
            Container(
              color: context.cardBg,
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Star rating row (always shown when avgRating > 0)
                  if (avgRating > 0) ...[
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFF59E0B), size: 13),
                      const SizedBox(width: 3),
                      Text(
                        avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                  ],
                  if (showProgress) ...[
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
                    const SizedBox(height: 4),
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
                ],
              ),
            ),
          ],
        ),
      ),  // Container
      // ── Premium price sticker ──────────────────────────────────────────
      if (isPremium)
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              price != null ? '\$${price.toStringAsFixed(2)}' : '💲',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      // ── Local-book badge ──────────────────────────────────────────────────
      if (isLocal)
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_android_rounded,
                    size: 10, color: Colors.white),
                SizedBox(width: 3),
                Text('Local',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ],  // Stack children
      ),  // Stack
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
// Today's Quote — uses user's own highlights when available, falls back
// to static literary quotes when they haven't highlighted anything yet.
// ─────────────────────────────────────────────────────────────────────────────

class _TodaysQuoteSection extends ConsumerWidget {
  const _TodaysQuoteSection();

  static const List<(String, String)> _fallbacks = [
    ('"It is not our abilities that show what we truly are. It is our choices."', 'Moby Dick'),
    ('"It does not do to dwell on dreams and forget to live."', 'The Great Gatsby'),
    ('"I must not fear. Fear is the mind-killer."', 'Dune'),
    ('"So we beat on, boats against the current, borne back ceaselessly into the past."', 'The Great Gatsby'),
    ('"War is peace. Freedom is slavery. Ignorance is strength."', '1984'),
    ('"It was a bright cold day in April, and the clocks were striking thirteen."', '1984'),
    ('"It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife."', 'Pride and Prejudice'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qotdAsync = ref.watch(qotdProvider);

    // Determine the text + source to display
    String quoteText;
    String quoteSource;
    bool isPersonal = false;

    final highlight = qotdAsync.valueOrNull;
    // highlightedText can be null — bookmarks may have notes but no text selection.
    // Fall through to the static quote if the field is absent or empty.
    final highlightText = highlight?['highlightedText'] as String?;
    if (highlight != null && highlightText != null && highlightText.isNotEmpty) {
      quoteText  = '"$highlightText"';
      quoteSource = 'Your highlight — ${highlight['bookTitle'] as String? ?? 'a book you read'}';
      isPersonal = true;
    } else {
      final dayIndex = DateTime.now().difference(DateTime(2024)).inDays;
      final q = _fallbacks[dayIndex % _fallbacks.length];
      quoteText  = q.$1;
      quoteSource = q.$2;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              isPersonal ? 'Your Highlight ✨' : "Today's Quote",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
                letterSpacing: -0.3,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPersonal ? context.primarySurface : context.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPersonal ? AppTheme.primary : context.borderPurpleMid,
                width: isPersonal ? 2 : 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: isPersonal ? 0.10 : 0.04),
                  blurRadius: 10,
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
                        quoteText,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textBody,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '— $quoteSource',
                        style: TextStyle(
                          fontSize: 12,
                          color: isPersonal ? AppTheme.primary : AppTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isPersonal
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : context.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      isPersonal ? '✨' : '📖',
                      style: const TextStyle(fontSize: 28),
                    ),
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
// Notification bell with unread badge
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider);
    final hasUnread = unread > 0;

    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
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
            if (hasUnread)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: unread > 9 ? 5 : 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendations section
// Surfaces the hybrid recommendation engine results from /api/recommendations.
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationsSection extends ConsumerWidget {
  const _RecommendationsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recAsync = ref.watch(recommendationsProvider);

    // Don't render the section at all while loading or on error —
    // the library content below is more important than a failed suggestions row.
    if (recAsync.isLoading) return const SizedBox.shrink();
    if (recAsync.hasError) return const SizedBox.shrink();

    final books = recAsync.valueOrNull ?? [];
    if (books.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(children: [
            const Text('✨', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              'Recommended for You',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: context.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ]),
        ),
        SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.40).clamp(220.0, 345.0),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final book = books[i];
              final reason = book['reason'] as String?;
              return SizedBox(
                width: 165,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LibraryBookCard(book: book, showProgress: false),
                    if (reason != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: context.textSecondary,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
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
                        ? CachedNetworkImage(
                            imageUrl: cover,
                            width: 52,
                            height: 72,
                            fit: BoxFit.cover,
                            memCacheWidth: 104,
                            placeholder: (_, __) => Container(
                              width: 52, height: 72,
                              color: context.primarySurface,
                              child: const Center(child: Icon(
                                  Icons.book_rounded, color: AppTheme.primary, size: 24)),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 52, height: 72,
                              color: context.primarySurface,
                              child: const Center(child: Icon(
                                  Icons.book_rounded, color: AppTheme.primary, size: 24)),
                            ),
                          )
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
