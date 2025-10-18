import 'package:flutter/material.dart';
import '../../core/models/abilities_models.dart';
import '../../core/models/component.dart';
import '../../core/theme/semantic/semantic_tokens.dart';

class AbilityTierLine {
  final String label; // e.g., '<=11', '12-16', '17+'
  final String primaryText; // Main damage expression
  final String? secondaryText; // Additional notes (potencies, conditions)
  const AbilityTierLine({
    required this.label,
    required this.primaryText,
    this.secondaryText,
  });
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
            color: CharacteristicTokens.color(potencyChar),
            fontWeight: FontWeight.bold,
          ),
        ));
        spans.add(TextSpan(
          text: '<$potencyStrength',
          style: baseStyle.copyWith(
            color: PotencyTokens.color(potencyStrength),
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (characteristic != null) {
        // Single characteristic highlighting
        spans.add(TextSpan(
          text: characteristic,
          style: baseStyle.copyWith(
            color: CharacteristicTokens.color(characteristic),
            fontWeight: FontWeight.bold,
          ),
        ));
      } else if (damageType != null) {
        // Damage type highlighting with emoji and color
        final emoji = DamageTokens.emoji(damageType);
        final color = DamageTokens.color(damageType);

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
  AbilityData(Component source)
      : component = source,
        detail = AbilityDetail.fromComponent(source);

  final Component component;
  final AbilityDetail detail;

  // Basics
  String get name => detail.name;
  String? get flavor => detail.storyText;
  int? get level => detail.level;
  String? get triggerText => detail.triggerText;

  // Costs
  String? get costString {
    final cost = detail.cost;
    if (cost == null) return null;
    final resource = _formatResource(cost.resource);
    return '${cost.amount} $resource';
  }

  String? get resourceType => detail.resourceType;

  // Keywords
  List<String> get keywords => detail.keywords;

  // Action / Range / Targeting
  String? get actionType => detail.actionType;

  String? get rangeSummary {
    final range = detail.range;
    if (range == null) return null;

    final distance = range.distance;
    final area = range.area;
    final value = range.value;

    final parts = <String>[];
    if (distance != null && distance.isNotEmpty) parts.add(distance);
    if (value != null && value.isNotEmpty) parts.add(value);
    if (area != null && area.isNotEmpty) parts.add(area);

    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String? get targets => detail.targets;

  // Power roll
  AbilityPowerRoll? get _powerRoll => detail.powerRoll;

  bool get hasPowerRoll => _powerRoll != null;

  String? get powerRollLabel {
    final label = _powerRoll?.label;
    return label ?? (_powerRoll != null ? 'Power roll' : null);
  }

  String? get characteristicSummary {
    final characteristics = _powerRoll?.characteristics;
    final trimmed = characteristics?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  List<String> get characteristics {
    final summary = characteristicSummary;
    if (summary == null) return const [];
    return _splitCharacteristics(summary)
        .map(_abbreviateCharacteristic)
        .where((value) => value.isNotEmpty)
        .toList();
  }

  List<AbilityTierLine> get tiers {
    final powerRoll = _powerRoll;
    if (powerRoll == null) return const [];

    const labels = {
      'low': '<=11',
      'mid': '12-16',
      'high': '17+',
    };

    final results = <AbilityTierLine>[];

    for (final entry in labels.entries) {
      final detail = powerRoll.tiers[entry.key];
      if (detail == null) continue;

      final baseDamage = detail.baseDamageValue;
      final characteristicDamage = detail.characteristicDamageOptions;
      final damageTypes = detail.damageTypes;
      final potencies = detail.potencies;
      final conditions = detail.conditions;

      final damageParts = <String>[];
      if (baseDamage != null) {
        damageParts.add(baseDamage.toString());
      }
      if (characteristicDamage != null && characteristicDamage.isNotEmpty) {
        damageParts.add(damageParts.isEmpty
            ? characteristicDamage
            : '+ $characteristicDamage');
      }
      if (damageTypes != null && damageTypes.isNotEmpty) {
        final suffix = damageTypes.toLowerCase().contains('damage')
            ? damageTypes
            : '$damageTypes damage';
        damageParts.add(suffix);
      }
      final primary = damageParts.join(' ').trim();

      final detailParts = <String>[];
      if (potencies != null && potencies.isNotEmpty) {
        detailParts.add(potencies);
      }
      if (conditions != null && conditions.isNotEmpty) {
        detailParts.add(conditions);
      }
      final secondary = detailParts.isEmpty ? null : detailParts.join(', ');

      if (primary.isEmpty && (secondary == null || secondary.isEmpty)) {
        continue;
      }

      results.add(
        AbilityTierLine(
          label: entry.value,
          primaryText: primary.isNotEmpty ? primary : (secondary ?? ''),
          secondaryText: primary.isNotEmpty ? secondary : null,
        ),
      );
    }

    return results;
  }

  String? get effect => detail.effect;
  String? get specialEffect => detail.specialEffect;

  String metaSummary() {
    final parts = <String>[];
    if (keywords.isNotEmpty) parts.add(keywords.join(', '));
    if (actionType != null) parts.add(actionType!);
    if (rangeSummary != null) parts.add(rangeSummary!);
    if (characteristicSummary != null) {
      parts.add('Power roll + $characteristicSummary');
    }
    return parts.join(' • ');
  }

  static String _formatResource(dynamic res) {
    if (res == null) return 'Heroic resource';
    final s = res.toString().trim();
    if (s.isEmpty) return 'Heroic resource';
    if (s == 'heroic_resource') return 'Heroic resource';
    return s
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) =>
            word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  static List<String> _splitCharacteristics(String value) {
    final normalized = value
        .replaceAll('/', ',')
        .replaceAll(RegExp(r'\band\b', caseSensitive: false), ',')
        .replaceAll(RegExp(r'\bor\b', caseSensitive: false), ',');
    return normalized
        .split(',')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList();
  }

  static String _abbreviateCharacteristic(String token) {
    final lower = token.toLowerCase();
    if (lower.startsWith('might')) return 'M';
    if (lower.startsWith('agility')) return 'A';
    if (lower.startsWith('reason')) return 'R';
    if (lower.startsWith('intuition')) return 'I';
    if (lower.startsWith('presence')) return 'P';
    if (token.length == 1 && 'marip'.contains(lower)) {
      return token.toUpperCase();
    }
    return token;
  }
}
