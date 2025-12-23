import 'package:flutter/material.dart';

import '../../../../core/controllers/starting_characteristics_controller.dart';
import '../../../../core/models/class_data.dart';
import '../../../../core/models/characteristics_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/text/starting_characteristics_widget_text.dart';

class StartingCharacteristicsWidget extends StatefulWidget {
  const StartingCharacteristicsWidget({
    super.key,
    required this.classData,
    required this.selectedLevel,
    this.selectedArray,
    required this.assignedCharacteristics,
    this.initialLevelChoiceSelections,
    required this.onArrayChanged,
    required this.onAssignmentsChanged,
    this.onFinalTotalsChanged,
    this.onLevelChoiceSelectionsChanged,
  });

  final ClassData classData;
  final int selectedLevel;
  final CharacteristicArray? selectedArray;
  final Map<String, int> assignedCharacteristics;
  final Map<String, String?>? initialLevelChoiceSelections;
  final ValueChanged<CharacteristicArray?> onArrayChanged;
  final ValueChanged<Map<String, int>> onAssignmentsChanged;
  final ValueChanged<Map<String, int>>? onFinalTotalsChanged;
  final ValueChanged<Map<String, String?>>? onLevelChoiceSelectionsChanged;

  @override
  State<StartingCharacteristicsWidget> createState() =>
      _StartingCharacteristicsWidgetState();
}

