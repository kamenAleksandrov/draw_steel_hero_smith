import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/class_data.dart';
import '../../../../core/models/subclass_models.dart';
import '../../../../core/services/subclass_data_service.dart';
import '../../../../core/services/subclass_service.dart';
import '../../../../core/theme/app_text_styles.dart';

typedef SubclassSelectionChanged = void Function(
    SubclassSelectionResult result);

class ChooseSubclassWidget extends StatefulWidget {
  const ChooseSubclassWidget({
    super.key,
    required this.classData,
    required this.selectedLevel,
    this.selectedSubclass,
    this.onSelectionChanged,
  });

  final ClassData classData;
  final int selectedLevel;
  final SubclassSelectionResult? selectedSubclass;
  final SubclassSelectionChanged? onSelectionChanged;

  @override
  State<ChooseSubclassWidget> createState() => _ChooseSubclassWidgetState();
}

class _ChooseSubclassWidgetState extends State<ChooseSubclassWidget> {
  final SubclassService _planService = const SubclassService();
  final SubclassDataService _dataService = SubclassDataService();
  final ListEquality<String> _listEquality = const ListEquality<String>();

  SubclassPlan? _plan;
  SubclassFeatureData? _featureData;
  Map<String, SubclassOption> _optionsByKey = const {};
  List<DeityOption> _deities = const [];
  Set<String> _allDomains = const {};

  bool _isLoading = true;
  String? _error;

  String? _selectedSubclassKey;
  String? _selectedSubclassName;
  String? _selectedDeityId;
  List<String> _selectedDomains = const [];

