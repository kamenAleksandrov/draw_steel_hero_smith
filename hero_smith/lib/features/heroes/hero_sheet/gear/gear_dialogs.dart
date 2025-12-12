import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/models/component.dart' as model;
import '../../../../core/services/class_data_service.dart';
import 'gear_utils.dart';

/// Dialog for adding treasures.
class AddTreasureDialog extends StatefulWidget {
  final List<model.Component> availableTreasures;
  final Function(String) onTreasureSelected;

  const AddTreasureDialog({
    super.key,
    required this.availableTreasures,
    required this.onTreasureSelected,
  });

  @override
  State<AddTreasureDialog> createState() => _AddTreasureDialogState();
}

class _AddTreasureDialogState extends State<AddTreasureDialog> {
  String _searchQuery = '';
  String _filterType = 'all';
  List<model.Component> _filteredTreasures = [];

  @override
  void initState() {
    super.initState();
    _filteredTreasures = widget.availableTreasures;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Treasure'),
      content: SizedBox(
        width: double.maxFinite,
        height: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search treasures',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterTreasures();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _filterType,
              decoration: const InputDecoration(
                labelText: 'Filter by type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Types')),
                DropdownMenuItem(
                    value: 'consumable', child: Text('Consumables')),
                DropdownMenuItem(value: 'trinket', child: Text('Trinkets')),
                DropdownMenuItem(value: 'artifact', child: Text('Artifacts')),
                DropdownMenuItem(
                    value: 'leveled_treasure',
                    child: Text('Leveled Equipment')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _filterType = value;
                  _filterTreasures();
                }
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredTreasures.isEmpty
                  ? Center(
                      child: Text(
                        'No treasures found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
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
                              if (echelon != null) Text('Echelon $echelon'),
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
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
      title: const Text('New Container'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Container name',
          hintText: 'e.g., Backpack, Belt Pouch...',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Create'),
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

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Item'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item name',
                hintText: 'e.g., Rope, Torch...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g., 50ft hemp rope',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop({
              'name': name,
              'description': _descController.text.trim(),
            });
          },
          child: const Text('Add'),
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
          _error = 'Hero has no class selected. Please set a class first.';
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
          _error = 'Could not find class data for "$classId".';
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
          _error = 'This class has no available kit/ward/prayer/enchantment/augmentation options.';
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
        _error = 'Failed to load kits: $e';
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
        title: const Text('Add Favorite'),
        content: const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    if (_error != null) {
      return AlertDialog(
        title: const Text('Add Favorite'),
        content: Text(
          _error!,
          style: TextStyle(color: theme.colorScheme.error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    // Build filter dropdown items
    final filterItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Types')),
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
      title: Text('Add Favorite${_heroClassName != null ? ' ($_heroClassName)' : ''}'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search',
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
                  labelText: 'Filter by type',
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
                            ? 'All available items are already in favorites.'
                            : 'No items match your search.',
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
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}