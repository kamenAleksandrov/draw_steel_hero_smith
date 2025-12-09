part of 'class_features_widget.dart';

class _LevelSection extends StatefulWidget {
  const _LevelSection({
    super.key,
    required this.levelNumber,
    required this.currentLevel,
    required this.features,
    required this.widget,
  });

  final int levelNumber;
  final int currentLevel;
  final List<Feature> features;
  final ClassFeaturesWidget widget;

  @override
  State<_LevelSection> createState() => _LevelSectionState();
}

class _LevelSectionState extends State<_LevelSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final levelColor = FeatureTokens.getLevelColor(widget.levelNumber);
    final isUnlocked = widget.levelNumber <= widget.currentLevel;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnlocked
              ? levelColor.withValues(alpha: 0.4)
              : scheme.outlineVariant.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey<String>('level_${widget.levelNumber}'),
            initiallyExpanded: isUnlocked,
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            backgroundColor: scheme.surface,
            collapsedBackgroundColor: scheme.surface,
            leading: _LevelBadge(level: widget.levelNumber, isUnlocked: isUnlocked),
            title: Text(
              'Level ${widget.levelNumber} Features',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isUnlocked
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            subtitle: Text(
              '${widget.features.length} feature${widget.features.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            children: [
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.features.length,
                  itemBuilder: (context, index) {
                    final feature = widget.features[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: index < widget.features.length - 1 ? 12 : 0),
                      child: _FeatureCard(
                        key: ValueKey(feature.id),
                        feature: feature,
                        widget: widget.widget,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.isUnlocked});

  final int level;
  final bool isUnlocked;

  @override
  Widget build(BuildContext context) {
    final levelColor = FeatureTokens.getLevelColor(level);
    final effectiveColor = isUnlocked ? levelColor : Colors.grey;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            effectiveColor.withValues(alpha: 0.3),
            effectiveColor.withValues(alpha: 0.15),
          ],
        ),
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '$level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: effectiveColor,
          ),
        ),
      ),
    );
  }
}
