import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/db/app_database.dart';
import '../../../core/models/component.dart' as model;
import '../../../core/models/downtime.dart';
import '../../../core/services/class_data_service.dart';
import '../../../core/theme/text/gear/gear_dialogs_text.dart';
import 'gear_utils.dart';

/// Dialog for adding treasures and imbuements.
class AddTreasureDialog extends StatefulWidget {
  final List<model.Component> availableTreasures;
  final List<DowntimeEntry> availableImbuements;
  final Function(String) onTreasureSelected;
  final Function(String) onImbuementSelected;

  const AddTreasureDialog({
    super.key,
    required this.availableTreasures,
    required this.onTreasureSelected,
    this.availableImbuements = const [],
    required this.onImbuementSelected,
  });

  @override
  State<AddTreasureDialog> createState() => _AddTreasureDialogState();
}

class _AddTreasureDialogState extends State<AddTreasureDialog>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _filterType = 'all';
  String _imbuementFilterType = 'all';
  List<model.Component> _filteredTreasures = [];
  List<DowntimeEntry> _filteredImbuements = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _filteredTreasures = widget.availableTreasures;
    _filteredImbuements = widget.availableImbuements;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _filterTreasures() {
    setState(() {
      _filteredTreasures = widget.availableTreasures.where((treasure) {
        final description = treasure.data['description']?.toString() ?? '';
        final matchesSearch = _searchQuery.isEmpty ||
            treasure.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            description.toLowerCase().contains(_searchQuery.toLowerCase());

        final matchesType =
            _filterType == 'all' || treasure.type == _filterType;

        return matchesSearch && matchesType;
      }).toList();
    });
  }

  void _filterImbuements() {
    setState(() {
      _filteredImbuements = widget.availableImbuements.where((imbuement) {
        final description = imbuement.raw['description']?.toString() ?? '';
        final matchesSearch = _searchQuery.isEmpty ||
            imbuement.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            description.toLowerCase().contains(_searchQuery.toLowerCase());

        final imbuementType = imbuement.raw['type']?.toString() ?? '';
        final matchesType = _imbuementFilterType == 'all' ||
            imbuementType == _imbuementFilterType;

        return matchesSearch && matchesType;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text(GearDialogsText.addTreasureOrImbuementTitle),
      content: SizedBox(
        width: double.maxFinite,
        height: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              tabs: [
                Tab(
                  icon: const Icon(Icons.diamond),
                  text:
                      '${GearDialogsText.treasuresTabLabel} (${widget.availableTreasures.length})',
                ),
                Tab(
                  icon: const Icon(Icons.auto_fix_high),
                  text:
                      '${GearDialogsText.imbuementsTabLabel} (${widget.availableImbuements.length})',
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Search field
            TextField(
              decoration: const InputDecoration(
                labelText: GearDialogsText.addTreasureSearchLabel,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterTreasures();
                _filterImbuements();
              },
            ),
            const SizedBox(height: 12),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTreasuresTab(theme),
                  _buildImbuementsTab(theme),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(GearDialogsText.addTreasureCancelAction),
        ),
      ],
    );
  }

  Widget _buildTreasuresTab(ThemeData theme) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _filterType,
          decoration: const InputDecoration(
            labelText: GearDialogsText.treasureFilterLabel,
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Text(GearDialogsText.treasureFilterAllTypesLabel),
            ),
            DropdownMenuItem(
              value: 'consumable',
              child: Text(GearDialogsText.treasureFilterConsumablesLabel),
            ),
            DropdownMenuItem(
              value: 'trinket',
              child: Text(GearDialogsText.treasureFilterTrinketsLabel),
            ),
            DropdownMenuItem(
              value: 'artifact',
              child: Text(GearDialogsText.treasureFilterArtifactsLabel),
            ),
            DropdownMenuItem(
              value: 'leveled_treasure',
              child: Text(GearDialogsText.treasureFilterLeveledEquipmentLabel),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              _filterType = value;
              _filterTreasures();
            }
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filteredTreasures.isEmpty
              ? Center(
                  child: Text(
                    GearDialogsText.treasuresEmptyMessage,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredTreasures.length,
                  itemBuilder: (context, index) {
                    final treasure = _filteredTreasures[index];
                    final echelon = treasure.data['echelon'] as int?;
                    final description =
                        treasure.data['description']?.toString() ?? '';

                    return ListTile(
                      leading: Icon(
                        getTreasureIcon(treasure.type),
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(treasure.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(getTreasureTypeName(treasure.type)),
                          if (echelon != null)
                            Text(
                              '${GearDialogsText.treasureEchelonPrefix}$echelon',
                            ),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      onTap: () => widget.onTreasureSelected(treasure.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildImbuementsTab(ThemeData theme) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _imbuementFilterType,
          decoration: const InputDecoration(
            labelText: GearDialogsText.imbuementFilterLabel,
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(
              value: 'all',
              child: Text(GearDialogsText.imbuementFilterAllTypesLabel),
            ),
            DropdownMenuItem(
              value: 'armor_imbuement',
              child: Text(GearDialogsText.imbuementFilterArmorLabel),
            ),
            DropdownMenuItem(
              value: 'weapon_imbuement',
              child: Text(GearDialogsText.imbuementFilterWeaponLabel),
            ),
            DropdownMenuItem(
              value: 'implement_imbuement',
              child: Text(GearDialogsText.imbuementFilterImplementLabel),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              _imbuementFilterType = value;
              _filterImbuements();
            }
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filteredImbuements.isEmpty
              ? Center(
                  child: Text(
                    GearDialogsText.imbuementsEmptyMessage,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredImbuements.length,
                  itemBuilder: (context, index) {
                    final imbuement = _filteredImbuements[index];
                    final level = imbuement.raw['level'] as int?;
                    final imbuementType = imbuement.raw['type']?.toString() ?? '';
                    final description =
                        imbuement.raw['description']?.toString() ?? '';

                    return ListTile(
                      leading: Icon(
                        _getImbuementTypeIcon(imbuementType),
                        color: Colors.deepPurple,
                      ),
                      title: Text(imbuement.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(_getImbuementTypeDisplay(imbuementType)),
                              if (level != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: getLevelColor(level).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${GearDialogsText.imbuementLevelPrefix}$level',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: getLevelColor(level),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      isThreeLine: description.isNotEmpty,
                      onTap: () => widget.onImbuementSelected(imbuement.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _getImbuementTypeIcon(String type) {
    switch (type) {
      case 'armor_imbuement':
        return Icons.shield;
      case 'weapon_imbuement':
        return Icons.sports_martial_arts;
      case 'implement_imbuement':
        return Icons.auto_awesome;
      default:
        return Icons.auto_fix_high;
    }
  }

  String _getImbuementTypeDisplay(String type) {
    switch (type) {
      case 'armor_imbuement':
        return GearDialogsText.imbuementTypeArmorDisplay;
      case 'weapon_imbuement':
        return GearDialogsText.imbuementTypeWeaponDisplay;
      case 'implement_imbuement':
        return GearDialogsText.imbuementTypeImplementDisplay;
      default:
        return type.replaceAll('_', ' ');
    }
  }
}

/// Dialog for creating a new inventory container.
class CreateContainerDialog extends StatefulWidget {
  const CreateContainerDialog({super.key});

  @override
  State<CreateContainerDialog> createState() => _CreateContainerDialogState();
}

class _CreateContainerDialogState extends State<CreateContainerDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(GearDialogsText.createContainerTitle),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: GearDialogsText.createContainerNameLabel,
          hintText: GearDialogsText.createContainerNameHint,
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(GearDialogsText.createContainerCancelAction),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text(GearDialogsText.createContainerCreateAction),
        ),
      ],
    );
  }
}

/// Dialog for creating a new inventory item.
class CreateItemDialog extends StatefulWidget {
  const CreateItemDialog({super.key});

  @override
  State<CreateItemDialog> createState() => _CreateItemDialogState();
}

class _CreateItemDialogState extends State<CreateItemDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  int _quantity = 1;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(GearDialogsText.createItemTitle),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: GearDialogsText.createItemNameLabel,
                hintText: GearDialogsText.createItemNameHint,
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: GearDialogsText.createItemDescriptionLabel,
                hintText: GearDialogsText.createItemDescriptionHint,
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(GearDialogsText.createItemQuantityLabel),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                InkWell(
                  onTap: () => _showQuantityInput(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _quantity < 999
                      ? () => setState(() => _quantity++)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(GearDialogsText.createItemCancelAction),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop({
              'name': name,
              'description': _descController.text.trim(),
              'quantity': _quantity.toString(),
            });
          },
          child: const Text(GearDialogsText.createItemAddAction),
        ),
      ],
    );
  }

  Future<void> _showQuantityInput() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _QuantityInputDialog(currentQuantity: _quantity),
    );
    if (result != null) {
      setState(() => _quantity = result);
    }
  }
}

/// Dialog for editing an existing inventory item.
class EditItemDialog extends StatefulWidget {
  const EditItemDialog({
    super.key,
    required this.item,
  });

  final Map<String, dynamic> item;

  @override
  State<EditItemDialog> createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item['name'] as String? ?? '');
    _descController = TextEditingController(text: widget.item['description'] as String? ?? '');
    final qty = widget.item['quantity'];
    _quantity = qty is int ? qty : int.tryParse(qty?.toString() ?? '1') ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(GearDialogsText.editItemTitle),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: GearDialogsText.editItemNameLabel,
                hintText: GearDialogsText.editItemNameHint,
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: GearDialogsText.editItemDescriptionLabel,
                hintText: GearDialogsText.editItemDescriptionHint,
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(GearDialogsText.editItemQuantityLabel),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                InkWell(
                  onTap: () => _showQuantityInput(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _quantity < 999
                      ? () => setState(() => _quantity++)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(GearDialogsText.editItemCancelAction),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop({
              'name': name,
              'description': _descController.text.trim(),
              'quantity': _quantity,
            });
          },
          child: const Text(GearDialogsText.editItemSaveAction),
        ),
      ],
    );
  }

  Future<void> _showQuantityInput() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _QuantityInputDialog(currentQuantity: _quantity),
    );
    if (result != null) {
      setState(() => _quantity = result);
    }
  }
}

/// Dialog for editing a container name.
class EditContainerDialog extends StatefulWidget {
  const EditContainerDialog({super.key, required this.currentName});

  final String currentName;

  @override
  State<EditContainerDialog> createState() => _EditContainerDialogState();
}

class _EditContainerDialogState extends State<EditContainerDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(GearDialogsText.editContainerTitle),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: GearDialogsText.editContainerNameLabel,
          hintText: GearDialogsText.editContainerNameHint,
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(GearDialogsText.editContainerCancelAction),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text(GearDialogsText.editContainerSaveAction),
        ),
      ],
    );
  }
}

