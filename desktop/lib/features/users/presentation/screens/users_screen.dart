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

  ({String searchTerm, bool? isBlocked}) get _params =>
      (searchTerm: _searchTerm, isBlocked: _filterBlocked);

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider(_params));

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
        data: (users) {
          final items = users['items'] as List? ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No users found.'));
          }
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Username')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Roles')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: items.map((u) {
                  final user = u as Map;
                  final isBlocked = user['isBlocked'] as bool? ?? false;
                  final roles = (user['roles'] as List? ?? []).cast<String>();
                  return DataRow(cells: [
                    DataCell(Text(user['userName'] as String? ?? '')),
                    DataCell(Text('${user['firstName']} ${user['lastName']}')),
                    DataCell(Text(user['email'] as String? ?? '')),
                    DataCell(Chip(
                      label: Text(isBlocked ? 'Blocked' : 'Active'),
                      backgroundColor: isBlocked
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                    )),
                    DataCell(Text(roles.join(', '))),
                    DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                      // Block / Unblock
                      IconButton(
                        icon: Icon(isBlocked ? Icons.lock_open : Icons.block),
                        tooltip: isBlocked ? 'Unblock' : 'Block',
                        onPressed: () => _toggleBlock(
                          context, user['id'] as String, isBlocked),
                      ),
                      // Change roles
                      IconButton(
                        icon: const Icon(Icons.manage_accounts_outlined),
                        tooltip: 'Change Role',
                        onPressed: () => _showRoleDialog(
                          context, user['id'] as String, roles),
                      ),
                      // Delete
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDelete(
                          context, user['id'] as String,
                          user['userName'] as String? ?? ''),
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

  Future<void> _toggleBlock(
      BuildContext context, String userId, bool isBlocked) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isBlocked ? 'Unblock User' : 'Block User'),
        content: Text(isBlocked
            ? 'Allow this user to access the app again?'
            : 'This user will lose access to the app.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await blockUser(userId, !isBlocked);
      ref.invalidate(usersProvider(_params));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showRoleDialog(
      BuildContext context, String userId, List<String> current) async {
    // Available roles in the system
    const availableRoles = ['mobile', 'desktop'];
    final selected = List<String>.from(current);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Change Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableRoles.map((role) {
              return CheckboxListTile(
                title: Text(role),
                value: selected.contains(role),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    selected.add(role);
                  } else {
                    selected.remove(role);
                  }
                }),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await updateUserRoles(userId, selected);
      ref.invalidate(usersProvider(_params));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
            'Permanently delete "$userName"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await deleteUser(userId);
      ref.invalidate(usersProvider(_params));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
