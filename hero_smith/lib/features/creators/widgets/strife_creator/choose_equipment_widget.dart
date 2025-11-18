import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart';
import '../../../../core/theme/hero_theme.dart';
import '../../../../widgets/kits/kit_card.dart';
import '../../../../widgets/kits/modifier_card.dart';
import '../../../../widgets/kits/stormwight_kit_card.dart';
import '../../../../widgets/kits/ward_card.dart';

/// Configuration for a single equipment slot rendered inside the unified section.
class EquipmentSlot {
  const EquipmentSlot({
    required this.label,
    required this.allowedTypes,
    required this.selectedItemId,
    required this.onChanged,
    this.helperText,
  });

  final String label;
  final List<String> allowedTypes;
  final String? selectedItemId;
  final ValueChanged<String?> onChanged;
  final String? helperText;
}

/// Compact section that renders all equipment and modification requirements together.
class EquipmentAndModificationsWidget extends ConsumerWidget {
  const EquipmentAndModificationsWidget({
    super.key,
    required this.slots,
  });

  final List<EquipmentSlot> slots;

  static const List<String> _allEquipmentTypes = <String>[
    'kit',
    'psionic_augmentation',
    'enchantment',
    'prayer',
    'ward',
    'stormwight_kit',
  ];

  static const Map<String, String> _equipmentTypeTitles = <String, String>{
    'kit': 'Standard Kits',
    'psionic_augmentation': 'Psionic Augmentations',
    'enchantment': 'Enchantments',
    'prayer': 'Prayers',
    'ward': 'Wards',
    'stormwight_kit': 'Stormwight Kits',
  };

  static const Map<String, String> _equipmentTypeChipTitles = <String, String>{
    'kit': 'Standard Kit',
    'psionic_augmentation': 'Augmentation',
    'enchantment': 'Enchantment',
    'prayer': 'Prayer',
    'ward': 'Ward',
    'stormwight_kit': 'Stormwight Kit',
  };

  static const Map<String, IconData> _equipmentTypeIcons = <String, IconData>{
    'kit': Icons.backpack_outlined,
    'psionic_augmentation': Icons.auto_awesome,
    'enchantment': Icons.auto_fix_high,
    'prayer': Icons.self_improvement,
    'ward': Icons.shield_outlined,
    'stormwight_kit': Icons.pets_outlined,
  };

