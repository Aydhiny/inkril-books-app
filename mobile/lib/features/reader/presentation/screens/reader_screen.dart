import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../reading/presentation/screens/reading_hub_screen.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String bookId;
  const ReaderScreen({super.key, required this.bookId});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  PDFViewController? _pdfController;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _showControls = true;
  bool _showBookmarksPanel = false;
  String? _localPdfPath;
  String? _error;
  bool _downloading = false;
  String? _sessionId;
  String _bookTitle = '';

  // ── Reading timer ──────────────────────────────────────────────────────────
  Timer? _readingTimer;
  int _elapsedSeconds = 0;

  // ── Page-change debounce — syncs progress to backend ~5 s after last turn ──
  Timer? _progressDebounce;

  String get _elapsedFormatted {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      return '${h}h ${(m % 60)}m';
    }
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  void _startTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadBook();
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _progressDebounce?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _endSession();
    super.dispose();
  }

  /// Debounced — called every time the user turns a page.
  /// Waits 5 s of inactivity before syncing to avoid hammering the API
  /// on fast page-flips.
  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(seconds: 5), () => _syncProgress(page));
  }

  Future<void> _syncProgress(int page) async {
    if (_totalPages <= 0) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.patch(
        '/api/user-books/${widget.bookId}/progress',
        data: {'currentPage': page},
      );
    } catch (_) {
      // Silently ignore — the final sync in _endSession() is the source of truth.
    }
  }

  Future<void> _loadBook() async {
    setState(() => _downloading = true);
    try {
      final bookDetail =
          await ref.read(bookDetailProvider(widget.bookId).future);
      final filePath = bookDetail['filePath'] as String?;
      _bookTitle = bookDetail['title'] as String? ?? '';

      if (filePath == null) {
        setState(() {
          _error = 'This book has no PDF file yet.';
          _downloading = false;
        });
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/book_${widget.bookId}.pdf');

      if (!await localFile.exists()) {
        final dio = ref.read(dioProvider);
        await dio.download(
          '${AppConfig.apiBaseUrl}$filePath',
          localFile.path,
          onReceiveProgress: (_, __) {},
        );
      }

      final startPage = (bookDetail['lastReadPage'] as int?) ?? 0;
      await _startSession(startPage);

      setState(() {
        _localPdfPath = localFile.path;
        _currentPage = startPage;
        _downloading = false;
      });
      _startTimer(); // begin counting reading time
    } catch (e) {
      setState(() {
        _error = 'Failed to load book: $e';
        _downloading = false;
      });
    }
  }

  Future<void> _startSession(int startPage) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/reading-sessions', data: {
        'bookId': widget.bookId,
        'startPage': startPage,
      });
      _sessionId = (response.data as Map)['id'] as String?;
    } catch (_) {}
  }

  Future<void> _endSession() async {
    if (_sessionId == null) return;
    try {
      final dio = ref.read(dioProvider);
      final minutesRead = (_elapsedSeconds / 60).ceil().clamp(1, 9999);
      await dio.put('/api/reading-sessions/$_sessionId/end', data: {
        'endPage': _currentPage,
        'durationMinutes': minutesRead,
      });
      ref.invalidate(userLibraryProvider);
      ref.invalidate(bookDetailProvider(widget.bookId));
    } catch (_) {}
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_downloading) return _LoadingView(bookTitle: _bookTitle);
    if (_error != null) return _ErrorView(error: _error!);
    if (_localPdfPath == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── PDF viewer ───────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() {
              _showControls = !_showControls;
              if (_showControls) _showBookmarksPanel = false;
            }),
            child: PDFView(
              filePath: _localPdfPath!,
              enableSwipe: true,
              swipeHorizontal: true,
              autoSpacing: false,
              pageFling: true,
              defaultPage: _currentPage,
              backgroundColor: Colors.white,
              onRender: (pages) => setState(() => _totalPages = pages ?? 0),
              onViewCreated: (ctrl) => _pdfController = ctrl,
              onPageChanged: (page, _) => _onPageChanged(page ?? _currentPage),
              onError: (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('PDF error: $e')));
                }
              },
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────────
          AnimatedSlide(
            offset: _showControls ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: _TopBar(
              bookTitle: _bookTitle,
              bookmarksActive: _showBookmarksPanel,
              elapsedFormatted: _elapsedFormatted,
              onBack: () => Navigator.of(context).pop(),
              onBookmark: _addBookmark,
              onToggleBookmarks: () =>
                  setState(() => _showBookmarksPanel = !_showBookmarksPanel),
            ),
          ),

          // ── Bottom bar ───────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: _showControls ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _BottomBar(
                currentPage: _currentPage,
                totalPages: _totalPages,
                onPrev: _currentPage > 0
                    ? () => _pdfController?.setPage(_currentPage - 1)
                    : null,
                onNext: _currentPage < _totalPages - 1
                    ? () => _pdfController?.setPage(_currentPage + 1)
                    : null,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // ── Bookmarks scrim — tap outside the panel to close ────────
          if (_showBookmarksPanel)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showBookmarksPanel = false),
                child: AnimatedOpacity(
                  opacity: _showBookmarksPanel ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
              ),
            ),

          // ── Bookmarks side panel ─────────────────────────────────────
          AnimatedSlide(
            offset: _showBookmarksPanel
                ? Offset.zero
                : const Offset(1, 0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            child: Align(
              alignment: Alignment.centerRight,
              child: _BookmarksPanel(
                bookId: widget.bookId,
                onClose: () => setState(() => _showBookmarksPanel = false),
                onGoToPage: (page) {
                  _pdfController?.setPage(page - 1);
                  setState(() => _showBookmarksPanel = false);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Bookmark sheet ──────────────────────────────────────────────────────

  void _addBookmark() {
    final highlightCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _BookmarkSheet(
        page: _currentPage + 1,
        highlightCtrl: highlightCtrl,
        noteCtrl: noteCtrl,
        onSave: () async {
          try {
            final dio = ref.read(dioProvider);
            await dio.post('/api/bookmarks', data: {
              'bookId': widget.bookId,
              'pageNumber': _currentPage + 1,
              'highlightedText': highlightCtrl.text.trim().isEmpty
                  ? null
                  : highlightCtrl.text.trim(),
              'note': noteCtrl.text.trim().isEmpty
                  ? null
                  : noteCtrl.text.trim(),
            });
            // Invalidate so the Reading Hub panel refreshes
            ref.invalidate(bookBookmarksProvider(widget.bookId));
            if (sheetCtx.mounted) {
              Navigator.pop(sheetCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Bookmark saved!'),
                  backgroundColor: AppTheme.progressGreen,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          } catch (_) {
            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
          }
        },
        onCancel: () => Navigator.pop(sheetCtx),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / error views
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String bookTitle;
  const _LoadingView({required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child:
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: AppTheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            bookTitle.isNotEmpty ? 'Opening "$bookTitle"…' : 'Loading book…',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151)),
          ),
          const SizedBox(height: 6),
          const Text('Downloading PDF',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primary,
        elevation: 0,
        title: const Text('Reader'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 56, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
                Text(error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 15)),
              ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String bookTitle;
  final bool bookmarksActive;
  final String elapsedFormatted;
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final VoidCallback onToggleBookmarks;

  const _TopBar({
    required this.bookTitle,
    required this.bookmarksActive,
    required this.elapsedFormatted,
    required this.onBack,
    required this.onBookmark,
    required this.onToggleBookmarks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: AppTheme.primary,
              onPressed: onBack,
            ),
            Expanded(
              child: Text(
                bookTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            // Live reading timer badge
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD8B4FE), width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined,
                    size: 13, color: AppTheme.primary),
                const SizedBox(width: 3),
                Text(
                  elapsedFormatted,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ]),
            ),
            // Add bookmark
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined, size: 22),
              color: AppTheme.primary,
              tooltip: 'Add Bookmark',
              onPressed: onBookmark,
            ),
            // Toggle bookmark list
            IconButton(
              icon: Icon(
                bookmarksActive
                    ? Icons.bookmarks_rounded
                    : Icons.bookmarks_outlined,
                size: 22,
              ),
              color: bookmarksActive
                  ? AppTheme.primary
                  : const Color(0xFF9CA3AF),
              tooltip: 'Bookmarks',
              onPressed: onToggleBookmarks,
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onBack;

  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              _PageButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
              Expanded(
                child: Center(
                  child: Text(
                    totalPages > 0
                        ? 'Page ${currentPage + 1} of $totalPages'
                        : 'Loading…',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
              _PageButton(icon: Icons.chevron_right_rounded, onTap: onNext),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to App',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _PageButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppTheme.primarySurface
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 22,
          color: onTap != null ? AppTheme.primary : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bookmarks side panel
// ─────────────────────────────────────────────────────────────────────────────

class _BookmarksPanel extends ConsumerWidget {
  final String bookId;
  final VoidCallback onClose;
  final void Function(int page) onGoToPage;

  const _BookmarksPanel({
    required this.bookId,
    required this.onClose,
    required this.onGoToPage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookBookmarksProvider(bookId));

    return Container(
      width: MediaQuery.of(context).size.width * 0.82,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 20,
              offset: Offset(-4, 0))
        ],
      ),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
            child: Row(children: [
              const Icon(Icons.bookmarks_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Bookmarks',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              bookmarksAsync.maybeWhen(
                data: (bms) => Text(
                  '${bms.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              // Explicit close button — much easier to find than swipe/scrim
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                color: const Color(0xFF6B7280),
                tooltip: 'Close',
                onPressed: onClose,
              ),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          // List
          Expanded(
            child: bookmarksAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
              error: (_, __) => const Center(
                  child: Text('Could not load bookmarks',
                      style: TextStyle(color: Color(0xFF9CA3AF)))),
              data: (bms) {
                if (bms.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No bookmarks yet.\nTap ＋ in the top bar to save a passage.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 13, height: 1.5),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: bms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final b = bms[i] as Map;
                    final page = (b['pageNumber'] as num?)?.toInt() ?? 0;
                    final highlighted = b['highlightedText'] as String?;
                    final note = b['note'] as String?;

                    return GestureDetector(
                      onTap: () => onGoToPage(page),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE9D5FF), width: 1.5),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.bookmark_rounded,
                                    color: AppTheme.primary, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Page $page',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ]),
                              if (highlighted != null &&
                                  highlighted.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '"$highlighted"',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF92400E),
                                      height: 1.4,
                                    ),
                                    maxLines: 5,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              if (note != null && note.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  note,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bookmark bottom sheet — with highlighted text + note fields
// ─────────────────────────────────────────────────────────────────────────────

class _BookmarkSheet extends StatelessWidget {
  final int page;
  final TextEditingController highlightCtrl;
  final TextEditingController noteCtrl;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _BookmarkSheet({
    required this.page,
    required this.highlightCtrl,
    required this.noteCtrl,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A6B21A8),
              blurRadius: 24,
              offset: Offset(0, -4))
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bookmark_rounded,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add to Bookmarks',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937)),
                    ),
                    Text(
                      'Page $page',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF9CA3AF)),
                    ),
                  ]),
            ]),
            const SizedBox(height: 20),

            // Highlighted text field (primary)
            const Text(
              'Highlighted text',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: highlightCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Paste or type the passage you want to remember…',
                hintStyle:
                    const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFFEF3C7),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFFF59E0B), width: 2),
                ),
              ),
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Color(0xFF92400E),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),

            // Note field (secondary)
            const Text(
              'Note (optional)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Why did this stand out to you?',
                hintStyle:
                    const TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save Bookmark',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
