import 'package:flutter/material.dart';
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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: selectedLevel,
                    decoration: const InputDecoration(
                      labelText: 'Hero Level',
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
                const SizedBox(width: 16)
              ],
            ),
          ],
        ),
      ),
    );
  }
}
