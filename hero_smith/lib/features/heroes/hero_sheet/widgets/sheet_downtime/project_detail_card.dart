import 'package:flutter/material.dart';
import '../../../../../core/models/downtime_tracking.dart';
import '../../../../../core/theme/hero_theme.dart';

/// Card displaying project details with progress
class ProjectDetailCard extends StatelessWidget {
  const ProjectDetailCard({
    super.key,
    required this.project,
    required this.heroId,
    this.onTap,
    this.onAddPoints,
    this.onDelete,
  });

  final HeroDowntimeProject project;
  final String heroId;
  final VoidCallback? onTap;
  final VoidCallback? onAddPoints;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = project.progress;
    final isCompleted = project.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: HeroTheme.cardRadius,
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
                    return Chip(
                      label: Text(
                        'Event at ${event.pointThreshold} points.',
                        style: theme.textTheme.bodySmall,
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
                  }).toList(),
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

              // Add Points button
              if (!isCompleted && onAddPoints != null) ...[
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
            ],
          ),
        ),
      ),
    );
  }
}