class _StartingCharacteristicsWidgetState
    extends State<StartingCharacteristicsWidget> {
  late StartingCharacteristicsController _controller;
  Map<String, int> _lastAssignments = const {};
  Map<String, int> _lastTotals = const {};
  Map<String, String?> _lastLevelChoiceSelections = const {};
  int _assignmentsCallbackVersion = 0;
  int _totalsCallbackVersion = 0;
  int _levelChoiceSelectionsCallbackVersion = 0;

  @override
  void initState() {
    super.initState();
    _controller = StartingCharacteristicsController(
      classData: widget.classData,
      selectedLevel: widget.selectedLevel,
      selectedArray: widget.selectedArray,
      initialAssignments: widget.assignedCharacteristics,
      initialLevelChoiceSelections: widget.initialLevelChoiceSelections,
    );
    _lastAssignments = Map<String, int>.from(
      _controller.assignedCharacteristics,
    );
    _lastLevelChoiceSelections = Map<String, String?>.from(
      _controller.levelChoiceSelections,
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

    if (widget.onFinalTotalsChanged != null) {
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

    // Notify parent of level choice selection changes
    if (widget.onLevelChoiceSelectionsChanged != null) {
      final levelSelections = _controller.levelChoiceSelections;
      if (!_levelChoiceSelectionsEqual(_lastLevelChoiceSelections, levelSelections)) {
        final snapshot = Map<String, String?>.from(levelSelections);
        _lastLevelChoiceSelections = snapshot;
        _levelChoiceSelectionsCallbackVersion += 1;
        final version = _levelChoiceSelectionsCallbackVersion;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || version != _levelChoiceSelectionsCallbackVersion) return;
          widget.onLevelChoiceSelectionsChanged?.call(Map<String, String?>.from(snapshot));
        });
      }
    }
  }

  bool _levelChoiceSelectionsEqual(Map<String, String?> a, Map<String, String?> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
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
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              StartingCharacteristicsWidgetText.title,
              style: AppTextStyles.title,
            ),
            const SizedBox(height: 4),
            _buildAllCharacteristicsRow(summary),
            if (selectedArray == null &&
                _controller.classData.startingCharacteristics
                    .startingCharacteristicsArrays.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: Colors.orangeAccent),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      StartingCharacteristicsWidgetText.selectArrayHint,
                      style: AppTextStyles.caption
                          .copyWith(color: Colors.orangeAccent, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
            _buildAssignmentStatus(assignmentsComplete, choicesComplete),
            if (selectedArray != null) ...[
              const SizedBox(height: 4),
              _buildArrayPicker(),
              const SizedBox(height: 4),
              _buildAvailableTokensSection(),
            ] else ...[
              const SizedBox(height: 4),
              _buildArrayPicker(),
            ],
            const SizedBox(height: 4),
            _buildPotencySection(potencyValues),
            if (_controller.levelChoices.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildLevelChoicesSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAllCharacteristicsRow(CharacteristicSummary summary) {
    // Desired order: Might, Agility, Reason, Intuition, Presence
    const desiredOrder = ['might', 'agility', 'reason', 'intuition', 'presence'];
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < desiredOrder.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == desiredOrder.length - 1 ? 0 : 3),
              child: _buildCompactCharacteristicTile(desiredOrder[i], summary),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactCharacteristicTile(String stat, CharacteristicSummary summary) {
    final color = AppColors.getCharacteristicColor(stat);
    final isLocked = _controller.lockedStats.contains(stat);
    final fixed = summary.fixed[stat] ?? 0;
    final arrayValue = summary.array[stat] ?? 0;
    final levelBonus = summary.levelBonuses[stat] ?? 0;
    final total = summary.totals[stat] ?? 0;
    final assignedToken = _controller.assignments[stat];
    final isPending = _controller.selectedArray != null && assignedToken == null && !isLocked;

    if (isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.45), width: 1),
          color: color.withOpacity(0.12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.lock, size: 10, color: color),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    _displayName(stat),
                    style: AppTextStyles.subtitle.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              total.toString(),
              style: AppTextStyles.title.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                _buildValueTag('${_formatSigned(fixed)}', color),
                if (levelBonus != 0)
                  _buildValueTag('+${levelBonus}', color),
              ],
            ),
          ],
        ),
      );
    }

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
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: borderColor,
              width: isPending ? 1.5 : 1,
            ),
            color: backgroundColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _displayName(stat),
                style: AppTextStyles.subtitle.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    total.toString(),
                    style: AppTextStyles.title.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (assignedToken != null)
                    _buildAssignedTokenChip(assignedToken, color)
                  else
                    _buildDropHint(color, highlight: isActive),
                ],
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [
                  if (fixed != 0)
                    _buildValueTag('${_formatSigned(fixed)}', color),
                  if (assignedToken != null)
                    _buildValueTag('${_formatSigned(arrayValue)}', color)
                  else
                    _buildValueOutlineTag(
                      StartingCharacteristicsWidgetText.valueOutlinePlaceholder,
                      color,
                    ),
                  if (levelBonus != 0)
                    _buildValueTag('+$levelBonus', color),
                ],
              ),
            ],
          ),
        );
      },
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
          StartingCharacteristicsWidgetText.allFixedMessage,
          style: AppTextStyles.caption,
        ),
      );
    }

    return DropdownButtonFormField<CharacteristicArray?>(
      value: _controller.selectedArray,
      decoration: const InputDecoration(
        labelText: StartingCharacteristicsWidgetText.arrayLabel,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        const DropdownMenuItem<CharacteristicArray?>(
          value: null,
          child: Text(StartingCharacteristicsWidgetText.arrayPlaceholder),
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

  Widget _buildDropHint(Color color, {bool highlight = false}) {
    final borderColor = color.withOpacity(highlight ? 0.8 : 0.5);
    final backgroundColor =
        highlight ? color.withOpacity(0.18) : color.withOpacity(0.1);
    final message =
        _controller.selectedArray == null
            ? StartingCharacteristicsWidgetText.dropHintEmpty
            : StartingCharacteristicsWidgetText.dropHintDrop;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
        color: backgroundColor,
      ),
      child: Text(
        message,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textPrimary,
          fontStyle: FontStyle.italic,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildTokenVisual(
    CharacteristicValueToken token,
    Color color, {
    bool filled = false,
    bool isFeedback = false,
    bool expanded = false,
  }) {
    final background = filled ? color : color.withOpacity(0.18);
    final borderColor = color.withOpacity(filled ? 0.9 : 0.45);
    final textColor = filled ? AppColors.textPrimary : color;

    final content = Text(
      _formatSigned(token.value),
      style: AppTextStyles.caption.copyWith(
        fontSize: expanded ? 16 : 11,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      textAlign: TextAlign.center,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(expanded ? 8 : 6),
        color: background,
        border: Border.all(color: borderColor, width: expanded ? 2 : 1),
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
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 16 : 8,
        vertical: expanded ? 14 : 4,
      ),
      child: expanded ? Center(child: content) : content,
    );
  }

  Widget _buildDraggableTokenChip(CharacteristicValueToken token) {
    final color = AppColors.secondary;
    final chip = _buildTokenVisual(token, color, expanded: true);
    final feedbackWidget = _buildTokenVisual(token, color, filled: true, isFeedback: true);

    // Fixed chip dimensions: width = 60, height = 60
    const estimatedWidth = 60.0;
    const estimatedHeight = 60.0;

    return Draggable<CharacteristicValueToken>(
      data: token,
      feedback: Material(
        color: Colors.transparent,
        child: feedbackWidget,
      ),
      feedbackOffset: Offset(-estimatedWidth / 2, -estimatedHeight / 2),
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
    final feedbackWidget = _buildTokenVisual(token, color, filled: true, isFeedback: true);

    // Smaller chip dimensions: horizontal padding = 8*2 = 16, vertical padding = 4*2 = 8
    // Text width is roughly 25-30px for typical values, so total ~45px wide, ~25px tall
    const estimatedWidth = 45.0;
    const estimatedHeight = 25.0;

    return Draggable<CharacteristicValueToken>(
      data: token,
      feedback: Material(
        color: Colors.transparent,
        child: feedbackWidget,
      ),
      feedbackOffset: Offset(-estimatedWidth / 2, -estimatedHeight / 2),
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
      parts.add(StartingCharacteristicsWidgetText.assignmentMissingArray);
    }
    if (!choicesComplete) {
      parts.add(StartingCharacteristicsWidgetText.assignmentMissingChoices);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.orangeAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.join(StartingCharacteristicsWidgetText.assignmentStatusSeparator),
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
                StartingCharacteristicsWidgetText.availableValuesTitle,
                style: AppTextStyles.subtitle.copyWith(
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (available.isEmpty)
                Text(
                  isActive
                      ? StartingCharacteristicsWidgetText.releaseToClearValue
                      : StartingCharacteristicsWidgetText.allValuesAssigned,
                  style: AppTextStyles.caption,
                )
              else ...[
                Text(
                  StartingCharacteristicsWidgetText.holdAndDragToAssign,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < available.length; i++) ...[
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: Center(
                          child: _buildDraggableTokenChip(available[i]),
                        ),
                      ),
                      if (i < available.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
              if (isActive) ...[
                const SizedBox(height: 8),
                Text(
                  StartingCharacteristicsWidgetText.releaseToClearSlot,
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
            '${StartingCharacteristicsWidgetText.potencyTitlePrefix}$baseName${StartingCharacteristicsWidgetText.potencyTitleSuffix}',
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
            StartingCharacteristicsWidgetText.levelBonusesTitle,
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
          labelText:
              '${StartingCharacteristicsWidgetText.levelBonusLabelPrefix}${choice.level}${StartingCharacteristicsWidgetText.levelBonusLabelSuffix}',
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child:
                Text(StartingCharacteristicsWidgetText.selectCharacteristicPlaceholder),
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withOpacity(0.18),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textPrimary,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildValueOutlineTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.6), width: 0.8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontSize: 10,
        ),
      ),
    );
  }
}
