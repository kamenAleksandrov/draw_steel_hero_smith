import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

/// Represents a single generation option preset
class GenerationPreset {
  final String key;
  final String label;

  const GenerationPreset({required this.key, required this.label});

  factory GenerationPreset.fromJson(Map<String, dynamic> json) {
    return GenerationPreset(
      key: json['key'] as String,
      label: json['label'] as String,
    );
  }
}

/// Represents a class's heroic resource generation options
class HeroicResourceGeneration {
  final String classKey;
  final String resourceKey;
  final List<String> generationOptions;

  const HeroicResourceGeneration({
    required this.classKey,
    required this.resourceKey,
    required this.generationOptions,
  });

  factory HeroicResourceGeneration.fromJson(Map<String, dynamic> json) {
    return HeroicResourceGeneration(
      classKey: json['class_key'] as String,
      resourceKey: json['resource_key'] as String,
      generationOptions: (json['generation_options'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}

/// Result of a resource generation action
class GenerationResult {
  final int value;
  final String description;
  final bool requiresConfirmation;
  final List<int>? alternativeValues; // For dice rolls where user can pick

  const GenerationResult({
    required this.value,
    required this.description,
    this.requiresConfirmation = false,
    this.alternativeValues,
  });
}

/// Service for managing heroic resource generation
class ResourceGenerationService {
  static ResourceGenerationService? _instance;
  static ResourceGenerationService get instance {
    _instance ??= ResourceGenerationService._();
    return _instance!;
  }

  ResourceGenerationService._();

  Map<String, GenerationPreset> _presets = {};
  Map<String, HeroicResourceGeneration> _classResources = {};
  bool _initialized = false;

  final Random _random = Random();

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final jsonString = await rootBundle.loadString(
        'data/features/class_features/resource_generation.json',
      );
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // Load presets
      final presetsList = data['amount_presets'] as List<dynamic>;
      for (final presetJson in presetsList) {
        final preset = GenerationPreset.fromJson(presetJson as Map<String, dynamic>);
        _presets[preset.key] = preset;
      }

      // Load class resources
      final resourcesList = data['heroic_resources'] as List<dynamic>;
      for (final resourceJson in resourcesList) {
        final resource = HeroicResourceGeneration.fromJson(resourceJson as Map<String, dynamic>);
        _classResources[resource.classKey] = resource;
      }

      _initialized = true;
    } catch (e) {
      // If loading fails, use empty defaults
      _presets = {};
      _classResources = {};
      _initialized = true;
    }
  }

  /// Get the generation options for a class
  List<GenerationPreset> getGenerationOptionsForClass(String? classId) {
    if (classId == null || classId.isEmpty) return [];

    // Extract class key from classId (e.g., "class_fury" -> "fury")
    final classKey = classId.startsWith('class_')
        ? classId.substring('class_'.length)
        : classId;

    final resourceGen = _classResources[classKey.toLowerCase()];
    if (resourceGen == null) return [];

    return resourceGen.generationOptions
        .map((key) => _presets[key])
        .whereType<GenerationPreset>()
        .toList();
  }

  /// Calculate the result for a generation option
  GenerationResult calculateGeneration({
    required String optionKey,
    required int victories,
  }) {
    switch (optionKey) {
      case 'victories':
        return GenerationResult(
          value: victories,
          description: '+$victories (Victories)',
        );

      case 'plus_1':
        return const GenerationResult(
          value: 1,
          description: '+1',
        );

      case 'plus_2':
        return const GenerationResult(
          value: 2,
          description: '+2',
        );

      case 'plus_1d3':
        // Roll 1d3 (1, 2, or 3)
        final roll = _random.nextInt(3) + 1;
        return GenerationResult(
          value: roll,
          description: '+$roll (1d3)',
          requiresConfirmation: true,
          alternativeValues: [1, 2, 3],
        );

      default:
        return const GenerationResult(
          value: 0,
          description: '+0',
        );
    }
  }

  /// Get the display label for an option, replacing X with victories count
  String getDisplayLabel(String optionKey, int victories) {
    final preset = _presets[optionKey];
    if (preset == null) return '+?';

    if (optionKey == 'victories') {
      return '+$victories';
    }

    return preset.label;
  }
}