/// Dialog for adding favorite kits, wards, prayers, enchantments, or augmentations.
/// Loads available options based on the hero's class and subclass.
class AddFavoriteKitDialog extends StatefulWidget {
  final String heroId;
  final AppDatabase db;
  final Set<String> existingFavoriteIds;
  final Function(String) onKitSelected;

  const AddFavoriteKitDialog({
    super.key,
    required this.heroId,
    required this.db,
    required this.existingFavoriteIds,
    required this.onKitSelected,
  });

  @override
  State<AddFavoriteKitDialog> createState() => _AddFavoriteKitDialogState();
}

class _AddFavoriteKitDialogState extends State<AddFavoriteKitDialog> {
  bool _isLoading = true;
  String? _error;
  List<model.Component> _availableKits = [];
  List<model.Component> _filteredKits = [];
  String _searchQuery = '';
  String _filterType = 'all';
  Set<String> _availableTypes = {};
  String? _heroClassName;

  @override
  void initState() {
    super.initState();
    _loadAvailableKits();
  }

  Future<void> _loadAvailableKits() async {
    try {
      // 1. Get hero's class from hero_entries table
      final classId = await widget.db.getSingleHeroEntryId(widget.heroId, 'class');
      final subclassId = await widget.db.getSingleHeroEntryId(widget.heroId, 'subclass');

      if (classId == null || classId.isEmpty) {
        setState(() {
          _error = GearDialogsText.addFavoriteNoClassError;
          _isLoading = false;
        });
        return;
      }

      // 2. Normalize class ID and get class data
      final normalizedClassId = _normalizeClassId(classId);
      final classDataService = ClassDataService();
      await classDataService.initialize();
      final classData = classDataService.getClassById(normalizedClassId);

      if (classData == null) {
        setState(() {
          _error =
              '${GearDialogsText.addFavoriteClassDataNotFoundPrefix}$classId${GearDialogsText.addFavoriteClassDataNotFoundSuffix}';
          _isLoading = false;
        });
        return;
      }

      _heroClassName = classData.name;
      final normalizedClassName = normalizedClassId.replaceFirst('class_', '').toLowerCase();

      // 3. Check for Fury Stormwight special case
      final normalizedSubclass = subclassId?.toLowerCase().trim() ?? '';
      final isStormwight = normalizedClassId == 'class_fury' &&
          normalizedSubclass.contains('stormwight');

      if (isStormwight) {
        // Only load stormwight kits
        final stormwightKits = await _loadKitsFromJson('stormwight_kits.json');
        setState(() {
          _availableKits = stormwightKits
              .where((k) => !widget.existingFavoriteIds.contains(k.id))
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          _filteredKits = _availableKits;
          _availableTypes = {'stormwight_kit'};
          _isLoading = false;
        });
        return;
      }

      // 4. Parse level 1 features to find allowed equipment types
      final allowedKitTypes = _parseAllowedKitTypes(classData);

      if (allowedKitTypes.isEmpty) {
        setState(() {
          _error = GearDialogsText.addFavoriteNoOptionsError;
          _isLoading = false;
        });
        return;
      }

      // 5. Load items from corresponding JSON files
      final allKits = <model.Component>[];

      for (final kitType in allowedKitTypes) {
        final jsonFile = _getJsonFileForType(kitType);
        if (jsonFile != null) {
          final kits = await _loadKitsFromJson(jsonFile);
          // Filter by available_to_classes
          final filteredByClass = kits.where((kit) {
            final availableToClasses = kit.data['available_to_classes'];
            if (availableToClasses == null) return true;
            if (availableToClasses is List) {
              return availableToClasses
                  .map((e) => e.toString().toLowerCase())
                  .contains(normalizedClassName);
            }
            return true;
          }).toList();
          allKits.addAll(filteredByClass);
        }
      }

      // Remove duplicates and already favorited items
      final uniqueKits = <String, model.Component>{};
      for (final kit in allKits) {
        if (!widget.existingFavoriteIds.contains(kit.id)) {
          uniqueKits[kit.id] = kit;
        }
      }

      setState(() {
        _availableKits = uniqueKits.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _filteredKits = _availableKits;
        _availableTypes = allowedKitTypes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '${GearDialogsText.addFavoriteLoadKitsFailedPrefix}$e';
        _isLoading = false;
      });
    }
  }

