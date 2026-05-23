import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

// Legal screen — renders Privacy Policy or Terms of Service based on [type].
// Driven by a route parameter so a single screen handles both documents.

class LegalScreen extends StatelessWidget {
  /// 'privacy-policy' or 'terms'
  final String type;
  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isPrivacy = type == 'privacy-policy';
    final title = isPrivacy ? 'Privacy Policy' : 'Terms of Service';
    final sections = isPrivacy ? _privacySections : _termsSections;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.primary, size: 20),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: context.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 4),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Last updated chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.primarySurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF9333EA), width: 1.5),
                      ),
                      child: Text(
                        'Last updated: May 2025 · v${AppConfig.appVersion}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Intro blurb
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: context.borderPurpleMid, width: 2),
                      ),
                      child: Text(
                        isPrivacy
                            ? 'Inkril is committed to protecting your privacy. This policy explains what personal data we collect, why we collect it, and how we keep it safe.'
                            : 'By using Inkril you agree to these Terms of Service. Please read them carefully before creating an account or making a purchase.',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textBody,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sections
                    for (final section in sections) ...[
                      _SectionHeader(section.title),
                      const SizedBox(height: 8),
                      for (final item in section.items) _BulletItem(item),
                      const SizedBox(height: 20),
                    ],

                    // Contact footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.subtleBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: context.borderGray, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Questions?',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Contact us at support@inkril.app — we respond within 48 hours.',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Section widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: context.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    ]);
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: context.textBody,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legal content
// ─────────────────────────────────────────────────────────────────────────────

class _Section {
  final String title;
  final List<String> items;
  const _Section(this.title, this.items);
}

const _privacySections = [
  _Section('Data We Collect', [
    'Account information: name, email address, and a securely hashed password.',
    'Reading data: books you read, progress, sessions, bookmarks, and highlights — used to power your personal statistics and recommendations.',
    'Payment information: Inkril does not store your card details. All payment processing is handled by Stripe, Inc., which is PCI-DSS Level 1 certified. We receive only a payment confirmation and a transaction reference ID.',
    'Usage data: feature interactions and app performance metrics to improve the product.',
  ]),
  _Section('How We Use Your Data', [
    'To provide and improve the Inkril service, including personalised book recommendations.',
    'To send you reading reminders and notifications you have opted into.',
    'To process and verify premium book purchases via Stripe.',
    'To send weekly reading summaries if you have opted in.',
    'We never sell, rent, or share your personal data with third parties for marketing purposes.',
  ]),
  _Section('Data Storage & Security', [
    'Your data is stored in a PostgreSQL database hosted on a private server. Passwords are hashed using industry-standard bcrypt.',
    'All communication between the app and our servers uses HTTPS/TLS encryption.',
    'We apply the principle of least privilege — database access is restricted to only the services that need it.',
    'Soft-deletion is used throughout: when you delete content, it is logically removed but retained briefly for recovery before permanent erasure.',
  ]),
  _Section('Your Rights', [
    'Access: you may request a copy of all personal data we hold about you.',
    'Correction: you may update your account information at any time in the Profile section.',
    'Deletion: you may request full account deletion by contacting support@inkril.app.',
    'Portability: your reading history and bookmarks can be exported on request.',
    'We will respond to all data requests within 30 days.',
  ]),
  _Section('Third-Party Services', [
    'Stripe — payment processing. Stripe\'s own privacy policy applies to data you provide during checkout (stripe.com/privacy).',
    'Open Library — cover images for books are fetched from openlibrary.org.',
    'No analytics, advertising, or social tracking SDKs are included in this app.',
  ]),
  _Section('Cookies & Local Storage', [
    'The mobile app does not use cookies. A secure local store holds only your authentication token and local preferences (theme, reminder time). This data never leaves your device unless required to authenticate with our API.',
  ]),
];

const _termsSections = [
  _Section('Acceptance', [
    'By creating an account or using the Inkril application you agree to be bound by these Terms. If you do not agree, do not use the app.',
    'We reserve the right to update these Terms at any time. Continued use after changes constitutes acceptance.',
  ]),
  _Section('Accounts', [
    'You must be at least 13 years old to create an account.',
    'You are responsible for maintaining the confidentiality of your credentials and for all activity that occurs under your account.',
    'You agree to provide accurate registration information and keep it up to date.',
    'We reserve the right to suspend or terminate accounts that violate these Terms.',
  ]),
  _Section('Premium Content & Payments', [
    'Certain books are marked as "Premium" and require a one-time purchase before reading.',
    'All payments are processed securely by Stripe, Inc. Inkril does not store your card details.',
    'Purchases are tied to your account and are available on all devices where you sign in.',
    'All sales are final. Refunds are issued only if you are unable to access purchased content due to a technical error on our side.',
    'Prices are displayed in USD and include applicable taxes where required.',
  ]),
  _Section('Acceptable Use', [
    'You agree not to reverse-engineer, copy, redistribute, or resell any content available through Inkril.',
    'You agree not to attempt to gain unauthorised access to any part of the service or its infrastructure.',
    'Reviews and comments must be honest and must not contain hate speech, harassment, or spam.',
    'We reserve the right to remove content that violates these guidelines without notice.',
  ]),
  _Section('Intellectual Property', [
    'The Inkril app, its UI, branding, and original code are the intellectual property of the developer.',
    'Books available in the app remain the property of their respective authors and publishers.',
    'User-generated content (reviews, highlights, notes) remains yours. By submitting it you grant Inkril a non-exclusive licence to display it within the service.',
  ]),
  _Section('Limitation of Liability', [
    'Inkril is provided "as is" without warranty of any kind. We do not guarantee uninterrupted or error-free operation.',
    'To the maximum extent permitted by law, we are not liable for any indirect, incidental, or consequential damages arising from your use of the service.',
    'Our total liability for any claim is limited to the amount you paid for the specific purchase that caused the claim.',
  ]),
  _Section('Governing Law', [
    'These Terms are governed by the laws of Bosnia and Herzegovina.',
    'Any disputes shall be resolved through good-faith negotiation first. If unresolved, disputes will be submitted to the competent court in Mostar, Bosnia and Herzegovina.',
  ]),
];
