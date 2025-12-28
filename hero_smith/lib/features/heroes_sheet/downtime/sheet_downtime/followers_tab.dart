import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/db/providers.dart';
import '../../../../core/models/downtime_tracking.dart';
import '../../../../core/theme/hero_theme.dart';
import '../../../../core/text/heroes_sheet/downtime/followers_tab_text.dart';
import 'follower_editor_dialog.dart';

/// Provider for hero followers
final heroFollowersProvider =
    FutureProvider.family<List<Follower>, String>((ref, heroId) async {
  final repo = ref.read(downtimeRepositoryProvider);
  return await repo.getHeroFollowers(heroId);
});

class FollowersTab extends ConsumerWidget {
  const FollowersTab({super.key, required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followersAsync = ref.watch(heroFollowersProvider(heroId));

    return followersAsync.when(
      data: (followers) => _buildContent(context, ref, followers),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<Follower> followers,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildAddButton(context, ref),
        ),
        if (followers.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyState(context, ref),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildFollowerCard(
                context,
                ref,
                followers[index],
              ),
              childCount: followers.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FilledButton.icon(
        onPressed: () => _addFollower(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text(FollowersTabText.addFollowerButtonLabel),
        style: HeroTheme.primaryActionButtonStyle(context),
      ),
    );
  }

  Widget _buildFollowerCard(BuildContext context, WidgetRef ref, Follower follower) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Name, Type, and menu
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: HeroTheme.primarySection.withValues(alpha: 0.2),
                  child: const Icon(Icons.person, size: 20, color: HeroTheme.primarySection),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        follower.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        follower.followerType,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  iconSize: 20,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text(FollowersTabText.editMenuLabel),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text(FollowersTabText.deleteMenuLabel),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editFollower(context, ref, follower);
                    } else if (value == 'delete') {
                      _deleteFollower(context, ref, follower);
                    }
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Characteristics row - all 5 in one compact row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCharacteristicChip(theme, 'M', follower.might),
                  _buildCharacteristicChip(theme, 'A', follower.agility),
                  _buildCharacteristicChip(theme, 'R', follower.reason),
                  _buildCharacteristicChip(theme, 'I', follower.intuition),
                  _buildCharacteristicChip(theme, 'P', follower.presence),
                ],
              ),
            ),
            
            // Skills section
            if (follower.skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.build_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: follower.skills.map((skill) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          skill,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ],
            
            // Languages section
            if (follower.languages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.translate, size: 16, color: theme.colorScheme.secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: follower.languages.map((lang) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          lang,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCharacteristicChip(ThemeData theme, String label, int value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.toString(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: HeroTheme.primarySection,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return HeroTheme.buildEmptyState(
      context,
      icon: Icons.people_outline,
      title: FollowersTabText.emptyTitle,
      subtitle: FollowersTabText.emptySubtitle,
      action: FilledButton.icon(
        onPressed: () => _addFollower(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text(FollowersTabText.emptyActionLabel),
        style: HeroTheme.primaryActionButtonStyle(context),
      ),
    );
  }

  void _addFollower(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Follower>(
      context: context,
      builder: (context) => FollowerEditorDialog(heroId: heroId),
    );

    if (result != null) {
      final repo = ref.read(downtimeRepositoryProvider);
      await repo.createFollower(
        heroId: heroId,
        name: result.name,
        followerType: result.followerType,
        might: result.might,
        agility: result.agility,
        reason: result.reason,
        intuition: result.intuition,
        presence: result.presence,
        skills: result.skills,
        languages: result.languages,
      );
      ref.invalidate(heroFollowersProvider(heroId));
    }
  }

  void _editFollower(BuildContext context, WidgetRef ref, Follower follower) async {
    final result = await showDialog<Follower>(
      context: context,
      builder: (context) => FollowerEditorDialog(
        heroId: heroId,
        existingFollower: follower,
      ),
    );

    if (result != null) {
      final repo = ref.read(downtimeRepositoryProvider);
      await repo.updateFollower(result);
      ref.invalidate(heroFollowersProvider(heroId));
    }
  }

  void _deleteFollower(BuildContext context, WidgetRef ref, Follower follower) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(FollowersTabText.deleteDialogTitle),
        content: Text('Remove ${follower.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(FollowersTabText.deleteDialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(FollowersTabText.deleteDialogConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(downtimeRepositoryProvider);
      await repo.deleteFollower(follower.id);
      ref.invalidate(heroFollowersProvider(heroId));
    }
  }
}