  String _normalizeClassId(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.startsWith('class_')) return trimmed;
    return 'class_$trimmed';
  }

  Set<String> _parseAllowedKitTypes(dynamic classData) {
    final types = <String>{};

    // Access level 1 features
    final levels = classData.levels as List<dynamic>;
    if (levels.isEmpty) return types;

    for (final level in levels) {
      final features = level.features as List<dynamic>;
      for (final feature in features) {
        final name = (feature.name as String).trim().toLowerCase();

        // Check for kit-related features
        if (name == 'kit') {
          types.add('kit');
        } else if (name.contains('prayer')) {
          types.add('prayer');
        } else if (name.contains('ward')) {
          types.add('ward');
        } else if (name.contains('enchantment')) {
          types.add('enchantment');
        } else if (name.contains('augmentation') || name.contains('psionic augmentation')) {
          types.add('psionic_augmentation');
        }
      }
    }

    return types;
  }

  String? _getJsonFileForType(String type) {
    switch (type) {
      case 'kit':
        return 'kits.json';
      case 'prayer':
        return 'prayers.json';
      case 'ward':
        return 'wards.json';
      case 'enchantment':
        return 'enchantments.json';
      case 'psionic_augmentation':
        return 'augmentations.json';
      case 'stormwight_kit':
        return 'stormwight_kits.json';
      default:
        return null;
    }
  }

  Future<List<model.Component>> _loadKitsFromJson(String filename) async {
    try {
      final jsonString = await rootBundle.loadString('data/kits/$filename');
      final jsonData = jsonDecode(jsonString) as List<dynamic>;
      return jsonData
          .map((item) => model.Component.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // File might not exist or be malformed
      return [];
    }
  }

  void _filterKits() {
    setState(() {
      _filteredKits = _availableKits.where((kit) {
        final description = kit.data['description']?.toString() ?? '';
        final matchesSearch = _searchQuery.isEmpty ||
            kit.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            description.toLowerCase().contains(_searchQuery.toLowerCase());

        final matchesType = _filterType == 'all' || kit.type == _filterType;

        return matchesSearch && matchesType;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return AlertDialog(
        title: const Text(GearDialogsText.addFavoriteLoadingTitle),
        content: const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(GearDialogsText.addFavoriteLoadingCancelAction),
          ),
        ],
      );
    }

    if (_error != null) {
      return AlertDialog(
        title: const Text(GearDialogsText.addFavoriteErrorTitle),
        content: Text(
          _error!,
          style: TextStyle(color: theme.colorScheme.error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(GearDialogsText.addFavoriteErrorCloseAction),
          ),
        ],
      );
    }

    // Build filter dropdown items
    final filterItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: 'all',
        child: Text(GearDialogsText.addFavoriteFilterAllTypesLabel),
      ),
    ];
    for (final type in _availableTypes) {
      final label = kitTypeLabels[type] ?? kitTypeDisplayName(type);
      final icon = kitTypeIcons[type] ?? kitTypeIcon(type);
      filterItems.add(
        DropdownMenuItem(
          value: type,
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(
        '${GearDialogsText.addFavoriteMainTitle}${_heroClassName != null ? '${GearDialogsText.addFavoriteMainTitleClassPrefix}$_heroClassName${GearDialogsText.addFavoriteMainTitleClassSuffix}' : ''}',
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: GearDialogsText.addFavoriteSearchLabel,
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterKits();
              },
            ),
            const SizedBox(height: 12),
            if (_availableTypes.length > 1)
              DropdownButtonFormField<String>(
                value: _filterType,
                decoration: const InputDecoration(
                  labelText: GearDialogsText.addFavoriteFilterLabel,
                  border: OutlineInputBorder(),
                ),
                items: filterItems,
                onChanged: (value) {
                  if (value != null) {
                    _filterType = value;
                    _filterKits();
                  }
                },
              ),
            if (_availableTypes.length > 1) const SizedBox(height: 16),
            Expanded(
              child: _filteredKits.isEmpty
                  ? Center(
                      child: Text(
                        _availableKits.isEmpty
                            ? GearDialogsText
                                .addFavoriteAllItemsAlreadyFavoritedMessage
                            : GearDialogsText.addFavoriteNoItemsMatchMessage,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredKits.length,
                      itemBuilder: (context, index) {
                        final kit = _filteredKits[index];
                        final description =
                            kit.data['description']?.toString() ?? '';
                        final icon = kitTypeIcons[kit.type] ?? kitTypeIcon(kit.type);

                        return ListTile(
                          leading: Icon(
                            icon,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(kit.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kitTypeDisplayName(kit.type),
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (description.isNotEmpty)
                                Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          isThreeLine: description.isNotEmpty,
                          onTap: () {
                            widget.onKitSelected(kit.id);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(GearDialogsText.addFavoriteMainCancelAction),
        ),
      ],
    );
  }
}

/// Dialog for inputting a quantity value.
class _QuantityInputDialog extends StatefulWidget {
  const _QuantityInputDialog({required this.currentQuantity});

  final int currentQuantity;

  @override
  State<_QuantityInputDialog> createState() => _QuantityInputDialogState();
}

class _QuantityInputDialogState extends State<_QuantityInputDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentQuantity}');
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = int.tryParse(_controller.text);
    if (qty != null && qty >= 1 && qty <= 999) {
      Navigator.of(context).pop(qty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(GearDialogsText.quantityDialogTitle),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: GearDialogsText.quantityDialogLabel,
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(GearDialogsText.quantityDialogCancelAction),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text(GearDialogsText.quantityDialogSetAction),
        ),
      ],
    );
  }
}
