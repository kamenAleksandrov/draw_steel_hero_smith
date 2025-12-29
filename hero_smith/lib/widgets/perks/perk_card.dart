import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/providers.dart';
import '../../core/models/component.dart';
import '../../core/services/perk_grants_service.dart';
import '../../core/theme/ds_theme.dart';
import '../abilities/ability_expandable_item.dart';
import '../shared/section_widgets.dart';
import '../shared/expandable_card.dart';

/// Provider for loading perk grant choices for a specific hero and perk
final _perkGrantChoicesProvider = FutureProvider.family<
    Map<String, List<String>>, ({String heroId, String perkId})>((ref, args) async {
  final db = ref.read(appDatabaseProvider);
  return PerkGrantsService().getAllGrantChoicesForPerk(
    db: db,
    heroId: args.heroId,
    perkId: args.perkId,
  );
});

/// Provider for loading hero's skills
final _heroSkillIdsProvider = FutureProvider.family<List<String>, String>((ref, heroId) async {
  final db = ref.read(appDatabaseProvider);
  return PerkGrantsService().getHeroSkillIds(db: db, heroId: heroId);
});

/// Provider for loading hero's languages  
final _heroLanguageIdsProvider = FutureProvider.family<List<String>, String>((ref, heroId) async {
  final db = ref.read(appDatabaseProvider);
  return PerkGrantsService().getHeroLanguageIds(db: db, heroId: heroId);
});

/// Provider for loading all skills
final _allSkillsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return PerkGrantsService().loadSkills();
});

/// Provider for loading all languages
final _allLanguagesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return PerkGrantsService().loadLanguages();
});

class PerkCard extends ConsumerWidget {
  final Component perk;
  /// If provided, enables hero-specific grant selection UI
  final String? heroId;
  /// Skill IDs that are already taken (from other sources) and should be excluded from pickers
  final Set<String> reservedSkillIds;
  /// Language IDs that are already taken (from other sources) and should be excluded from pickers
  final Set<String> reservedLanguageIds;

