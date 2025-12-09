import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/providers.dart';
import '../../../core/models/class_data.dart';
import '../../../core/models/subclass_models.dart';
import '../../../core/services/class_data_service.dart';
import '../../../core/services/class_feature_data_service.dart';
import '../widgets/strength_creator/class_features_section.dart';
import '../../../widgets/creature stat block/hero_green_form_widget.dart';

class StrenghtCreatorPage extends ConsumerStatefulWidget {
  const StrenghtCreatorPage({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<StrenghtCreatorPage> createState() =>
      _StrenghtCreatorPageState();
}

class _StrenghtCreatorPageState extends ConsumerState<StrenghtCreatorPage>
    with AutomaticKeepAliveClientMixin {
  final ClassDataService _classDataService = ClassDataService();

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  bool _hasLoadedOnce = false;
  ClassData? _classData;
  SubclassSelectionResult? _subclassSelection;
  int _selectedLevel = 1;
  Map<String, Set<String>> _featureSelections = const {};
  List<String?> _equipmentIds = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showFullScreenLoader = false}) async {
    final useFullScreenLoader = !_hasLoadedOnce || showFullScreenLoader;
    setState(() {
      _isLoading = useFullScreenLoader;
      _isRefreshing = !useFullScreenLoader;
      _error = null;
    });

    try {
      await _classDataService.initialize();
      final repo = ref.read(heroRepositoryProvider);
      final hero = await repo.load(widget.heroId);

      if (hero == null) {
        setState(() {
          _error = 'Hero data could not be found.';
          _isLoading = false;
        });
        return;
      }

      final classId = hero.className?.trim();
      final allClasses = _classDataService.getAllClasses();
      final classData =
          allClasses.firstWhereOrNull((c) => c.classId == classId);

      final domainNames = hero.domain == null
          ? <String>[]
          : hero.domain!
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

      final savedSubclassKey = await repo.getSubclassKey(widget.heroId);
      final subclassName = hero.subclass?.trim();
      final subclassKey = savedSubclassKey ??
          (subclassName != null && subclassName.isNotEmpty
              ? ClassFeatureDataService.slugify(subclassName)
              : null);

      SubclassSelectionResult? subclassSelection;
      if ((subclassName?.isNotEmpty ?? false) ||
          (hero.deityId?.trim().isNotEmpty ?? false) ||
          domainNames.isNotEmpty) {
        subclassSelection = SubclassSelectionResult(
          subclassKey: subclassKey,
          subclassName: subclassName,
          deityId: hero.deityId?.trim().isNotEmpty == true
              ? hero.deityId!.trim()
              : null,
          deityName: hero.deityId?.trim().isNotEmpty == true
              ? hero.deityId!.trim()
              : null,
          domainNames: domainNames,
        );
      }

      final savedFeatureSelections =
          await repo.getFeatureSelections(widget.heroId);
      
      // Load equipment IDs for kit detection
      final equipmentIds = await repo.getEquipmentIds(widget.heroId);

      if (!mounted) return;
      setState(() {
        _classData = classData;
        _subclassSelection = subclassSelection;
        _selectedLevel = hero.level;
        _featureSelections = savedFeatureSelections.isNotEmpty
            ? savedFeatureSelections
            : const {};
        _equipmentIds = equipmentIds;
        _hasLoadedOnce = true;
        _isLoading = false;
        _isRefreshing = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (!_hasLoadedOnce || showFullScreenLoader) {
        setState(() {
          _error = 'Failed to load strength data: $e';
          _isLoading = false;
          _isRefreshing = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh features: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> reload() => _load();

  Future<void> _handleSelectionsChanged(
    Map<String, Set<String>> selections,
  ) async {
    setState(() {
      _featureSelections = selections;
    });
    try {
      final repo = ref.read(heroRepositoryProvider);
      await repo.saveFeatureSelections(widget.heroId, selections);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save feature selections: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && !_hasLoadedOnce) {
      return _NoticeCard(
        icon: Icons.error_outline,
        color: Colors.red,
        title: 'Something went wrong',
        message: _error!,
        action: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }

    final notices = <Widget>[];
    if (_classData == null) {
      notices.add(
        _NoticeCard(
          icon: Icons.info_outline,
          color: Colors.orange,
          title: 'Class required',
          message:
              'Select a class on the Strife tab to load class features. A class is required before features can be shown.',
        ),
      );
    }
    if (_classData != null && _subclassSelection == null) {
      notices.add(
        _NoticeCard(
          icon: Icons.error_outline,
          color: Colors.amber,
          title: 'Subclass missing',
          message:
              'Subclass features cannot be loaded until a subclass is chosen on the Strife tab.',
        ),
      );
    }

    final content = <Widget>[
      if (notices.isNotEmpty) ...[
        ...notices,
        const SizedBox(height: 12),
      ],
      if (_classData != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: AutoHeroGreenFormWidget(
            heroId: widget.heroId,
            sectionTitle: 'Green Elementalist Forms',
            sectionSpacing: 12,
          ),
        ),
      if (_classData != null)
        ClassFeaturesSection(
          classData: _classData!,
          selectedLevel: _selectedLevel,
          selectedSubclass: _subclassSelection,
          initialSelections: _featureSelections,
          equipmentIds: _equipmentIds,
          onSelectionsChanged: _handleSelectionsChanged,
        )
      else
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Choose a class first to load features.',
            textAlign: TextAlign.center,
          ),
      ),
      const SizedBox(height: 24),
    ];

    final listView = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      addAutomaticKeepAlives: true,
      children: content,
    );

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _load(),
          child: listView,
        ),
        if (_isRefreshing)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: color, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef StrenghtCreatorPageState = _StrenghtCreatorPageState;
