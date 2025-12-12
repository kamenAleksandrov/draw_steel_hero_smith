import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/damage_resistance_model.dart';
import '../../../../core/services/ancestry_bonus_service.dart';
import 'hero_main_stats_providers.dart';

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

  @override
  Widget build(BuildContext context) {
    // Watch the stream provider for automatic updates
    final resistancesAsync = ref.watch(heroDamageResistancesProvider(widget.heroId));
    
    return resistancesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error loading resistances: $error'),
            ElevatedButton(
              onPressed: () => ref.invalidate(heroDamageResistancesProvider(widget.heroId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (resistances) {
        // Update local state for editing
        _resistances = resistances;
        return _buildContent(context);
      },
    );
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
      'damage' => Icons.dangerous,
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
      'damage' => Colors.red,
      _ => Colors.grey,
    };
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No damage resistances tracked',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Column(
                children: _resistances.resistances
                    .map((r) => _buildResistanceTile(context, r))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResistanceTile(BuildContext context, DamageResistance resistance) {
    final theme = Theme.of(context);
    final net = resistance.netValue;
    final color = net > 0 ? Colors.green : net < 0 ? Colors.red : null;
    final typeColor = _getDamageTypeColor(resistance.damageType);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _showEditResistanceDialog(resistance),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Row(
            children: [
              // Type icon
              Icon(
                _getDamageTypeIcon(resistance.damageType),
                size: 18,
                color: typeColor,
              ),
              const SizedBox(width: 8),
              // Type name
              Expanded(
                child: Text(
                  DamageTypes.displayName(resistance.damageType),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Net value chip with fixed min width for alignment
              Container(
                constraints: const BoxConstraints(minWidth: 90),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color?.withOpacity(0.15) ?? theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: color != null
                      ? Border.all(color: color.withOpacity(0.4))
                      : null,
                ),
                child: Text(
                  _formatNetValue(net),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color ?? theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Delete button
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: theme.colorScheme.onSurfaceVariant),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeDamageType(resistance.damageType),
                tooltip: 'Remove',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
