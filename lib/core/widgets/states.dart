import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'layout.dart';

/// Centred spinner with the breathing room a full screen needs.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.height = 220});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          height: 26,
          width: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

/// Failure state for anything loaded from Supabase.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 28),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.error_outline,
              color: AppColors.destructive,
              size: 22,
            ),
          ),
          const SizedBox(height: 13),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.bodyMuted,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

/// Quiet centred message for a list with nothing in it yet.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(icon, size: 25, color: AppColors.accentForeground),
          ),
          const SizedBox(height: 15),
          Text(title, textAlign: TextAlign.center, style: AppText.cardTitleLarge),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: AppText.bodyMuted),
          ],
        ],
      ),
    );
  }
}

/// Small reassurance line with a shield icon, used under the primary
/// action on the request and bid screens.
class FootNote extends StatelessWidget {
  const FootNote(this.text, {super.key, this.icon = Icons.verified_user_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kTextGutter, 13, kTextGutter, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: AppColors.mutedForeground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: AppText.bodyMuted.copyWith(fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}
