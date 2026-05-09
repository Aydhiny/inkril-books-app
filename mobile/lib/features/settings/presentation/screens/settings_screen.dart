import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
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
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: context.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _SettingsCard(children: [
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
                      _Divider(),
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
                      _Divider(),
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
                    ]),
                    const SizedBox(height: 12),
                    _SettingsCard(children: [
                      _SettingsRow(
                        label: 'Reminder',
                        trailing: _TimeTrailing(
                          time: _fmtTime(_reminderTime),
                          onTap: _pickReminderTime,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _SettingsCard(children: [
                      _SettingsRow(
                        label: 'Daily Reading Goal',
                        trailing: _TimeTrailing(
                          time: '${_dailyGoalMinutes}m',
                          onTap: _pickDailyGoal,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _SettingsCard(children: [
                      _AppearanceRow(),
                    ]),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Version 1.0',
                      style: TextStyle(color: context.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ajdin Mehmedović',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.textBody,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '@Copyright, Aydhiny',
                      style: TextStyle(color: context.textSecondary, fontSize: 12),
                      textAlign: TextAlign.center,
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

  Future<void> _pickDailyGoal() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _DailyGoalSheet(
        current: _dailyGoalMinutes,
        onPick: (val) {
          Navigator.pop(sheetCtx);
          setState(() => _dailyGoalMinutes = val);
          _save();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Duolingo-style daily goal picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _DailyGoalSheet extends StatelessWidget {
  final int current;
  final void Function(int) onPick;
  const _DailyGoalSheet({required this.current, required this.onPick});

  static const _goals = [
    (15, '☕ Casual',   '15 min / day', 'Just getting started'),
    (20, '📖 Regular',  '20 min / day', 'Building a habit'),
    (30, '🎯 Focused',  '30 min / day', 'Most popular goal'),
    (45, '🔥 Serious',  '45 min / day', 'Dedicated reader'),
    (60, '🚀 Intense',  '60 min / day', 'Power reader'),
    (90, '⚡ Ultra',    '90 min / day', 'True bookworm'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: context.borderPurpleMid, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.borderPurpleMid,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Daily Reading Goal',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'How much do you want to read each day?',
          style: TextStyle(fontSize: 14, color: context.textSecondary),
        ),
        const SizedBox(height: 20),
        ...(_goals.map((g) {
          final mins = g.$1;
          final title = g.$2;
          final timeStr = g.$3;
          final subtitle = g.$4;
          final selected = current == mins;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onPick(mins);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: selected ? context.primarySurface : context.subtleBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppTheme.primary : context.borderGray,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(children: [
                Text(title.split(' ')[0],
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.substring(title.indexOf(' ') + 1),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppTheme.primary
                              : context.textPrimary,
                        ),
                      ),
                      Text(
                        '$timeStr • $subtitle',
                        style: TextStyle(
                            fontSize: 12, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.primary, size: 22),
              ]),
            ),
          );
        })),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable settings widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderPurpleMid, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A6B21A8),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
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
            style: TextStyle(
              fontSize: 15,
              color: context.textBody,
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
      onTap: onChanged != null
          ? () {
              HapticFeedback.lightImpact();
              onChanged!(!value);
            }
          : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: value ? AppTheme.primary : context.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: value ? AppTheme.primary : context.borderGray,
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
          color: context.subtleBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.borderGray),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.keyboard_arrow_up_rounded,
              size: 16, color: context.textSecondary),
          Text(
            time,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: context.textBody,
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: context.textSecondary),
        ]),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 16, endIndent: 16, color: context.divider);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appearance toggle
// ─────────────────────────────────────────────────────────────────────────────

class _AppearanceRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Appearance',
          style: TextStyle(
            fontSize: 15,
            color: context.textBody,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _ThemeChip(
            label: '☀️ Light',
            selected: current == ThemeMode.light,
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(themeProvider.notifier).setMode(ThemeMode.light);
            },
          ),
          const SizedBox(width: 8),
          _ThemeChip(
            label: '🌙 Dark',
            selected: current == ThemeMode.dark,
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(themeProvider.notifier).setMode(ThemeMode.dark);
            },
          ),
          const SizedBox(width: 8),
          _ThemeChip(
            label: '⚙️ Auto',
            selected: current == ThemeMode.system,
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(themeProvider.notifier).setMode(ThemeMode.system);
            },
          ),
        ]),
      ]),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.primarySurface : context.subtleBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primary : context.borderGray,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.primary : context.textSecondary,
          ),
        ),
      ),
    );
  }
}
