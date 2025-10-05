import 'package:flutter/material.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

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
            Text(
              'Hero Class',
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 4),
            Text(
              'Choose your hero\'s class',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ClassData>(
              value: selectedClass,
              decoration: const InputDecoration(
                labelText: 'Class',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: availableClasses
                  .map((classData) => DropdownMenuItem(
                        value: classData,
                        child: Text(
                          classData.name,
                          style: AppTextStyles.body,
                        ),
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
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.secondary,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedClass!
                              .startingCharacteristics.heroicResourceName,
                          style: AppTextStyles.subtitle.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (selectedClass!.startingCharacteristics.motto != null)
                      Text(
                        selectedClass!.startingCharacteristics.motto!,
                        style: AppTextStyles.caption.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (selectedClass!.startingCharacteristics.motto != null)
                      const SizedBox(height: 12),
                    if (selectedClass!.startingCharacteristics.motto == null)
                      const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildStatChip(
                          'Stamina',
                          '${_calculateStamina(selectedClass!.startingCharacteristics.baseStamina, selectedClass!.startingCharacteristics.staminaPerLevel, selectedLevel)} (Base ${selectedClass!.startingCharacteristics.baseStamina} + ${selectedClass!.startingCharacteristics.staminaPerLevel}/lvl)',
                        ),
                        _buildStatChip(
                          'Recoveries',
                          '${selectedClass!.startingCharacteristics.baseRecoveries}',
                        ),
                        _buildStatChip(
                          'Speed',
                          '${selectedClass!.startingCharacteristics.baseSpeed}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _calculateStamina(int baseStamina, int staminaPerLevel, int level) {
    return baseStamina + (staminaPerLevel * (level - 1));
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
