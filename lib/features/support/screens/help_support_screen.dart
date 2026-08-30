import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/surfaces.dart';

const _supportEmail = 'innself.vvc@gmail.com';

/// General help/contact, distinct from the two things InnSelf already
/// had: dispute flagging (tied to one specific job) and report/block
/// (safety-specific). Neither covers "the app crashed" or "how do
/// refunds work" -- this is that catch-all, reachable from Profile on
/// both sides. Pure UI + external links; no backend of its own.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchOrWarn(BuildContext context, Uri uri, String failureMessage) async {
    bool launched;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 10, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TopBar(eyebrow: 'HELP', title: 'Support'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kGutter),
                child: AppCard(
                  margin: EdgeInsets.zero,
                  radius: 19,
                  padding: const EdgeInsets.all(17),
                  child: Row(
                    children: [
                      const SoftIcon(
                        Icons.mail_outline_rounded,
                        background: AppColors.secondary,
                        foreground: AppColors.secondaryForeground,
                        size: 44,
                        iconSize: 21,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email support', style: AppText.cardTitleLarge),
                            const SizedBox(height: 3),
                            Text(_supportEmail, style: AppText.bodyMuted),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _launchOrWarn(
                          context,
                          Uri(
                            scheme: 'mailto',
                            path: _supportEmail,
                            query: 'subject=InnSelf support request',
                          ),
                          'Could not open your email app',
                        ),
                        child: const Text('Email'),
                      ),
                    ],
                  ),
                ),
              ),
              const SectionHeading(title: 'Common questions'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: kGutter),
                child: Column(
                  children: [
                    _FaqTile(
                      question: 'How does bidding work?',
                      answer:
                          'You post what you need and nearby technicians send their own price. '
                          'You compare price, rating, and distance, then pick who you want -- '
                          'there is no fixed rate set by InnSelf.',
                    ),
                    _FaqTile(
                      question: "What if my technician cancels or doesn't show up?",
                      answer:
                          'Either side can cancel with a reason once assigned, and the other '
                          'person is notified immediately. If a technician cancels late or '
                          "doesn't show, use Flag an issue on that job so it reaches an admin.",
                    ),
                    _FaqTile(
                      question: 'How do I pay, and is it safe?',
                      answer:
                          'Payment happens in the app through Razorpay once the job is marked '
                          'complete with your one-time code -- InnSelf never sees or stores your '
                          'card or UPI details directly.',
                    ),
                    _FaqTile(
                      question: 'How do I delete my account?',
                      answer:
                          'From Profile, or from the account deletion page linked below -- either '
                          'way it takes effect without needing to email anyone.',
                    ),
                    _FaqTile(
                      question: 'What data does InnSelf collect, and why?',
                      answer:
                          'Only what the app needs to work -- your profile, job details, and, if '
                          "you choose to share it, your location for matching. See the privacy "
                          'policy below for the full breakdown.',
                    ),
                  ],
                ),
              ),
              const SectionHeading(title: 'Policies'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: kGutter),
                child: Column(
                  children: [
                    _LinkRow(
                      label: 'Privacy policy',
                      onTap: () => _launchOrWarn(
                        context,
                        Uri.parse('https://vismayvchandra.github.io/innselfpro/privacy.html'),
                        'Could not open the privacy policy',
                      ),
                    ),
                    _LinkRow(
                      label: 'Terms of service',
                      onTap: () => _launchOrWarn(
                        context,
                        Uri.parse('https://vismayvchandra.github.io/innselfpro/terms.html'),
                        'Could not open the terms of service',
                      ),
                    ),
                    _LinkRow(
                      label: 'Delete my account',
                      onTap: () => _launchOrWarn(
                        context,
                        Uri.parse(
                            'https://vismayvchandra.github.io/innselfpro/delete-account.html'),
                        'Could not open the account deletion page',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        margin: EdgeInsets.zero,
        radius: 17,
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 15),
            childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            expandedAlignment: Alignment.centerLeft,
            iconColor: AppColors.primary,
            collapsedIconColor: AppColors.mutedForeground,
            title: Text(
              question,
              style: AppText.cardTitle.copyWith(fontSize: 12.5),
            ),
            children: [
              Text(answer, style: AppText.bodyMuted.copyWith(fontSize: 12, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        margin: EdgeInsets.zero,
        radius: 17,
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            child: Row(
              children: [
                Expanded(child: Text(label, style: AppText.cardTitle.copyWith(fontSize: 12.5))),
                const Icon(Icons.open_in_new_rounded, size: 16, color: AppColors.mutedForeground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
