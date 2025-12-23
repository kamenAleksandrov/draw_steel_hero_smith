part of 'package:hero_smith/features/heroes_sheet/story/story_sections/token_tracker_widget.dart';

class _TokenRow extends StatelessWidget {
  const _TokenRow({
    required this.name,
    required this.current,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String name;
  final int current;
  final int max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrement = current > 0;
    final canIncrement = current < max;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$current / $max',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: canDecrement ? onDecrement : null,
            icon: const Icon(Icons.remove_circle_outline),
            iconSize: 28,
            color: canDecrement
                ? theme.colorScheme.error
                : theme.colorScheme.outline.withOpacity(0.3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          Container(
            width: 48,
            alignment: Alignment.center,
            child: Text(
              current.toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: current == 0
                    ? theme.colorScheme.error
                    : current == max
                        ? theme.colorScheme.primary
                        : null,
              ),
            ),
          ),
          IconButton(
            onPressed: canIncrement ? onIncrement : null,
            icon: const Icon(Icons.add_circle_outline),
            iconSize: 28,
            color: canIncrement
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}
