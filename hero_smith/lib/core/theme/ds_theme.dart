import 'package:flutter/material.dart';

class DsTheme extends ThemeExtension<DsTheme> {
  // Border color maps
  final Map<String, Color> languageTypeBorder;
  final Map<String, Color> skillGroupBorder;
  final Map<String, Color> deityCategoryBorder;
  final Map<int, Color> titleEchelonBorder;

  // Emojis
  final Map<String, String> languageTypeEmoji;
  final Map<String, String> languageSectionEmoji;
  final Map<String, String> skillGroupEmoji;
  final Map<String, String> skillSectionEmoji;
  final Map<String, String> titleSectionEmoji;
  final Map<String, String> deityCategoryEmoji;
  final Map<String, String> deitySectionEmoji;

  // Special colors
  final Color specialSectionColor;

  // Text styles
  final TextStyle cardTitleStyle;
  final TextStyle sectionLabelStyle;
  final TextStyle badgeTextStyle;

  const DsTheme({
    required this.languageTypeBorder,
    required this.skillGroupBorder,
    required this.deityCategoryBorder,
    required this.titleEchelonBorder,
    required this.languageTypeEmoji,
    required this.languageSectionEmoji,
    required this.skillGroupEmoji,
    required this.skillSectionEmoji,
    required this.titleSectionEmoji,
    required this.deityCategoryEmoji,
    required this.deitySectionEmoji,
    required this.specialSectionColor,
    required this.cardTitleStyle,
    required this.sectionLabelStyle,
    required this.badgeTextStyle,
  });

  factory DsTheme.defaults(ColorScheme scheme) {
    return DsTheme(
      languageTypeBorder: {
        'human': Colors.blue.shade300,
        'ancestral': Colors.green.shade300,
        'dead': Colors.grey.shade400,
        'unknown': Colors.grey.shade300,
      },
      skillGroupBorder: {
        'crafting': Colors.orangeAccent.shade200,
        'exploration': Colors.blue.shade300,
        'interpersonal': Colors.pink.shade300,
        'intrigue': Colors.teal.shade300,
        'lore': Colors.indigo.shade300,
        'other': Colors.grey.shade300,
      },
      deityCategoryBorder: {
        'god': Colors.amber.shade300,
        'saint': Colors.lightBlue.shade300,
        'other': Colors.grey.shade400,
      },
      titleEchelonBorder: {
        1: Colors.green.shade300,
        2: Colors.blue.shade300,
        3: Colors.purple.shade300,
        4: Colors.orange.shade300,
        0: Colors.grey.shade300, // fallback for unknown echelon
      },
      languageTypeEmoji: {
        'human': '🗣️',
        'ancestral': '📜',
        'dead': '☠️',
        'unknown': '💬',
      },
      languageSectionEmoji: {
        'region': '🗺️',
        'ancestry': '🧬',
        'related': '🔗',
        'topics': '🧩',
      },
      skillGroupEmoji: {
        'crafting': '⚒️',
        'exploration': '🧭',
        'interpersonal': '🤝',
        'intrigue': '🕵️',
        'lore': '📚',
        'other': '🧩',
      },
      skillSectionEmoji: {
        'group': '📂',
        'description': '📝',
      },
      titleSectionEmoji: {
        'prerequisite': '🗝️',
        'description': '📝',
        'benefits': '🎁',
        'special': '✨',
      },
      deityCategoryEmoji: {
        'god': '🕊️',
        'saint': '✨',
        'other': '🔰',
      },
      deitySectionEmoji: {
        'domains': '🧭',
      },
      specialSectionColor: Colors.amber.shade300,
      cardTitleStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: scheme.onSurface.withOpacity(0.95),
      ),
      sectionLabelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: scheme.onSurface.withOpacity(0.85),
      ),
      badgeTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
        color: scheme.onSurface.withOpacity(0.85),
      ),
    );
  }

  static DsTheme of(BuildContext context) {
    final ext = Theme.of(context).extension<DsTheme>();
    return ext ?? DsTheme.defaults(Theme.of(context).colorScheme);
  }

  @override
  DsTheme copyWith({
    Map<String, Color>? languageTypeBorder,
    Map<String, Color>? skillGroupBorder,
    Map<String, Color>? deityCategoryBorder,
    Map<int, Color>? titleEchelonBorder,
    Map<String, String>? languageTypeEmoji,
    Map<String, String>? languageSectionEmoji,
    Map<String, String>? skillGroupEmoji,
    Map<String, String>? skillSectionEmoji,
    Map<String, String>? titleSectionEmoji,
    Map<String, String>? deityCategoryEmoji,
    Map<String, String>? deitySectionEmoji,
    Color? specialSectionColor,
    TextStyle? cardTitleStyle,
    TextStyle? sectionLabelStyle,
    TextStyle? badgeTextStyle,
  }) {
    return DsTheme(
      languageTypeBorder: languageTypeBorder ?? this.languageTypeBorder,
      skillGroupBorder: skillGroupBorder ?? this.skillGroupBorder,
      deityCategoryBorder: deityCategoryBorder ?? this.deityCategoryBorder,
      titleEchelonBorder: titleEchelonBorder ?? this.titleEchelonBorder,
      languageTypeEmoji: languageTypeEmoji ?? this.languageTypeEmoji,
      languageSectionEmoji: languageSectionEmoji ?? this.languageSectionEmoji,
      skillGroupEmoji: skillGroupEmoji ?? this.skillGroupEmoji,
      skillSectionEmoji: skillSectionEmoji ?? this.skillSectionEmoji,
      titleSectionEmoji: titleSectionEmoji ?? this.titleSectionEmoji,
      deityCategoryEmoji: deityCategoryEmoji ?? this.deityCategoryEmoji,
      deitySectionEmoji: deitySectionEmoji ?? this.deitySectionEmoji,
      specialSectionColor: specialSectionColor ?? this.specialSectionColor,
      cardTitleStyle: cardTitleStyle ?? this.cardTitleStyle,
      sectionLabelStyle: sectionLabelStyle ?? this.sectionLabelStyle,
      badgeTextStyle: badgeTextStyle ?? this.badgeTextStyle,
    );
  }

  @override
  ThemeExtension<DsTheme> lerp(ThemeExtension<DsTheme>? other, double t) {
    // Non-animated for simplicity.
    return this;
  }
}
