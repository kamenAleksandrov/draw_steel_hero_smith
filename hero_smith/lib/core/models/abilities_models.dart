import 'component.dart';

class AbilityOption {
  const AbilityOption({
    required this.id,
    required this.name,
    required this.component,
    required this.level,
    this.isSignature = false,
    this.costAmount,
    this.resource,
    this.subclass,
  });

  final String id;
  final String name;
  final Component component;
  final int level;
  final bool isSignature;
  final int? costAmount;
  final String? resource;
  final String? subclass;
}

class AbilityAllowance {
  const AbilityAllowance({
    required this.id,
    required this.level,
    required this.pickCount,
    required this.label,
    required this.isSignature,
    required this.requiresSubclass,
    required this.includePreviousLevels,
    this.costAmount,
    this.resource,
  });

  final String id;
  final int level;
  final int pickCount;
  final String label;
  final bool isSignature;
  final bool requiresSubclass;
  final bool includePreviousLevels;
  final int? costAmount;
  final String? resource;
}

class StartingAbilityPlan {
  const StartingAbilityPlan({
    required this.allowances,
  });

  final List<AbilityAllowance> allowances;
}

class StartingAbilitySelectionResult {
  const StartingAbilitySelectionResult({
    required this.selectionsBySlot,
    required this.selectedAbilityIds,
  });

  final Map<String, String?> selectionsBySlot;
  final Set<String> selectedAbilityIds;
}
