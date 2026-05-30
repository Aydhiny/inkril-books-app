import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../providers/auth_notifier.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _usernameCtrl  = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  bool  _obscurePass   = true;
  String? _errorMessage;

  // ── Password requirement flags — updated on every keystroke ────────────────
  bool _hasMinLen    = false;
  bool _hasUppercase = false;
  bool _hasDigit     = false;

  @override
  void initState() {
    super.initState();
    _passwordCtrl.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final v = _passwordCtrl.text;
    setState(() {
      _hasMinLen    = v.length >= 8;
      _hasUppercase = v.contains(RegExp(r'[A-Z]'));
      _hasDigit     = v.contains(RegExp(r'[0-9]'));
    });
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _emailCtrl,
      _usernameCtrl, _passwordCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _strengthScore => [_hasMinLen, _hasUppercase, _hasDigit]
      .where((b) => b)
      .length; // 0..3

  Future<void> _submit() async {
    if (_errorMessage != null) setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authNotifierProvider.notifier).register(
      firstName: _firstNameCtrl.text.trim(),
      lastName:  _lastNameCtrl.text.trim(),
      email:     _emailCtrl.text.trim(),
      userName:  _usernameCtrl.text.trim(),
      password:  _passwordCtrl.text,
    );

    if (!mounted) return;

    final state = ref.read(authNotifierProvider);
    if (state.hasError) {
      setState(() => _errorMessage = parseError(state.error));
      return;
    }

    context.push('/auth/verify-email', extra: _emailCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppTheme.primary,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join Inkril and start your reading journey.',
                  style: TextStyle(fontSize: 15, color: context.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 28),

                // ── Inline server error ────────────────────────────────────────
                if (_errorMessage != null) ...[
                  _ErrorBox(_errorMessage!),
                  const SizedBox(height: 20),
                ],

                // ── Name row ───────────────────────────────────────────────────
                Row(children: [
                  Expanded(child: _field(
                    label: 'First name',
                    ctrl: _firstNameCtrl,
                    hint: 'Ajdin',
                    icon: Icons.badge_outlined,
                    action: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required.' : null,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _field(
                    label: 'Last name',
                    ctrl: _lastNameCtrl,
                    hint: 'Mehmedović',
                    icon: Icons.badge_outlined,
                    action: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required.' : null,
                  )),
                ]),
                const SizedBox(height: 16),

                // ── Email ──────────────────────────────────────────────────────
                _field(
                  label: 'Email address',
                  ctrl: _emailCtrl,
                  hint: 'you@example.com',
                  icon: Icons.email_outlined,
                  keyboard: TextInputType.emailAddress,
                  action: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required.';
                    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v.trim()))
                      return 'Please enter a valid email address.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Username ───────────────────────────────────────────────────
                _field(
                  label: 'Username',
                  ctrl: _usernameCtrl,
                  hint: 'e.g. inkrilreader',
                  icon: Icons.alternate_email_rounded,
                  action: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Username is required.';
                    if (v.trim().length < 3) return 'Must be at least 3 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Password ───────────────────────────────────────────────────
                _Label('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePass,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: _dec(
                    hint: 'Min. 8 chars, 1 uppercase, 1 number',
                    icon: Icons.lock_outline_rounded,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF9CA3AF),
                      ),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required.';
                    if (v.length < 8)                      return 'Must be at least 8 characters.';
                    if (!v.contains(RegExp(r'[A-Z]')))     return 'Must contain an uppercase letter.';
                    if (!v.contains(RegExp(r'[0-9]')))     return 'Must contain a number.';
                    return null;
                  },
                ),

                // ── Strength bar + checklist (shown while typing) ─────────────
                if (_passwordCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PasswordStrengthBar(score: _strengthScore),
                  const SizedBox(height: 10),
                  _PasswordChecklist(
                    hasMinLen:    _hasMinLen,
                    hasUppercase: _hasUppercase,
                    hasDigit:     _hasDigit,
                  ),
                ],
                const SizedBox(height: 28),

                // ── Submit ─────────────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : const Text('Create Account',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Login link ─────────────────────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: const Text(
                      'Already have an account? Sign In',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    TextInputAction? action,
    String? Function(String?)? validator,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Label(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          textInputAction: action,
          decoration: _dec(hint: hint, icon: icon),
          validator: validator,
        ),
      ]);

  InputDecoration _dec({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.textHint, fontSize: 14),
        prefixIcon: Icon(icon, color: context.textHint),
        filled: true,
        fillColor: context.inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Password strength bar — 3-segment (weak / fair / strong)
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final int score; // 0..3
  const _PasswordStrengthBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (score) {
      0 || 1 => ('Weak', const Color(0xFFEF4444)),
      2      => ('Fair', const Color(0xFFF59E0B)),
      _      => ('Strong', const Color(0xFF22C55E)),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 3,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ]),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Password requirements checklist
// ─────────────────────────────────────────────────────────────────────────────

class _PasswordChecklist extends StatelessWidget {
  final bool hasMinLen;
  final bool hasUppercase;
  final bool hasDigit;
  const _PasswordChecklist({
    required this.hasMinLen,
    required this.hasUppercase,
    required this.hasDigit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CheckRow(met: hasMinLen,    label: 'At least 8 characters'),
        const SizedBox(height: 4),
        _CheckRow(met: hasUppercase, label: 'One uppercase letter (A–Z)'),
        const SizedBox(height: 4),
        _CheckRow(met: hasDigit,     label: 'One number (0–9)'),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  final bool met;
  final String label;
  const _CheckRow({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = met ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF);
    return Row(children: [
      Icon(
        met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        size: 15,
        color: color,
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFFCA5A5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ]),
      );
}
