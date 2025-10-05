import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/models/class_data.dart';
import '../../../../core/models/subclass_models.dart';
import '../../../../core/services/class_feature_data_service.dart';
import 'class_features_widget.dart';

class ClassFeaturesSection extends StatefulWidget {
  const ClassFeaturesSection({
    super.key,
    required this.classData,
    required this.selectedLevel,
    this.selectedSubclass,
    this.initialSelections = const {},
    this.onSelectionsChanged,
  });

  final ClassData classData;
  final int selectedLevel;
  final SubclassSelectionResult? selectedSubclass;
  final Map<String, Set<String>> initialSelections;
  final ValueChanged<Map<String, Set<String>>>? onSelectionsChanged;

  @override
  State<ClassFeaturesSection> createState() => _ClassFeaturesSectionState();
}

class _ClassFeaturesSectionState extends State<ClassFeaturesSection> {
  final ClassFeatureDataService _service = ClassFeatureDataService();

  bool _isLoading = true;
  String? _error;
  ClassFeatureDataResult? _data;
  Map<String, Set<String>> _selections = const {};
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _selections = _normalizeSelections(widget.initialSelections);
    _load();
  }

  @override
  void didUpdateWidget(covariant ClassFeaturesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final classChanged =
        oldWidget.classData.classId != widget.classData.classId;
    final levelChanged = oldWidget.selectedLevel != widget.selectedLevel;
    final subclassChanged =
        oldWidget.selectedSubclass != widget.selectedSubclass;
    final initialSelectionsChanged =
        !_mapsEqual(oldWidget.initialSelections, widget.initialSelections);

    if (classChanged) {
      _selections = _normalizeSelections(widget.initialSelections);
      _load();
      return;
    }

    if (levelChanged || subclassChanged) {
      _load();
      return;
    }

    if (initialSelectionsChanged) {
      setState(() {
        _selections = _normalizeSelections(widget.initialSelections);
      });
    }
  }

  void _load() async {
    final requestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _error = null;
      _data = null;
    });

    final activeSubclassSlugs =
        ClassFeatureDataService.activeSubclassSlugs(widget.selectedSubclass);

    try {
      final result = await _service.loadFeatures(
        classData: widget.classData,
        level: widget.selectedLevel,
        activeSubclassSlugs: activeSubclassSlugs,
      );
      if (!mounted || requestId != _loadRequestId) return;

      final allowedOptionKeys = <String, Set<String>>{};
      result.featureDetailsById.forEach((featureId, details) {
        allowedOptionKeys[featureId] =
            ClassFeatureDataService.extractOptionKeys(details);
      });

      final baseSelections = Map<String, Set<String>>.from(_selections);
      if (baseSelections.isEmpty) {
        baseSelections.addAll(_normalizeSelections(widget.initialSelections));
      }

      final cleanedSelections = <String, Set<String>>{};
      baseSelections.forEach((featureId, values) {
        final allowed = allowedOptionKeys[featureId] ?? const <String>{};
        final filtered = values.where(allowed.contains).toSet();
        if (filtered.isNotEmpty) {
          cleanedSelections[featureId] = filtered;
        }
      });

      final workingSelections =
          Map<String, Set<String>>.from(cleanedSelections);
      final domainSlugs =
          ClassFeatureDataService.selectedDomainSlugs(widget.selectedSubclass);
      final deitySlugs =
          ClassFeatureDataService.selectedDeitySlugs(widget.selectedSubclass);
      ClassFeatureDataService.applyDomainSelectionToFeatures(
        selections: workingSelections,
        featureDetailsById: result.featureDetailsById,
        domainLinkedFeatureIds: result.domainLinkedFeatureIds,
        domainSlugs: domainSlugs,
      );
      ClassFeatureDataService.applySubclassSelectionToFeatures(
        selections: workingSelections,
        features: result.features,
        featureDetailsById: result.featureDetailsById,
        subclassSlugs: activeSubclassSlugs,
      );
      ClassFeatureDataService.applyDeitySelectionToFeatures(
        selections: workingSelections,
        featureDetailsById: result.featureDetailsById,
        deityLinkedFeatureIds: result.deityLinkedFeatureIds,
        deitySlugs: deitySlugs,
      );

      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _isLoading = false;
        _error = null;
        _data = result;
        _selections = workingSelections;
      });
      _notifySelectionsChanged();
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load class features: $e';
        _data = null;
        _selections = const {};
      });
      _notifySelectionsChanged();
    }
  }

  Map<String, Set<String>> _normalizeSelections(
    Map<String, Set<String>> selections,
  ) {
    final normalized = <String, Set<String>>{};
    selections.forEach((featureId, values) {
      final trimmedId = featureId.trim();
      if (trimmedId.isEmpty) return;
      final cleanedValues = values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet();
      if (cleanedValues.isNotEmpty) {
        normalized[trimmedId] = cleanedValues;
      }
    });
    return normalized;
  }

  void _handleSelectionChanged(String featureId, Set<String> selections) {
    final trimmedId = featureId.trim();
    if (trimmedId.isEmpty) return;

    final updated = Map<String, Set<String>>.from(_selections);
    final cleanedSelections = selections
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (cleanedSelections.isEmpty) {
      updated.remove(trimmedId);
    } else {
      updated[trimmedId] = cleanedSelections;
    }

    final data = _data;
    if (data != null) {
      final domainSlugs =
          ClassFeatureDataService.selectedDomainSlugs(widget.selectedSubclass);
      final subclassSlugs =
          ClassFeatureDataService.activeSubclassSlugs(widget.selectedSubclass);
      final deitySlugs =
          ClassFeatureDataService.selectedDeitySlugs(widget.selectedSubclass);
      ClassFeatureDataService.applyDomainSelectionToFeatures(
        selections: updated,
        featureDetailsById: data.featureDetailsById,
        domainLinkedFeatureIds: data.domainLinkedFeatureIds,
        domainSlugs: domainSlugs,
      );
      ClassFeatureDataService.applySubclassSelectionToFeatures(
        selections: updated,
        features: data.features,
        featureDetailsById: data.featureDetailsById,
        subclassSlugs: subclassSlugs,
      );
      ClassFeatureDataService.applyDeitySelectionToFeatures(
        selections: updated,
        featureDetailsById: data.featureDetailsById,
        deityLinkedFeatureIds: data.deityLinkedFeatureIds,
        deitySlugs: deitySlugs,
      );
    }

    setState(() {
      _selections = updated;
    });
    _notifySelectionsChanged();
  }

  void _notifySelectionsChanged() {
    if (widget.onSelectionsChanged == null) return;
    widget.onSelectionsChanged!(
      Map<String, Set<String>>.unmodifiable(_selections),
    );
  }

  bool _mapsEqual(
    Map<String, Set<String>> a,
    Map<String, Set<String>> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) {
        if (!b.containsKey(entry.key)) {
          return false;
        }
        if (entry.value.isNotEmpty) {
          return false;
        }
        continue;
      }
      if (!setEquals(entry.value, other)) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text('Loading class features...'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      );
    }

    final data = _data;
    if (data == null || data.features.isEmpty) {
      return const SizedBox.shrink();
    }

    final domainSlugs =
        ClassFeatureDataService.selectedDomainSlugs(widget.selectedSubclass);
    final subclassSlugs =
        ClassFeatureDataService.activeSubclassSlugs(widget.selectedSubclass);
    final subclassLabel =
        ClassFeatureDataService.subclassLabel(widget.selectedSubclass);
    final deitySlugs =
        ClassFeatureDataService.selectedDeitySlugs(widget.selectedSubclass);

    return ClassFeaturesWidget(
      level: widget.selectedLevel,
      features: data.features,
      featureDetailsById: data.featureDetailsById,
      selectedOptions: _selections,
      onSelectionChanged: _handleSelectionChanged,
      domainLinkedFeatureIds: data.domainLinkedFeatureIds,
      selectedDomainSlugs: domainSlugs,
      deityLinkedFeatureIds: data.deityLinkedFeatureIds,
      selectedDeitySlugs: deitySlugs,
      abilityDetailsById: data.abilityDetailsById,
      abilityIdByName: data.abilityIdByName,
      activeSubclassSlugs: subclassSlugs,
      subclassLabel: subclassLabel,
      subclassSelection: widget.selectedSubclass,
    );
  }
}
