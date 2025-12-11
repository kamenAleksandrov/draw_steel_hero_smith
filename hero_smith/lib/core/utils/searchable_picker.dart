import 'package:flutter/material.dart';

/// Represents an option in a searchable picker.
class SearchableOption<T> {
  const SearchableOption({
    required this.label,
    required this.value,
    this.subtitle,
    this.isDisabled = false,
    this.disabledReason,
  });

  final String label;
  final T? value;
  final String? subtitle;
  
  /// If true, this option is shown but cannot be selected.
  final bool isDisabled;
  
  /// Reason shown when the option is disabled (e.g., "Already selected").
  final String? disabledReason;
}

/// Result from a searchable picker selection.
class SearchablePickerResult<T> {
  const SearchablePickerResult({required this.value});

  final T? value;
}

/// Configuration for conflict detection in pickers.
class PickerConflictConfig {
  const PickerConflictConfig({
    this.existingIds = const {},
    this.pageSelectedIds = const {},
    this.staticGrantIds = const {},
    this.currentSlotId,
  });

  /// IDs already saved in the database for this hero (from hero_entries).
  final Set<String> existingIds;
  
  /// IDs currently selected in other pickers on this page.
  final Set<String> pageSelectedIds;
  
  /// IDs that are statically granted (cannot be changed) from features/subclasses.
  final Set<String> staticGrantIds;
  
  /// The current ID in this slot (should not be excluded from its own picker).
  final String? currentSlotId;

  /// Returns all IDs that should be excluded from selection.
  Set<String> get allExcludedIds {
    final excluded = <String>{};
    excluded.addAll(existingIds);
    excluded.addAll(pageSelectedIds);
    excluded.addAll(staticGrantIds);
    // Don't exclude the current selection from its own picker
    if (currentSlotId != null) {
      excluded.remove(currentSlotId);
    }
    return excluded;
  }

  /// Checks if an ID is blocked and returns the reason.
  String? getBlockReason(String? id) {
    if (id == null || id.isEmpty) return null;
    if (id == currentSlotId) return null;
    
    if (staticGrantIds.contains(id)) {
      return 'Granted by a feature (cannot be changed)';
    }
    if (existingIds.contains(id)) {
      return 'Already owned by this hero';
    }
    if (pageSelectedIds.contains(id)) {
      return 'Already selected on this page';
    }
    return null;
  }
}

/// A notification widget that shows when there are static grant conflicts.
class StaticGrantConflictNotice extends StatelessWidget {
  const StaticGrantConflictNotice({
    super.key,
    required this.conflictingIds,
    required this.itemType,
    this.onDismiss,
  });

  final Set<String> conflictingIds;
  final String itemType; // e.g., "skill", "language"
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    if (conflictingIds.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duplicate $itemType${conflictingIds.length > 1 ? 's' : ''} detected',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Multiple features grant the same $itemType. '
                  'Discuss with your Director to choose an alternative.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
              iconSize: 20,
            ),
        ],
      ),
    );
  }
}

