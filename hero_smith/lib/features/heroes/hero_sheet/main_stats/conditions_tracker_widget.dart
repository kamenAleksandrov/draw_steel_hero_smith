import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart';

/// Information about a condition immunity and its source
class ConditionImmunityInfo {
  final String conditionId;
  final String conditionName;
  final String sourceType;
  final String sourceId;
  final String? sourceName; // Human-readable source name

  const ConditionImmunityInfo({
    required this.conditionId,
    required this.conditionName,
    required this.sourceType,
    required this.sourceId,
    this.sourceName,
  });
}

enum ConditionEndType {
  endOfTurn,
  saveEnds,
  endOfEncounter,
}

class TrackedCondition {
  final String conditionId;
  final String conditionName;
  final ConditionEndType endType;

  TrackedCondition({
    required this.conditionId,
    required this.conditionName,
    required this.endType,
  });

  TrackedCondition copyWith({
    String? conditionId,
    String? conditionName,
    ConditionEndType? endType,
  }) {
    return TrackedCondition(
      conditionId: conditionId ?? this.conditionId,
      conditionName: conditionName ?? this.conditionName,
      endType: endType ?? this.endType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conditionId': conditionId,
      'conditionName': conditionName,
      'endType': endType.name,
    };
  }

  factory TrackedCondition.fromJson(Map<String, dynamic> json) {
    return TrackedCondition(
      conditionId: json['conditionId'] as String,
      conditionName: json['conditionName'] as String,
      endType: ConditionEndType.values.firstWhere(
        (e) => e.name == json['endType'],
        orElse: () => ConditionEndType.saveEnds,
      ),
    );
  }
}

