import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Widget for selecting hero level (1-10)
class LevelSelectorWidget extends StatelessWidget {
  final int selectedLevel;
  final ValueChanged<int> onLevelChanged;

  const LevelSelectorWidget({
    super.key,
    required this.selectedLevel,
    required this.onLevelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hero Level',
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 4),
            const Text(
              'Select your hero\'s level',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedLevel,
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: List.generate(10, (index) => index + 1)
                        .map((level) => DropdownMenuItem(
                              value: level,
                              child: Text(
                                'Level $level',
                                style: AppTextStyles.body,
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
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        selectedLevel.toString(),
                        style: AppTextStyles.title.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'Level',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
