import 'package:flutter/material.dart';

import '../../../../core/models/class_data.dart';
import '../../../../core/theme/creator_theme.dart';
import '../../../../core/text/creators/widgets/strife_creator/class_selector_widget_text.dart';

/// Widget for selecting hero class
class ClassSelectorWidget extends StatelessWidget {
  final List<ClassData> availableClasses;
  final ClassData? selectedClass;
  final int selectedLevel;
  final ValueChanged<ClassData> onClassChanged;

  const ClassSelectorWidget({
    super.key,
    required this.availableClasses,
    required this.selectedClass,
    required this.selectedLevel,
    required this.onClassChanged,
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
            title: ClassSelectorWidgetText.title,
            subtitle: ClassSelectorWidgetText.subtitle,
            icon: Icons.school,
            accent: _accent,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<ClassData>(
                  value: selectedClass,
                  dropdownColor: const Color(0xFF2A2A2A),
                  decoration: CreatorTheme.dropdownDecoration(
                    label: ClassSelectorWidgetText.classLabel,
                    accent: _accent,
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: availableClasses
                      .map((classData) => DropdownMenuItem(
                            value: classData,
                            child: Text(classData.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onClassChanged(value);
                    }
                  },
                ),
                if (selectedClass != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: _accent.withValues(alpha: 0.2),
                                border: Border.all(color: _accent.withValues(alpha: 0.4)),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: _accent,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedClass!.startingCharacteristics.heroicResourceName,
                                style: const TextStyle(
                                  color: _accent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (selectedClass!.startingCharacteristics.motto != null)
                          Text(
                            selectedClass!.startingCharacteristics.motto!,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        if (selectedClass!.startingCharacteristics.motto != null)
                          const SizedBox(height: 12),
                        if (selectedClass!.startingCharacteristics.motto == null)
                          const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _buildStatChip(
                              ClassSelectorWidgetText.staminaLabel,
                              '${_calculateStamina(selectedClass!.startingCharacteristics.baseStamina, selectedClass!.startingCharacteristics.staminaPerLevel, selectedLevel)}${ClassSelectorWidgetText.staminaValueSuffixPrefix}${selectedClass!.startingCharacteristics.baseStamina}${ClassSelectorWidgetText.staminaValueSuffixMiddle}${selectedClass!.startingCharacteristics.staminaPerLevel}${ClassSelectorWidgetText.staminaValueSuffixSuffix}',
                            ),
                            _buildStatChip(
                              ClassSelectorWidgetText.recoveriesLabel,
                              '${selectedClass!.startingCharacteristics.baseRecoveries}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _calculateStamina(int baseStamina, int staminaPerLevel, int level) {
    return baseStamina + (staminaPerLevel * (level - 1));
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label${ClassSelectorWidgetText.statLabelSuffix}',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
