import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../library/presentation/providers/library_provider.dart';

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
  bool _showToolbar = true;
  String? _localPdfPath;
  String? _error;
  bool _downloading = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  @override
  void dispose() {
    _endSession();
    super.dispose();
  }

  Future<void> _loadBook() async {
    setState(() => _downloading = true);
    try {
      final bookDetail = await ref.read(bookDetailProvider(widget.bookId).future);
      final filePath = bookDetail['filePath'] as String?;
      if (filePath == null) {
        setState(() { _error = 'This book has no PDF file yet.'; _downloading = false; });
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

      setState(() { _localPdfPath = localFile.path; _downloading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load book: $e'; _downloading = false; });
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
      await dio.put('/api/reading-sessions/$_sessionId/end', data: {
        'endPage': _currentPage,
      });
      ref.invalidate(userLibraryProvider);
      ref.invalidate(bookDetailProvider(widget.bookId));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_downloading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Downloading book...'),
          ]),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reader')),
        body: Center(child: Text(_error!)),
      );
    }

    if (_localPdfPath == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: _showToolbar
          ? AppBar(
              title: Text('Page ${_currentPage + 1} / $_totalPages'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  tooltip: 'Add Bookmark',
                  onPressed: _addBookmark,
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showToolbar = !_showToolbar),
        child: PDFView(
          filePath: _localPdfPath!,
          enableSwipe: true,
          swipeHorizontal: true,
          autoSpacing: false,
          pageFling: true,
          defaultPage: _currentPage,
          onRender: (pages) => setState(() => _totalPages = pages ?? 0),
          onViewCreated: (ctrl) => _pdfController = ctrl,
          onPageChanged: (page, _) => setState(() => _currentPage = page ?? 0),
          onError: (e) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('PDF error: $e'))),
        ),
      ),
      bottomNavigationBar: _showToolbar
          ? BottomAppBar(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0
                        ? () => _pdfController?.setPage(_currentPage - 1)
                        : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: _totalPages > 0 ? _currentPage / (_totalPages - 1) : 0,
                      onChanged: (v) => _pdfController?.setPage((v * (_totalPages - 1)).round()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < _totalPages - 1
                        ? () => _pdfController?.setPage(_currentPage + 1)
                        : null,
                  ),
                ],
              ),
            )
          : null,
    );
  }

  void _addBookmark() {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Bookmark'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Page: ${_currentPage + 1}'),
          const SizedBox(height: 12),
          TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final dio = ref.read(dioProvider);
                await dio.post('/api/bookmarks', data: {
                  'bookId': widget.bookId,
                  'pageNumber': _currentPage + 1,
                  'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                });
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bookmark saved.')),
                  );
                }
              } catch (e) {
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
