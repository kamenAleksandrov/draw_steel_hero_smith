import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart';
import '../../../../core/theme/hero_theme.dart';
import '../../../../widgets/kits/kit_card.dart';
import '../../../../widgets/kits/modifier_card.dart';
import '../../../../widgets/kits/stormwight_kit_card.dart';
import '../../../../widgets/kits/ward_card.dart';

const List<String> _allKitTypes = <String>[
  'kit',
  'psionic_augmentation',
  'enchantment',
  'prayer',
  'ward',
  'stormwight_kit',
];

const Map<String, String> _kitTypeTitles = <String, String>{
  'kit': 'Standard Kits',
  'psionic_augmentation': 'Psionic Augmentations',
  'enchantment': 'Enchantments',
  'prayer': 'Prayers',
  'ward': 'Wards',
  'stormwight_kit': 'Stormwight Kits',
};

const Map<String, String> _kitTypeChipTitles = <String, String>{
  'kit': 'Standard Kit',
  'psionic_augmentation': 'Augmentation',
  'enchantment': 'Enchantment',
  'prayer': 'Prayer',
  'ward': 'Ward',
  'stormwight_kit': 'Stormwight Kit',
};

const Map<String, IconData> _kitTypeIcons = <String, IconData>{
  'kit': Icons.backpack_outlined,
  'psionic_augmentation': Icons.auto_awesome,
  'enchantment': Icons.auto_fix_high,
  'prayer': Icons.self_improvement,
  'ward': Icons.shield_outlined,
  'stormwight_kit': Icons.pets_outlined,
};

const String _removeKitSignal = '__remove_kit__';