class ConditionsTrackerWidget extends ConsumerStatefulWidget {
  const ConditionsTrackerWidget({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<ConditionsTrackerWidget> createState() =>
      _ConditionsTrackerWidgetState();
}

class _ConditionsTrackerWidgetState
    extends ConsumerState<ConditionsTrackerWidget> {
  int _saveEndsBase = 6;
  int _saveEndsMod = 0;
  final List<TrackedCondition> _trackedConditions = [];
  List<ConditionImmunityInfo> _conditionImmunities = [];

  int get _saveEndsTotal => _saveEndsBase + _saveEndsMod;

  @override
  void initState() {
    super.initState();
    _loadTrackedConditions();
    _loadConditionImmunities();
  }

  Future<void> _loadTrackedConditions() async {
    try {
      final repo = ref.read(heroRepositoryProvider);
      final hero = await repo.load(widget.heroId);
      if (hero == null || !mounted) return;

      // Load base save ends value
      // Note: We'll need to get this from HeroValues, not hero model
      // For now, we'll fetch it directly
      final db = ref.read(appDatabaseProvider);
      final values = await db.getHeroValues(widget.heroId);
      
      int readInt(String key, {int defaultValue = 0}) {
        final v = values.firstWhereOrNull((e) => e.key == key);
        if (v == null) return defaultValue;
        return v.value ?? int.tryParse(v.textValue ?? '') ?? defaultValue;
      }

      // Load save ends base value
      final saveEndsBase = readInt('conditions.save_ends', defaultValue: 6);
      
      // Load user's manual modifier
      final userMod = hero.modifications['conditions_save_ends_mod'] ?? 0;
      
      // Load modifiers from assembly (ancestry, kit, complication sources)
      int assemblyMod = 0;
      try {
        final assemblyAsync = ref.read(heroAssemblyProvider(widget.heroId));
        final assembly = assemblyAsync.valueOrNull;
        if (assembly != null) {
          // Check for saving_throw stat mod
          assemblyMod = assembly.statMods.getTotalForStat('saving_throw');
        }
      } catch (_) {
        // Assembly not available yet, ignore
      }
      
      // Total mod is user mod + assembly mod
      final totalMod = userMod + assemblyMod;
      
      if (mounted) {
        setState(() {
          _saveEndsBase = saveEndsBase;
          _saveEndsMod = totalMod;
        });
      }

      // Load tracked conditions from conditions list with metadata
      final conditionsData = hero.conditions;
      if (conditionsData.isNotEmpty) {
        final List<TrackedCondition> conditions = [];
        for (final conditionJson in conditionsData) {
          try {
            final decoded = jsonDecode(conditionJson);
            if (decoded is Map<String, dynamic>) {
              conditions.add(TrackedCondition.fromJson(decoded));
            }
          } catch (_) {
            // Skip invalid condition data
          }
        }
        
        if (mounted) {
          setState(() {
            _trackedConditions.clear();
            _trackedConditions.addAll(conditions);
          });
        }
      }
    } catch (e) {
      // Failed to load, but that's okay - start with empty state
    }
  }

  /// Load condition immunities from hero_entries via HeroAssembly
  Future<void> _loadConditionImmunities() async {
    try {
      final assemblyAsync = ref.read(heroAssemblyProvider(widget.heroId));
      final assembly = assemblyAsync.valueOrNull;
      if (assembly == null || !mounted) return;

      final immunities = <ConditionImmunityInfo>[];
      
      for (final entry in assembly.conditionImmunities) {
        // Parse the condition name from the entry
        String conditionName = entry.entryId;
        
        // Try to extract condition name from payload
        if (entry.payload != null) {
          try {
            final payload = jsonDecode(entry.payload!);
            if (payload is Map) {
              conditionName = payload['condition']?.toString() ?? 
                              payload['conditionName']?.toString() ?? 
                              entry.entryId;
            }
          } catch (_) {}
        }
        
        // Clean up the condition name (remove prefixes like "immunity_")
        if (conditionName.startsWith('immunity_')) {
          conditionName = conditionName.substring('immunity_'.length);
        }
        
        // Capitalize first letter
        if (conditionName.isNotEmpty) {
          conditionName = conditionName[0].toUpperCase() + conditionName.substring(1);
        }
        
        // Get source name
        String? sourceName = _getSourceName(entry.sourceType, entry.sourceId);
        
        immunities.add(ConditionImmunityInfo(
          conditionId: entry.entryId,
          conditionName: conditionName,
          sourceType: entry.sourceType,
          sourceId: entry.sourceId,
          sourceName: sourceName,
        ));
      }

      if (mounted) {
        setState(() {
          _conditionImmunities = immunities;
        });
      }
    } catch (e) {
      // Failed to load immunities, continue without them
    }
  }

  /// Get a human-readable name for the source of an immunity
  String? _getSourceName(String sourceType, String sourceId) {
    // Format source type for display
    switch (sourceType) {
      case 'class_feature':
        // Extract feature name from ID (e.g., "feature_null_i_am_the_weapon" -> "I Am the Weapon")
        var name = sourceId;
        if (name.startsWith('feature_')) {
          // Remove "feature_" prefix and class name
          final parts = name.split('_');
          if (parts.length > 2) {
            // Skip "feature" and class name, join the rest
            name = parts.skip(2).map((p) => 
              p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}'
            ).join(' ');
          }
        }
        return 'Feature: $name';
      case 'ancestry':
        return 'Ancestry Trait';
      case 'perk':
        return 'Perk';
      case 'title':
        return 'Title';
      case 'equipment':
      case 'kit':
        return 'Equipment';
      default:
        return sourceType;
    }
  }

  Future<void> _saveTrackedConditions() async {
    try {
      final repo = ref.read(heroRepositoryProvider);
      
      // Save modifier (not the base value)
      await repo.setModification(
        widget.heroId,
        key: 'conditions_save_ends_mod',
        value: _saveEndsMod,
      );

      // Save tracked conditions as JSON strings
      final conditionsJson = _trackedConditions
          .map((c) => jsonEncode(c.toJson()))
          .toList();
      
      // Update the conditions list in the hero
      final hero = await repo.load(widget.heroId);
      if (hero != null) {
        hero.conditions = conditionsJson;
        await repo.save(hero);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving conditions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showSaveEndsEditDialog() async {
    final modController = TextEditingController(text: _saveEndsMod.toString());

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Edit Save Ends Modifier'),
            content: StatefulBuilder(
              builder: (context, setState) {
                final currentMod = int.tryParse(modController.text) ?? _saveEndsMod;
                final total = _saveEndsBase + currentMod;
                
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base: $_saveEndsBase',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: $total',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: modController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(signed: true),
                      decoration: const InputDecoration(
                        labelText: 'Modifier',
                        border: OutlineInputBorder(),
                        helperText: 'Adjustments (-99 to +99)',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                        LengthLimitingTextInputFormatter(3),
                      ],
                      onChanged: (value) {
                        setState(() {}); // Update total display
                      },
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      if (result == true && mounted) {
        final newMod = int.tryParse(modController.text) ?? 0;
        setState(() {
          _saveEndsMod = newMod.clamp(-99, 99);
        });
        _saveTrackedConditions();
      }
    } finally {
      // Brief delay to ensure dialog animation completes and IME handles focus change
      await Future.delayed(const Duration(milliseconds: 100));
      modController.dispose();
    }
  }

  void _addCondition(Component condition) {
    setState(() {
      _trackedConditions.add(
        TrackedCondition(
          conditionId: condition.id,
          conditionName: condition.name,
          endType: ConditionEndType.saveEnds,
        ),
      );
    });
    _saveTrackedConditions();
    Navigator.of(context).pop();
  }

  void _removeCondition(int index) {
    setState(() {
      _trackedConditions.removeAt(index);
    });
    _saveTrackedConditions();
  }

  void _updateConditionEndType(int index, ConditionEndType newType) {
    setState(() {
      _trackedConditions[index] = _trackedConditions[index].copyWith(
        endType: newType,
      );
    });
    _saveTrackedConditions();
  }

  void _showAddConditionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final conditionsAsync = ref.watch(componentsByTypeProvider('condition'));
            
            return AlertDialog(
              title: const Text('Add Condition'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: conditionsAsync.when(
                  data: (conditions) {
                    return ListView.builder(
                      itemCount: conditions.length + 1, // +1 for custom option
                      itemBuilder: (context, index) {
                        if (index == conditions.length) {
                          // Custom condition option at the end
                          return ListTile(
                            leading: const Icon(Icons.add_circle_outline),
                            title: const Text(
                              'Create Custom Condition',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              _showCreateCustomConditionDialog();
                            },
                          );
                        }
                        
                        final condition = conditions[index];
                        return ListTile(
                          title: Text(condition.name),
                          subtitle: Text(
                            condition.data['short_description'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _addCondition(condition),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text('Error loading conditions: $error'),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateCustomConditionDialog() async {
    final nameController = TextEditingController();
    final shortDescController = TextEditingController();
    final longDescController = TextEditingController();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Create Custom Condition'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Condition Name *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: shortDescController,
                    decoration: const InputDecoration(
                      labelText: 'Short Description',
                      border: OutlineInputBorder(),
                      hintText: 'Brief summary of the condition',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: longDescController,
                    decoration: const InputDecoration(
                      labelText: 'Detailed Description',
                      border: OutlineInputBorder(),
                      hintText: 'Full details and effects',
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );

      if (result == true && nameController.text.trim().isNotEmpty) {
        try {
          final repo = ref.read(componentRepositoryProvider);
          final customCondition = await repo.createCustom(
            type: 'condition',
            name: nameController.text.trim(),
            data: {
              'short_description': shortDescController.text.trim(),
              'long_description': longDescController.text.trim(),
            },
          );

          if (mounted) {
            setState(() {
              _trackedConditions.add(
                TrackedCondition(
                  conditionId: customCondition.id,
                  conditionName: customCondition.name,
                  endType: ConditionEndType.saveEnds,
                ),
              );
            });
            _saveTrackedConditions();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Custom condition "${customCondition.name}" created'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error creating condition: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 100));
      nameController.dispose();
      shortDescController.dispose();
      longDescController.dispose();
    }
  }

  void _showConditionDetails(TrackedCondition trackedCondition) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final conditionsAsync = ref.watch(componentsByTypeProvider('condition'));
            
            return AlertDialog(
              title: Text(trackedCondition.conditionName),
              content: SizedBox(
                width: double.maxFinite,
                child: conditionsAsync.when(
                  data: (conditions) {
                    final condition = conditions.firstWhere(
                      (c) => c.id == trackedCondition.conditionId,
                      orElse: () => Component(
                        id: trackedCondition.conditionId,
                        type: 'condition',
                        name: trackedCondition.conditionName,
                        data: const {},
                        source: 'unknown',
                      ),
                    );
                    
                    final shortDesc = condition.data['short_description'] as String? ?? '';
                    final longDesc = condition.data['long_description'] as String? ?? '';
                    
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (shortDesc.isNotEmpty) ...[
                            const Text(
                              'Summary',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(shortDesc),
                            const SizedBox(height: 16),
                          ],
                          if (longDesc.isNotEmpty) ...[
                            const Text(
                              'Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(longDesc),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => const Center(
                    child: Text('Could not load condition details'),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // For save ends, lower is better, so invert colors
    final modColor = _saveEndsMod < 0 
        ? Colors.green 
        : _saveEndsMod > 0 
            ? Colors.red 
            : null;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with save ends
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 6),
                Text(
                  'Conditions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Save Ends compact display
                InkWell(
                  onTap: _showSaveEndsEditDialog,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Save ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '$_saveEndsTotal+',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_saveEndsMod != 0)
                          Text(
                            ' (${_saveEndsMod > 0 ? '+' : ''}$_saveEndsMod)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: modColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Conditions list
            if (_trackedConditions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No active conditions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < _trackedConditions.length; i++)
                    _buildConditionTile(context, i, _trackedConditions[i]),
                ],
              ),
            
            const SizedBox(height: 8),
            
            // Add button
            Center(
              child: TextButton.icon(
                onPressed: _showAddConditionDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Condition'),
              ),
            ),
            
            // Condition Immunities section
            if (_conditionImmunities.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildConditionImmunitiesSection(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConditionImmunitiesSection(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Condition Immunities',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final immunity in _conditionImmunities)
              _buildImmunityChip(context, immunity),
          ],
        ),
      ],
    );
  }

  Widget _buildImmunityChip(BuildContext context, ConditionImmunityInfo immunity) {
    final theme = Theme.of(context);
    
    return Tooltip(
      message: immunity.sourceName ?? 'Unknown source',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              immunity.conditionName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionTile(BuildContext context, int index, TrackedCondition condition) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            // Condition name (clickable, expands)
            Expanded(
              child: InkWell(
                onTap: () => _showConditionDetails(condition),
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(
                    condition.conditionName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            // End type selector (segmented style)
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEndTypeChip(context, index, ConditionEndType.endOfTurn, 'EoT'),
                  _buildEndTypeChip(context, index, ConditionEndType.saveEnds, 'Save'),
                  _buildEndTypeChip(context, index, ConditionEndType.endOfEncounter, 'EoE'),
                ],
              ),
            ),
            // Delete button
            IconButton(
              icon: Icon(Icons.close, size: 18, color: theme.colorScheme.onSurfaceVariant),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              onPressed: () => _removeCondition(index),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndTypeChip(BuildContext context, int index, ConditionEndType type, String label) {
    final theme = Theme.of(context);
    final isSelected = _trackedConditions[index].endType == type;
    
    return GestureDetector(
      onTap: () => _updateConditionEndType(index, type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSelected 
                ? theme.colorScheme.onPrimary 
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
