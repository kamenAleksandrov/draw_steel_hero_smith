import 'package:flutter/material.dart';

class AbilityFilterDropdown extends StatelessWidget {
  const AbilityFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.allLabelPrefix,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final List<String> options;
  final void Function(String?) onChanged;
  final String allLabelPrefix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value != null
              ? theme.colorScheme.primary
              : (enabled
                    ? theme.colorScheme.outline
                    : theme.colorScheme.outline.withValues(alpha: 0.5)),
          width: value != null ? 2 : 1,
        ),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(
          label,
          style: TextStyle(color: enabled ? null : theme.disabledColor),
        ),
        underline: const SizedBox.shrink(),
        isDense: true,
        items: enabled
            ? [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('$allLabelPrefix$label'),
                ),
                ...options.map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  ),
                ),
              ]
            : null,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
