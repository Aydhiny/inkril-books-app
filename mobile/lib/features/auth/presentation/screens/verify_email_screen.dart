import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_notifier.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  bool _success  = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authNotifierProvider.notifier).verifyEmail(
          email: widget.email,
          otp: _otpCtrl.text.trim(),
        );

    if (!mounted) return;
    final state = ref.read(authNotifierProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error.toString()),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _success = true);
  }

  Future<void> _resend() async {
    await ref
        .read(authNotifierProvider.notifier)
        .resendVerification(widget.email);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('A new code has been sent to your email.'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _success
            ? _SuccessView(onContinue: () => context.go('/library'))
            : _FormView(
                formKey: _formKey,
                email: widget.email,
                otpCtrl: _otpCtrl,
                isLoading: isLoading,
                onSubmit: _submit,
                onResend: _resend,
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
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  const _FormView({
    required this.formKey,
    required this.email,
    required this.otpCtrl,
    required this.isLoading,
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
              child: const Icon(Icons.mark_email_unread_rounded,
                  color: AppTheme.primary, size: 32),
            ),
            const SizedBox(height: 20),

            // ── Title ─────────────────────────────────────────────────
            const Text(
              'Verify your email',
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
                  const TextSpan(text: '. Enter it below to activate your account.'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── OTP field ─────────────────────────────────────────────
            const Text(
              'Verification code',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onFieldSubmitted: (_) => onSubmit(),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
                        'Verify Email',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Resend ────────────────────────────────────────────────
            Center(
              child: TextButton(
                onPressed: isLoading ? null : onResend,
                child: const Text(
                  "Didn't receive a code? Resend",
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Success state
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final VoidCallback onContinue;
  const _SuccessView({required this.onContinue});

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
              child: const Icon(Icons.mark_email_read_rounded,
                  color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Email verified!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your account is now active. Welcome to Inkril!',
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
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Start Reading',
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
