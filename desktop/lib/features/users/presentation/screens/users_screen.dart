import 'dart:math' show max, min;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/users_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Users screen — styled table with coloured rows matching the spec
// ─────────────────────────────────────────────────────────────────────────────

const _kRowColorActive  = Color(0xFF8590D4);
const _kRowColorBanned  = Color(0xFFD47882);
const _kPageSize        = 8;

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  String _searchTerm = '';
  bool?  _filterBlocked;
  int    _currentPage = 0;

  ({String searchTerm, bool? isBlocked}) get _params =>
      (searchTerm: _searchTerm, isBlocked: _filterBlocked);

  void _goToPage(int page) => setState(() => _currentPage = page);

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider(_params));

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 4),
            child: Row(children: [
              const Text('👥', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Text(
                'Users',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF5B6AD0),
                    ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
            child: Text(
              'Browse users by filtering the table below.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),

          // ── Search + filter row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Search field
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: Icon(Icons.search,
                          size: 18, color: Colors.grey.shade500),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (v) => setState(() {
                      _searchTerm = v;
                      _currentPage = 0;
                    }),
                  ),
                ),
                const SizedBox(width: 20),

                // Status filter
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('User status',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<bool?>(
                          value: _filterBlocked,
                          isDense: true,
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: Color(0xFF5B6AD0)),
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF5B6AD0),
                              fontWeight: FontWeight.w600),
                          items: const [
                            DropdownMenuItem(
                                value: null, child: Text('All')),
                            DropdownMenuItem(
                                value: false, child: Text('Active')),
                            DropdownMenuItem(
                                value: true, child: Text('Blocked')),
                          ],
                          onChanged: (v) => setState(() {
                            _filterBlocked = v;
                            _currentPage = 0;
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Table ────────────────────────────────────────────────────
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) {
                final allUsers = data['items'] as List? ?? [];
                final totalPages =
                    (allUsers.length / _kPageSize).ceil().clamp(1, 999);
                final page = _currentPage.clamp(0, totalPages - 1);
                final start = page * _kPageSize;
                final end =
                    (start + _kPageSize).clamp(0, allUsers.length);
                final pageUsers = allUsers.sublist(start, end);

                return Column(
                  children: [
                    // Table header
                    Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 11),
                      child: Row(children: [
                        _headerCell('Name', flex: 2),
                        _headerCell('E-mail', flex: 3),
                        _headerCell('Status'),
                        _headerCell('Roles'),
                        const SizedBox(width: 52),
                      ]),
                    ),

                    // Table rows
                    Expanded(
                      child: pageUsers.isEmpty
                          ? const Center(child: Text('No users found.'))
                          : ListView.separated(
                              itemCount: pageUsers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 1),
                              itemBuilder: (_, i) {
                                final user = pageUsers[i] as Map;
                                return _UserRow(
                                  user: user,
                                  onEdit: () => _showEditDialog(
                                      context, user),
                                );
                              },
                            ),
                    ),

                    // Pagination
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: _Pagination(
                          currentPage: page,
                          totalPages: totalPages,
                          onPageChanged: _goToPage,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      );

  // ── Edit dialog ──────────────────────────────────────────────────────────

  Future<void> _showEditDialog(BuildContext context, Map user) async {
    await showDialog(
      context: context,
      builder: (dialogCtx) => _UserEditDialog(
        user: user,
        onDone: () {
          ref.invalidate(usersProvider(_params));
          Navigator.pop(dialogCtx);
        },
        onClose: () => Navigator.pop(dialogCtx),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single coloured table row
// ─────────────────────────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  final Map user;
  final VoidCallback onEdit;
  const _UserRow({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isBlocked = user['isBlocked'] as bool? ?? false;
    final firstName = user['firstName'] as String? ?? '';
    final lastName  = user['lastName']  as String? ?? '';
    final email     = user['email']     as String? ?? '';
    final roles     = (user['roles']    as List? ?? []).cast<String>();
    final rowColor  = isBlocked ? _kRowColorBanned : _kRowColorActive;

    return Container(
      color: rowColor,
      padding:
          const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
      child: Row(
        children: [
          // Name
          Expanded(
            flex: 2,
            child: Text(
              '$firstName $lastName',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          // Email
          Expanded(
            flex: 3,
            child: Text(
              email,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          // Status
          Expanded(
            child: Text(
              isBlocked ? 'Banned' : 'Active',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isBlocked
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
          // Roles
          Expanded(
            child: Text(
              roles.join(', '),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          // Edit icon button
          _EditIconButton(onPressed: onEdit),
        ],
      ),
    );
  }
}

class _EditIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _EditIconButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Edit user',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.edit, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pagination row — < 1 2 … n-1 n >
// ─────────────────────────────────────────────────────────────────────────────

class _Pagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;
  const _Pagination(
      {required this.currentPage,
      required this.totalPages,
      required this.onPageChanged});

  List<int> get _pages {
    if (totalPages <= 7) return List.generate(totalPages, (i) => i);
    final result = <int>[0];
    if (currentPage > 2) result.add(-1); // ellipsis
    for (int i = max(1, currentPage - 1);
        i <= min(totalPages - 2, currentPage + 1);
        i++) {
      result.add(i);
    }
    if (currentPage < totalPages - 3) result.add(-1);
    result.add(totalPages - 1);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PageBtn(
          label: '<',
          enabled: currentPage > 0,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        for (final p in _pages)
          p == -1
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('…',
                      style: TextStyle(color: Colors.grey)),
                )
              : _PageBtn(
                  label: '${p + 1}',
                  selected: p == currentPage,
                  onTap: () => onPageChanged(p),
                ),
        _PageBtn(
          label: '>',
          enabled: currentPage < totalPages - 1,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ],
    );
  }
}

class _PageBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn(
      {required this.label,
      required this.onTap,
      this.selected = false,
      this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final active = enabled || selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF5B6AD0)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? const Color(0xFF5B6AD0)
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : active
                      ? Colors.black87
                      : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User edit dialog — block/unblock + role management
// ─────────────────────────────────────────────────────────────────────────────

class _UserEditDialog extends StatefulWidget {
  final Map user;
  final VoidCallback onDone;
  final VoidCallback onClose;
  const _UserEditDialog(
      {required this.user, required this.onDone, required this.onClose});

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  late bool _isBlocked;
  late List<String> _roles;
  bool _loading = false;

  static const _availableRoles = ['mobile', 'desktop'];

  @override
  void initState() {
    super.initState();
    _isBlocked = widget.user['isBlocked'] as bool? ?? false;
    _roles = List<String>.from(
        (widget.user['roles'] as List? ?? []).cast<String>());
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final userId = widget.user['id'] as String;
      await blockUser(userId, _isBlocked);
      await updateUserRoles(userId, _roles);
      widget.onDone();
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
    final name =
        '${widget.user['firstName'] ?? ''} ${widget.user['lastName'] ?? ''}'
            .trim();

    return AlertDialog(
      title: Text('Edit User — $name'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Block toggle
            Row(
              children: [
                const Icon(Icons.block, size: 18, color: Colors.red),
                const SizedBox(width: 8),
                const Text('Blocked',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: _isBlocked,
                  activeTrackColor: Colors.red.shade400,
                  activeThumbColor: Colors.white,
                  onChanged: (v) => setState(() => _isBlocked = v),
                ),
              ],
            ),
            const Divider(),
            const Text('Roles',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            ..._availableRoles.map((role) => CheckboxListTile(
                  dense: true,
                  title: Text(role),
                  value: _roles.contains(role),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _roles.add(role);
                    } else {
                      _roles.remove(role);
                    }
                  }),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: widget.onClose, child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5B6AD0)),
          onPressed: _loading || _roles.isEmpty ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
