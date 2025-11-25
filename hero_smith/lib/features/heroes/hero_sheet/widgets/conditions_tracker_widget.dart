import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/models/component.dart';

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

  int get _saveEndsTotal => _saveEndsBase + _saveEndsMod;

  @override
  void initState() {
    super.initState();
    _loadTrackedConditions();
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
      final saveEndsMod = hero.modifications['conditions_save_ends_mod'] ?? 0;
      
      if (mounted) {
        setState(() {
          _saveEndsBase = saveEndsBase;
          _saveEndsMod = saveEndsMod;
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
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Conditions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Save Ends threshold
            Row(
              children: [
                const Text('Save Ends = '),
                InkWell(
                  onTap: _showSaveEndsEditDialog,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _saveEndsTotal.toString(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_saveEndsMod != 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${_saveEndsMod > 0 ? '+' : ''}$_saveEndsMod)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _saveEndsMod > 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Text(' or higher on 1d10'),
              ],
            ),
            const SizedBox(height: 16),
            
            // Conditions table
            if (_trackedConditions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No active conditions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FixedColumnWidth(48),
                },
                border: TableBorder.all(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
                children: [
                  // Header row
                  TableRow(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    children: [
                      _buildTableHeader('Condition'),
                      _buildTableHeader('End of\nTurn'),
                      _buildTableHeader('Save\nEnds'),
                      _buildTableHeader('End of\nEncounter'),
                      _buildTableHeader(''),
                    ],
                  ),
                  // Condition rows
                  for (int i = 0; i < _trackedConditions.length; i++)
                    _buildConditionRow(i, _trackedConditions[i]),
                ],
              ),
            
            const SizedBox(height: 16),
            
            // Add button
            Center(
              child: OutlinedButton.icon(
                onPressed: _showAddConditionDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Condition'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  TableRow _buildConditionRow(int index, TrackedCondition condition) {
    return TableRow(
      children: [
        // Condition name (clickable)
        InkWell(
          onTap: () => _showConditionDetails(condition),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              condition.conditionName,
            ),
          ),
        ),
        // End of Turn radio
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _buildRadioCell(
            index,
            ConditionEndType.endOfTurn,
            condition.endType == ConditionEndType.endOfTurn,
          ),
        ),
        // Save Ends radio
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _buildRadioCell(
            index,
            ConditionEndType.saveEnds,
            condition.endType == ConditionEndType.saveEnds,
          ),
        ),
        // End of Encounter radio
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _buildRadioCell(
            index,
            ConditionEndType.endOfEncounter,
            condition.endType == ConditionEndType.endOfEncounter,
          ),
        ),
        // Delete button
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Center(
            child: IconButton(
              icon: const Icon(Icons.delete, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _removeCondition(index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioCell(int index, ConditionEndType type, bool isSelected) {
    return Center(
      child: Radio<ConditionEndType>(
        value: type,
        groupValue: _trackedConditions[index].endType,
        onChanged: (value) {
          if (value != null) {
            _updateConditionEndType(index, value);
          }
        },
      ),
    );
  }
}
