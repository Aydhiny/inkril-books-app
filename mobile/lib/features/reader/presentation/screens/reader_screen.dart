import 'dart:async';
import 'dart:io';
import 'dart:math' show pi;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/services/dictionary_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/offline_banner.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../reading/presentation/screens/reading_hub_screen.dart';
import '../models/reader_settings.dart';
import '../models/reader_theme.dart';
import '../providers/buddy_reading_provider.dart';
import '../providers/reader_settings_provider.dart';

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

  // ── Confetti — fires once when the book is completed ──────────────────────
  late final ConfettiController _confetti;
  bool _confettiFired = false;

  // ── Session summary overlay ────────────────────────────────────────────────
  bool _showSummary = false;
  Completer<void>? _summaryCompleter;

  // ── Sleep timer ────────────────────────────────────────────────────────────
  // Per-session only — not persisted. null = off.
  int? _sleepTimerMinutes;
  int _sleepRemainingSeconds = 0;

  // ── Auto-scroll (auto page-turn) ───────────────────────────────────────────
  bool _autoScrollActive = false;
  Timer? _autoScrollTimer;

  // ── ETA tracking ──────────────────────────────────────────────────────────
  // Counts forward page turns to compute an average seconds-per-page.
  int _pagesReadThisSession = 0;

  // ── Streak nudge ──────────────────────────────────────────────────────────
  bool _showStreakNudge = false;
  bool _streakNudgeSent = false;
  Timer? _nudgeHideTimer;

  // ── Go-to-page search bar ─────────────────────────────────────────────────
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  // ── Two-page spread (landscape) ───────────────────────────────────────────
  PDFViewController? _pdfController2;

  // ── Focus mode — dims page outside a reading band ─────────────────────────
  bool _focusMode = false;

  // ── Dictionary ────────────────────────────────────────────────────────────
  // Long-press on the PDF area opens the lookup sheet.
  // _lastLongPressWord is pre-populated when the user copied a word before
  // long-pressing; otherwise the sheet shows an empty search field.
  final TextEditingController _dictController = TextEditingController();

  // ── Computed properties ───────────────────────────────────────────────────

  /// Estimated reading time remaining, shown in the bottom bar.
  /// Only computed once ≥ 3 pages and ≥ 60 s have elapsed.
  String? get _etaText {
    if (_pagesReadThisSession < 3 || _elapsedSeconds < 60 || _totalPages <= 0) {
      return null;
    }
    final avgSecsPerPage = _elapsedSeconds / _pagesReadThisSession;
    final pagesLeft = _totalPages - _currentPage - 1;
    if (pagesLeft <= 0) return null;
    final etaMins = (pagesLeft * avgSecsPerPage / 60).round();
    if (etaMins < 1) return '< 1 min left';
    if (etaMins < 60) return '~$etaMins min left';
    return '~${etaMins ~/ 60}h ${etaMins % 60}m left';
  }

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
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;

        // Sleep timer countdown
        if (_sleepTimerMinutes != null) {
          _sleepRemainingSeconds =
              (_sleepTimerMinutes! * 60) - _elapsedSeconds;
          if (_sleepRemainingSeconds <= 0 && !_showSummary) {
            _sleepTimerMinutes = null;
            _closeReader();
          }
        }

        // Streak nudge at exactly 25 minutes
        if (!_streakNudgeSent && _elapsedSeconds == 25 * 60) {
          _streakNudgeSent = true;
          _showStreakNudge = true;
          _nudgeHideTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _showStreakNudge = false);
          });
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadBook();
  }

  @override
  void dispose() {
    _readingTimer?.cancel();
    _progressDebounce?.cancel();
    _autoScrollTimer?.cancel();
    _nudgeHideTimer?.cancel();
    _searchController.dispose();
    _dictController.dispose();
    _confetti.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Always restore free rotation when leaving the reader
    SystemChrome.setPreferredOrientations([]);
    _endSession();
    super.dispose();
  }

  /// Debounced — called every time the user turns a page (primary controller only).
  void _onPageChanged(int page) {
    final wasForward = page > _currentPage;
    setState(() {
      _currentPage = page;
      if (wasForward) _pagesReadThisSession++;
    });

    HapticFeedback.lightImpact(); // tactile page-turn feedback

    // Keep the right-panel in sync during two-page spread
    _pdfController2?.setPage(page + 1);

    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(seconds: 5), () => _syncProgress(page));

    // Confetti on book completion (last page reached)
    if (!_confettiFired && _totalPages > 0 && page >= _totalPages - 1) {
      _confettiFired = true;
      _confetti.play();
      HapticFeedback.heavyImpact();
    }
  }

  // ── Sleep timer ────────────────────────────────────────────────────────────

  void _setSleepTimer(int? minutes) {
    setState(() {
      _sleepTimerMinutes = minutes;
      _sleepRemainingSeconds = (minutes ?? 0) * 60;
    });
  }

  // ── Auto-scroll ────────────────────────────────────────────────────────────

  void _startAutoScroll(int wpm) {
    _autoScrollTimer?.cancel();
    // seconds per page — clamp between 3 s (600 WPM) and 600 s (very slow)
    final secsPerPage =
        ((250.0 / wpm.clamp(50, 600)) * 60).round().clamp(3, 600);
    _autoScrollTimer =
        Timer.periodic(Duration(seconds: secsPerPage), (_) {
      if (!mounted || _showSummary) return;
      final step = _pdfController2 != null ? 2 : 1; // two-page advances by 2
      final next = _currentPage + step;
      if (next < _totalPages) {
        _pdfController?.setPage(next);
      } else {
        _stopAutoScroll();
      }
    });
    setState(() => _autoScrollActive = true);
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (mounted) setState(() => _autoScrollActive = false);
  }

  /// Called when the user deliberately exits via "Back to App".
  /// Shows the summary overlay, ends the session, then pops.
  /// The user can tap anywhere on the overlay to dismiss early — the 2.5s timer
  /// and the API call race via Future.any / Future.wait so neither blocks the other.
  Future<void> _closeReader() async {
    setState(() => _showSummary = true);
    _summaryCompleter = Completer<void>();
    final sessionSeconds = _elapsedSeconds; // capture before async gap

    await Future.wait([
      _endSession(),
      Future.any([
        _summaryCompleter!.future,
        Future.delayed(const Duration(milliseconds: 2500)),
      ]),
    ]);

    if (!mounted) return;

    // Capture GoRouter reference BEFORE pop — after pop() the widget
    // unmounts and mounted becomes false, making context.push unreachable.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();

    // 5+ minute session → streak celebration (router is still valid after pop)
    if (sessionSeconds >= 300) {
      router.push('/reading-stats');
    }
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
    final sid = _sessionId!;
    _sessionId = null; // prevent double-call from dispose + _closeReader
    try {
      final dio = ref.read(dioProvider);
      final minutesRead = (_elapsedSeconds / 60).ceil().clamp(1, 9999);
      await dio.put('/api/reading-sessions/$sid/end', data: {
        'endPage': _currentPage,
        'durationMinutes': minutesRead,
      });
      // These may throw if the widget is already disposed (called from dispose()).
      // The try-catch swallows it — providers will refresh on next navigation anyway.
      ref.invalidate(userLibraryProvider);
      ref.invalidate(bookDetailProvider(widget.bookId));
      ref.invalidate(myProfileProvider);
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

    final settings = ref.watch(readerSettingsProvider);

    // Apply / release portrait lock in sync with the setting.
    // SystemChrome.setPreferredOrientations is idempotent so calling it on
    // every build (only when value actually changed) is safe and cheap.
    ref.listen<bool>(
      readerSettingsProvider.select((s) => s.lockPortrait),
      (_, locked) => SystemChrome.setPreferredOrientations(
        locked
            ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
            : [],
      ),
    );
    // Also apply immediately on first build
    SystemChrome.setPreferredOrientations(
      settings.lockPortrait
          ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
          : [],
    );

    // Night mode overrides the selected theme and brightness
    final effectiveTheme =
        settings.isNightMode ? ReaderTheme.twilight : settings.theme;
    final effectiveBrightness =
        settings.isNightMode ? 0.6 : settings.brightness;

    // Two-page spread: detect landscape
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;
    // Clear stale right-panel controller when rotating back to portrait
    if (!isLandscape && _pdfController2 != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) {
        if (mounted) setState(() => _pdfController2 = null);
      });
    }

    // Prev/Next respect two-page stride
    final pageStride = isLandscape ? 2 : 1;

    Widget pdfArea() {
      final pdfView = PDFView(
        filePath: _localPdfPath!,
        enableSwipe: !isLandscape,
        swipeHorizontal: settings.horizontalScroll,
        autoSpacing: false,
        pageFling: true,
        defaultPage: _currentPage,
        backgroundColor: Colors.white,
        onRender: (pages) => setState(() => _totalPages = pages ?? 0),
        onViewCreated: (ctrl) => _pdfController = ctrl,
        onPageChanged: (page, _) => _onPageChanged(page ?? _currentPage),
        onError: (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('PDF error: $e')));
          }
        },
      );

      if (!isLandscape || _totalPages <= 1) {
        return ColorFiltered(
          colorFilter: effectiveTheme.colorFilter,
          child: pdfView,
        );
      }

      // Two-page spread — primary left, secondary right
      final rightPage = _currentPage + 1;
      return Row(children: [
        Expanded(
          child: ColorFiltered(
            colorFilter: effectiveTheme.colorFilter,
            child: pdfView,
          ),
        ),
        Container(
          width: 1,
          color: effectiveTheme.isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
        Expanded(
          child: ColorFiltered(
            colorFilter: effectiveTheme.colorFilter,
            child: PDFView(
              filePath: _localPdfPath!,
              enableSwipe: false,
              defaultPage: rightPage < _totalPages ? rightPage : _currentPage,
              backgroundColor: Colors.white,
              onViewCreated: (ctrl) => _pdfController2 = ctrl,
              onError: (_) {},
            ),
          ),
        ),
      ]);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_showSummary) _closeReader();
      },
      child: Scaffold(
      backgroundColor: effectiveTheme.scaffoldColor,
      body: Stack(
        children: [
          // ── PDF viewer ───────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() {
              _showControls = !_showControls;
              if (_showControls) _showBookmarksPanel = false;
            }),
            onLongPress: _openDictionary,
            child: pdfArea(),
          ),

          // ── Brightness overlay ────────────────────────────────────────
          if (effectiveBrightness < 1.0)
            IgnorePointer(
              child: Container(
                color: Colors.black
                    .withValues(alpha: (1 - effectiveBrightness) * 0.65),
              ),
            ),

          // ── Focus mode — dims everything outside a ~3-line reading band ──
          if (_focusMode)
            _FocusModeOverlay(screenHeight: size.height),

          // ── Buddy reading chips ───────────────────────────────────────
          _BuddyChips(
            bookId: widget.bookId,
            currentPage: _currentPage,
            totalPages: _totalPages,
          ),

          // ── Offline banner ───────────────────────────────────────────
          const OfflineBanner(),

          // ── Streak nudge toast ────────────────────────────────────────
          _StreakNudgeToast(visible: _showStreakNudge),

          // ── Go-to-page search bar ─────────────────────────────────────
          AnimatedSlide(
            offset: _showSearch ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: _SearchBar(
              controller: _searchController,
              isDark: effectiveTheme.isDark,
              onGo: () {
                final page = int.tryParse(_searchController.text.trim());
                if (page != null && page >= 1 && page <= _totalPages) {
                  _pdfController?.setPage(page - 1);
                }
                setState(() => _showSearch = false);
                _searchController.clear();
              },
              onClose: () {
                setState(() => _showSearch = false);
                _searchController.clear();
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
              fontScale: settings.hudFontScale,
              isDarkTheme: effectiveTheme.isDark,
              isNightMode: settings.isNightMode,
              onBack: _closeReader,
              onBookmark: _addBookmark,
              onToggleBookmarks: () =>
                  setState(() => _showBookmarksPanel = !_showBookmarksPanel),
              onReadingSettings: _showReadingSettings,
              onToggleSearch: () =>
                  setState(() => _showSearch = !_showSearch),
              onToggleNightMode: () =>
                  ref.read(readerSettingsProvider.notifier)
                      .setNightMode(!settings.isNightMode),
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
                fontScale: settings.hudFontScale,
                isDarkTheme: effectiveTheme.isDark,
                etaText: _etaText,
                onPrev: _currentPage > 0
                    ? () => _pdfController
                        ?.setPage(_currentPage - pageStride)
                    : null,
                onNext: _currentPage + pageStride < _totalPages
                    ? () => _pdfController
                        ?.setPage(_currentPage + pageStride)
                    : null,
                onBack: _closeReader,
              ),
            ),
          ),

          // ── Progress ring — always visible, bottom-right ──────────────
          if (_totalPages > 0)
            Positioned(
              right: 12,
              bottom: _showControls ? 140 : 16,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: _ProgressRing(
                  progress: (_currentPage + 1) / _totalPages,
                  isDark: effectiveTheme.isDark,
                ),
              ),
            ),

          // ── Sleep timer badge — top-right below status bar ────────────
          if (_sleepTimerMinutes != null)
            Positioned(
              right: 12,
              top: MediaQuery.of(context).padding.top + 64,
              child: _SleepTimerBadge(
                remainingSeconds: _sleepRemainingSeconds.clamp(0, 99999),
              ),
            ),

          // ── Auto-scroll indicator — bottom-left ───────────────────────
          AnimatedOpacity(
            opacity: _autoScrollActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Positioned(
              left: 12,
              bottom: _showControls ? 140 : 16,
              child: _autoScrollActive
                  ? GestureDetector(
                      onTap: _stopAutoScroll,
                      child: _AutoScrollBadge(
                          wpm: settings.preferredAutoScrollWpm),
                    )
                  : const SizedBox.shrink(),
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

          // ── Confetti cannon — fires from top-center ──────────────────
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 24,
              gravity: 0.2,
              colors: const [
                Color(0xFF6B21A8),
                Color(0xFFA855F7),
                Color(0xFFF59E0B),
                Color(0xFF22C55E),
                Color(0xFFEF4444),
              ],
            ),
          ),

          // ── Session summary overlay ───────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _showSummary
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_summaryCompleter != null &&
                          !_summaryCompleter!.isCompleted) {
                        _summaryCompleter!.complete();
                      }
                    },
                    child: _SessionSummary(
                      elapsedSeconds: _elapsedSeconds,
                      currentPage: _currentPage,
                      totalPages: _totalPages,
                      bookTitle: _bookTitle,
                    ),
                  )
                : const SizedBox.shrink(),
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
                onExport: _exportBookmarks,
              ),
            ),
          ),
        ],
      ),
    ), // Scaffold
    ); // PopScope
  }

  // ── Export bookmarks ────────────────────────────────────────────────────

  Future<void> _exportBookmarks() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/bookmarks/export', data: {'bookId': widget.bookId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Highlights emailed to you! 📧'),
            backgroundColor: AppTheme.progressGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not send email. Try again later.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // ── Dictionary ─────────────────────────────────────────────────────────

  void _openDictionary() {
    HapticFeedback.mediumImpact();
    // Try to pre-populate from clipboard — common flow: select word in PDF,
    // copy, long-press to look it up. Clear after the sheet closes.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DictionarySheet(
        controller: _dictController,
        service: ref.read(dictionaryServiceProvider),
      ),
    ).whenComplete(() => _dictController.clear());
  }

  // ── Reading settings sheet ──────────────────────────────────────────────

  void _showReadingSettings() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReadingSettingsSheet(
        settingsNotifier: ref.read(readerSettingsProvider.notifier),
        initialSettings: ref.read(readerSettingsProvider),
        sleepTimerMinutes: _sleepTimerMinutes,
        onSleepTimer: (mins) {
          Navigator.pop(context);
          _setSleepTimer(mins);
        },
        autoScrollActive: _autoScrollActive,
        onAutoScrollToggle: (active) {
          Navigator.pop(context);
          if (active) {
            _startAutoScroll(ref.read(readerSettingsProvider).preferredAutoScrollWpm);
          } else {
            _stopAutoScroll();
          }
        },
        focusMode: _focusMode,
        onFocusModeToggle: (v) {
          setState(() => _focusMode = v);
        },
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
          // Capture messenger before the async gap to satisfy
          // use_build_context_synchronously — context may be stale after await.
          final messenger = ScaffoldMessenger.of(context);
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
            HapticFeedback.mediumImpact();
            ref.invalidate(bookBookmarksProvider(widget.bookId));
            if (sheetCtx.mounted) {
              Navigator.pop(sheetCtx);
              messenger.showSnackBar(
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
  final double fontScale;
  final bool isDarkTheme;
  final bool isNightMode;
  final VoidCallback onBack;
  final VoidCallback onBookmark;
  final VoidCallback onToggleBookmarks;
  final VoidCallback onReadingSettings;
  final VoidCallback onToggleSearch;
  final VoidCallback onToggleNightMode;

  const _TopBar({
    required this.bookTitle,
    required this.bookmarksActive,
    required this.elapsedFormatted,
    required this.fontScale,
    required this.isDarkTheme,
    required this.isNightMode,
    required this.onBack,
    required this.onBookmark,
    required this.onToggleBookmarks,
    required this.onReadingSettings,
    required this.onToggleSearch,
    required this.onToggleNightMode,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDarkTheme ? const Color(0xFF1E1E1E) : Colors.white;
    final fg = isDarkTheme ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final iconMuted = isDarkTheme ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
              color: isDarkTheme
                  ? Colors.black.withValues(alpha: 0.4)
                  : const Color(0x14000000),
              blurRadius: 8,
              offset: const Offset(0, 2))
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
                style: TextStyle(
                  fontSize: 15 * fontScale,
                  fontWeight: FontWeight.w700,
                  color: fg,
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
                  style: TextStyle(
                    fontSize: 12 * fontScale,
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
            // Go-to-page search
            IconButton(
              icon: const Icon(Icons.search_rounded, size: 22),
              color: iconMuted,
              tooltip: 'Go to page',
              onPressed: onToggleSearch,
            ),
            // Night mode quick toggle
            IconButton(
              icon: Icon(
                isNightMode
                    ? Icons.bedtime_rounded
                    : Icons.bedtime_outlined,
                size: 20,
              ),
              color: isNightMode ? const Color(0xFFF59E0B) : iconMuted,
              tooltip: isNightMode ? 'Night mode on' : 'Night mode',
              onPressed: onToggleNightMode,
            ),
            // Reading settings
            IconButton(
              icon: const Icon(Icons.tune_rounded, size: 22),
              color: iconMuted,
              tooltip: 'Reading Settings',
              onPressed: onReadingSettings,
            ),
            // Toggle bookmark list
            IconButton(
              icon: Icon(
                bookmarksActive
                    ? Icons.bookmarks_rounded
                    : Icons.bookmarks_outlined,
                size: 22,
              ),
              color: bookmarksActive ? AppTheme.primary : iconMuted,
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
  final double fontScale;
  final bool isDarkTheme;
  final String? etaText;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onBack;

  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.fontScale,
    required this.isDarkTheme,
    required this.onPrev,
    required this.onNext,
    required this.onBack,
    this.etaText,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDarkTheme ? const Color(0xFF1E1E1E) : Colors.white;
    final textMuted = isDarkTheme ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
              color: isDarkTheme
                  ? Colors.black.withValues(alpha: 0.5)
                  : const Color(0x14000000),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              _PageButton(icon: Icons.chevron_left_rounded, onTap: onPrev, isDark: isDarkTheme),
              Expanded(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      totalPages > 0
                          ? 'Page ${currentPage + 1} of $totalPages'
                          : 'Loading…',
                      style: TextStyle(
                        fontSize: 14 * fontScale,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                    if (etaText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        etaText!,
                        style: TextStyle(
                          fontSize: 10 * fontScale,
                          color: textMuted.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
              _PageButton(icon: Icons.chevron_right_rounded, onTap: onNext, isDark: isDarkTheme),
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
  final bool isDark;
  const _PageButton({required this.icon, required this.onTap, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null
              ? (isDark ? const Color(0xFF2D2D2D) : AppTheme.primarySurface)
              : (isDark ? const Color(0xFF252525) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 22,
          color: onTap != null
              ? AppTheme.primary
              : (isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB)),
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
  final VoidCallback onExport;

  const _BookmarksPanel({
    required this.bookId,
    required this.onClose,
    required this.onGoToPage,
    required this.onExport,
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
              // Export button
              IconButton(
                icon: const Icon(Icons.email_outlined, size: 20),
                color: AppTheme.primary,
                tooltip: 'Email highlights',
                onPressed: onExport,
              ),
              // Explicit close button
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

// ─────────────────────────────────────────────────────────────────────────────
// Reading Settings sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingSettingsSheet extends StatefulWidget {
  final ReaderSettingsNotifier settingsNotifier;
  final ReaderSettings initialSettings;
  final int? sleepTimerMinutes;
  final void Function(int?) onSleepTimer;
  final bool autoScrollActive;
  final void Function(bool) onAutoScrollToggle;
  final bool focusMode;
  final void Function(bool) onFocusModeToggle;

  const _ReadingSettingsSheet({
    required this.settingsNotifier,
    required this.initialSettings,
    required this.sleepTimerMinutes,
    required this.onSleepTimer,
    required this.autoScrollActive,
    required this.onAutoScrollToggle,
    required this.focusMode,
    required this.onFocusModeToggle,
  });

  @override
  State<_ReadingSettingsSheet> createState() => _ReadingSettingsSheetState();
}

class _ReadingSettingsSheetState extends State<_ReadingSettingsSheet> {
  late ReaderSettings _s;

  @override
  void initState() {
    super.initState();
    _s = widget.initialSettings;
  }

  void _setTheme(ReaderTheme t) {
    HapticFeedback.selectionClick();
    widget.settingsNotifier.setTheme(t);
    setState(() => _s = _s.copyWith(theme: t));
  }

  void _setBrightness(double v) {
    widget.settingsNotifier.setBrightness(v);
    setState(() => _s = _s.copyWith(brightness: v));
  }

  void _setFontScale(double v) {
    HapticFeedback.selectionClick();
    widget.settingsNotifier.setHudFontScale(v);
    setState(() => _s = _s.copyWith(hudFontScale: v));
  }

  void _setHorizontal(bool v) {
    HapticFeedback.selectionClick();
    widget.settingsNotifier.setHorizontalScroll(v);
    setState(() => _s = _s.copyWith(horizontalScroll: v));
  }

  void _setNightMode(bool v) {
    HapticFeedback.selectionClick();
    widget.settingsNotifier.setNightMode(v);
    setState(() => _s = _s.copyWith(isNightMode: v));
  }

  void _setWpm(double v) {
    final wpm = v.round();
    widget.settingsNotifier.setAutoScrollWpm(wpm);
    setState(() => _s = _s.copyWith(preferredAutoScrollWpm: wpm));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Color(0x1A6B21A8), blurRadius: 32, offset: Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune_rounded,
                color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Reading Settings',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937)),
          ),
        ]),

        const SizedBox(height: 20),

        // ── Night mode ────────────────────────────────────────────────────
        GestureDetector(
          onTap: () => _setNightMode(!_s.isNightMode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: _s.isNightMode
                  ? const LinearGradient(
                      colors: [Color(0xFF1A0A2E), Color(0xFF3B0764)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: _s.isNightMode ? null : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _s.isNightMode
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFFE5E7EB),
                width: _s.isNightMode ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              Text(
                '🌙',
                style: TextStyle(
                    fontSize: _s.isNightMode ? 24 : 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Night Mode',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _s.isNightMode
                              ? Colors.white
                              : const Color(0xFF1F2937),
                        ),
                      ),
                      Text(
                        'Twilight theme + 60 % brightness',
                        style: TextStyle(
                          fontSize: 11,
                          color: _s.isNightMode
                              ? Colors.white.withValues(alpha: 0.55)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ]),
              ),
              Switch.adaptive(
                value: _s.isNightMode,
                onChanged: _setNightMode,
                activeThumbColor: const Color(0xFF7C3AED),
                activeTrackColor: const Color(0xFF7C3AED),
              ),
            ]),
          ),
        ),

        const SizedBox(height: 12),

        // ── Portrait lock ─────────────────────────────────────────────────
        _DirectionTile(
          icon: Icons.screen_lock_portrait_rounded,
          label: 'Lock Portrait',
          subtitle: 'Prevent rotation while reading',
          selected: _s.lockPortrait,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.settingsNotifier.setLockPortrait(!_s.lockPortrait);
            setState(() => _s = _s.copyWith(lockPortrait: !_s.lockPortrait));
          },
        ),

        const SizedBox(height: 10),

        // ── Focus mode ────────────────────────────────────────────────────
        _DirectionTile(
          icon: Icons.center_focus_strong_rounded,
          label: 'Focus Mode',
          subtitle: 'Dims page outside reading band',
          selected: widget.focusMode,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onFocusModeToggle(!widget.focusMode);
          },
        ),

        const SizedBox(height: 20),

        // ── Sleep timer ───────────────────────────────────────────────────
        const _SectionLabel(label: 'Sleep Timer'),
        const SizedBox(height: 10),
        Row(children: [
          for (final (label, mins) in [
            ('Off', null),
            ('15 m', 15),
            ('30 m', 30),
            ('60 m', 60),
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSleepTimer(mins);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.sleepTimerMinutes == mins
                          ? AppTheme.primarySurface
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.sleepTimerMinutes == mins
                            ? AppTheme.primary
                            : const Color(0xFFE5E7EB),
                        width: widget.sleepTimerMinutes == mins ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: widget.sleepTimerMinutes == mins
                              ? AppTheme.primary
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),

        const SizedBox(height: 20),

        // ── Auto-scroll ───────────────────────────────────────────────────
        const _SectionLabel(label: 'Auto-Scroll'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto page-turn at ${_s.preferredAutoScrollWpm} WPM',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  Text(
                    '≈ ${(250.0 / _s.preferredAutoScrollWpm * 60).round()} sec/page',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ]),
          ),
          Switch.adaptive(
            value: widget.autoScrollActive,
            onChanged: widget.onAutoScrollToggle,
            activeThumbColor: AppTheme.primary,
            activeTrackColor: AppTheme.primary,
          ),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primary,
            inactiveTrackColor: const Color(0xFFE9D5FF),
            thumbColor: AppTheme.primary,
            overlayColor: const Color(0x1A6B21A8),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: _s.preferredAutoScrollWpm.toDouble(),
            min: 100,
            max: 500,
            divisions: 16,
            onChanged: _setWpm,
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('100 WPM\n(slow)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
            Text('250 WPM\n(average)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
            Text('500 WPM\n(speed)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
          ],
        ),

        const SizedBox(height: 24),

        // ── Themes ────────────────────────────────────────────────────────
        const _SectionLabel(label: 'Theme'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: ReaderTheme.values
              .map((t) => _ThemeTile(
                    theme: t,
                    selected: _s.theme == t,
                    onTap: () => _setTheme(t),
                  ))
              .toList(),
        ),

        const SizedBox(height: 24),

        // ── Brightness ────────────────────────────────────────────────────
        const _SectionLabel(label: 'Brightness'),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.brightness_3_rounded,
              size: 18, color: Color(0xFF9CA3AF)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primary,
                inactiveTrackColor: const Color(0xFFE9D5FF),
                thumbColor: AppTheme.primary,
                overlayColor: const Color(0x1A6B21A8),
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 9),
              ),
              child: Slider(
                value: _s.brightness,
                min: 0.1,
                max: 1.0,
                onChanged: _setBrightness,
              ),
            ),
          ),
          const Icon(Icons.brightness_high_rounded,
              size: 20, color: AppTheme.primary),
        ]),

        const SizedBox(height: 20),

        // ── HUD Text Size ────────────────────────────────────────────────
        const _SectionLabel(label: 'HUD Text Size'),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final (label, scale) in [
            ('Small', 0.85),
            ('Normal', 1.0),
            ('Large', 1.2),
          ])
            GestureDetector(
              onTap: () => _setFontScale(scale),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 90,
                height: 64,
                decoration: BoxDecoration(
                  color: _s.hudFontScale == scale
                      ? AppTheme.primarySurface
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _s.hudFontScale == scale
                        ? AppTheme.primary
                        : const Color(0xFFE5E7EB),
                    width: _s.hudFontScale == scale ? 2 : 1,
                  ),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Aa',
                          style: TextStyle(
                            fontSize: 17 * scale,
                            fontWeight: FontWeight.w700,
                            color: _s.hudFontScale == scale
                                ? AppTheme.primary
                                : const Color(0xFF6B7280),
                          )),
                      const SizedBox(height: 2),
                      Text(label,
                          style: TextStyle(
                            fontSize: 10,
                            color: _s.hudFontScale == scale
                                ? AppTheme.primary
                                : const Color(0xFF9CA3AF),
                          )),
                    ]),
              ),
            ),
        ]),

        const SizedBox(height: 20),

        // ── Scroll direction ──────────────────────────────────────────────
        const _SectionLabel(label: 'Page Direction'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _DirectionTile(
              icon: Icons.swap_horiz_rounded,
              label: 'Horizontal',
              subtitle: 'Book-style swipe',
              selected: _s.horizontalScroll,
              onTap: () => _setHorizontal(true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DirectionTile(
              icon: Icons.swap_vert_rounded,
              label: 'Vertical',
              subtitle: 'Scroll down',
              selected: !_s.horizontalScroll,
              onTap: () => _setHorizontal(false),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Supporting widgets for the settings sheet ──────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final ReaderTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: theme.previewBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? theme.accentColor : const Color(0xFFE5E7EB),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.accentColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(theme.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                theme.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.previewText,
                ),
              ),
            ]),
          ),
          if (selected)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 11, color: Colors.white),
              ),
            ),
        ]),
      ),
    );
  }
}

