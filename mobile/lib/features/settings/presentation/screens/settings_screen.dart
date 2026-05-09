import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final _settingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/api/user-settings');
  return res.data as Map<String, dynamic>;
});

// ── Screen ─────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _friendActivity = true;
  bool _weeklySummary = true;
  int _dailyGoalMinutes = 30;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);
  bool _loaded = false;

  static const _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadReminderTime();
  }

  Future<void> _loadReminderTime() async {
    final val = await _storage.read(key: 'reminder_time');
    if (val != null) {
      final parts = val.split(':');
      if (parts.length == 2) {
        setState(() {
          _reminderTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 21,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        });
      }
    }
  }

  void _applyFromApi(Map<String, dynamic> data) {
    if (_loaded) return;
    _loaded = true;
    setState(() {
      _notificationsEnabled = data['notificationsEnabled'] as bool? ?? true;
      _friendActivity = data['friendActivityNotifications'] as bool? ?? true;
      _weeklySummary = data['weeklySummaryEmail'] as bool? ?? true;
      _dailyGoalMinutes = data['dailyReadingGoalMinutes'] as int? ?? 30;
    });
  }

  Future<void> _save() async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/user-settings', data: {
        'notificationsEnabled': _notificationsEnabled,
        'friendActivityNotifications': _friendActivity,
        'weeklySummaryEmail': _weeklySummary,
        'dailyReadingGoalMinutes': _dailyGoalMinutes,
        'theme': 'system',
        'language': 'en',
      });
      await _storage.write(
          key: 'reminder_time',
          value: '${_reminderTime.hour}:${_reminderTime.minute}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved'),
            backgroundColor: AppTheme.progressGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
      _save();
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(_settingsProvider);
    settingsAsync.whenData((data) => _applyFromApi(data));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            ),
            // ── Settings cards ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Notifications
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          label: 'Enable Notifications',
                          trailing: _CheckboxTrailing(
                            value: _notificationsEnabled,
                            onChanged: (v) {
                              setState(() => _notificationsEnabled = v);
                              _save();
                            },
                          ),
                        ),
                        const _Divider(),
                        _SettingsRow(
                          label: 'Friend Activity',
                          trailing: _CheckboxTrailing(
                            value: _friendActivity && _notificationsEnabled,
                            onChanged: _notificationsEnabled
                                ? (v) {
                                    setState(() => _friendActivity = v);
                                    _save();
                                  }
                                : null,
                          ),
                        ),
                        const _Divider(),
                        _SettingsRow(
                          label: 'Weekly Summary Email',
                          trailing: _CheckboxTrailing(
                            value: _weeklySummary,
                            onChanged: (v) {
                              setState(() => _weeklySummary = v);
                              _save();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Reminder time
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          label: 'Reminder',
                          trailing: _TimeTrailing(
                            time: _fmtTime(_reminderTime),
                            onTap: _pickReminderTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Daily reading goal
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          label: 'Daily Reading Goal',
                          trailing: _TimeTrailing(
                            time: '${_dailyGoalMinutes}m',
                            onTap: _pickDailyGoal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // ── Version footer ────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Text(
                    'Version 1.0',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ajdin Mehmedović',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '@Copyright, Aydhiny',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDailyGoal() async {
    final options = [15, 20, 30, 45, 60, 90, 120];
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Daily Reading Goal',
            style: TextStyle(fontWeight: FontWeight.w800)),
        children: options
            .map((m) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, m),
                  child: Text('$m minutes',
                      style: TextStyle(
                        fontWeight: m == _dailyGoalMinutes
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: m == _dailyGoalMinutes
                            ? AppTheme.primary
                            : null,
                      )),
                ))
            .toList(),
      ),
    );
    if (picked != null) {
      setState(() => _dailyGoalMinutes = picked);
      _save();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable settings UI widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  const _SettingsRow({required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF4B5563),
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _CheckboxTrailing extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _CheckboxTrailing({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: value ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? AppTheme.primary : const Color(0xFFD1D5DB),
            width: 2,
          ),
        ),
        child: value
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}

class _TimeTrailing extends StatelessWidget {
  final String time;
  final VoidCallback onTap;
  const _TimeTrailing({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.keyboard_arrow_up_rounded,
              size: 16, color: Color(0xFF6B7280)),
          Text(
            time,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF374151),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: Color(0xFF6B7280)),
        ]),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, endIndent: 16,
        color: Color(0xFFF3F4F6));
  }
}