/// Shows a searchable picker dialog with exclusion support.
/// 
/// Parameters:
/// - [context]: Build context for the dialog.
/// - [title]: Title shown at the top of the picker.
/// - [options]: List of options to display.
/// - [selected]: Currently selected value.
/// - [conflictConfig]: Optional configuration for excluding already-selected items.
/// - [autofocusSearch]: Whether to auto-focus the search field (default: false).
/// - [showDisabledOptions]: Whether to show disabled options in the list (default: true).
/// - [emptyOptionLabel]: Label for an empty/clear option (e.g., "None").
Future<SearchablePickerResult<T>?> showSearchablePicker<T>({
  required BuildContext context,
  required String title,
  required List<SearchableOption<T>> options,
  T? selected,
  PickerConflictConfig? conflictConfig,
  bool autofocusSearch = false,
  bool showDisabledOptions = true,
  String? emptyOptionLabel,
}) {
  return showDialog<SearchablePickerResult<T>>(
    context: context,
    builder: (dialogContext) {
      final controller = TextEditingController();
      var query = '';

      return StatefulBuilder(
        builder: (context, setState) {
          final normalizedQuery = query.trim().toLowerCase();
          
          // Filter by search query
          List<SearchableOption<T>> filtered = normalizedQuery.isEmpty
              ? options
              : options
                  .where(
                    (option) =>
                        option.label.toLowerCase().contains(normalizedQuery) ||
                        (option.subtitle?.toLowerCase().contains(normalizedQuery) ?? false),
                  )
                  .toList();

          // Apply conflict config to mark disabled options
          if (conflictConfig != null) {
            filtered = filtered.map((option) {
              final id = option.value?.toString();
              final blockReason = conflictConfig.getBlockReason(id);
              if (blockReason != null && !option.isDisabled) {
                return SearchableOption<T>(
                  label: option.label,
                  value: option.value,
                  subtitle: option.subtitle,
                  isDisabled: true,
                  disabledReason: blockReason,
                );
              }
              return option;
            }).toList();
          }

          // Optionally hide disabled options
          if (!showDisabledOptions) {
            filtered = filtered.where((o) => !o.isDisabled).toList();
          }

          final theme = Theme.of(context);
          final scheme = theme.colorScheme;

          return Dialog(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: 500,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: controller,
                      autofocus: autofocusSearch,
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          query = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No matches found')),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length + (emptyOptionLabel != null ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Handle empty option at the top
                              if (emptyOptionLabel != null && index == 0) {
                                final isSelected = selected == null;
                                return ListTile(
                                  title: Text(
                                    emptyOptionLabel,
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  trailing: isSelected ? const Icon(Icons.check) : null,
                                  onTap: () => Navigator.of(context).pop(
                                    SearchablePickerResult<T>(value: null),
                                  ),
                                );
                              }
                              
                              final optionIndex = emptyOptionLabel != null ? index - 1 : index;
                              final option = filtered[optionIndex];
                              final isSelected = option.value == selected ||
                                  (option.value == null && selected == null);
                              
                              if (option.isDisabled) {
                                return ListTile(
                                  title: Text(
                                    option.label,
                                    style: TextStyle(
                                      color: scheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  subtitle: Text(
                                    option.disabledReason ?? 'Unavailable',
                                    style: TextStyle(
                                      color: scheme.error.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  enabled: false,
                                );
                              }

                              return ListTile(
                                title: Text(option.label),
                                subtitle: option.subtitle != null
                                    ? Text(option.subtitle!)
                                    : null,
                                trailing: isSelected ? const Icon(Icons.check) : null,
                                onTap: () => Navigator.of(context).pop(
                                  SearchablePickerResult<T>(value: option.value),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Helper to build options from components, automatically marking excluded ones.
List<SearchableOption<String?>> buildComponentOptions({
  required Iterable<dynamic> components,
  required String Function(dynamic) idSelector,
  required String Function(dynamic) labelSelector,
  String Function(dynamic)? subtitleSelector,
  PickerConflictConfig? conflictConfig,
  bool includeNoneOption = false,
  String noneLabel = 'None',
}) {
  final options = <SearchableOption<String?>>[];
  
  if (includeNoneOption) {
    options.add(SearchableOption<String?>(
      label: noneLabel,
      value: null,
    ));
  }
  
  for (final component in components) {
    final id = idSelector(component);
    final label = labelSelector(component);
    final subtitle = subtitleSelector?.call(component);
    
    String? disabledReason;
    if (conflictConfig != null) {
      disabledReason = conflictConfig.getBlockReason(id);
    }
    
    options.add(SearchableOption<String?>(
      label: label,
      value: id,
      subtitle: subtitle,
      isDisabled: disabledReason != null,
      disabledReason: disabledReason,
    ));
  }
  
  return options;
}
