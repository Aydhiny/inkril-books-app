import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/users_provider.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _searchTerm = '';
  bool? _filterBlocked;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider(
      searchTerm: _searchTerm,
      isBlocked: _filterBlocked,
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name, username or email...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchTerm = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<bool?>(
                value: _filterBlocked,
                hint: const Text('Status'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(value: false, child: Text('Active')),
                  DropdownMenuItem(value: true, child: Text('Blocked')),
                ],
                onChanged: (v) => setState(() => _filterBlocked = v),
              ),
            ]),
          ),
        ),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) => DataTable(
          columns: const [
            DataColumn(label: Text('Username')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Roles')),
            DataColumn(label: Text('Actions')),
          ],
          rows: (users['items'] as List? ?? []).map((u) {
            final user = u as Map;
            final isBlocked = user['isBlocked'] as bool? ?? false;
            return DataRow(cells: [
              DataCell(Text(user['userName'] as String? ?? '')),
              DataCell(Text('${user['firstName']} ${user['lastName']}')),
              DataCell(Text(user['email'] as String? ?? '')),
              DataCell(Chip(
                label: Text(isBlocked ? 'Blocked' : 'Active'),
                backgroundColor: isBlocked ? Colors.red.shade100 : Colors.green.shade100,
              )),
              DataCell(Text((user['roles'] as List? ?? []).join(', '))),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: Icon(isBlocked ? Icons.lock_open : Icons.block),
                  tooltip: isBlocked ? 'Unblock' : 'Block',
                  onPressed: () => _toggleBlock(context, ref, user['id'] as String, isBlocked),
                ),
              ])),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _toggleBlock(BuildContext context, WidgetRef ref, String userId, bool isBlocked) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isBlocked ? 'Unblock User' : 'Block User'),
        content: Text(isBlocked ? 'Allow this user to access the app again?' : 'This user will lose access to the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // TODO: call updateUserStatus API
      ref.invalidate(usersProvider(searchTerm: _searchTerm, isBlocked: _filterBlocked));
    }
  }
}
