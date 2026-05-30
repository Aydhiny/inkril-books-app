import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/books_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(adminBooksProvider(_params));
    final genresAsync = ref.watch(adminGenresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Books'),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Book'),
            onPressed: () => _showBookDialog(context, ref, null),
          ),
          const SizedBox(width: 16),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                // Row 1: text search
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by title, author...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchTerm = v),
                ),
                const SizedBox(height: 8),
                // Row 2: genre + date filters
                Row(children: [
                  // Genre filter
                  genresAsync.when(
                    loading: () => const SizedBox(width: 140, child: LinearProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (genres) => SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String?>(
                        value: _selectedGenreId,
                        decoration: const InputDecoration(
                          labelText: 'Genre',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All genres')),
                          ...genres.map((g) {
                            final gMap = g as Map;
                            return DropdownMenuItem(
                              value: gMap['id'] as String,
                              child: Text(gMap['name'] as String),
                            );
                          }),
                        ],
                        onChanged: (v) => setState(() => _selectedGenreId = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Published from
                  _DateFilterChip(
                    label: _publishedFrom == null
                        ? 'From date'
                        : 'From: ${_publishedFrom!.year}-${_publishedFrom!.month.toString().padLeft(2, '0')}-${_publishedFrom!.day.toString().padLeft(2, '0')}',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _publishedFrom ?? DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _publishedFrom = picked);
                    },
                    onClear: _publishedFrom == null
                        ? null
                        : () => setState(() => _publishedFrom = null),
                  ),
                  const SizedBox(width: 8),
                  // Published to
                  _DateFilterChip(
                    label: _publishedTo == null
                        ? 'To date'
                        : 'To: ${_publishedTo!.year}-${_publishedTo!.month.toString().padLeft(2, '0')}-${_publishedTo!.day.toString().padLeft(2, '0')}',
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _publishedTo ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _publishedTo = picked);
                    },
                    onClear: _publishedTo == null
                        ? null
                        : () => setState(() => _publishedTo = null),
                  ),
                  const Spacer(),
                  // Clear all filters
                  if (_selectedGenreId != null ||
                      _publishedFrom != null ||
                      _publishedTo != null)
                    TextButton.icon(
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear filters'),
                      onPressed: () => setState(() {
                        _selectedGenreId = null;
                        _publishedFrom = null;
                        _publishedTo = null;
                      }),
                    ),
                ]),
              ],
            ),
          ),
        ),
      ),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final books = data['items'] as List? ?? [];
          if (books.isEmpty) {
            return const Center(child: Text('No books found.'));
          }
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Cover')),
                  DataColumn(label: Text('Title')),
                  DataColumn(label: Text('Author')),
                  DataColumn(label: Text('Genre')),
                  DataColumn(label: Text('Published')),
                  DataColumn(label: Text('Rating')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: books.map((b) {
                  final book = b as Map;
                  final published = book['publishedDate'] as String? ?? '';
                  final publishedShort = published.length >= 10
                      ? published.substring(0, 10)
                      : published;
                  return DataRow(cells: [
                    DataCell(book['coverImageUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              book['coverImageUrl'] as String,
                              width: 40,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const SizedBox(
                            width: 40,
                            height: 50,
                            child: Icon(Icons.book, size: 32),
                          )),
                    DataCell(SizedBox(
                      width: 200,
                      child: Text(book['title'] as String,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Text(book['author'] as String? ?? '')),
                    DataCell(Text(
                        (book['genres'] as List? ?? []).join(', '))),
                    DataCell(Text(publishedShort)),
                    DataCell(Row(children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      Text(
                          ' ${(book['averageRating'] as num?)?.toStringAsFixed(1) ?? '0'}'),
                    ])),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.upload_file_outlined),
                        tooltip: 'Upload PDF',
                        onPressed: () =>
                            _uploadPdf(context, ref, book['id'] as String),
                      ),
                      IconButton(
                        icon: const Icon(Icons.image_outlined),
                        tooltip: 'Upload Cover',
                        onPressed: () =>
                            _uploadCover(context, ref, book['id'] as String),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit',
                        onPressed: () =>
                            _showBookDialog(context, ref, book),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () =>
                            _confirmDelete(context, ref, book['id'] as String),
                      ),
                    ])),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBookDialog(BuildContext context, WidgetRef ref, Map? book) {
    showDialog(
      context: context,
      builder: (_) => _BookFormDialog(
        book: book,
        onSaved: () => ref.invalidate(adminBooksProvider(_params)),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String bookId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await deleteBook(bookId);
      ref.invalidate(adminBooksProvider(_params));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _uploadPdf(
      BuildContext context, WidgetRef ref, String bookId) async {
    try {
      await uploadBookPdf(bookId);
      ref.invalidate(adminBooksProvider(_params));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('PDF uploaded.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _uploadCover(
      BuildContext context, WidgetRef ref, String bookId) async {
    try {
      await uploadBookCover(bookId);
      ref.invalidate(adminBooksProvider(_params));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cover uploaded.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

/// Small chip-style button for date range selection.
class _DateFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  const _DateFilterChip(
      {required this.label, required this.onTap, this.onClear});

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      avatar: const Icon(Icons.calendar_today, size: 14),
      deleteIcon: onClear != null
          ? const Icon(Icons.close, size: 14)
          : null,
      onDeleted: onClear,
      onPressed: onTap,
    );
  }
}

class _BookFormDialog extends ConsumerStatefulWidget {
  final Map? book;
  final VoidCallback onSaved;
  const _BookFormDialog({required this.book, required this.onSaved});

  @override
  ConsumerState<_BookFormDialog> createState() => _BookFormDialogState();
}

class _BookFormDialogState extends ConsumerState<_BookFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _isbnCtrl = TextEditingController();
  bool _isPublic = true;
  bool _loading = false;
  bool _isbnLooking = false;
  String? _isbnError;
  List<String> _selectedGenreIds = [];

  bool get _isEditing => widget.book != null;

  /// Calls the free Open Library Books API to auto-fill title, author, and
  /// description from a 10- or 13-digit ISBN.
  ///
  /// Endpoint: https://openlibrary.org/api/books?bibkeys=ISBN:{isbn}&format=json&jscmd=data
  /// No API key, no rate limits at human speed.
  Future<void> _lookupIsbn(String isbn) async {
    final cleaned = isbn.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.length != 10 && cleaned.length != 13) return;
    // Don't overwrite fields that the user already filled in edit mode
    if (_isEditing && _titleCtrl.text.isNotEmpty) return;

    setState(() {
      _isbnLooking = true;
      _isbnError = null;
    });

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 8),
        validateStatus: (s) => s != null && s < 500,
      ));
      final response = await dio.get(
        'https://openlibrary.org/api/books',
        queryParameters: {
          'bibkeys': 'ISBN:$cleaned',
          'format': 'json',
          'jscmd': 'data',
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final book = data?['ISBN:$cleaned'] as Map<String, dynamic>?;

      if (book == null) {
        setState(() => _isbnError = 'No book found for this ISBN.');
        return;
      }

      final title = book['title'] as String? ?? '';
      final authors = (book['authors'] as List?)
              ?.map((a) => (a as Map)['name'] as String? ?? '')
              .where((s) => s.isNotEmpty)
              .join(', ') ??
          '';
      final desc = (book['excerpts'] as List?)
              ?.map((e) => (e as Map)['text'] as String? ?? '')
              .where((s) => s.isNotEmpty)
              .firstOrNull ??
          '';

      setState(() {
        if (title.isNotEmpty && _titleCtrl.text.isEmpty) {
          _titleCtrl.text = title;
        }
        if (authors.isNotEmpty && _authorCtrl.text.isEmpty) {
          _authorCtrl.text = authors;
        }
        if (desc.isNotEmpty && _descCtrl.text.isEmpty) {
          _descCtrl.text = desc;
        }
      });
    } catch (_) {
      setState(() => _isbnError = 'Could not reach Open Library. Check connection.');
    } finally {
      if (mounted) setState(() => _isbnLooking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleCtrl.text = widget.book!['title'] as String? ?? '';
      _authorCtrl.text = widget.book!['author'] as String? ?? '';
      _descCtrl.text = widget.book!['description'] as String? ?? '';
      _isbnCtrl.text = widget.book!['isbn'] as String? ?? '';
      _isPublic = widget.book!['isPublic'] as bool? ?? true;
    }
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _authorCtrl, _descCtrl, _isbnCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_isEditing) {
        await updateBook(
          id: widget.book!['id'] as String,
          title: _titleCtrl.text.trim(),
          author: _authorCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          isbn: _isbnCtrl.text.trim().isEmpty ? null : _isbnCtrl.text.trim(),
          isPublic: _isPublic,
          genreIds: _selectedGenreIds,
        );
      } else {
        await createBook(
          title: _titleCtrl.text.trim(),
          author: _authorCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          isbn: _isbnCtrl.text.trim().isEmpty ? null : _isbnCtrl.text.trim(),
          isPublic: _isPublic,
          genreIds: _selectedGenreIds,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final genresAsync = ref.watch(adminGenresProvider);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Book' : 'Add New Book'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _authorCtrl,
                decoration: const InputDecoration(labelText: 'Author *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Author is required.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _isbnCtrl,
                decoration: InputDecoration(
                  labelText: 'ISBN',
                  helperText: 'Enter ISBN-10 or ISBN-13 to auto-fill details',
                  errorText: _isbnError,
                  suffixIcon: _isbnLooking
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search),
                          tooltip: 'Look up on Open Library',
                          onPressed: () => _lookupIsbn(_isbnCtrl.text),
                        ),
                ),
                onEditingComplete: () => _lookupIsbn(_isbnCtrl.text),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Public (visible in shared library)'),
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              genresAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Could not load genres.'),
                data: (genres) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Genres',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: genres.map((g) {
                        final gMap = g as Map;
                        final id = gMap['id'] as String;
                        final selected = _selectedGenreIds.contains(id);
                        return FilterChip(
                          label: Text(gMap['name'] as String),
                          selected: selected,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selectedGenreIds.add(id);
                            } else {
                              _selectedGenreIds.remove(id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEditing ? 'Save Changes' : 'Add Book'),
        ),
      ],
    );
  }
}
