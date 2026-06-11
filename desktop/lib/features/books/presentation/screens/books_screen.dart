import 'dart:math' show pi;
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../providers/books_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Library (Books) screen — grid view matching the admin dashboard spec.
// ─────────────────────────────────────────────────────────────────────────────

class BooksScreen extends ConsumerStatefulWidget {
  const BooksScreen({super.key});

  @override
  ConsumerState<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends ConsumerState<BooksScreen> {
  String _searchTerm = '';
  String? _selectedGenreId;
  DateTime? _publishedFrom;
  DateTime? _publishedTo;

  ({String searchTerm, String? genreId, DateTime? publishedFrom, DateTime? publishedTo})
      get _params => (
            searchTerm: _searchTerm,
            genreId: _selectedGenreId,
            publishedFrom: _publishedFrom,
            publishedTo: _publishedTo,
          );

  void _refresh() => ref.invalidate(adminBooksProvider(_params));

  void _showUploadDialog(BuildContext context, Map? book) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _BookUploadDialog(
        book: book,
        onSaved: _refresh,
        onClose: () => Navigator.pop(dialogCtx),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String bookId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await deleteBook(bookId);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(adminBooksProvider(_params));
    final genresAsync = ref.watch(adminGenresProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page title ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            child: Row(children: [
              const Text('📚', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Text(
                'Library',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF5B6AD0),
                    ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Filter row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Search
                _FilterColumn(
                  label: 'Search books',
                  child: SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: Colors.grey.shade500,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) => setState(() => _searchTerm = v),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Genre
                _FilterColumn(
                  label: 'Genre',
                  child: genresAsync.when(
                    loading: () => const SizedBox(
                        width: 120, child: LinearProgressIndicator()),
                    error: (_, __) => const SizedBox(width: 120),
                    data: (genres) => _GenreDropdown(
                      genres: genres,
                      value: _selectedGenreId,
                      onChanged: (v) => setState(() => _selectedGenreId = v),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // From date
                _FilterColumn(
                  label: 'From Date:',
                  child: _DateButton(
                    value: _publishedFrom,
                    onPicked: (d) => setState(() => _publishedFrom = d),
                    onCleared: () => setState(() => _publishedFrom = null),
                  ),
                ),
                const SizedBox(width: 16),

                // To date
                _FilterColumn(
                  label: 'To Date:',
                  child: _DateButton(
                    value: _publishedTo,
                    onPicked: (d) => setState(() => _publishedTo = d),
                    onCleared: () => setState(() => _publishedTo = null),
                  ),
                ),

                const Spacer(),

                // Upload Book button — aligned to bottom of filter row
                FilledButton.icon(
                  icon: const Icon(Icons.upload_sharp, size: 18),
                  label: const Text('Upload Book'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF5B6AD0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showUploadDialog(context, null),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Book grid ─────────────────────────────────────────────────
          Expanded(
            child: booksAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                final books = data['items'] as List? ?? [];
                if (books.isEmpty) {
                  return const Center(
                      child: Text('No books found.',
                          style: TextStyle(color: Colors.grey)));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(28),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 0.62,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: books.length,
                  itemBuilder: (ctx, i) {
                    final book = books[i] as Map;
                    return _BookCard(
                      book: book,
                      onEdit: () => _showUploadDialog(context, book),
                      onDelete: () => _confirmDelete(
                          context, book['id'] as String),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper: label + child stacked vertically
// ─────────────────────────────────────────────────────────────────────────────

class _FilterColumn extends StatelessWidget {
  final String label;
  final Widget child;
  const _FilterColumn({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                )),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Genre dropdown — styled with primary colour background
// ─────────────────────────────────────────────────────────────────────────────

class _GenreDropdown extends StatelessWidget {
  final List genres;
  final String? value;
  final ValueChanged<String?> onChanged;
  const _GenreDropdown(
      {required this.genres, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF5B6AD0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Colors.white, size: 20),
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          dropdownColor: const Color(0xFF5B6AD0),
          isDense: true,
          onChanged: onChanged,
          items: [
            const DropdownMenuItem(
                value: null,
                child: Text('All genres',
                    style: TextStyle(color: Colors.white))),
            ...genres.map((g) {
              final gMap = g as Map;
              return DropdownMenuItem<String>(
                value: gMap['id'] as String,
                child: Text(gMap['name'] as String,
                    style: const TextStyle(color: Colors.white)),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Styled date button — opens DatePicker on tap
// ─────────────────────────────────────────────────────────────────────────────

class _DateButton extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback onCleared;
  const _DateButton(
      {required this.value,
      required this.onPicked,
      required this.onCleared});

  String _fmt(DateTime d) =>
      '${d.month}/${d.day}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(2000),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value != null ? _fmt(value!) : 'Select...',
              style: TextStyle(
                  fontSize: 14,
                  color: value != null
                      ? Colors.black87
                      : Colors.grey.shade500),
            ),
            const SizedBox(width: 8),
            if (value != null)
              GestureDetector(
                onTap: onCleared,
                child:
                    Icon(Icons.close, size: 14, color: Colors.grey.shade600),
              )
            else
              Icon(Icons.calendar_today,
                  size: 16, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Book card — lavender background, cover image, hover actions
// ─────────────────────────────────────────────────────────────────────────────

class _BookCard extends StatefulWidget {
  final Map book;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _BookCard(
      {required this.book, required this.onEdit, required this.onDelete});

  @override
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final title = book['title'] as String? ?? '';
    final author = book['author'] as String? ?? '';
    final published = book['publishedDate'] as String? ?? '';
    final year =
        published.length >= 4 ? published.substring(0, 4) : published;
    final rawCover = book['coverImageUrl'] as String?;
    final coverUrl = rawCover == null
        ? null
        : rawCover.startsWith('http')
            ? rawCover
            : '${AppConfig.apiBaseUrl}$rawCover';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Card(
        margin: EdgeInsets.zero,
        color: const Color(0xFFEBE8F8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.hardEdge,
        elevation: _hovered ? 4 : 1,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover image
                Expanded(
                  flex: 3,
                  child: coverUrl != null
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.book,
                                size: 48, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.book,
                              size: 48, color: Colors.grey),
                        ),
                ),
                // Text info
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoLine('Title: ', title),
                      _infoLine('Release Date: ', year),
                      _infoLine('Author: ', author),
                    ],
                  ),
                ),
              ],
            ),
            // Hover action overlay
            if (_hovered)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionIcon(
                        icon: Icons.edit,
                        tooltip: 'Edit',
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 12),
                      _ActionIcon(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete',
                        color: Colors.red.shade300,
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style:
                const TextStyle(fontSize: 11, color: Colors.black87),
            children: [
              TextSpan(
                  text: label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback onPressed;
  const _ActionIcon(
      {required this.icon,
      required this.tooltip,
      required this.onPressed,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color ?? Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload / Edit book dialog — 3-panel layout matching the spec
// ─────────────────────────────────────────────────────────────────────────────

class _BookUploadDialog extends ConsumerStatefulWidget {
  final Map? book;
  final VoidCallback onSaved;
  final VoidCallback onClose;
  const _BookUploadDialog(
      {required this.book, required this.onSaved, required this.onClose});

  @override
  ConsumerState<_BookUploadDialog> createState() =>
      _BookUploadDialogState();
}

class _BookUploadDialogState extends ConsumerState<_BookUploadDialog> {
  final _formKey  = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  String? _selectedGenreId;
  DateTime? _releaseDate;
  PlatformFile? _pdfFile;
  PlatformFile? _coverFile;
  bool _loading = false;

  bool get _isEditing => widget.book != null;

  String? get _existingCoverUrl {
    if (!_isEditing) return null;
    final raw = widget.book!['coverImageUrl'] as String?;
    if (raw == null || raw.isEmpty) return null;
    return raw.startsWith('http') ? raw : '${AppConfig.apiBaseUrl}$raw';
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleCtrl.text = widget.book!['title'] as String? ?? '';
      _authorCtrl.text = widget.book!['author'] as String? ?? '';
      // Pre-select genre if exactly one
      final genres = widget.book!['genres'] as List? ?? [];
      if (genres.isNotEmpty) _selectedGenreId = null; // resolved below
      // Parse published date if present
      final pub = widget.book!['publishedDate'] as String?;
      if (pub != null && pub.isNotEmpty) {
        _releaseDate = DateTime.tryParse(pub);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final file = await pickPdfFile();
    if (file != null) setState(() => _pdfFile = file);
  }

  Future<void> _pickImage() async {
    final file = await pickImageFile();
    if (file != null) setState(() => _coverFile = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final genreIds =
          _selectedGenreId != null ? [_selectedGenreId!] : <String>[];

      if (_isEditing) {
        final id = widget.book!['id'] as String;
        await updateBook(
          id: id,
          title: _titleCtrl.text.trim(),
          author: _authorCtrl.text.trim(),
          description: null,
          isbn: null,
          isPublic: true,
          genreIds: genreIds,
          publishedDate: _releaseDate,
        );
        if (_pdfFile != null) await uploadPlatformPdf(id, _pdfFile!);
        if (_coverFile != null) await uploadPlatformCover(id, _coverFile!);
      } else {
        final id = await createBook(
          title: _titleCtrl.text.trim(),
          author: _authorCtrl.text.trim(),
          description: null,
          isbn: null,
          isPublic: true,
          genreIds: genreIds,
          publishedDate: _releaseDate,
        );
        if (id.isNotEmpty) {
          if (_pdfFile != null) await uploadPlatformPdf(id, _pdfFile!);
          if (_coverFile != null) await uploadPlatformCover(id, _coverFile!);
        }
      }
      widget.onSaved();
      widget.onClose();
    } catch (e) {
      if (mounted) {
        // Extract the actual backend error message when Dio returns a 4xx/5xx,
        // otherwise fall back to the raw exception string.
        String message;
        if (e is DioException && e.response?.data is Map) {
          final data = e.response!.data as Map;
          final errors = data['errors'];
          if (errors is List && errors.isNotEmpty) {
            message = errors.join('\n');
          } else {
            message = data['title']?.toString() ?? e.toString();
          }
        } else {
          message = e.toString();
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $message')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final genresAsync = ref.watch(adminGenresProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 900,
        height: 540,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left: form ─────────────────────────────────────
                  SizedBox(
                    width: 300,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 32, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Row(children: [
                            const Text('📚',
                                style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Text(
                              _isEditing ? 'Edit Book' : 'Upload Book',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 20),

                          // Book Title
                          _FieldLabel('Book Title'),
                          const SizedBox(height: 4),
                          _ValidatedField(
                            controller: _titleCtrl,
                            hint: 'Title here...',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Title is required' : null,
                          ),
                          const SizedBox(height: 14),

                          // Author
                          _FieldLabel('Author Name'),
                          const SizedBox(height: 4),
                          _ValidatedField(
                            controller: _authorCtrl,
                            hint: 'Author name here...',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Author is required' : null,
                          ),
                          const SizedBox(height: 14),

                          // Genre
                          _FieldLabel('Genre'),
                          const SizedBox(height: 4),
                          genresAsync.when(
                            loading: () =>
                                const LinearProgressIndicator(),
                            error: (_, __) =>
                                const Text('Could not load genres'),
                            data: (genres) => Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _selectedGenreId,
                                  isExpanded: true,
                                  isDense: true,
                                  style: const TextStyle(
                                    color: Color(0xFF5B6AD0),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Color(0xFF5B6AD0)),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null,
                                        child: Text('Select genre...',
                                            style: TextStyle(
                                                color: Colors.grey))),
                                    ...genres.map((g) {
                                      final gMap = g as Map;
                                      return DropdownMenuItem<String>(
                                        value: gMap['id'] as String,
                                        child: Text(
                                            gMap['name'] as String),
                                      );
                                    }),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _selectedGenreId = v),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Release Date
                          _FieldLabel('Release Date'),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    _releaseDate ?? DateTime(2000),
                                firstDate: DateTime(1800),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => _releaseDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                    _releaseDate != null
                                        ? '${_releaseDate!.month}/${_releaseDate!.day}/${_releaseDate!.year}'
                                        : 'Select date...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _releaseDate != null
                                          ? Colors.black87
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                                Icon(Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey.shade500),
                              ]),
                            ),
                          ),

                          const Spacer(),

                          // Buttons
                          Row(children: [
                            Expanded(
                              child: FilledButton.icon(
                                icon: _loading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.upload_sharp,
                                        size: 16),
                                label: Text(
                                    _loading ? 'Saving...' : 'Submit'),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF4A5DC8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                                onPressed: _loading ? null : _submit,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor:
                                      const Color(0xFFE53935),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                                onPressed:
                                    _loading ? null : widget.onClose,
                                child: const Text('Cancel'),
                              ),
                            ),
                          ]),
                        ],
                        ),
                      ),
                    ),
                  ),

                  const VerticalDivider(width: 1, thickness: 1),

                  // ── Middle: PDF upload ──────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PDF Upload',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Drop zone
                          GestureDetector(
                            onTap: _pickPdf,
                            child: Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDAE8F5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF9BB5D0)),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.download_outlined,
                                      size: 36,
                                      color: const Color(0xFF7BA8C8)),
                                  const SizedBox(height: 10),
                                  RichText(
                                    text: const TextSpan(
                                      style: TextStyle(fontSize: 13),
                                      children: [
                                        TextSpan(
                                          text: 'Choose a file ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF4A5DC8),
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'or drag it here.',
                                          style: TextStyle(
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Selected PDF chip
                          if (_pdfFile != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F8E9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.shade200),
                              ),
                              child: Row(children: [
                                Icon(Icons.picture_as_pdf,
                                    color: Colors.red.shade400, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _pdfFile!.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: 1.0,
                                        color: Colors.green.shade500,
                                        backgroundColor:
                                            Colors.green.shade100,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      setState(() => _pdfFile = null),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const VerticalDivider(width: 1, thickness: 1),

                  // ── Right: image upload ─────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Image Upload',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Dashed image drop zone
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: CustomPaint(
                                painter: _DashedBorderPainter(),
                                child: Container(
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  child: _coverFile != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: Image.memory(
                                            _coverFile!.bytes!,
                                            fit: BoxFit.contain,
                                          ),
                                        )
                                      : _existingCoverUrl != null
                                          ? Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Image.network(
                                                    _existingCoverUrl!,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) =>
                                                        const Icon(Icons.image_not_supported,
                                                            size: 48, color: Colors.grey),
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: 8,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black54,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'Tap to replace',
                                                      style: TextStyle(
                                                          color: Colors.white, fontSize: 11),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Insert Image Here',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Tap to choose',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade400),
                                                ),
                                              ],
                                            ),
                                ),
                              ),
                            ),
                          ),
                          if (_coverFile != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_coverFile!.name,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () =>
                                      setState(() => _coverFile = null),
                                  child: Icon(Icons.close,
                                      size: 14,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Close (×) button ──────────────────────────────────────
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onClose,
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small form helpers
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      );
}

class _ValidatedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  const _ValidatedField(
      {required this.controller, required this.hint, this.validator});

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        validator: validator,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashed-border painter for the image drop zone
// ─────────────────────────────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dash = 6.0;
    const gap = 4.0;
    const r = 8.0;

    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      var d = 0.0;
      while (d < total) {
        final end = (d + dash).clamp(0.0, total);
        canvas.drawLine(a + dir * d, a + dir * end, paint);
        d += dash + gap;
      }
    }

    line(Offset(r, 0), Offset(size.width - r, 0));
    line(Offset(size.width, r), Offset(size.width, size.height - r));
    line(Offset(size.width - r, size.height), Offset(r, size.height));
    line(Offset(0, size.height - r), Offset(0, r));

    final arc = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
        Rect.fromLTWH(0, 0, r * 2, r * 2), pi, pi / 2, false, arc);
    canvas.drawArc(
        Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2),
        -pi / 2,
        pi / 2,
        false,
        arc);
    canvas.drawArc(
        Rect.fromLTWH(
            size.width - r * 2, size.height - r * 2, r * 2, r * 2),
        0,
        pi / 2,
        false,
        arc);
    canvas.drawArc(
        Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2),
        pi / 2,
        pi / 2,
        false,
        arc);
  }

  @override
  bool shouldRepaint(_) => false;
}