  static const String _removeSignal = '__remove_item__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (slots.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: HeroTheme.sectionCardElevation,
        shape: const RoundedRectangleBorder(borderRadius: HeroTheme.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeroTheme.buildSectionHeader(
              context,
              title: 'Equipment & Modifications',
              subtitle: 'Select the loadout required by your class',
              icon: Icons.inventory_2,
              color: HeroTheme.getStepColor('kit'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < slots.length; i++) ...[
                    _EquipmentSlotTile(slot: slots[i]),
                    if (i != slots.length - 1) const Divider(height: 32),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<Component?> _findItemById(WidgetRef ref, String itemId) async {
    for (final type in _allEquipmentTypes) {
      final components =
          await ref.read(componentsByTypeProvider(type).future);
      for (final component in components) {
        if (component.id == itemId) {
          return component;
        }
      }
    }
    return null;
  }

  static String _placeholderForAllowedTypes(List<String> allowedTypes) {
    if (allowedTypes.length == 1) {
      final type = allowedTypes.first;
      final title = _equipmentTypeTitles[type] ?? _titleize(type);
      return 'Select one of the ${title.toLowerCase()}';
    }
    return 'Select one of the available options';
  }

  static List<String> _normalizeAllowedTypes(List<String> types) {
    final normalized = <String>{};
    for (final type in types) {
      final trimmed = type.trim().toLowerCase();
      if (trimmed.isNotEmpty) {
        normalized.add(trimmed);
      }
    }
    if (normalized.isEmpty) {
      normalized.addAll(_allEquipmentTypes);
    }
    return normalized.toList();
  }

  static List<String> _sortEquipmentTypes(Iterable<String> types) {
    final seen = <String>{};
    final sorted = <String>[];
    for (final type in _allEquipmentTypes) {
      if (types.contains(type) && seen.add(type)) {
        sorted.add(type);
      }
    }
    for (final type in types) {
      if (seen.add(type)) {
        sorted.add(type);
      }
    }
    return sorted;
  }

  static String _titleize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value
        .split(RegExp(r'[_\s]+'))
        .where((segment) => segment.isNotEmpty)
        .map((segment) =>
            '${segment[0].toUpperCase()}${segment.substring(1).toLowerCase()}')
        .join(' ');
  }

}

class _EquipmentSlotTile extends ConsumerWidget {
  const _EquipmentSlotTile({
    required this.slot,
  });

  final EquipmentSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allowedTypes =
        EquipmentAndModificationsWidget._normalizeAllowedTypes(slot.allowedTypes);
    final placeholder =
        EquipmentAndModificationsWidget._placeholderForAllowedTypes(allowedTypes);

    final future = slot.selectedItemId == null
        ? Future<Component?>.value(null)
        : EquipmentAndModificationsWidget._findItemById(
            ref,
            slot.selectedItemId!,
          );

    return FutureBuilder<Component?>(
      future: future,
      builder: (context, snapshot) {
        final selectedItem = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting &&
            slot.selectedItemId != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                final result = await showDialog<String?>(
                  context: context,
                  builder: (dialogContext) => _EquipmentSelectionDialog(
                    slotLabel: slot.label,
                    allowedTypes: allowedTypes,
                    currentItemId: slot.selectedItemId,
                    canRemove: slot.selectedItemId != null,
                  ),
                );

                if (result == null) {
                  return;
                }
                if (result == EquipmentAndModificationsWidget._removeSignal) {
                  slot.onChanged(null);
                } else {
                  slot.onChanged(result);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: slot.label,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: isLoading
                          ? Row(
                              children: const [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Loading selection...'),
                              ],
                            )
                          : Text(
                              selectedItem?.name ?? placeholder,
                              style: selectedItem == null
                                  ? theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    )
                                  : theme.textTheme.bodyMedium,
                            ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: theme.iconTheme.color,
                    ),
                  ],
                ),
              ),
            ),
            if (slot.helperText != null) ...[
              const SizedBox(height: 6),
              Text(
                slot.helperText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
            if (snapshot.hasError) ...[
              const SizedBox(height: 8),
              Text(
                'Unable to load selected item',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ] else if (selectedItem != null && !isLoading) ...[
              const SizedBox(height: 12),
              _SelectedItemPreview(
                item: selectedItem,
                allowedTypes: allowedTypes,
              ),
             
            ],
          ],
        );
      },
    );
  }
}

class _SelectedItemPreview extends StatelessWidget {
  const _SelectedItemPreview({
    required this.item,
    required this.allowedTypes,
  });

  final Component item;
  final List<String> allowedTypes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allowedSet = allowedTypes.map((e) => e.toLowerCase()).toSet();
    final isAllowed = allowedSet.contains(item.type.toLowerCase());

    // Show full equipment card
    final card = _buildCardForComponent(item);

    if (!isAllowed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          card,
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This selection is not allowed for this slot. '
                    'Please choose an option that matches the required type.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return card;
  }

  Widget _buildCardForComponent(Component item) {
    switch (item.type) {
      case 'kit':
        return KitCard(component: item);
      case 'stormwight_kit':
        return StormwightKitCard(component: item);
      case 'ward':
        return WardCard(component: item);
      case 'psionic_augmentation':
      case 'enchantment':
      case 'prayer':
        return ModifierCard(component: item, badgeLabel: item.type);
      default:
        return KitCard(component: item);
    }
  }
}

class _EquipmentCategoryData {
  _EquipmentCategoryData({
    required this.type,
    required this.label,
    required this.chipLabel,
    required this.icon,
    required this.data,
  });

  final String type;
  final String label;
  final String chipLabel;
  final IconData icon;
  final AsyncValue<List<Component>> data;

  String get tabTitle {
    final count = data.maybeWhen(
      data: (items) => items.length,
      orElse: () => null,
    );
    return count == null ? label : '$label ($count)';
  }
}

