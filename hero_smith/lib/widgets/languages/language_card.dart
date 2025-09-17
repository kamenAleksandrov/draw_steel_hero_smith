import 'package:flutter/material.dart';
import '../../core/models/component.dart';

class LanguageCard extends StatelessWidget {
  final Component language;

  const LanguageCard({
    super.key,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final data = language.data;
    final region = data['region'] as String?;
    final ancestry = data['ancestry'] as String?;
    final langType = data['language_type'] as String?;
    final related = (data['related_languages'] as List?)?.cast<String>();
    final topics = (data['common_topics'] as List?)?.cast<String>();

    // Determine border color based on language type - more subtle for dark mode
    Color borderColor = switch (langType) {
      'human' => Colors.blue.shade300,
      'ancestral' => Colors.green.shade300,
      'dead' => Colors.grey.shade400,
      _ => Colors.grey.shade300,
    };

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Language name with type badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      language.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (langType != null)
                    _buildTypeBadge(langType, borderColor),
                ],
              ),
              const SizedBox(height: 6),
              
              // Region or ancestry info
              if (region != null)
                _buildInfoChip(Icons.location_on_outlined, region, Colors.blue.shade50, Colors.blue.shade700),
              if (ancestry != null)
                _buildInfoChip(Icons.people_outline, ancestry, Colors.orange.shade50, Colors.orange.shade700),
                
              // Related languages
              if (related != null && related.isNotEmpty)
                _buildInfoChip(Icons.link_outlined, related.join(', '), Colors.purple.shade50, Colors.purple.shade700),
                
              // Common topics
              if (topics != null && topics.isNotEmpty)
                _buildInfoChip(Icons.topic_outlined, topics.join(', '), Colors.green.shade50, Colors.green.shade700),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: borderColor.withOpacity(0.1),
        border: Border.all(color: borderColor.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: borderColor.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color backgroundColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: 12,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}