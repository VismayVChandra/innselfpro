import 'package:flutter/material.dart';

import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../models/category.dart';

/// Multi-select category chips -- a technician's skills, structured
/// against the same taxonomy the job feed filters on, rather than a
/// free-text box the feed could never match against.
class SkillsSelector extends StatelessWidget {
  const SkillsSelector({
    super.key,
    required this.categories,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<Category> categories;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final category in categories)
            ChoicePill(
              label: category.name,
              selected: selectedIds.contains(category.id),
              onTap: () => onToggle(category.id),
            ),
        ],
      ),
    );
  }
}
