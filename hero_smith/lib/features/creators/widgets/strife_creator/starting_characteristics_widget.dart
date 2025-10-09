import 'package:flutter/material.dart';

import '../../../../core/controllers/starting_characteristics_controller.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/models/characteristics_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class StartingCharacteristicsWidget extends StatefulWidget {
  const StartingCharacteristicsWidget({
    super.key,
    required this.classData,
    required this.selectedLevel,
    this.selectedArray,
    required this.assignedCharacteristics,
    required this.onArrayChanged,
    required this.onAssignmentsChanged,
    this.onFinalTotalsChanged,
  });

  final ClassData classData;
  final int selectedLevel;
  final CharacteristicArray? selectedArray;
  final Map<String, int> assignedCharacteristics;
  final ValueChanged<CharacteristicArray?> onArrayChanged;
  final ValueChanged<Map<String, int>> onAssignmentsChanged;
  final ValueChanged<Map<String, int>>? onFinalTotalsChanged;

  @override
  State<StartingCharacteristicsWidget> createState() =>
      _StartingCharacteristicsWidgetState();
}

class _StartingCharacteristicsWidgetState
    extends State<StartingCharacteristicsWidget> {
  late StartingCharacteristicsController _controller;
  Map<String, int> _lastAssignments = const {};
  Map<String, int> _lastTotals = const {};
  int _assignmentsCallbackVersion = 0;
  int _totalsCallbackVersion = 0;

  @override
  void initState() {
    super.initState();
    _controller = StartingCharacteristicsController(
      classData: widget.classData,
      selectedLevel: widget.selectedLevel,
      selectedArray: widget.selectedArray,
      initialAssignments: widget.assignedCharacteristics,
    );
    _lastAssignments = Map<String, int>.from(
      _controller.assignedCharacteristics,
    );
    _controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifyParent();
    });
  }

  @override
  void didUpdateWidget(covariant StartingCharacteristicsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classData.classId != widget.classData.classId) {
      _controller.updateClass(widget.classData);
    }

    if (oldWidget.selectedLevel != widget.selectedLevel) {
      _controller.updateLevel(widget.selectedLevel);
    }

    if (oldWidget.selectedArray != widget.selectedArray) {
      _controller.updateArray(widget.selectedArray);
    }

    if (!CharacteristicUtils.intMapEquality.equals(
      oldWidget.assignedCharacteristics,
      widget.assignedCharacteristics,
    )) {
      _controller.updateExternalAssignments(widget.assignedCharacteristics);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    _notifyParent();
  }

  void _notifyParent() {
    final assignments = _controller.assignedCharacteristics;
    if (!CharacteristicUtils.intMapEquality.equals(
      _lastAssignments,
      assignments,
    )) {
      final snapshot = Map<String, int>.from(assignments);
      _lastAssignments = snapshot;
      _assignmentsCallbackVersion += 1;
      final version = _assignmentsCallbackVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || version != _assignmentsCallbackVersion) return;
        widget.onAssignmentsChanged(Map<String, int>.from(snapshot));
      });
    }

    if (widget.onFinalTotalsChanged == null) return;
    final totals = _controller.summary.totals;
    if (!CharacteristicUtils.intMapEquality.equals(_lastTotals, totals)) {
      final snapshot = Map<String, int>.from(totals);
      _lastTotals = snapshot;
      _totalsCallbackVersion += 1;
      final version = _totalsCallbackVersion;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || version != _totalsCallbackVersion) return;
        widget.onFinalTotalsChanged?.call(Map<String, int>.from(snapshot));
      });
    }
  }

  String _displayName(String key) => CharacteristicUtils.displayName(key);

  String _formatSigned(int value) => CharacteristicUtils.formatSigned(value);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _buildContent(),
    );
  }

  Widget _buildContent() {
    final summary = _controller.summary;
    final potencyValues = _controller.computePotency();
    final assignments = _controller.assignments;
    final levelChoices = _controller.levelChoices;
    final levelSelections = _controller.levelChoiceSelections;
    final selectedArray = _controller.selectedArray;

    final assignmentsComplete = selectedArray == null ||
        assignments.values.every((token) => token != null);
    final choicesComplete = levelChoices.isEmpty ||
        levelChoices.every(
          (choice) => (levelSelections[choice.id] ?? '').isNotEmpty,
        );

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Starting Characteristics',
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 4),
            const Text(
              'Review your fixed scores, choose an array, and distribute the remaining values.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            if (_controller.lockedStats.isNotEmpty) ...[
              _buildFixedStatsRow(summary),
              const SizedBox(height: 16),
            ],
            _buildArrayPicker(),
            if (selectedArray == null &&
                _controller.classData.startingCharacteristics
                    .startingCharacteristicsArrays.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: Colors.orangeAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Select an array to unlock assignable values.',
                      style: AppTextStyles.caption
                          .copyWith(color: Colors.orangeAccent),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _buildAssignableSection(summary),
            _buildAssignmentStatus(assignmentsComplete, choicesComplete),
            if (selectedArray != null) ...[
              const SizedBox(height: 12),
              _buildAvailableTokensSection(),
            ],
            const SizedBox(height: 16),
            _buildPotencySection(potencyValues),
            if (_controller.levelChoices.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildLevelChoicesSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFixedStatsRow(CharacteristicSummary summary) {
    final stats = CharacteristicUtils.characteristicOrder
        .where((stat) => _controller.lockedStats.contains(stat))
        .toList();
    if (stats.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == stats.length - 1 ? 0 : 12),
              child: _buildFixedTile(stats[i], summary),
            ),
          ),
      ],
    );
  }

  Widget _buildFixedTile(String stat, CharacteristicSummary summary) {
    final color = AppColors.getCharacteristicColor(stat);
    final fixed = summary.fixed[stat] ?? 0;
    final levelBonus = summary.levelBonuses[stat] ?? 0;
    final total = summary.totals[stat] ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.45), width: 1.2),
        color: color.withOpacity(0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                _displayName(stat),
                style: AppTextStyles.subtitle.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            total.toString(),
            style: AppTextStyles.title.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildValueTag('Fixed ${_formatSigned(fixed)}', color),
              if (levelBonus != 0)
                _buildValueTag('Level ${_formatSigned(levelBonus)}', color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArrayPicker() {
    final arrays = _controller
        .classData.startingCharacteristics.startingCharacteristicsArrays;
    if (arrays.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.4)),
          color: Colors.grey.withOpacity(0.12),
        ),
        child: const Text(
          'All starting characteristics are fixed for this class.',
          style: AppTextStyles.caption,
        ),
      );
    }

    return DropdownButtonFormField<CharacteristicArray?>(
      value: _controller.selectedArray,
      decoration: const InputDecoration(
        labelText: 'Characteristic array',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        const DropdownMenuItem<CharacteristicArray?>(
          value: null,
          child: Text('Select characteristic array'),
        ),
        ...arrays.map((array) {
          final preview = array.values.map(_formatSigned).join(' / ');
          return DropdownMenuItem<CharacteristicArray?>(
            value: array,
            child: Text(
              preview,
              style: AppTextStyles.body,
            ),
          );
        }),
      ],
      onChanged: (array) {
        _controller.updateArray(array);
        widget.onArrayChanged(array);
      },
    );
  }

  Widget _buildAssignableSection(CharacteristicSummary summary) {
    final stats = CharacteristicUtils.characteristicOrder
        .where((stat) => !_controller.lockedStats.contains(stat))
        .toList();
    if (stats.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.4)),
          color: Colors.grey.withOpacity(0.12),
        ),
        child: const Text(
          'No flexible characteristics remain to assign.',
          style: AppTextStyles.caption,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const runSpacing = 12.0;
        const minTileWidth = 260.0;

        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        var columns = (availableWidth / (minTileWidth + spacing)).floor();
        if (columns < 1) {
          columns = 1;
        }
        columns = columns.clamp(1, stats.length).toInt();

        final totalSpacing = spacing * (columns - 1);
        final usableWidth = availableWidth - totalSpacing;
        final tileWidth = usableWidth / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final stat in stats)
              SizedBox(
                width: tileWidth,
                child: _buildAssignableTile(stat, summary),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAssignableTile(String stat, CharacteristicSummary summary) {
    final color = AppColors.getCharacteristicColor(stat);
    final fixed = summary.fixed[stat] ?? 0;
    final arrayValue = summary.array[stat] ?? 0;
    final levelBonus = summary.levelBonuses[stat] ?? 0;
    final total = summary.totals[stat] ?? 0;
    final assignedToken = _controller.assignments[stat];
    final isPending =
        _controller.selectedArray != null && assignedToken == null;

    return DragTarget<CharacteristicValueToken>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) =>
          _controller.assignToken(stat, details.data),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        final backgroundColor =
            isActive ? color.withOpacity(0.18) : color.withOpacity(0.08);
        final borderColor = isPending
            ? Colors.orangeAccent
            : color.withOpacity(isActive ? 0.6 : 0.35);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: isPending ? 1.6 : 1.2,
            ),
            color: backgroundColor,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName(stat),
                      style: AppTextStyles.subtitle.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      total.toString(),
                      style: AppTextStyles.title.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (fixed != 0)
                          _buildValueTag(
                              'Fixed ${_formatSigned(fixed)}', color),
                        if (assignedToken != null)
                          _buildValueTag(
                              'Array ${_formatSigned(arrayValue)}', color)
                        else
                          _buildValueOutlineTag('Array pending', color),
                        if (levelBonus != 0)
                          _buildValueTag(
                              'Level ${_formatSigned(levelBonus)}', color),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildAssignmentSlot(stat, color, assignedToken, isActive),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssignmentSlot(
    String stat,
    Color color,
    CharacteristicValueToken? token,
    bool isActive,
  ) {
    final slotChild = token != null
        ? _buildAssignedTokenChip(token, color)
        : _buildDropHint(color, highlight: isActive);

    return SizedBox(
      width: 120,
      child: Align(
        alignment: Alignment.topRight,
        child: slotChild,
      ),
    );
  }

  Widget _buildDropHint(Color color, {bool highlight = false}) {
    final borderColor = color.withOpacity(highlight ? 0.8 : 0.5);
    final backgroundColor =
        highlight ? color.withOpacity(0.18) : color.withOpacity(0.1);
    final message =
        _controller.selectedArray == null ? 'Select array' : 'Drop value';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        color: backgroundColor,
      ),
      child: Text(
        message,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textPrimary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildTokenVisual(
    CharacteristicValueToken token,
    Color color, {
    bool filled = false,
    bool isFeedback = false,
  }) {
    final background = filled ? color : color.withOpacity(0.18);
    final borderColor = color.withOpacity(filled ? 0.9 : 0.45);
    final textColor = filled ? AppColors.textPrimary : color;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: background,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isFeedback
            ? [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          _formatSigned(token.value),
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableTokenChip(CharacteristicValueToken token) {
    final color = AppColors.secondary;
    final chip = _buildTokenVisual(token, color);

    return Draggable<CharacteristicValueToken>(
      data: token,
      feedback: Material(
        color: Colors.transparent,
        child: _buildTokenVisual(token, color, filled: true, isFeedback: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: chip,
      ),
      child: chip,
    );
  }

  Widget _buildAssignedTokenChip(
    CharacteristicValueToken token,
    Color color,
  ) {
    final chip = _buildTokenVisual(token, color, filled: true);

    return Draggable<CharacteristicValueToken>(
      data: token,
      feedback: Material(
        color: Colors.transparent,
        child: _buildTokenVisual(token, color, filled: true, isFeedback: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: chip,
      ),
      child: chip,
    );
  }

  Widget _buildAssignmentStatus(
      bool assignmentsComplete, bool choicesComplete) {
    if (assignmentsComplete && choicesComplete) {
      return const SizedBox.shrink();
    }
    final parts = <String>[];
    if (!assignmentsComplete) {
      parts.add('Assign all array values');
    }
    if (!choicesComplete) {
      parts.add('Choose level-up bonuses');
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.orangeAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join(' \u2022 '),
              style: AppTextStyles.caption.copyWith(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableTokensSection() {
    final available = _controller.unassignedTokens;
    final accent = AppColors.secondary;
    return DragTarget<CharacteristicValueToken>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => _controller.clearToken(details.data),
      builder: (context, candidateData, rejectedData) {
        final isActive = candidateData.isNotEmpty;
        final background = accent.withOpacity(isActive ? 0.18 : 0.1);
        final border = accent.withOpacity(isActive ? 0.6 : 0.4);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
            color: background,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available values',
                style: AppTextStyles.subtitle.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (available.isEmpty)
                Text(
                  isActive
                      ? 'Release to clear this value.'
                      : 'All values assigned. Drag a chip here to clear it.',
                  style: AppTextStyles.caption,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: available.map(_buildDraggableTokenChip).toList(),
                ),
              if (isActive) ...[
                const SizedBox(height: 8),
                Text(
                  'Release to clear from its current slot.',
                  style: AppTextStyles.caption.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPotencySection(Map<String, int> potencyValues) {
    final progression =
        _controller.classData.startingCharacteristics.potencyProgression;
    final baseKey =
        CharacteristicUtils.normalizeKey(progression.characteristic) ??
            progression.characteristic;
    final baseName = _displayName(baseKey);
    const order = ['strong', 'average', 'weak'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withOpacity(0.4)),
        color: AppColors.accent.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Potency (based on $baseName)',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: order.map((strength) {
              final value = potencyValues[strength] ?? 0;
              final label = strength[0].toUpperCase() + strength.substring(1);
              final color = AppColors.getPotencyColor(strength);
              return _buildPotencyChip(label, value, color);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPotencyChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.7)),
        color: color.withOpacity(0.2),
      ),
      child: Text(
        '$label ${_formatSigned(value)}',
        style: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildLevelChoicesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        color: AppColors.primary.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Level bonuses',
            style: AppTextStyles.subtitle.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ..._controller.levelChoices.map(_buildLevelChoiceDropdown),
        ],
      ),
    );
  }

  Widget _buildLevelChoiceDropdown(LevelChoice choice) {
    final current = _controller.levelChoiceSelections[choice.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        value: current,
        decoration: InputDecoration(
          labelText: 'Level ${choice.level} bonus',
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Select characteristic'),
          ),
          ...CharacteristicUtils.characteristicOrder.map((stat) {
            final label = _displayName(stat);
            return DropdownMenuItem<String?>(
              value: stat,
              child: Text(label, style: AppTextStyles.body),
            );
          }),
        ],
        onChanged: (value) => _controller.selectLevelChoice(choice.id, value),
      ),
    );
  }

  Widget _buildValueTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withOpacity(0.18),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildValueOutlineTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color),
      ),
    );
  }
}
