import 'package:flutter/material.dart';

import '../../../../core/theme/creator_theme.dart';
import '../../../../core/text/creators/widgets/strife_creator/level_selector_widget_text.dart';

/// Widget for selecting hero level (1-10)
class LevelSelectorWidget extends StatelessWidget {
  final int selectedLevel;
  final ValueChanged<int> onLevelChanged;

  const LevelSelectorWidget({
    super.key,
    required this.selectedLevel,
    required this.onLevelChanged,
  });

  static const _accent = CreatorTheme.classAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: CreatorTheme.sectionMargin,
      decoration: CreatorTheme.sectionDecoration(_accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CreatorTheme.sectionHeader(
            title: LevelSelectorWidgetText.heroLevelLabel,
            subtitle: LevelSelectorWidgetText.levelSubtitle,
            icon: Icons.trending_up,
            accent: _accent,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: DropdownButtonFormField<int>(
              value: selectedLevel,
              dropdownColor: const Color(0xFF2A2A2A),
              decoration: CreatorTheme.dropdownDecoration(
                label: LevelSelectorWidgetText.heroLevelLabel,
                accent: _accent,
              ),
              style: const TextStyle(color: Colors.white),
              items: List.generate(10, (index) => index + 1)
                  .map((level) => DropdownMenuItem(
                        value: level,
                        child: Text(
                          '${LevelSelectorWidgetText.levelOptionPrefix}$level',
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  onLevelChanged(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
