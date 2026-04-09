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
            return const Center(child: Text('No genres yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: genres.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final g = genres[i] as Map;
              return ListTile(
                leading: const Icon(Icons.category_outlined),
                title: Text(g['name'] as String),
                trailing: const Icon(Icons.chevron_right),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Genre'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Genre name *'),
            autofocus: true,
            onSubmitted: (_) {},
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: loading ? null : () async {
                if (ctrl.text.trim().isEmpty) return;
                setState(() => loading = true);
                try {
                  const storage = FlutterSecureStorage();
                  final token = await storage.read(key: 'access_token');
                  final dio = Dio(BaseOptions(
                    baseUrl: AppConfig.apiBaseUrl,
                    headers: {'Authorization': 'Bearer $token'},
                  ));
                  await dio.post('/api/genres', data: {'name': ctrl.text.trim()});
                  ref.invalidate(adminGenresProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setState(() => loading = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