  SubclassSelectionResult? _lastNotified;
  int _callbackVersion = 0;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadData(initialSelection: widget.selectedSubclass);
  }

  @override
  void didUpdateWidget(covariant ChooseSubclassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final classChanged =
        oldWidget.classData.classId != widget.classData.classId;
    final levelChanged = oldWidget.selectedLevel != widget.selectedLevel;
    if (classChanged || levelChanged) {
      _loadData(initialSelection: widget.selectedSubclass);
    } else if (oldWidget.selectedSubclass != widget.selectedSubclass) {
      _applyExternalSelection(widget.selectedSubclass);
    }
  }

  Future<void> _loadData({SubclassSelectionResult? initialSelection}) async {
    final requestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plan = _planService.buildPlan(
        classData: widget.classData,
        selectedLevel: widget.selectedLevel,
      );

      SubclassFeatureData? featureData;
      if (plan.hasSubclassChoice && plan.subclassFeatureName != null) {
        featureData = await _dataService.loadSubclassFeatureData(
          classSlug: plan.classSlug,
          featureName: plan.subclassFeatureName!,
        );
      }

      List<DeityOption> deities = const [];
      if (plan.requiresDeity || plan.requiresDomains) {
        deities = await _dataService.loadDeities();
      }

      Set<String> allDomains = const {};
      if (plan.requiresDomains) {
        if (plan.deityPickCount == 0) {
          allDomains = await _dataService.loadAllDomains();
        } else {
          final domainSet = <String>{};
          for (final deity in deities) {
            domainSet.addAll(deity.domains);
          }
          allDomains = domainSet;
        }
      }

      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _plan = plan;
        _featureData = featureData;
        _optionsByKey = {
          for (final option in featureData?.options ?? const <SubclassOption>[])
            option.key: option,
        };
        _deities = deities;
        _allDomains = allDomains;
        _selectedSubclassKey = null;
        _selectedSubclassName = null;
        _selectedDeityId = null;
        _selectedDomains = const [];
        _isLoading = false;
      });

      _applyExternalSelection(initialSelection);
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _error = 'Failed to load subclass data: $e';
        _isLoading = false;
      });
    }
  }

  void _applyExternalSelection(SubclassSelectionResult? selection) {
    if (_isLoading) return;
    if (_plan == null) return;

    String? subclassKey;
    String? subclassName;
    String? deityId;
    List<String> domains = _selectedDomains;

    if (selection != null) {
      subclassKey = selection.subclassKey;
      subclassName = selection.subclassName;
      deityId = selection.deityId;
      domains = selection.domainNames;
    }

    if (subclassKey != null && !_optionsByKey.containsKey(subclassKey)) {
      subclassKey = null;
      subclassName = null;
    }

    if (!_plan!.requiresDeity) {
      deityId = null;
    } else if (deityId != null &&
        !_deities.any((deity) => deity.id == deityId)) {
      deityId = null;
    }

    if (!_plan!.requiresDomains) {
      domains = const [];
    }

    if (!_listEquality.equals(_selectedDomains, domains) ||
        _selectedSubclassKey != subclassKey ||
        _selectedSubclassName != subclassName ||
        _selectedDeityId != deityId) {
      setState(() {
        _selectedSubclassKey = subclassKey;
        _selectedSubclassName = subclassName;
        _selectedDeityId = deityId;
        _selectedDomains = List<String>.from(domains);
      });
      _ensureSubclassFromDomains();
      _notifySelectionChanged();
    }
  }

  void _handleSubclassChanged(String? key) {
    if (key == _selectedSubclassKey) return;
    final option = key == null ? null : _optionsByKey[key];
    setState(() {
      _selectedSubclassKey = key;
      _selectedSubclassName = option?.name;
    });
    _notifySelectionChanged();
  }

  void _handleDeityChanged(String? id) {
    if (id == _selectedDeityId) return;
    setState(() {
      _selectedDeityId = id;
      _selectedDomains = const [];
    });
    _ensureSubclassFromDomains();
    _notifySelectionChanged();
  }

  void _toggleDomain(String domain, bool selected) {
    final requiredCount = _plan?.domainPickCount ?? 0;
    final current = List<String>.from(_selectedDomains);

    if (selected) {
      if (!current.contains(domain)) {
        if (requiredCount > 0 && current.length >= requiredCount) {
          return;
        }
        current.add(domain);
      }
    } else {
      current.remove(domain);
    }

    if (!_listEquality.equals(_selectedDomains, current)) {
      setState(() {
        _selectedDomains = current;
      });
      _ensureSubclassFromDomains();
      _notifySelectionChanged();
    }
  }

  void _ensureSubclassFromDomains() {
    final plan = _plan;
    if (plan == null || !plan.combineDomainsAsSubclass) {
      return;
    }

    final requiredCount = plan.domainPickCount;
    String? key;
    String? name;

    if (_selectedDomains.isNotEmpty &&
        (requiredCount == 0 || _selectedDomains.length >= requiredCount)) {
      final sorted = _selectedDomains.toList()..sort((a, b) => a.compareTo(b));
      key = sorted.map((e) => e.toLowerCase().replaceAll(' ', '_')).join('_');
      name = sorted.join(' + ');
    }

    if (_selectedSubclassKey != key || _selectedSubclassName != name) {
      setState(() {
        _selectedSubclassKey = key;
        _selectedSubclassName = name;
      });
    }
  }

  void _notifySelectionChanged() {
    if (widget.onSelectionChanged == null) return;
    final plan = _plan;
    if (plan == null) return;

    final deity = _selectedDeityId == null
        ? null
        : _deities.firstWhere(
            (entry) => entry.id == _selectedDeityId,
            orElse: () => DeityOption(
              id: _selectedDeityId!,
              name: _selectedDeityId!,
              category: 'god',
              domains: const [],
            ),
          );

    final result = SubclassSelectionResult(
      subclassKey: _selectedSubclassKey,
      subclassName: _selectedSubclassName,
      deityId: deity?.id,
      deityName: deity?.name,
      domainNames: List<String>.from(_selectedDomains),
    );

    if (result == _lastNotified) {
      return;
    }

    _lastNotified = result;
    final version = ++_callbackVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || version != _callbackVersion) return;
      widget.onSelectionChanged?.call(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildContainer(
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return _buildContainer(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: AppTextStyles.caption,
          ),
        ),
      );
    }

    final plan = _plan;
    if (plan == null) {
      return const SizedBox.shrink();
    }

    if (!plan.hasSubclassChoice &&
        !plan.requiresDeity &&
        !plan.requiresDomains) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[];

    children.add(
      Text(
        'Subclass & Calling',
        style: AppTextStyles.subtitle.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    children.add(const SizedBox(height: 4));
    children.add(
      Text(
        'Pick your order, oath, or domains to define your specialization.',
        style: AppTextStyles.caption,
      ),
    );

    children.add(const SizedBox(height: 12));

    if (plan.hasSubclassChoice && !plan.combineDomainsAsSubclass) {
      children.addAll(_buildSubclassPickerSection());
      children.add(const SizedBox(height: 16));
    } else if (plan.combineDomainsAsSubclass && plan.domainPickCount > 0) {
      children.add(
        Text(
          'Your subclass is determined by the domains you select below.',
          style: AppTextStyles.caption,
        ),
      );
      children.add(const SizedBox(height: 16));
    }

    if (plan.requiresDeity) {
      children.addAll(_buildDeityPickerSection());
      children.add(const SizedBox(height: 16));
    }

    if (plan.requiresDomains) {
      children.addAll(_buildDomainSection());
    }

    return _buildContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildContainer({required Widget child}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: child,
    );
  }

  List<Widget> _buildSubclassPickerSection() {
    final featureData = _featureData;
    final options = featureData?.options ?? const <SubclassOption>[];

    final dropdownItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('-- Choose subclass --'),
      ),
      ...options.map(
        (option) => DropdownMenuItem<String?>(
          value: option.key,
          child: Text(option.name),
        ),
      ),
    ];

    final selectedOption = _selectedSubclassKey == null
        ? null
        : _optionsByKey[_selectedSubclassKey!];

    return [
      DropdownButtonFormField<String?>(
        value: _selectedSubclassKey,
        decoration: const InputDecoration(
          labelText: 'Subclass',
          border: OutlineInputBorder(),
        ),
        items: dropdownItems,
        onChanged: (value) => _handleSubclassChanged(value),
      ),
      if (selectedOption != null) ...[
        const SizedBox(height: 12),
        _buildSubclassDetails(selectedOption),
      ] else if (featureData?.featureDescription != null &&
          featureData!.featureDescription!.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          featureData.featureDescription!,
          style: AppTextStyles.caption,
        ),
      ],
    ];
  }

  Widget _buildSubclassDetails(SubclassOption option) {
    final skillInfo = option.skill;
    final skillGroup = option.skillGroup;
    final ability = option.abilityName;

    final chips = <Widget>[];
    if (skillInfo != null && skillInfo.isNotEmpty) {
      chips.add(_buildInfoChip(Icons.psychology_outlined, skillInfo));
    }
    if (skillGroup != null && skillGroup.isNotEmpty) {
      chips.add(_buildInfoChip(Icons.folder_shared_outlined, skillGroup));
    }
    if (option.domain != null && option.domain!.isNotEmpty) {
      chips.add(_buildInfoChip(Icons.public_outlined, option.domain!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          option.name,
          style: AppTextStyles.subtitle,
        ),
        const SizedBox(height: 4),
        if (option.description != null && option.description!.isNotEmpty)
          Text(
            option.description!,
            style: AppTextStyles.body,
          ),
        if (ability != null && ability.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Grants ability: $ability',
            style: AppTextStyles.caption,
          ),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildDeityPickerSection() {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('-- Choose deity --'),
      ),
      ..._deities.map(
        (deity) => DropdownMenuItem<String?>(
          value: deity.id,
          child: Text('${deity.name} (${deity.category})'),
        ),
      ),
    ];

    return [
      DropdownButtonFormField<String?>(
        value: _selectedDeityId,
        decoration: const InputDecoration(
          labelText: 'Deity',
          border: OutlineInputBorder(),
        ),
        items: items,
        onChanged: _handleDeityChanged,
      ),
    ];
  }

  List<Widget> _buildDomainSection() {
    final plan = _plan;
    if (plan == null) return const [];

    Iterable<String> availableDomains = _allDomains;
    if (plan.deityPickCount > 0 && _selectedDeityId != null) {
      final deity = _deities.firstWhere(
        (element) => element.id == _selectedDeityId,
        orElse: () => DeityOption(
          id: _selectedDeityId!,
          name: _selectedDeityId!,
          category: 'god',
          domains: const [],
        ),
      );
      availableDomains = deity.domains;
    }

    final required = plan.domainPickCount;
    final remaining = required > 0 ? required - _selectedDomains.length : 0;

    final chips = availableDomains.toList()..sort((a, b) => a.compareTo(b));

    return [
      Text(
        required > 0
            ? 'Choose $required domain${required == 1 ? '' : 's'}'
            : 'Choose domains',
        style: AppTextStyles.subtitle.copyWith(fontSize: 14),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips.map((domain) {
          final isSelected = _selectedDomains.contains(domain);
          final canSelectMore = !isSelected &&
              required > 0 &&
              _selectedDomains.length >= required;
          return FilterChip(
            label: Text(domain),
            selected: isSelected,
            onSelected:
                canSelectMore ? null : (value) => _toggleDomain(domain, value),
          );
        }).toList(),
      ),
      if (remaining > 0) ...[
        const SizedBox(height: 8),
        Text(
          '$remaining pick${remaining == 1 ? '' : 's'} remaining.',
          style: AppTextStyles.caption,
        ),
      ],
    ];
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
