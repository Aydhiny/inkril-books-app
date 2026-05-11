import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/app_config.dart';
import '../../../books/presentation/providers/books_provider.dart';

class GenresScreen extends ConsumerWidget {
  const GenresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genresAsync = ref.watch(adminGenresProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Genres'),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Genre'),
            onPressed: () => _showAddDialog(context, ref),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: genresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (genres) {
          if (genres.isEmpty) {
            return const Center(child: Text('No genres yet. Add one above.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: genres.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final g = genres[i] as Map;
              final id = g['id'] as String;
              final name = g['name'] as String;
              final description = g['description'] as String?;
              return ListTile(
                leading: const Icon(Icons.category_outlined),
                title: Text(name),
                subtitle: description != null && description.isNotEmpty
                    ? Text(description, maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit genre',
                      onPressed: () => _showEditDialog(context, ref, id, name, description),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete genre',
                      onPressed: () => _confirmDelete(context, ref, id, name),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Add ──────────────────────────────────────────────────────────────────

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Genre'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Genre name *'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setState(() => loading = true);
                      try {
                        final dio = await _authedDio();
                        await dio.post('/api/genres', data: {
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        });
                        ref.invalidate(adminGenresProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setState(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit ─────────────────────────────────────────────────────────────────

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    String id,
    String currentName,
    String? currentDescription,
  ) {
    final nameCtrl = TextEditingController(text: currentName);
    final descCtrl = TextEditingController(text: currentDescription ?? '');
    bool loading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit Genre'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Genre name *'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (nameCtrl.text.trim().isEmpty) return;
                      setState(() => loading = true);
                      try {
                        final dio = await _authedDio();
                        await dio.put('/api/genres/$id', data: {
                          'id': id,
                          'name': nameCtrl.text.trim(),
                          'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        });
                        ref.invalidate(adminGenresProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setState(() => loading = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete genre?'),
        content: Text(
          'Delete "$name"?\n\nThis will fail if any books are still tagged with this genre.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final dio = await _authedDio();
                await dio.delete('/api/genres/$id');
                ref.invalidate(adminGenresProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not delete: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Future<Dio> _authedDio() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    return Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: {'Authorization': 'Bearer $token'},
    ));
  }
}