  const PerkCard({
    super.key,
    required this.perk,
    this.heroId,
    this.reservedSkillIds = const {},
    this.reservedLanguageIds = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = perk.data;
    final group = (data['group'] as String?) ?? 'exploration';
    final description = data['description'] as String?;
    final grantsRaw = data['grants'];

    final ds = DsTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final borderColor = ds.perkGroupBorder[group] ?? scheme.outlineVariant;
    final neutralText = scheme.onSurface;
    
    // Parse grants using the service
    final parsedGrant = PerkGrant.fromJson(grantsRaw);
    final hasGrants = parsedGrant != null;

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
          if (hasGrants) ...[
            SectionLabel('Grants', emoji: ds.perkSectionEmoji['grants'], color: borderColor),
            const SizedBox(height: 8),
            _buildGrantsFromParsed(context, ref, parsedGrant, neutralText, borderColor),
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

  Widget _buildGrantsFromParsed(BuildContext context, WidgetRef ref, PerkGrant grant, Color textColor, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildGrantWidgets(context, ref, grant, textColor, accentColor),
      ),
    );
  }

  List<Widget> _buildGrantWidgets(BuildContext context, WidgetRef ref, PerkGrant grant, Color textColor, Color accentColor) {
    return switch (grant) {
      AbilityGrant(:final abilityName) => [_buildAbilityGrantItem(context, ref, abilityName, textColor, accentColor)],
      CreatureGrant(:final creatureName) => [_buildCreatureGrantItem(creatureName, textColor)],
      SkillFromOwnedGrant(:final group) => [_buildSkillFromOwnedGrantItem(context, ref, group, textColor, accentColor)],
      SkillPickGrant(:final group, :final count) => [_buildSkillPickGrantItem(context, ref, group, count, textColor, accentColor)],
      LanguageGrant(:final count) => [_buildLanguageGrantItem(context, ref, count, textColor, accentColor)],
      MultiGrant(:final grants) => grants.expand((g) => _buildGrantWidgets(context, ref, g, textColor, accentColor)).toList(),
    };
  }

  Widget _buildAbilityGrantItem(BuildContext context, WidgetRef ref, String abilityName, Color textColor, Color accentColor) {
    // Look up the full ability by name
    final abilityAsync = ref.watch(abilityByNameProvider(abilityName));
    
    return abilityAsync.when(
      data: (ability) {
        if (ability == null) {
          return _buildGrantRow('Ability: $abilityName', textColor);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AbilityExpandableItem(component: ability),
        );
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

  Widget _buildCreatureGrantItem(String creatureName, Color textColor) {
    // For now, just display the creature name - future implementation
    return _buildGrantRow('🐾 Creature: $creatureName', textColor);
  }

  Widget _buildSkillFromOwnedGrantItem(BuildContext context, WidgetRef ref, String group, Color textColor, Color accentColor) {
    // If no heroId, just show generic text
    if (heroId == null) {
      return _buildGrantRow('Choose one $group skill you own', textColor);
    }

    // Load hero's skills and all skills for the group
    final heroSkillsAsync = ref.watch(_heroSkillIdsProvider(heroId!));
    final allSkillsAsync = ref.watch(_allSkillsProvider);
    final choicesAsync = ref.watch(_perkGrantChoicesProvider((heroId: heroId!, perkId: perk.id)));

    return heroSkillsAsync.when(
      loading: () => _buildLoadingGrant(accentColor, textColor),
      error: (e, _) => _buildGrantRow('Choose one $group skill you own', textColor),
      data: (heroSkillIds) => allSkillsAsync.when(
        loading: () => _buildLoadingGrant(accentColor, textColor),
        error: (e, _) => _buildGrantRow('Choose one $group skill you own', textColor),
        data: (allSkills) => choicesAsync.when(
          loading: () => _buildLoadingGrant(accentColor, textColor),
          error: (e, _) => _buildGrantRow('Choose one $group skill you own', textColor),
          data: (choices) {
            // Get skills that: 1) hero owns AND 2) match the group
            final groupSkills = allSkills.where((s) =>
              (s['group'] as String?)?.toLowerCase() == group.toLowerCase()
            ).toList();
            
            final ownedGroupSkills = groupSkills.where((s) =>
              heroSkillIds.contains(s['id'] as String?)
            ).toList();

            if (ownedGroupSkills.isEmpty) {
              return _buildGrantRow('⚠️ No $group skills owned', textColor.withOpacity(0.7));
            }

            // Get current choice
            final currentChoice = choices['skill_owned']?.firstOrNull;
            final selectedSkill = currentChoice != null
              ? ownedGroupSkills.firstWhere(
                  (s) => s['id'] == currentChoice,
                  orElse: () => <String, dynamic>{},
                )
              : null;

            return _buildSkillSelector(
              context: context,
              ref: ref,
              label: 'Chosen ${_capitalize(group)} Skill',
              skills: ownedGroupSkills,
              selectedSkillId: currentChoice,
              selectedSkillName: selectedSkill?['name'] as String?,
              grantType: 'skill_owned',
              textColor: textColor,
              accentColor: accentColor,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkillPickGrantItem(BuildContext context, WidgetRef ref, String group, int count, Color textColor, Color accentColor) {
    // If no heroId, just show generic text
    if (heroId == null) {
      return _buildGrantRow('Choose $count new $group skill${count > 1 ? 's' : ''}', textColor);
    }

    // Load hero's skills and all skills for the group
    final heroSkillsAsync = ref.watch(_heroSkillIdsProvider(heroId!));
    final allSkillsAsync = ref.watch(_allSkillsProvider);
    final choicesAsync = ref.watch(_perkGrantChoicesProvider((heroId: heroId!, perkId: perk.id)));

    return heroSkillsAsync.when(
      loading: () => _buildLoadingGrant(accentColor, textColor),
      error: (e, _) => _buildGrantRow('Choose $count new $group skill${count > 1 ? 's' : ''}', textColor),
      data: (heroSkillIds) => allSkillsAsync.when(
        loading: () => _buildLoadingGrant(accentColor, textColor),
        error: (e, _) => _buildGrantRow('Choose $count new $group skill${count > 1 ? 's' : ''}', textColor),
        data: (allSkills) => choicesAsync.when(
          loading: () => _buildLoadingGrant(accentColor, textColor),
          error: (e, _) => _buildGrantRow('Choose $count new $group skill${count > 1 ? 's' : ''}', textColor),
          data: (choices) {
            // Get skills that: 1) hero DOESN'T own AND 2) match the group
            final groupSkills = allSkills.where((s) =>
              (s['group'] as String?)?.toLowerCase() == group.toLowerCase()
            ).toList();
            
            // Exclude skills that are already owned OR reserved by other sources
            final availableSkills = groupSkills.where((s) {
              final skillId = s['id'] as String?;
              if (skillId == null) return false;
              if (heroSkillIds.contains(skillId)) return false;
              if (reservedSkillIds.contains(skillId)) return false;
              return true;
            }).toList();

            // Get current choices
            final currentChoices = choices['skill_pick'] ?? [];
            
            // Build a widget for each slot
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(count, (index) {
                final selectedId = index < currentChoices.length ? currentChoices[index] : null;
                final selectedSkill = selectedId != null
                  ? groupSkills.firstWhere(
                      (s) => s['id'] == selectedId,
                      orElse: () => <String, dynamic>{},
                    )
                  : null;

                // For available options, exclude already selected ones (from other slots)
                final alreadySelected = currentChoices.where((id) => id != selectedId).toSet();
                final slotOptions = availableSkills.where((s) =>
                  !alreadySelected.contains(s['id'] as String?)
                ).toList();

                return _buildSkillSelector(
                  context: context,
                  ref: ref,
                  label: count == 1 
                    ? 'New ${_capitalize(group)} Skill'
                    : 'New ${_capitalize(group)} Skill ${index + 1}',
                  skills: slotOptions,
                  selectedSkillId: selectedId,
                  selectedSkillName: selectedSkill?['name'] as String?,
                  grantType: 'skill_pick',
                  slotIndex: index,
                  allCurrentChoices: currentChoices,
                  textColor: textColor,
                  accentColor: accentColor,
                );
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLanguageGrantItem(BuildContext context, WidgetRef ref, int count, Color textColor, Color accentColor) {
    // If no heroId, just show generic text
    if (heroId == null) {
      return _buildGrantRow('Choose $count new language${count > 1 ? 's' : ''}', textColor);
    }

    // Load hero's languages and all languages
    final heroLanguagesAsync = ref.watch(_heroLanguageIdsProvider(heroId!));
    final allLanguagesAsync = ref.watch(_allLanguagesProvider);
    final choicesAsync = ref.watch(_perkGrantChoicesProvider((heroId: heroId!, perkId: perk.id)));

    return heroLanguagesAsync.when(
      loading: () => _buildLoadingGrant(accentColor, textColor),
      error: (e, _) => _buildGrantRow('Choose $count new language${count > 1 ? 's' : ''}', textColor),
      data: (heroLanguageIds) => allLanguagesAsync.when(
        loading: () => _buildLoadingGrant(accentColor, textColor),
        error: (e, _) => _buildGrantRow('Choose $count new language${count > 1 ? 's' : ''}', textColor),
        data: (allLanguages) => choicesAsync.when(
          loading: () => _buildLoadingGrant(accentColor, textColor),
          error: (e, _) => _buildGrantRow('Choose $count new language${count > 1 ? 's' : ''}', textColor),
          data: (choices) {
            // Get languages that hero DOESN'T own AND are not reserved by other sources
            final availableLanguages = allLanguages.where((l) {
              final langId = l['id'] as String?;
              if (langId == null) return false;
              if (heroLanguageIds.contains(langId)) return false;
              if (reservedLanguageIds.contains(langId)) return false;
              return true;
            }).toList();

            // Get current choices
            final currentChoices = choices['language'] ?? [];
            
            // Build a widget for each slot
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(count, (index) {
                final selectedId = index < currentChoices.length ? currentChoices[index] : null;
                final selectedLanguage = selectedId != null
                  ? allLanguages.firstWhere(
                      (l) => l['id'] == selectedId,
                      orElse: () => <String, dynamic>{},
                    )
                  : null;

                // For available options, exclude already selected ones (from other slots)
                final alreadySelected = currentChoices.where((id) => id != selectedId).toSet();
                final slotOptions = availableLanguages.where((l) =>
                  !alreadySelected.contains(l['id'] as String?)
                ).toList();

                return _buildLanguageSelector(
                  context: context,
                  ref: ref,
                  label: count == 1 ? 'New Language' : 'New Language ${index + 1}',
                  languages: slotOptions,
                  selectedLanguageId: selectedId,
                  selectedLanguageName: selectedLanguage?['name'] as String?,
                  slotIndex: index,
                  allCurrentChoices: currentChoices,
                  textColor: textColor,
                  accentColor: accentColor,
                );
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingGrant(Color accentColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: accentColor),
          ),
          const SizedBox(width: 8),
          Text('Loading...', style: TextStyle(fontSize: 11, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildSkillSelector({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required List<Map<String, dynamic>> skills,
    required String? selectedSkillId,
    required String? selectedSkillName,
    required String grantType,
    int? slotIndex,
    List<String>? allCurrentChoices,
    required Color textColor,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 0, left: 2, right: 6),
            child: Icon(Icons.school, size: 14, color: accentColor),
          ),
          Expanded(
            child: InkWell(
              onTap: skills.isEmpty ? null : () => _showSkillPicker(
                context: context,
                ref: ref,
                skills: skills,
                currentSelectedId: selectedSkillId,
                grantType: grantType,
                slotIndex: slotIndex,
                allCurrentChoices: allCurrentChoices,
                accentColor: accentColor,
              ),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selectedSkillId != null 
                      ? accentColor.withOpacity(0.4)
                      : accentColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedSkillName ?? 'Tap to select $label',
                        style: TextStyle(
                          fontSize: 11,
                          color: selectedSkillName != null ? textColor : textColor.withOpacity(0.6),
                          fontStyle: selectedSkillName != null ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: accentColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required List<Map<String, dynamic>> languages,
    required String? selectedLanguageId,
    required String? selectedLanguageName,
    int? slotIndex,
    List<String>? allCurrentChoices,
    required Color textColor,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 0, left: 2, right: 6),
            child: Icon(Icons.translate, size: 14, color: accentColor),
          ),
          Expanded(
            child: InkWell(
              onTap: languages.isEmpty ? null : () => _showLanguagePicker(
                context: context,
                ref: ref,
                languages: languages,
                currentSelectedId: selectedLanguageId,
                slotIndex: slotIndex,
                allCurrentChoices: allCurrentChoices,
                accentColor: accentColor,
              ),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selectedLanguageId != null 
                      ? accentColor.withOpacity(0.4)
                      : accentColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedLanguageName ?? 'Tap to select $label',
                        style: TextStyle(
                          fontSize: 11,
                          color: selectedLanguageName != null ? textColor : textColor.withOpacity(0.6),
                          fontStyle: selectedLanguageName != null ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: accentColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSkillPicker({
    required BuildContext context,
    required WidgetRef ref,
    required List<Map<String, dynamic>> skills,
    required String? currentSelectedId,
    required String grantType,
    int? slotIndex,
    List<String>? allCurrentChoices,
    required Color accentColor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Select Skill',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: skills.length,
                itemBuilder: (_, index) {
                  final skill = skills[index];
                  final id = skill['id'] as String?;
                  final name = skill['name'] as String? ?? 'Unknown';
                  final isSelected = id == currentSelectedId;

                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? accentColor : null,
                    ),
                    title: Text(name),
                    selected: isSelected,
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (id == null || heroId == null) return;
                      
                      final db = ref.read(appDatabaseProvider);
                      final service = PerkGrantsService();
                      
                      // Update the choice list
                      List<String> newChoices;
                      if (slotIndex != null && allCurrentChoices != null) {
                        // Multi-slot selection
                        newChoices = List<String>.from(allCurrentChoices);
                        while (newChoices.length <= slotIndex) {
                          newChoices.add('');
                        }
                        newChoices[slotIndex] = id;
                        // Remove empty strings
                        newChoices = newChoices.where((c) => c.isNotEmpty).toList();
                      } else {
                        // Single selection
                        newChoices = [id];
                      }
                      
                      // Save choice and apply changes (removes old grants, adds new ones)
                      await service.saveGrantChoiceAndApply(
                        db: db,
                        heroId: heroId!,
                        perkId: perk.id,
                        grantType: grantType,
                        chosenIds: newChoices,
                      );
                      
                      // Invalidate providers to refresh
                      ref.invalidate(_perkGrantChoicesProvider((heroId: heroId!, perkId: perk.id)));
                      ref.invalidate(_heroSkillIdsProvider(heroId!));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker({
    required BuildContext context,
    required WidgetRef ref,
    required List<Map<String, dynamic>> languages,
    required String? currentSelectedId,
    int? slotIndex,
    List<String>? allCurrentChoices,
    required Color accentColor,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Select Language',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: languages.length,
                itemBuilder: (_, index) {
                  final language = languages[index];
                  final id = language['id'] as String?;
                  final name = language['name'] as String? ?? 'Unknown';
                  final isSelected = id == currentSelectedId;

                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? accentColor : null,
                    ),
                    title: Text(name),
                    selected: isSelected,
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (id == null || heroId == null) return;
                      
                      final db = ref.read(appDatabaseProvider);
                      final service = PerkGrantsService();
                      
                      // Update the choice list
                      List<String> newChoices;
                      if (slotIndex != null && allCurrentChoices != null) {
                        // Multi-slot selection
                        newChoices = List<String>.from(allCurrentChoices);
                        while (newChoices.length <= slotIndex) {
                          newChoices.add('');
                        }
                        newChoices[slotIndex] = id;
                        // Remove empty strings
                        newChoices = newChoices.where((c) => c.isNotEmpty).toList();
                      } else {
                        // Single selection
                        newChoices = [id];
                      }
                      
                      // Save choice and apply changes (removes old grants, adds new ones)
                      await service.saveGrantChoiceAndApply(
                        db: db,
                        heroId: heroId!,
                        perkId: perk.id,
                        grantType: 'language',
                        chosenIds: newChoices,
                      );
                      
                      // Invalidate providers to refresh
                      ref.invalidate(_perkGrantChoicesProvider((heroId: heroId!, perkId: perk.id)));
                      ref.invalidate(_heroLanguageIdsProvider(heroId!));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
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
}
