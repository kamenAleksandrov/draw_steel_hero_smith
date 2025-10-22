import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/models/abilities_models.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/perks_models.dart';
import '../../../core/models/skills_models.dart';
import '../../../core/models/subclass_models.dart';
import '../../../core/services/class_data_service.dart';
import '../widgets/strife_creator/class_features_section.dart';
import '../widgets/strife_creator/choose_abilities_widget.dart';
import '../widgets/strife_creator/choose_perks_widget.dart';
import '../widgets/strife_creator/choose_skills_widget.dart';
import '../widgets/strife_creator/choose_subclass_widget.dart';
import '../widgets/strife_creator/class_selector_widget.dart';
import '../widgets/strife_creator/level_selector_widget.dart';
import '../widgets/strife_creator/starting_characteristics_widget.dart';

/// Demo page for the new Strife Creator (Level, Class, and Starting Characteristics)
class StrifeCreatorPage extends ConsumerStatefulWidget {
  const StrifeCreatorPage({super.key, required this.heroId});

  final String heroId;

  @override
  ConsumerState<StrifeCreatorPage> createState() => _StrifeCreatorPageState();
}

class _StrifeCreatorPageState extends ConsumerState<StrifeCreatorPage> {
  final ClassDataService _classDataService = ClassDataService();

  bool _isLoading = true;
  String? _errorMessage;

  // State variables
  int _selectedLevel = 1;
  ClassData? _selectedClass;
  CharacteristicArray? _selectedArray;
  Map<String, int> _assignedCharacteristics = {};
// ignore: unused_field
  Map<String, int> _finalCharacteristics = {};
  Map<String, String?> _selectedSkills = {};
  Map<String, String?> _selectedAbilities = {};
  Map<String, String?> _selectedPerks = {};
  SubclassSelectionResult? _selectedSubclass;
  Map<String, Set<String>> _featureSelections = {};
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _classDataService.initialize();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load class data: $e';
      });
    }
  }

  void _handleLevelChanged(int level) {
    setState(() {
      _selectedLevel = level;
    });
  }

  void _handleClassChanged(ClassData classData) {
    setState(() {
      _selectedClass = classData;
      // Reset characteristic and skill selections when class changes
      _selectedArray = null;
      _assignedCharacteristics = {};
      _selectedSkills = {};
      _selectedAbilities = {};
      _selectedPerks = {};
      _selectedSubclass = null;
      _featureSelections = {};
    });
  }

  void _handleArrayChanged(CharacteristicArray? array) {
    setState(() {
      _selectedArray = array;
      _assignedCharacteristics = {};
    });
  }

  void _handleAssignmentsChanged(Map<String, int> assignments) {
    setState(() {
      _assignedCharacteristics = assignments;
    });
  }

  void _handleFinalTotalsChanged(Map<String, int> totals) {
    setState(() {
      _finalCharacteristics = totals;
    });
  }

  void _handleSkillSelectionsChanged(StartingSkillSelectionResult result) {
    setState(() {
      _selectedSkills = result.selectionsBySlot;
    });
  }

  void _handlePerkSelectionsChanged(StartingPerkSelectionResult result) {
    setState(() {
      _selectedPerks = result.selectionsBySlot;
    });
  }

  void _handleAbilitySelectionsChanged(StartingAbilitySelectionResult result) {
    setState(() {
      _selectedAbilities = result.selectionsBySlot;
    });
  }

  void _handleSubclassSelectionChanged(SubclassSelectionResult result) {
    setState(() {
      _selectedSubclass = result;
    });
  }

  bool _validateSelections() {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a class')),
      );
      return false;
    }

    if (_selectedArray == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a characteristic array')),
      );
      return false;
    }

    if (_assignedCharacteristics.length != _selectedArray!.values.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please assign all characteristic values')),
      );
      return false;
    }

    return true;
  }

  Future<void> _handleSave() async {
    if (!_validateSelections()) return;

    final repo = ref.read(heroRepositoryProvider);
    
    try {
      // Save level
      await repo.updateMainStats(
        widget.heroId,
        level: _selectedLevel,
      );

      // Save characteristics (base values directly to DB)
      final updates = <Future>[];
      
      _assignedCharacteristics.forEach((characteristic, value) {
        // Determine which DB key to use based on characteristic name
        final charLower = characteristic.toLowerCase();
        if (charLower == 'might' || charLower == 'agility' || 
            charLower == 'reason' || charLower == 'intuition' || 
            charLower == 'presence') {
          // Save base characteristic value directly
          updates.add(
            repo.setCharacteristicBase(widget.heroId, characteristic: charLower, value: value),
          );
        }
      });
      
      await Future.wait(updates);

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved: Level $_selectedLevel ${_selectedClass!.name}\n'
            'Characteristics saved successfully',
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initializeData();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hero Strife'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _handleSave,
            tooltip: 'Save',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Level Selector
          LevelSelectorWidget(
            selectedLevel: _selectedLevel,
            onLevelChanged: _handleLevelChanged,
          ),

          // Class Selector
          ClassSelectorWidget(
            availableClasses: _classDataService.getAllClasses(),
            selectedClass: _selectedClass,
            selectedLevel: _selectedLevel,
            onClassChanged: _handleClassChanged,
          ),

          if (_selectedClass != null) ...[
            StartingCharacteristicsWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedArray: _selectedArray,
              assignedCharacteristics: _assignedCharacteristics,
              onArrayChanged: _handleArrayChanged,
              onAssignmentsChanged: _handleAssignmentsChanged,
              onFinalTotalsChanged: _handleFinalTotalsChanged,
            ),
            ChooseSubclassWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedSubclass: _selectedSubclass,
              onSelectionChanged: _handleSubclassSelectionChanged,
            ),
            StartingAbilitiesWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedAbilities: _selectedAbilities,
              onSelectionChanged: _handleAbilitySelectionsChanged,
            ),
            StartingSkillsWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedSkills: _selectedSkills,
              onSelectionChanged: _handleSkillSelectionsChanged,
            ),
            StartingPerksWidget(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedPerks: _selectedPerks,
              onSelectionChanged: _handlePerkSelectionsChanged,
            ),
            ClassFeaturesSection(
              classData: _selectedClass!,
              selectedLevel: _selectedLevel,
              selectedSubclass: _selectedSubclass,
              initialSelections: _featureSelections,
              onSelectionsChanged: (value) {
                setState(() {
                  _featureSelections = value;
                });
              },
            ),
          ],

          // Bottom padding
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
