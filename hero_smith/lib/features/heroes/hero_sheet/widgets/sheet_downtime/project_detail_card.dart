import 'package:flutter/material.dart';
import '../../../../../core/models/downtime_tracking.dart';
import '../../../../../core/theme/hero_theme.dart';
import '../../../../../widgets/downtime/downtime_tabs.dart';

/// Card displaying project details with progress
class ProjectDetailCard extends StatelessWidget {
  const ProjectDetailCard({
    super.key,
    required this.project,
    required this.heroId,
    this.onTap,
    this.onAddPoints,
    this.onDelete,
    this.onAddToGear,
    this.isTreasureProject = false,
  });

  final HeroDowntimeProject project;
  final String heroId;
  final VoidCallback? onTap;
  final VoidCallback? onAddPoints;
  final VoidCallback? onDelete;
  final VoidCallback? onAddToGear;
  final bool isTreasureProject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = project.progress;
    final isCompleted = project.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isCompleted)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 24,
                  ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: onTap,
                    iconSize: 20,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    tooltip: 'Edit Project',
                  ),
                ],
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                    iconSize: 20,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    tooltip: 'Remove Project',
                  ),
                ],
              ],
            ),

              const SizedBox(height: 8),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted
                        ? Colors.green
                        : HeroTheme.primarySection,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Points display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${project.currentPoints} / ${project.projectGoal} points',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: HeroTheme.primarySection,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Event indicators
              if (project.events.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: project.events.map((event) {
                    final triggered = event.triggered;
                    return _EventChip(
                      event: event,
                      triggered: triggered,
                      theme: theme,
                    );
                  }).toList(),
                ),
                // Show event descriptions for triggered events
                ...project.events
                    .where((e) => e.triggered && e.eventDescription != null && e.eventDescription!.isNotEmpty)
                    .map((event) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.event_note,
                                  size: 16,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Event at ${event.pointThreshold} pts',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: Colors.amber.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        event.eventDescription!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
              ],

              // Notes section
              if (project.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notes',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              project.notes,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Roll characteristics
              if (project.rollCharacteristics.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: project.rollCharacteristics.map((char) {
                    return Chip(
                      label: Text(
                        char.toUpperCase(),
                        style: theme.textTheme.bodySmall,
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    );
                  }).toList(),
                ),
              ],

              // Add Points button (show if not completed and goal not yet reached)
              if (!isCompleted && onAddPoints != null && onAddToGear == null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAddPoints,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Points'),
                    style: FilledButton.styleFrom(
                      backgroundColor: HeroTheme.primarySection,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],

              // Add to Gear button for treasure projects that reached their goal
              if (isTreasureProject && onAddToGear != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onAddToGear,
                    icon: const Icon(Icons.backpack, size: 20),
                    label: const Text('Add Crafted Item to Gear'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

/// Event chip that becomes tappable when triggered
class _EventChip extends StatelessWidget {
  const _EventChip({
    required this.event,
    required this.triggered,
    required this.theme,
  });

  final ProjectEvent event;
  final bool triggered;
  final ThemeData theme;

  void _navigateToEvents(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EventsPageScaffold(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chip = Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Event at ${event.pointThreshold} pts',
            style: theme.textTheme.bodySmall,
          ),
          if (triggered) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: 14,
              color: Colors.amber.shade800,
            ),
          ],
        ],
      ),
      backgroundColor: triggered
          ? Colors.amber.withValues(alpha: 0.3)
          : theme.colorScheme.surfaceContainerHighest,
      side: BorderSide(
        color: triggered
            ? Colors.amber
            : theme.colorScheme.outline.withValues(alpha: 0.2),
      ),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );

    if (triggered) {
      return InkWell(
        onTap: () => _navigateToEvents(context),
        borderRadius: BorderRadius.circular(16),
        child: Tooltip(
          message: 'Tap to view event tables',
          child: chip,
        ),
      );
    }

    return chip;
  }
}
