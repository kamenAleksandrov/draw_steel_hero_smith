import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/db/providers.dart';
import '../../../../../core/models/downtime_tracking.dart';
import '../../../../../core/theme/hero_theme.dart';
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
          child: _buildHeader(context),
        ),
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

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: HeroTheme.heroCardRadius,
        gradient: HeroTheme.headerGradient(context),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people,
            size: 40,
            color: HeroTheme.primarySection,
          ),
          const SizedBox(height: 12),
          Text(
            'Followers',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: HeroTheme.primarySection,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'NPCs who can help with your downtime projects',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FilledButton.icon(
        onPressed: () => _addFollower(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Follower'),
        style: HeroTheme.primaryActionButtonStyle(context),
      ),
    );
  }

  Widget _buildFollowerCard(BuildContext context, WidgetRef ref, Follower follower) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: HeroTheme.primarySection.withValues(alpha: 0.2),
          child: const Icon(Icons.person, color: HeroTheme.primarySection),
        ),
        title: Text(
          follower.name,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(follower.followerType),
            const SizedBox(height: 4),
            Text(
              'M:${follower.might} A:${follower.agility} R:${follower.reason} '
              'I:${follower.intuition} P:${follower.presence}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
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
        isThreeLine: true,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return HeroTheme.buildEmptyState(
      context,
      icon: Icons.people_outline,
      title: 'No Followers Yet',
      subtitle: 'Add NPCs who can assist with your projects',
      action: FilledButton.icon(
        onPressed: () => _addFollower(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Add First Follower'),
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
        title: const Text('Delete Follower'),
        content: Text('Remove ${follower.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
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
