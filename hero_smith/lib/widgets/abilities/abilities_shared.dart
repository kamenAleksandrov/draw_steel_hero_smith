import 'package:flutter/material.dart';
import '../../core/models/component.dart';
import '../../core/theme/app_colors.dart';

class AbilityTierLine {
  final String label; // e.g., 'Low', 'Mid', 'High'
  final String text;
  const AbilityTierLine(this.label, this.text);
}

/// Utility class for highlighting game mechanics in ability text
class AbilityTextHighlighter {
  /// Creates a RichText widget with highlighted characteristics, potencies, and damage types
  static Widget highlightGameMechanics(String text, BuildContext context,
      {TextStyle? baseStyle}) {
    final theme = Theme.of(context);
    baseStyle ??= theme.textTheme.bodyMedium ?? const TextStyle();

    final spans = <TextSpan>[];
    // Enhanced regex to include damage types
    final regex = RegExp(
        r'([MARIP])<(weak|average|strong|w|a|s)\b|\b([MARIP])\b|\b(acid|poison|fire|cold|sonic|holy|corruption|psychic|lightning)\b',
        caseSensitive: false);
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before this match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      final potencyChar = match.group(1); // Characteristic with potency
      final potencyStrength =
          match.group(2); // Potency strength (weak, average, strong, w, a, s)
      final characteristic =
          match.group(3); // Single characteristic (M, A, R, I, P)
      final damageType = match.group(4); // Damage type (acid, fire, etc.)

      if (potencyChar != null && potencyStrength != null) {
        // Potency highlighting (e.g., "M<w", "P<strong")
        spans.add(TextSpan(
          text: potencyChar,
          style: baseStyle.copyWith(
            color: AppColors.getCharacteristicColor(potencyChar),
            fontWeight: FontWeight.bold,
          ),
        ));
        spans.add(TextSpan(
          text: '<$potencyStrength',
          style: baseStyle.copyWith(
            color: AppColors.getPotencyColor(potencyStrength),
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (characteristic != null) {
        // Single characteristic highlighting
        spans.add(TextSpan(
          text: characteristic,
          style: baseStyle.copyWith(
            color: AppColors.getCharacteristicColor(characteristic),
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (damageType != null) {
        // Damage type highlighting with emoji and color
        final emoji = AppColors.getDamageTypeEmoji(damageType);
        final color = AppColors.getElementalColor(damageType);

        spans.add(TextSpan(
          text: emoji.isNotEmpty ? '$emoji $damageType' : damageType,
          style: baseStyle.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ));
      }

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

class AbilityData {
  final Component c;
  AbilityData(this.c);

  // Basics
  String get name => c.name;
  String? get flavor => _s(c.data['story_text']);

  // Costs: if amount is null => free (no cost label shown). Otherwise show amount + resource label
  String? get costString {
    final costs = c.data['costs'];
    if (costs is Map) {
      final amount = costs['amount'];
      if (amount == null) return null; // free to use
      final resourceRaw = costs['resource'];
      final resource = _formatResource(resourceRaw);
      final amtStr =
          amount is num ? amount.toInt().toString() : amount.toString();
      return '$amtStr $resource';
    }
    return null;
  }

  // Keywords
  List<String> get keywords {
    final k = c.data['keywords'];
    if (k is List) {
      return k
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  // Action type label (e.g., 'Main action', 'Maneuver')
  String? get actionType => _s(c.data['action_type']);

  // Range/Area/Targets
  String? get rangeDistance {
    final r = c.data['range'];
    if (r is Map) return _s(r['distance']);
    return null;
  }

  String? get rangeArea {
    final r = c.data['range'];
    if (r is Map) return _s(r['area']);
    return null;
  }

  String? get targets => _s(c.data['targets']);

  // Power roll
  String? get powerRollLabel {
    final pr = c.data['power_roll'];
    if (pr is Map) return _s(pr['label']) ?? 'Power roll';
    return null;
  }

  String? get characteristicSummary {
    final pr = c.data['power_roll'];
    if (pr is Map) {
      final chars = pr['characteristics'];
      if (chars is List) {
        final list = chars
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (list.isNotEmpty) return list.join(' or ');
      }
    }
    return null;
  }

  List<String> get characteristics {
    final pr = c.data['power_roll'];
    if (pr is Map) {
      final chars = pr['characteristics'];
      if (chars is List) {
        return chars
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  List<AbilityTierLine> get tiers {
    final pr = c.data['power_roll'];
    if (pr is! Map) return const [];
    final t = pr['tiers'];
    if (t is! Map) return const [];
    String? pick(Map m) =>
        _s(m['all_text']) ??
        _s(m['descriptive_text']) ??
        _s(m['damage_expression']);

    final lines = <AbilityTierLine>[];
    for (final entry in const [
      ('low', '<11'),
      ('mid', '12-16'),
      ('high', '17+'),
    ]) {
      final data = t[(entry.$1)];
      if (data is Map) {
        final text = pick(data);
        if (text != null && text.isNotEmpty) {
          lines.add(AbilityTierLine(entry.$2, text));
        }
      }
    }
    return lines;
  }

  String? get effect => _s(c.data['effect']);
  String? get specialEffect => _s(c.data['special_effect']);

  // Compose a concise summary line for list rows (cost moved to title)
  String metaSummary() {
    final parts = <String>[];
    if (keywords.isNotEmpty) parts.add(keywords.join(', '));
    if (actionType != null) parts.add(actionType!);
    if (characteristicSummary != null) parts.add('Power roll + $characteristicSummary');
    return parts.join(' • ');
  }

  static String _formatResource(dynamic res) {
    if (res == null) return 'Heroic resource';
    final s = res.toString().trim();
    if (s.isEmpty) return 'Heroic resource';
    if (s == 'heroic_resource') return 'Heroic resource';
    // Title-case fallback
    return s
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static String? _s(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