class _EquipmentSelectionDialog extends ConsumerStatefulWidget {
  const _EquipmentSelectionDialog({
    required this.slotLabel,
    required this.allowedTypes,
    required this.currentItemId,
    required this.canRemove,
  });

  final String slotLabel;
  final List<String> allowedTypes;
  final String? currentItemId;
  final bool canRemove;

  @override
  ConsumerState<_EquipmentSelectionDialog> createState() =>
      _EquipmentSelectionDialogState();
}

class _EquipmentSelectionDialogState
    extends ConsumerState<_EquipmentSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_EquipmentCategoryData> _buildCategories() {
    final normalized = EquipmentAndModificationsWidget._normalizeAllowedTypes(
      widget.allowedTypes,
    );
    final sorted =
        EquipmentAndModificationsWidget._sortEquipmentTypes(normalized);

    return [
      for (final type in sorted)
        _EquipmentCategoryData(
          type: type,
          label: EquipmentAndModificationsWidget._equipmentTypeTitles[type] ??
              EquipmentAndModificationsWidget._titleize(type),
          chipLabel:
              EquipmentAndModificationsWidget._equipmentTypeChipTitles[type] ??
                  EquipmentAndModificationsWidget._titleize(type),
          icon: EquipmentAndModificationsWidget._equipmentTypeIcons[type] ??
              Icons.inventory_2_outlined,
          data: ref.watch(componentsByTypeProvider(type)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final categories = _buildCategories();
    final navigator = Navigator.of(context);

    if (categories.isEmpty) {
      return Dialog(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text('Select ${widget.slotLabel}'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => navigator.pop(),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('No items available'),
              ),
            ],
          ),
        ),
      );
    }

    final hasMultipleCategories = categories.length > 1;

    return DefaultTabController(
      length: categories.length,
      child: Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              AppBar(
                title: Text('Select ${widget.slotLabel}'),
                automaticallyImplyLeading: false,
                actions: [
                  if (widget.canRemove)
                    TextButton.icon(
                      onPressed: () => navigator
                          .pop(EquipmentAndModificationsWidget._removeSignal),
                      icon: const Icon(Icons.clear, color: Colors.white),
                      label: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => navigator.pop(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search equipment...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
              ),
              if (hasMultipleCategories)
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: TabBar(
                    isScrollable: true,
                    tabs: categories
                        .map(
                          (cat) => Tab(
                            text: cat.tabTitle,
                            icon: Icon(cat.icon, size: 18),
                          ),
                        )
                        .toList(),
                  ),
                ),
              Expanded(
                child: hasMultipleCategories
                    ? TabBarView(
                        children: [
                          for (final category in categories)
                            _buildCategoryList(context, category),
                        ],
                      )
                    : _buildCategoryList(context, categories.first),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context,
    _EquipmentCategoryData category,
  ) {
    final query = _searchQuery;

    return category.data.when(
      data: (items) {
        final filtered = query.isEmpty
            ? items
            : items.where((item) {
                final name = item.name.toLowerCase();
                final description =
                    (item.data['description'] as String?)?.toLowerCase() ?? '';
                return name.contains(query) || description.contains(query);
              }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                query.isEmpty
                    ? 'No ${category.label.toLowerCase()} available'
                    : 'No results for "${_searchController.text}"',
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final item = filtered[index];
            final isSelected = item.id == widget.currentItemId;
            final description = item.data['description'] as String?;
            final theme = Theme.of(context);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(item.id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                        : theme.colorScheme.surface,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withOpacity(0.5),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              item.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                          Chip(
                            avatar: Icon(
                              EquipmentAndModificationsWidget
                                      ._equipmentTypeIcons[item.type] ??
                                  Icons.inventory_2_outlined,
                              size: 16,
                            ),
                            label: Text(
                              EquipmentAndModificationsWidget
                                      ._equipmentTypeChipTitles[item.type] ??
                                  EquipmentAndModificationsWidget._titleize(
                                      item.type),
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error loading ${category.label.toLowerCase()}: $error'),
        ),
      ),
    );
  }
}
