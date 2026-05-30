import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../providers/auth_notifier.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  /// The email address passed from [ForgotPasswordScreen] via GoRouter extra.
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _otpCtrl       = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  bool    _obscureNew     = true;
  bool    _obscureConfirm = true;
  bool    _success        = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_errorMessage != null) setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authNotifierProvider.notifier).resetPassword(
          email: widget.email,
          otp: _otpCtrl.text.trim(),
          newPassword: _passwordCtrl.text,
        );

    if (!mounted) return;

    final state = ref.read(authNotifierProvider);
    if (state.hasError) {
      setState(() => _errorMessage = parseError(state.error));
      return;
    }

    setState(() => _success = true);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        leading: _success
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: AppTheme.primary,
                onPressed: () => context.pop(),
              ),
      ),
      body: SafeArea(
        child: _success ? _SuccessView(onLogin: () => context.go('/auth/login')) : _FormView(
          formKey: _formKey,
          email: widget.email,
          otpCtrl: _otpCtrl,
          passwordCtrl: _passwordCtrl,
          confirmCtrl: _confirmCtrl,
          obscureNew: _obscureNew,
          obscureConfirm: _obscureConfirm,
          isLoading: isLoading,
          errorMessage: _errorMessage,
          onToggleNew: () => setState(() => _obscureNew = !_obscureNew),
          onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
          onSubmit: _submit,
          onResend: () => context.pop(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form view
// ─────────────────────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final String email;
  final TextEditingController otpCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final bool obscureNew;
  final bool obscureConfirm;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onToggleNew;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  const _FormView({
    required this.formKey,
    required this.email,
    required this.otpCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.obscureNew,
    required this.obscureConfirm,
    required this.isLoading,
    this.errorMessage,
    required this.onToggleNew,
    required this.onToggleConfirm,
    required this.onSubmit,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Icon ──────────────────────────────────────────────────
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE9D5FF), width: 2),
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: AppTheme.primary, size: 32),
            ),
            const SizedBox(height: 20),

            // ── Title ─────────────────────────────────────────────────
            const Text(
              'Enter reset code',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 15, color: Color(0xFF6B7280), height: 1.5),
                children: [
                  const TextSpan(text: 'We sent a 6-digit code to '),
                  TextSpan(
                    text: email,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                  ),
                  const TextSpan(
                      text: '. Enter it below along with your new password.'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Inline error ──────────────────────────────────────────
            if (errorMessage != null) ...[
              Container(
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
                  Expanded(child: Text(
                    errorMessage!,
                    style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  )),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // ── OTP field ─────────────────────────────────────────────
            _Label('Reset code'),
            const SizedBox(height: 8),
            TextFormField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 14,
                color: AppTheme.primary,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: const TextStyle(
                  color: Color(0xFFD1D5DB),
                  letterSpacing: 14,
                  fontSize: 28,
                ),
                filled: true,
                fillColor: AppTheme.primarySurface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE9D5FF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE9D5FF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xFFEF4444), width: 2),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter the 6-digit code.';
                if (v.length != 6) return 'Code must be exactly 6 digits.';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── New password ──────────────────────────────────────────
            _Label('New password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscureNew,
              textInputAction: TextInputAction.next,
              decoration: _passwordDecoration(
                hint: 'At least 8 characters',
                obscure: obscureNew,
                onToggle: onToggleNew,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'New password is required.';
                if (v.length < 8) return 'Password must be at least 8 characters.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Confirm password ──────────────────────────────────────
            _Label('Confirm new password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: confirmCtrl,
              obscureText: obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: _passwordDecoration(
                hint: 'Repeat your new password',
                obscure: obscureConfirm,
                onToggle: onToggleConfirm,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm your password.';
                if (v != passwordCtrl.text) return 'Passwords do not match.';
                return null;
              },
            ),
            const SizedBox(height: 28),

            // ── Submit ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Reset Password',
                        style:
                            TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Resend ────────────────────────────────────────────────
            Center(
              child: TextButton(
                onPressed: onResend,
                child: const Text(
                  "Didn't receive a code? Try again",
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _passwordDecoration({
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 14),
      prefixIcon:
          const Icon(Icons.lock_outline_rounded, color: Color(0xFF9CA3AF)),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: const Color(0xFF9CA3AF),
        ),
        onPressed: onToggle,
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success state
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final VoidCallback onLogin;
  const _SuccessView({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Password reset!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your password has been updated. You can now sign in with your new password.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
