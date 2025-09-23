import 'package:flutter/material.dart';
import '../../core/models/component.dart';
import '../../core/theme/semantic/semantic_tokens.dart';
import 'abilities_shared.dart';

class AbilitySummary extends StatelessWidget {
  final Component component;
  const AbilitySummary({super.key, required this.component});

  @override
  Widget build(BuildContext context) {
    final a = AbilityData(component);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and cost row
          Row(
            children: [
              Expanded(
                child: Text(
                  a.name, 
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (a.costString != null)
                () {
                  final resourceColor = a.resourceType != null 
                    ? HeroicResourceTokens.color(a.resourceType!)
                    : scheme.primary;
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          resourceColor.withValues(alpha: 0.3),
                          resourceColor.withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: resourceColor.withValues(alpha: 0.8),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: resourceColor.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      a.costString!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  );
                }(),
            ],
          ),
          
          // Compact info chips
          if (a.actionType != null || a.keywords.isNotEmpty || a.characteristicSummary != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (a.actionType != null)
                    _buildActionTypeChip(context, a.actionType!),
                  if (a.characteristicSummary != null)
                    _buildInfoChip(context, a.characteristicSummary!, scheme.secondary),
                  ...a.keywords.take(2).map((keyword) => 
                    _buildKeywordChip(context, keyword)),
                  if (a.keywords.length > 2)
                    _buildInfoChip(context, '+${a.keywords.length - 2} more', scheme.outline),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, String text, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildActionTypeChip(BuildContext context, String actionType) {
    final theme = Theme.of(context);
    final actionColor = ActionTokens.color(actionType);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            actionColor.withValues(alpha: 0.35),
            actionColor.withValues(alpha: 0.22),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: actionColor.withValues(alpha: 0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: actionColor.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        actionType,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.normal,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildKeywordChip(BuildContext context, String keyword) {
    final theme = Theme.of(context);
    final keywordColor = KeywordTokens.color(keyword);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: keywordColor.withOpacity(0.12),
        border: Border.all(
          color: keywordColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        keyword,
        style: theme.textTheme.labelSmall?.copyWith(
          color: keywordColor,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
