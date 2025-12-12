import 'package:flutter/material.dart';

import '../../../../core/models/component.dart' as model;
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

        final matchesType = _filterType == 'all' || treasure.type == _filterType;

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
                DropdownMenuItem(value: 'consumable', child: Text('Consumables')),
                DropdownMenuItem(value: 'trinket', child: Text('Trinkets')),
                DropdownMenuItem(value: 'artifact', child: Text('Artifacts')),
                DropdownMenuItem(value: 'leveled_treasure', child: Text('Leveled Equipment')),
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
                        final description = treasure.data['description']?.toString() ?? '';
                        
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
                                Text('Echelon $echelon'),
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

/// Dialog for adding kit favorites.
class AddKitFavoriteDialog extends StatefulWidget {
  const AddKitFavoriteDialog({
    super.key,
    required this.availableKits,
    required this.allowedTypes,
    required this.onKitSelected,
    this.classId,
  });

  final List<model.Component> availableKits;
  final List<String> allowedTypes;
  final Function(String) onKitSelected;
  /// The class ID to filter equipment with class restrictions (e.g., psionic_augmentation)
  final String? classId;

  @override
  State<AddKitFavoriteDialog> createState() => _AddKitFavoriteDialogState();
}

class _AddKitFavoriteDialogState extends State<AddKitFavoriteDialog> {
  String _searchQuery = '';
  String _filterType = 'all';
  List<model.Component> _filteredKits = [];

  @override
  void initState() {
    super.initState();
    _filteredKits = _applyClassFilter(widget.availableKits);
  }

  /// Filter items by class restrictions (available_to_classes) - same logic as choose_equipment_widget
  List<model.Component> _applyClassFilter(List<model.Component> items) {
    if (widget.classId == null) return items;
    
    return items.where((item) {
      final availableToClasses = item.data['available_to_classes'];
      if (availableToClasses == null) {
        // No class restriction, available to all
        return true;
      }
      if (availableToClasses is List) {
        // Normalize the class ID for comparison (strip 'class_' prefix, lowercase)
        final normalizedClassId = widget.classId!
            .toLowerCase()
            .replaceFirst('class_', '');
        return availableToClasses
            .map((e) => e.toString().toLowerCase())
            .contains(normalizedClassId);
      }
      return true;
    }).toList();
  }

  void _filterKits() {
    setState(() {
      final classFiltered = _applyClassFilter(widget.availableKits);
      _filteredKits = classFiltered.where((kit) {
        final matchesSearch = _searchQuery.isEmpty ||
            kit.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesType = _filterType == 'all' || kit.type == _filterType;
        return matchesSearch && matchesType;
      }).toList();
    });
  }

  List<DropdownMenuItem<String>> _buildTypeDropdownItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'all', child: Text('All Types')),
    ];

    // Only add types that the hero has access to
    for (final type in widget.allowedTypes) {
      final label = kitTypeLabels[type] ?? type;
      items.add(DropdownMenuItem(value: type, child: Text(label)));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Favorite'),
      content: SizedBox(
        width: double.maxFinite,
        height: 500,
        child: Column(
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
            if (widget.allowedTypes.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _filterType,
                decoration: const InputDecoration(
                  labelText: 'Filter by type',
                  border: OutlineInputBorder(),
                ),
                items: _buildTypeDropdownItems(),
                onChanged: (value) {
                  if (value != null) {
                    _filterType = value;
                    _filterKits();
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: _filteredKits.isEmpty
                  ? Center(
                      child: Text(
                        'No equipment found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredKits.length,
                      itemBuilder: (context, index) {
                        final kit = _filteredKits[index];
                        final icon = kitTypeIcons[kit.type] ?? Icons.inventory_2;
                        final typeLabel = kitTypeLabels[kit.type] ?? kit.type;
                        return ListTile(
                          leading: Icon(icon, color: theme.colorScheme.primary),
                          title: Text(kit.name),
                          subtitle: Text(typeLabel),
                          onTap: () => widget.onKitSelected(kit.id),
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
