import 'package:flutter/material.dart';
import '../../core/models/component.dart';
import '../../core/theme/ds_theme.dart';
import '../shared/section_widgets.dart';
import '../shared/expandable_card.dart';

class PerkCard extends StatelessWidget {
  final Component perk;

  const PerkCard({super.key, required this.perk});

  @override
  Widget build(BuildContext context) {
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
            _buildGrants(grants, neutralText),
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

  Widget _buildGrants(List<dynamic> grants, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final grant in grants)
            _buildGrantRow(_formatGrant(grant), textColor),
        ],
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
