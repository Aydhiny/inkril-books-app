import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../payments/presentation/providers/payment_methods_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.primary, size: 20),
                  onPressed: () => context.pop(),
                ),
                const Expanded(
                  child: Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 4),

            // ── Content ───────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile card
                    _ProfileCard(profileAsync: profileAsync),
                    const SizedBox(height: 12),

                    // Payment methods card
                    _PaymentMethodsCard(methodsAsync: methodsAsync),
                    const SizedBox(height: 12),

                    // Quick links card
                    _AccountCard(children: [
                      _NavRow(
                        icon: Icons.settings_outlined,
                        label: 'App Settings',
                        subtitle: 'Notifications, goals, appearance',
                        onTap: () => context.push('/settings'),
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        onTap: () => context.push('/legal/privacy-policy'),
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.gavel_rounded,
                        label: 'Terms of Service',
                        onTap: () => context.push('/legal/terms'),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile summary card
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final AsyncValue profileAsync;
  const _ProfileCard({required this.profileAsync});

  @override
  Widget build(BuildContext context) {
    final profile = profileAsync.valueOrNull as Map<String, dynamic>?;
    final firstName = profile?['firstName'] as String? ?? '';
    final lastName  = profile?['lastName']  as String? ?? '';
    final userName  = profile?['userName']  as String? ?? '';
    final email     = profile?['email']     as String? ?? '';
    final fullName  = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

    final initials = () {
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        return '${firstName[0]}${lastName[0]}'.toUpperCase();
      }
      return userName.isNotEmpty ? userName[0].toUpperCase() : '?';
    }();

    return _AccountCard(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          // Avatar circle
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.primary,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Name + username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isNotEmpty ? fullName : userName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                    ),
                  ),
                ],
                if (userName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$userName',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Edit button
          OutlinedButton(
            onPressed: () => GoRouter.of(context).push('/profile/edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Edit',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment methods card
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentMethodsCard extends ConsumerWidget {
  final AsyncValue methodsAsync;
  const _PaymentMethodsCard({required this.methodsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupState = ref.watch(setupProvider);
    final isAdding   = setupState.status == SetupStatus.loading;

    return _AccountCard(children: [
      // Header row
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Row(children: [
          const Icon(Icons.credit_card_rounded,
              size: 20, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Payment Methods',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
          ),
          // Add card button
          GestureDetector(
            onTap: isAdding ? null : () => _addCard(context, ref),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isAdding
                    ? context.primarySurface.withValues(alpha: 0.5)
                    : context.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary, width: 1.5),
              ),
              child: isAdding
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    )
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, size: 16, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text('Add Card',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary)),
                    ]),
            ),
          ),
        ]),
      ),

      // Error message if setup failed
      if (setupState.status == SetupStatus.failure &&
          setupState.errorMessage != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            setupState.errorMessage!,
            style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ),

      // Card list
      methodsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Text('Failed to load cards.',
              style: TextStyle(color: context.textSecondary, fontSize: 13)),
        ),
        data: (methods) {
          if ((methods as List).isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: context.textHint),
                const SizedBox(width: 8),
                Text(
                  'No saved cards yet. Add one above.',
                  style: TextStyle(fontSize: 13, color: context.textSecondary),
                ),
              ]),
            );
          }
          return Column(
            children: [
              for (int i = 0; i < methods.length; i++) ...[
                if (i > 0) _Divider(),
                _CardTile(
                  card: methods[i] as Map<String, dynamic>,
                  onDelete: () => _deleteCard(
                      context, ref, methods[i]['id'] as String),
                ),
              ],
              const SizedBox(height: 4),
            ],
          );
        },
      ),
    ]);
  }

  Future<void> _addCard(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(setupProvider.notifier);
    final success  = await notifier.addCard();
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Card saved successfully!'),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _deleteCard(
      BuildContext context, WidgetRef ref, String paymentMethodId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove card'),
        content: const Text('Remove this saved card from your account?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/api/payments/payment-methods/$paymentMethodId');
      ref.invalidate(paymentMethodsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Card removed.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to remove card.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single saved card tile
// ─────────────────────────────────────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final Map<String, dynamic> card;
  final VoidCallback onDelete;
  const _CardTile({required this.card, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final brand    = (card['brand'] as String? ?? 'card').toLowerCase();
    final last4    = card['last4']    as String? ?? '••••';
    final expMonth = card['expMonth'] as int? ?? 0;
    final expYear  = card['expYear']  as int? ?? 0;

    final brandIcon = switch (brand) {
      'visa'       => Icons.credit_card_rounded,
      'mastercard' => Icons.credit_card_rounded,
      'amex'       => Icons.credit_card_rounded,
      _            => Icons.credit_card_outlined,
    };

    final brandColor = switch (brand) {
      'visa'       => const Color(0xFF1A1F71),
      'mastercard' => const Color(0xFFEB001B),
      'amex'       => const Color(0xFF007BC1),
      _            => AppTheme.primary,
    };

    final expStr =
        '${expMonth.toString().padLeft(2, '0')}/${expYear.toString().substring(2)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        // Brand icon
        Container(
          width: 38,
          height: 28,
          decoration: BoxDecoration(
            color: brandColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: brandColor.withValues(alpha: 0.3), width: 1),
          ),
          child: Icon(brandIcon, size: 18, color: brandColor),
        ),
        const SizedBox(width: 12),

        // Card details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${brand[0].toUpperCase()}${brand.substring(1)} •••• $last4',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              Text(
                'Expires $expStr',
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
            ],
          ),
        ),

        // Delete
        IconButton(
          icon: Icon(Icons.delete_outline_rounded,
              size: 20, color: context.textHint),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: onDelete,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final List<Widget> children;
  const _AccountCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderPurpleMid, width: 2.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A6B21A8), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  const _NavRow(
      {required this.icon,
      required this.label,
      this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        color: context.textBody,
                        fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 12, color: context.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: context.textSecondary),
        ]),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 16, endIndent: 16, color: context.divider);
}
