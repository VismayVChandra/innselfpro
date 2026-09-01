import 'package:flutter/material.dart';

import '../widgets/layout.dart';
import 'app_colors.dart';
import 'app_text.dart';
import 'theme_controller.dart';

String appearanceLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

/// Bottom sheet with the three appearance options -- a friend's
/// suggestion after seeing the app in the emulator. Reachable from
/// Profile on both sides. Picking an option calls ThemeController
/// directly; nothing here needs its own state, since app.dart already
/// rebuilds the whole tree (this sheet included, while it's open) the
/// moment the controller changes.
Future<void> showAppearancePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _AppearanceSheet(),
  );
}

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final current = ThemeController.instance.mode;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: Text('Appearance', style: AppText.cardTitleLarge),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: Text(
                    'System follows your phone\'s own setting.',
                    style: AppText.bodyMuted.copyWith(fontSize: 11.5),
                  ),
                ),
                const SizedBox(height: 10),
                for (final mode in ThemeMode.values)
                  _AppearanceOption(
                    mode: mode,
                    selected: mode == current,
                    onTap: () {
                      // Popping the sheet and swapping the whole app's
                      // theme are each big tree mutations on their own;
                      // firing both in the same frame can leave part of
                      // the tree painted with the outgoing palette until
                      // the next interaction forces a repaint. Letting
                      // the pop's frame finish first avoids that.
                      Navigator.of(context).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ThemeController.instance.setMode(mode);
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (mode) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_icon, color: selected ? AppColors.primary : AppColors.mutedForeground),
      title: Text(
        appearanceLabel(mode),
        style: AppText.body.copyWith(
          fontSize: 13.5,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? AppColors.primary : AppColors.foreground,
        ),
      ),
      trailing: selected ? Icon(Icons.check_rounded, color: AppColors.primary) : null,
      onTap: onTap,
    );
  }
}
