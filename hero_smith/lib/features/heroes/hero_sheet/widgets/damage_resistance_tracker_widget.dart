import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/damage_resistance_model.dart';
import '../../../../core/services/ancestry_bonus_service.dart';

/// Widget for tracking damage immunities and weaknesses.
/// Displays a merged view where immunity and weakness are additive:
/// e.g., 5 immunity + 3 weakness = 2 immunity (net).
/// Users can click on the net value to modify base immunity/weakness values.
class DamageResistanceTrackerWidget extends ConsumerStatefulWidget {
  const DamageResistanceTrackerWidget({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<DamageResistanceTrackerWidget> createState() =>
      _DamageResistanceTrackerWidgetState();
}

class _DamageResistanceTrackerWidgetState
    extends ConsumerState<DamageResistanceTrackerWidget> {
  HeroDamageResistances _resistances = HeroDamageResistances.empty;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(ancestryBonusServiceProvider);
      final resistances = await service.loadDamageResistances(widget.heroId);
      if (mounted) {
        setState(() {
          _resistances = resistances;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading resistances: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    try {
      final service = ref.read(ancestryBonusServiceProvider);
      await service.saveDamageResistances(widget.heroId, _resistances);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving resistances: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddDamageTypeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Damage Type'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: DamageTypes.all.length,
              itemBuilder: (context, index) {
                final type = DamageTypes.all[index];
                final existing = _resistances.forType(type);
                final isTracked = existing != null;
                
                return ListTile(
                  leading: Icon(
                    _getDamageTypeIcon(type),
                    color: _getDamageTypeColor(type),
                  ),
                  title: Text(DamageTypes.displayName(type)),
                  trailing: isTracked
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: isTracked
                      ? null
                      : () {
                          _addDamageType(type);
                          Navigator.of(context).pop();
                        },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _showCustomDamageTypeDialog(context),
              child: const Text('Custom...'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCustomDamageTypeDialog(BuildContext parentContext) async {
    final controller = TextEditingController();
    Navigator.of(parentContext).pop(); // Close the add dialog
    
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Custom Damage Type'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Damage Type Name',
                hintText: 'e.g., Radiant',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Add'),
              ),
            ],
          );
        },
      );

      if (result == true && controller.text.trim().isNotEmpty) {
        _addDamageType(controller.text.trim().toLowerCase());
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 100));
      controller.dispose();
    }
  }

  void _addDamageType(String type) {
    setState(() {
      _resistances = _resistances.upsertResistance(
        DamageResistance(damageType: type),
      );
    });
    _save();
  }

  void _removeDamageType(String type) {
    setState(() {
      _resistances = _resistances.removeResistance(type);
    });
    _save();
  }

  Future<void> _showEditResistanceDialog(DamageResistance resistance) async {
    final immunityController = TextEditingController(
      text: resistance.baseImmunity.toString(),
    );
    final weaknessController = TextEditingController(
      text: resistance.baseWeakness.toString(),
    );

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Edit ${DamageTypes.displayName(resistance.damageType)}'),
            content: StatefulBuilder(
              builder: (context, setState) {
                final baseImm =
                    int.tryParse(immunityController.text) ?? resistance.baseImmunity;
                final baseWeak =
                    int.tryParse(weaknessController.text) ?? resistance.baseWeakness;
                final totalImm = baseImm + resistance.bonusImmunity;
                final totalWeak = baseWeak + resistance.bonusWeakness;
                final net = totalImm - totalWeak;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Net Result: ${_formatNetValue(net)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: net > 0
                                  ? Colors.green
                                  : net < 0
                                      ? Colors.red
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Total Immunity: $totalImm (Base: $baseImm + Bonus: ${resistance.bonusImmunity})'),
                          Text('Total Weakness: $totalWeak (Base: $baseWeak + Bonus: ${resistance.bonusWeakness})'),
                        ],
                      ),
                    ),
                    if (resistance.sources.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Sources:',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: resistance.sources
                            .map((s) => Chip(
                                  label: Text(s, style: const TextStyle(fontSize: 11)),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Base values inputs
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: immunityController,
                            decoration: const InputDecoration(
                              labelText: 'Base Immunity',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: weaknessController,
                            decoration: const InputDecoration(
                              labelText: 'Base Weakness',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
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
        final newBaseImm = int.tryParse(immunityController.text) ?? 0;
        final newBaseWeak = int.tryParse(weaknessController.text) ?? 0;
        setState(() {
          _resistances = _resistances.upsertResistance(
            resistance.copyWith(
              baseImmunity: newBaseImm,
              baseWeakness: newBaseWeak,
            ),
          );
        });
        _save();
      }
    } finally {
      await Future.delayed(const Duration(milliseconds: 100));
      immunityController.dispose();
      weaknessController.dispose();
    }
  }

  String _formatNetValue(int net) {
    if (net > 0) return 'Immunity $net';
    if (net < 0) return 'Weakness ${net.abs()}';
    return 'None';
  }

  IconData _getDamageTypeIcon(String type) {
    return switch (type.toLowerCase()) {
      'fire' => Icons.local_fire_department,
      'cold' => Icons.ac_unit,
      'lightning' => Icons.bolt,
      'acid' => Icons.science,
      'poison' => Icons.coronavirus,
      'psychic' => Icons.psychology,
      'corruption' => Icons.warning,
      'holy' => Icons.star,
      'sonic' => Icons.volume_up,
      _ => Icons.shield,
    };
  }

  Color _getDamageTypeColor(String type) {
    return switch (type.toLowerCase()) {
      'fire' => Colors.orange,
      'cold' => Colors.lightBlue,
      'lightning' => Colors.yellow.shade700,
      'acid' => Colors.green,
      'poison' => Colors.purple,
      'psychic' => Colors.pink,
      'corruption' => Colors.deepPurple,
      'holy' => Colors.amber,
      'sonic' => Colors.cyan,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Damage Resistances',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Add damage type',
                  onPressed: _showAddDamageTypeDialog,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Immunity - Weakness = Net Value',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),

            // Resistances list
            if (_resistances.resistances.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No damage resistances tracked',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2), // Type
                  1: FlexColumnWidth(2), // Net Value
                  2: FixedColumnWidth(40), // Delete
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    children: [
                      _buildTableHeader('Type'),
                      _buildTableHeader('Net Value'),
                      const SizedBox.shrink(),
                    ],
                  ),
                  ..._resistances.resistances.map(_buildResistanceRow),
                ],
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
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  TableRow _buildResistanceRow(DamageResistance resistance) {
    final net = resistance.netValue;
    final color = net > 0 ? Colors.green : net < 0 ? Colors.red : null;

    return TableRow(
      children: [
        // Type with icon
        InkWell(
          onTap: () => _showEditResistanceDialog(resistance),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getDamageTypeIcon(resistance.damageType),
                  size: 16,
                  color: _getDamageTypeColor(resistance.damageType),
                ),
                const SizedBox(width: 6),
                Text(DamageTypes.displayName(resistance.damageType)),
              ],
            ),
          ),
        ),
        // Net value (clickable)
        InkWell(
          onTap: () => _showEditResistanceDialog(resistance),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color?.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: color != null
                        ? Border.all(color: color.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Text(
                    _formatNetValue(net),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (resistance.sources.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'From: ${resistance.sources.join(", ")}',
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
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
              onPressed: () => _removeDamageType(resistance.damageType),
              tooltip: 'Remove',
            ),
          ),
        ),
      ],
    );
  }
}
