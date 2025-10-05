import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/providers.dart';
import '../models/story_creator_models.dart';
import '../repositories/hero_repository.dart';

class StoryCreatorService {
  StoryCreatorService(this._heroRepository);

  final HeroRepository _heroRepository;
  Map<String, StoryCultureSuggestion>? _suggestionsCache;

  Future<StoryCreatorLoadResult> loadInitialData(String heroId) async {
    final hero = await _heroRepository.load(heroId);
    final culture = await _heroRepository.loadCultureSelection(heroId);
    final career = await _heroRepository.loadCareerSelection(heroId);
    final traits = await _heroRepository.getSelectedAncestryTraits(heroId);
    return StoryCreatorLoadResult(
      hero: hero,
      cultureSelection: culture,
      careerSelection: career,
      ancestryTraitIds: traits,
    );
  }

  Future<void> saveStory(StoryCreatorSavePayload payload) async {
    final hero = await _heroRepository.load(payload.heroId);
    if (hero == null) {
      throw Exception('Hero with id ${payload.heroId} not found.');
    }

    hero.name = payload.name;
    hero.ancestry = payload.ancestryId;
    hero.career = payload.careerId;

    await _heroRepository.save(hero);

    await _heroRepository.saveAncestryTraits(
      heroId: payload.heroId,
      ancestryId: payload.ancestryId,
      selectedTraitIds: payload.ancestryTraitIds.toList(),
    );

    final languageIds = payload.languageIds
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();

    await _heroRepository.saveCultureSelection(
      heroId: payload.heroId,
      environmentId: payload.environmentId,
      organisationId: payload.organisationId,
      upbringingId: payload.upbringingId,
      languageIds: languageIds,
      environmentSkillId: payload.environmentSkillId,
      organisationSkillId: payload.organisationSkillId,
      upbringingSkillId: payload.upbringingSkillId,
    );

    await _heroRepository.saveCareerSelection(
      heroId: payload.heroId,
      careerId: payload.careerId,
      chosenSkillIds: payload.careerSkillIds.toList(),
      chosenPerkIds: payload.careerPerkIds.toList(),
      incitingIncidentName: payload.careerIncidentName,
    );
  }

  Future<StoryCultureSuggestion?> suggestionForAncestry(String? ancestryName) async {
    if (ancestryName == null || ancestryName.trim().isEmpty) return null;
    final map = await _loadSuggestions();
    return map[ancestryName.trim().toLowerCase()];
  }

  Future<Map<String, StoryCultureSuggestion>> _loadSuggestions() async {
    if (_suggestionsCache != null) return _suggestionsCache!;
    try {
      final raw = await rootBundle
          .loadString('data/story/culture/culture_suggestions.json');
      final decoded = jsonDecode(raw);
      final result = <String, StoryCultureSuggestion>{};
      if (decoded is Map && decoded['typical_ancestry_cultures'] is List) {
        for (final entry in decoded['typical_ancestry_cultures']) {
          if (entry is! Map) continue;
          final map = entry.cast<String, dynamic>();
          final key = (map['ancestry']?.toString() ?? '').toLowerCase();
          if (key.isEmpty) continue;
          result[key] = StoryCultureSuggestion(
            language: _clean(map['language']),
            environment: _clean(map['environment']),
            organization: _clean(map['organization']),
            upbringing: _clean(map['upbringing']),
          );
        }
      }
      _suggestionsCache = result;
      return result;
    } catch (_) {
      _suggestionsCache = const <String, StoryCultureSuggestion>{};
      return _suggestionsCache!;
    }
  }

  String? _clean(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

final storyCreatorServiceProvider = Provider<StoryCreatorService>((ref) {
  final repo = ref.read(heroRepositoryProvider);
  return StoryCreatorService(repo);
});
