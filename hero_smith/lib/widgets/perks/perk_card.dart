import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/providers.dart';
import '../../core/models/component.dart';
import '../../core/theme/ds_theme.dart';
import '../shared/section_widgets.dart';
import '../shared/expandable_card.dart';

class PerkCard extends ConsumerWidget {
  final Component perk;

  const PerkCard({super.key, required this.perk});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = perk.data;
    final group = (data['group'] as String?) ?? 'exploration';
    final description = data['description'] as String?;
    final grants = data['grants'] as List?;

    final ds = DsTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final borderColor = ds.perkGroupBorder[group] ?? scheme.outlineVariant;
    final neutralText = scheme.onSurface;

    return ExpandableCard(
      title: perk.name,
      borderColor: borderColor,
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: borderColor.withOpacity(0.1),
          border: Border.all(color: borderColor.withOpacity(0.3), width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '${ds.perkGroupEmoji[group] ?? '✨'} ${group.toUpperCase()}',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: borderColor,
          ),
        ),
      ),
      expandedContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (description != null && description.isNotEmpty) ...[
            SectionLabel('Description', emoji: ds.perkSectionEmoji['description'], color: borderColor),
            const SizedBox(height: 2),
            _buildIndentedText(description, neutralText),
          ],
          if (grants != null && grants.isNotEmpty) ...[
            SectionLabel('Grants', emoji: ds.perkSectionEmoji['grants'], color: borderColor),
            const SizedBox(height: 2),
            _buildGrants(context, ref, grants, neutralText, borderColor),
          ],
        ],
      ),
    );
  }

  Widget _buildIndentedText(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color),
        maxLines: 12,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildGrants(BuildContext context, WidgetRef ref, List<dynamic> grants, Color textColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final grant in grants)
            _buildGrantItem(context, ref, grant, textColor, accentColor),
        ],
      ),
    );
  }

  Widget _buildGrantItem(BuildContext context, WidgetRef ref, dynamic grant, Color textColor, Color accentColor) {
    if (grant is! Map) {
      return _buildGrantRow(grant.toString(), textColor);
    }
    
    final abilityName = grant['ability'] as String?;
    if (abilityName == null) {
      return _buildGrantRow(_formatGrant(grant), textColor);
    }

    // Look up the full ability by name
    final abilityAsync = ref.watch(abilityByNameProvider(abilityName));
    
    return abilityAsync.when(
      data: (ability) {
        if (ability == null) {
          return _buildGrantRow('Ability: $abilityName', textColor);
        }
        return _buildAbilityCard(context, ability, textColor, accentColor);
      },
      loading: () => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 8),
            Text('Loading $abilityName...', style: TextStyle(fontSize: 11, color: textColor)),
          ],
        ),
      ),
      error: (e, _) => _buildGrantRow('Ability: $abilityName', textColor),
    );
  }

  Widget _buildAbilityCard(BuildContext context, Component ability, Color textColor, Color accentColor) {
    final data = ability.data;
    final actionType = data['action_type'] as String?;
    final keywords = (data['keywords'] as List?)?.cast<String>() ?? [];
    final range = data['range'] as Map?;
    final targets = data['targets'] as String?;
    final effect = data['effect'] as String?;
    final storyText = data['story_text'] as String?;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with name and action type
          Row(
            children: [
              Text(
                '⚡ ${ability.name}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              if (actionType != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    actionType,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Keywords
          if (keywords.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: keywords.map((k) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  k,
                  style: TextStyle(
                    fontSize: 8,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              )).toList(),
            ),
          ],
          // Story text / flavor
          if (storyText != null && storyText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              storyText,
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: textColor.withOpacity(0.8),
              ),
            ),
          ],
          // Range and Targets
          if (range != null || targets != null) ...[
            const SizedBox(height: 6),
            if (range != null && range['distance'] != null)
              _buildAbilityDetail('Range', range['distance'].toString(), textColor),
            if (targets != null)
              _buildAbilityDetail('Targets', targets, textColor),
          ],
          // Effect
          if (effect != null && effect.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Effect:',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              effect,
              style: TextStyle(fontSize: 10, color: textColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAbilityDetail(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(fontSize: 10, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrantRow(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2, right: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: color.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: color),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatGrant(dynamic grant) {
    if (grant is String) return grant;
    if (grant is Map) {
      final ability = grant['ability'];
      if (ability is String) return 'Ability: $ability';
      
      // Handle other grant types if needed
      final keys = grant.keys.cast<String>().toList();
      keys.sort();
      return keys.map((k) => '$k: ${grant[k]}').join(', ');
    }
    return grant.toString();
  }
}