String _titleize(String value) {
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

List<String> _normalizeAllowedTypes(List<String> types) {
  final normalized = <String>{};
  for (final type in types) {
    final trimmed = type.trim().toLowerCase();
    if (trimmed.isNotEmpty) {
      normalized.add(trimmed);
    }
  }
  if (normalized.isEmpty) {
    normalized.addAll(_allKitTypes);
  }
  return normalized.toList();
}

List<String> _sortKitTypes(Iterable<String> types) {
  final seen = <String>{};
  final sorted = <String>[];
  for (final type in _allKitTypes) {
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

class ChooseKitWidget extends ConsumerWidget {
  const ChooseKitWidget({
    super.key,
    required this.selectedKitId,
    required this.onKitChanged,
    this.allowedKitTypes = const [],
    this.label,
  });

  final String? selectedKitId;
  final ValueChanged<String?> onKitChanged;
  final List<String> allowedKitTypes;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kitTypes = _sortKitTypes(_normalizeAllowedTypes(allowedKitTypes));
    final categories = [
      for (final kitType in kitTypes)
        _KitCategoryData(
          type: kitType,
          label: _kitTypeTitles[kitType] ?? _titleize(kitType),
          chipLabel: _kitTypeChipTitles[kitType] ?? _titleize(kitType),
          icon: _kitTypeIcons[kitType] ?? Icons.inventory_2_outlined,
          data: ref.watch(componentsByTypeProvider(kitType)),
        ),
    ];

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
              title: label ?? 'Kit',
              subtitle: 'Choose your fighting style and equipment',
              icon: Icons.inventory_2,
              color: HeroTheme.getStepColor('kit'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Your Kit',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A kit determines what weapons and armor you can use effectively, '
                    'and grants bonuses to your combat statistics.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories
                          .map(
                            (category) => Chip(
                              avatar: Icon(
                                category.icon,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              label: Text(category.chipLabel),
                              backgroundColor: theme.colorScheme.primaryContainer
                                  .withOpacity(0.2),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (selectedKitId != null) ...[
                    _buildSelectedKitDisplay(
                      context,
                      ref,
                      selectedKitId!,
                      kitTypes,
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton.icon(
                    onPressed: categories.isEmpty
                        ? null
                        : () => _showKitSelectionDialog(
                              context,
                              categories,
                              canRemove: selectedKitId != null,
                            ),
                    icon: Icon(
                      selectedKitId == null
                          ? Icons.add
                          : Icons.swap_horiz_outlined,
                    ),
                    label: Text(
                      selectedKitId == null ? 'Select Kit' : 'Change Kit',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HeroTheme.getStepColor('kit'),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (selectedKitId != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => onKitChanged(null),
                      icon: const Icon(Icons.clear),
                      label: const Text('Remove Kit'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedKitDisplay(
    BuildContext context,
    WidgetRef ref,
    String kitId,
    List<String> allowedTypes,
  ) {
    final theme = Theme.of(context);
    final allowedSet = allowedTypes.map((e) => e.toLowerCase()).toSet();

    return FutureBuilder<Component?>(
      future: _findKitById(ref, kitId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Selected kit not found: $kitId',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          );
        }

        final kit = snapshot.data!;
        final isAllowed =
            allowedSet.isEmpty || allowedSet.contains(kit.type.toLowerCase());

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      kit.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      _kitTypeIcons[kit.type] ?? Icons.inventory_2_outlined,
                      size: 18,
                    ),
                    label: Text(
                      _kitTypeChipTitles[kit.type] ?? _titleize(kit.type),
                    ),
                  ),
                ],
              ),
              if (kit.data['description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  kit.data['description'].toString(),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (!isAllowed) ...[
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
                          'This kit is not available for the selected class. '
                          'Choose a new option that matches the allowed kit types.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<Component?> _findKitById(WidgetRef ref, String kitId) async {
    for (final type in _allKitTypes) {
      final components =
          await ref.read(componentsByTypeProvider(type).future);
      for (final component in components) {
        if (component.id == kitId) {
          return component;
        }
      }
    }
    return null;
  }

  Future<void> _showKitSelectionDialog(
    BuildContext context,
    List<_KitCategoryData> categories, {
    required bool canRemove,
  }) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => _KitSelectionDialog(
        categories: categories,
        currentKitId: selectedKitId,
        canRemove: canRemove,
      ),
    );

    if (result == null) {
      return;
    }
    if (result == _removeKitSignal) {
      onKitChanged(null);
    } else {
      onKitChanged(result);
    }
  }
}

class _KitCategoryData {
  _KitCategoryData({
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
      data: (kits) => kits.length,
      orElse: () => null,
    );
    return count == null ? label : '$label ($count)';
  }
}

class _KitSelectionDialog extends StatelessWidget {
  const _KitSelectionDialog({
    required this.categories,
    required this.currentKitId,
    required this.canRemove,
  });

  final List<_KitCategoryData> categories;
  final String? currentKitId;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);

    if (categories.isEmpty) {
      return Dialog(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Select Kit'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => navigator.pop(),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No kits available for this class.'),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 820,
          maxHeight: 700,
        ),
        child: Column(
          children: [
            AppBar(
              title: const Text('Select Kit'),
              automaticallyImplyLeading: false,
              actions: [
                if (canRemove)
                  TextButton(
                    onPressed: () => navigator.pop(_removeKitSignal),
                    child: const Text('Remove Kit'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => navigator.pop(),
                ),
              ],
            ),
            Expanded(
              child: DefaultTabController(
                length: categories.length,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        for (final category in categories)
                          Tab(
                            icon: Icon(category.icon),
                            text: category.tabTitle,
                          ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final category in categories)
                            _KitSelectionTab(
                              category: category,
                              currentKitId: currentKitId,
                              onSelect: (kitId) => navigator.pop(kitId),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KitSelectionTab extends StatelessWidget {
  const _KitSelectionTab({
    required this.category,
    required this.currentKitId,
    required this.onSelect,
  });

  final _KitCategoryData category;
  final String? currentKitId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return category.data.when(
      data: (kits) {
        if (kits.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No ${category.label.toLowerCase()} available'),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: kits.length,
          itemBuilder: (context, index) {
            final kit = kits[index];
            final isSelected = kit.id == currentKitId;
            final actionLabel = isSelected
                ? 'Selected'
                : 'Select ${category.chipLabel.toLowerCase()}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onSelect(kit.id),
                      child: _kitCardForComponent(kit),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: isSelected ? null : () => onSelect(kit.id),
                      icon: Icon(
                        isSelected ? Icons.check_circle : Icons.check,
                      ),
                      label: Text(actionLabel),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading ${category.label.toLowerCase()}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _kitCardForComponent(Component kit) {
  switch (kit.type) {
    case 'kit':
      return KitCard(component: kit);
    case 'stormwight_kit':
      return StormwightKitCard(component: kit);
    case 'ward':
      return WardCard(component: kit);
    case 'psionic_augmentation':
    case 'enchantment':
    case 'prayer':
      return ModifierCard(component: kit, badgeLabel: kit.type);
    default:
      return KitCard(component: kit);
  }
}
