import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Horizontal gutter cards sit inside.
const double kGutter = 18;

/// Horizontal gutter free-standing text sits inside. Slightly wider than
/// [kGutter] so text optically lines up with the content of a card
/// rather than the card's edge.
const double kTextGutter = 22;

/// The big "eyebrow + title" block at the top of a tab screen, with an
/// optional round action button on the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.action,
  });

  final String eyebrow;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kTextGutter, 0, kTextGutter, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eyebrow.toUpperCase(), style: AppText.eyebrow),
                const SizedBox(height: 6),
                Text(title, style: AppText.display),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Top bar for a pushed screen: back arrow, centred eyebrow + title, and
/// an optional trailing action. Mirrors the prototype's stack screens,
/// which never used a stock navigation bar.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
    this.onBack,
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, size: 21),
              color: AppColors.foreground,
              tooltip: 'Back',
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppText.eyebrow.copyWith(fontSize: 9),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.pageTitle,
                ),
              ],
            ),
          ),
          SizedBox(width: 40, height: 40, child: trailing),
        ],
      ),
    );
  }
}

/// "Section title" with an optional text link on the right.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.topPadding = 29,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(kTextGutter, topPadding, kTextGutter, 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: Text(title, style: AppText.section)),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Form field label, used above inputs on the request/profile forms.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.topPadding = 0});

  final String text;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(kTextGutter, topPadding, kTextGutter, 12),
      child: Text(text, style: AppText.fieldLabel),
    );
  }
}