class _DirectionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DirectionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySurface : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              size: 22,
              color: selected ? AppTheme.primary : const Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppTheme.primary
                      : const Color(0xFF374151),
                )),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF9CA3AF))),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress ring — always-on circular arc showing % through the book
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  final double progress; // 0.0–1.0
  final bool isDark;
  const _ProgressRing({required this.progress, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).toInt();
    return SizedBox(
      width: 48,
      height: 48,
      child: CustomPaint(
        painter: _RingPainter(progress: progress.clamp(0.0, 1.0),
            isDark: isDark),
        child: Center(
          child: Text(
            '$pct%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  const _RingPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = (isDark ? Colors.white : AppTheme.primary)
            .withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect,
        -pi / 2,
        progress * 2 * pi,
        false,
        Paint()
          ..color = isDark ? Colors.white.withValues(alpha: 0.85) : AppTheme.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Sleep timer badge — countdown pill shown when timer is active
// ─────────────────────────────────────────────────────────────────────────────

class _SleepTimerBadge extends StatelessWidget {
  final int remainingSeconds;
  const _SleepTimerBadge({required this.remainingSeconds});

  @override
  Widget build(BuildContext context) {
    final mins = remainingSeconds ~/ 60;
    final secs = remainingSeconds % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.bedtime_rounded,
            size: 12, color: AppTheme.primary),
        const SizedBox(width: 5),
        Text(
          '$mins:${secs.toString().padLeft(2, '0')}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Auto-scroll indicator badge — tap to stop
// ─────────────────────────────────────────────────────────────────────────────

class _AutoScrollBadge extends StatelessWidget {
  final int wpm;
  const _AutoScrollBadge({required this.wpm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.slow_motion_video_rounded,
            size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(
          '$wpm WPM  ✕',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak nudge toast — animated card that slides in from top at 25 min
// ─────────────────────────────────────────────────────────────────────────────

class _StreakNudgeToast extends StatelessWidget {
  final bool visible;
  const _StreakNudgeToast({required this.visible});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1.5),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: visible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: SafeArea(
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B21A8), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B21A8).withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Row(children: [
                  Text('🔥', style: TextStyle(fontSize: 26)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "You've been reading 25 min!",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Streak is safe today 🎉',
                            style: TextStyle(
                              color: Color(0xFFE9D5FF),
                              fontSize: 12,
                            ),
                          ),
                        ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Go-to-page search bar — slides down from below the top bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final VoidCallback onGo;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.isDark,
    required this.onGo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final fg = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 72, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 4))
          ],
        ),
        child: Row(children: [
          const Icon(Icons.menu_book_rounded,
              size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => onGo(),
              autofocus: true,
              style: TextStyle(fontSize: 14, color: fg), // dynamic — can't be const
              decoration: const InputDecoration(
                hintText: 'Go to page…',
                hintStyle: TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          TextButton(
            onPressed: onGo,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              minimumSize: const Size(40, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Go',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close_rounded,
                size: 18, color: Color(0xFF9CA3AF)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session summary overlay — slides up from bottom when user exits reader
// ─────────────────────────────────────────────────────────────────────────────

class _SessionSummary extends StatefulWidget {
  final int elapsedSeconds;
  final int currentPage;
  final int totalPages;
  final String bookTitle;

  const _SessionSummary({
    required this.elapsedSeconds,
    required this.currentPage,
    required this.totalPages,
    required this.bookTitle,
  });

  @override
  State<_SessionSummary> createState() => _SessionSummaryState();
}

class _SessionSummaryState extends State<_SessionSummary>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = widget.elapsedSeconds ~/ 60;
    final secs = widget.elapsedSeconds % 60;
    final timeStr = mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
    final progress = widget.totalPages > 0
        ? ((widget.currentPage + 1) / widget.totalPages * 100).clamp(0.0, 100.0)
        : 0.0;
    final isComplete = progress >= 99.9;

    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: SlideTransition(
          position: _slide,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A0A2E), Color(0xFF3B0764)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF6B21A8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B21A8).withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Emoji header
                Text(
                  isComplete ? '🎉' : '📚',
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(height: 12),
                Text(
                  isComplete ? 'Book complete!' : 'Session complete!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.bookTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryChip(emoji: '⏱', label: 'Read', value: timeStr),
                    _SummaryChip(
                      emoji: '📖',
                      label: 'Progress',
                      value: '${progress.toInt()}%',
                    ),
                    _SummaryChip(
                      emoji: '📄',
                      label: 'Page',
                      value:
                          '${widget.currentPage + 1}/${widget.totalPages}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Tap anywhere to dismiss',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  const _SummaryChip(
      {required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Focus mode overlay — two dark rectangles above and below a reading band
// ─────────────────────────────────────────────────────────────────────────────

class _FocusModeOverlay extends StatelessWidget {
  final double screenHeight;
  const _FocusModeOverlay({required this.screenHeight});

  @override
  Widget build(BuildContext context) {
    // Band sits at ~42 % from top — slightly above centre (natural eye rest point).
    const bandHeight = 100.0;
    final bandTop = screenHeight * 0.42;

    return IgnorePointer(
      child: Stack(children: [
        // Top dimmer
        Positioned(
          top: 0, left: 0, right: 0,
          height: bandTop,
          child: Container(
              color: Colors.black.withValues(alpha: 0.55)),
        ),
        // Bottom dimmer
        Positioned(
          top: bandTop + bandHeight, left: 0, right: 0, bottom: 0,
          child: Container(
              color: Colors.black.withValues(alpha: 0.55)),
        ),
        // Subtle top edge of the band
        Positioned(
          top: bandTop, left: 0, right: 0,
          child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.18)),
        ),
        // Subtle bottom edge of the band
        Positioned(
          top: bandTop + bandHeight - 1, left: 0, right: 0,
          child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.18)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Buddy reading chips — shows the closest friend's progress on the same book
// ─────────────────────────────────────────────────────────────────────────────

class _BuddyChips extends ConsumerWidget {
  final String bookId;
  final int currentPage;
  final int totalPages;

  const _BuddyChips({
    required this.bookId,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    if (!isOnline) return const SizedBox.shrink();

    final buddiesAsync = ref.watch(buddyProgressProvider(bookId));

    return buddiesAsync.maybeWhen(
      data: (friends) {
        if (friends.isEmpty) return const SizedBox.shrink();

        // Sort by proximity to the current page; show only the closest friend
        final sorted = [...friends]..sort((a, b) {
            final aPage = (a['currentPage'] as num?)?.toInt() ?? 0;
            final bPage = (b['currentPage'] as num?)?.toInt() ?? 0;
            return (aPage - currentPage).abs().compareTo((bPage - currentPage).abs());
          });

        final f = sorted.first;
        final friendPage = (f['currentPage'] as num?)?.toInt() ?? 0;
        final userName = f['userName'] as String? ?? 'Friend';
        final isAhead = currentPage > friendPage;
        final diff = (currentPage - friendPage).abs();

        return Positioned(
          // Sit just below the top bar when controls are visible
          top: MediaQuery.of(context).padding.top + 64,
          left: 12,
          child: _BuddyChip(
            userName: userName,
            friendPage: friendPage,
            totalPages: totalPages,
            isAhead: isAhead,
            pageDiff: diff,
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _BuddyChip extends StatelessWidget {
  final String userName;
  final int friendPage;
  final int totalPages;
  final bool isAhead;
  final int pageDiff;

  const _BuddyChip({
    required this.userName,
    required this.friendPage,
    required this.totalPages,
    required this.isAhead,
    required this.pageDiff,
  });

  @override
  Widget build(BuildContext context) {
    final label = isAhead
        ? '$userName is $pageDiff pages behind'
        : pageDiff == 0
            ? 'Reading alongside $userName!'
            : '$userName is $pageDiff pages ahead';

    final trail = isAhead ? ' 🎉' : pageDiff == 0 ? ' 📖' : ' 💪';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B21A8).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.people_rounded, size: 12, color: Color(0xFFA855F7)),
        const SizedBox(width: 5),
        Text(
          '$label$trail',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dictionary sheet — long-press the page to look up any word via Wiktionary
// ─────────────────────────────────────────────────────────────────────────────

/// The PDF renderer does not expose text layer events to Flutter gestures,
/// so we can't intercept "which word was tapped" automatically.
/// Instead, long-press opens this sheet with a search field so the user can
/// type (or paste from clipboard after selecting text in native PDF selection
/// mode) the word they want to look up.
class _DictionarySheet extends StatefulWidget {
  final TextEditingController controller;
  final DictionaryService service;

  const _DictionarySheet({
    required this.controller,
    required this.service,
  });

  @override
  State<_DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends State<_DictionarySheet> {
  List<WordEntry>? _entries;
  bool _loading = false;
  String? _errorMsg;
  String _lookedUpWord = '';

  Future<void> _lookup() async {
    final word = widget.controller.text.trim();
    if (word.isEmpty) return;

    setState(() {
      _loading  = true;
      _errorMsg = null;
      _entries  = null;
    });

    try {
      final results = await widget.service.lookup(word);
      if (mounted) {
        setState(() {
          _lookedUpWord = word;
          _entries  = results;
          _loading  = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _loading  = false;
          _errorMsg = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A6B21A8),
                blurRadius: 32,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(children: [
            // ── Handle ────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_stories_rounded,
                      color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Dictionary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // ── Search field ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _lookup(),
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter a word…',
                      hintStyle: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 15),
                      prefixIcon: const Icon(
                          Icons.search_rounded, color: AppTheme.primary),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppTheme.primary, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _lookup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: const Text(
                      'Look up',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            // ── Results ───────────────────────────────────────────────
            Expanded(
              child: _buildResults(scrollCtrl),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildResults(ScrollController ctrl) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppTheme.primary),
      );
    }

    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded,
                size: 40, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            const Text(
              'Could not reach dictionary',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMsg!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ]),
        ),
      );
    }

    if (_entries == null) {
      // Initial state — nothing searched yet
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Type a word above to look it up.\n\n'
            'Tip: select text in the PDF, copy it,\n'
            'then paste it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
              height: 1.6,
            ),
          ),
        ),
      );
    }

    if (_entries!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('📖', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              '"$_lookedUpWord" not found',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a different spelling or a base form.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ]),
        ),
      );
    }

    return ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // Word heading
        Text(
          _lookedUpWord,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),

        // Entries grouped by part of speech
        for (final entry in _entries!) ...[
          // POS chip
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.partOfSpeech,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Senses
          for (int i = 0; i < entry.senses.length; i++) ...[
            _SenseRow(
              number: i + 1,
              sense: entry.senses[i],
            ),
            if (i < entry.senses.length - 1)
              const Divider(
                  height: 16, indent: 28, color: Color(0xFFF3F4F6)),
          ],

          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _SenseRow extends StatelessWidget {
  final int number;
  final WordSense sense;

  const _SenseRow({required this.number, required this.sense});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Number badge
      Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.only(top: 1, right: 10),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$number',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppTheme.primary,
            ),
          ),
        ),
      ),

      // Definition + examples
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(
            sense.definition,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1F2937),
              height: 1.5,
            ),
          ),
          for (final ex in sense.examples) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"$ex"',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF92400E),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }
}
