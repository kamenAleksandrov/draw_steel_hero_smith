part of 'sheet_story.dart';

// Skills Tab Widget
class _SkillsTab extends ConsumerStatefulWidget {
  final String heroId;

  const _SkillsTab({required this.heroId});

  @override
  ConsumerState<_SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends ConsumerState<_SkillsTab> {
  final SkillDataService _skillService = SkillDataService();
  List<_SkillOption> _availableSkills = [];
  List<String> _selectedSkillIds = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load skills from service
      final skills = await _skillService.loadSkills();

      _availableSkills = skills.map((skill) {
        return _SkillOption(
          id: skill.id,
          name: skill.name,
          group: skill.group,
          description: skill.description,
        );
      }).toList();

      final grantsService = ref.read(complicationGrantsServiceProvider);
      await grantsService.syncSkillGrants(widget.heroId);

      // Load selected skills for this hero
      final db = ref.read(appDatabaseProvider);
      _selectedSkillIds = await db.getHeroComponentIds(widget.heroId, 'skill');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load skills: $e';
      });
    }
  }

  Future<void> _addSkill(String skillId) async {
    if (_selectedSkillIds.contains(skillId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Skill already added')),
        );
      }
      return;
    }
    try {
      final db = ref.read(appDatabaseProvider);
      final updatedIds = [..._selectedSkillIds, skillId];
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'skill',
        componentIds: updatedIds,
      );

      setState(() {
        _selectedSkillIds = updatedIds;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add skill: $e')),
        );
      }
    }
  }

  Future<void> _removeSkill(String skillId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final updatedIds = _selectedSkillIds.where((id) => id != skillId).toList();
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'skill',
        componentIds: updatedIds,
      );

      setState(() {
        _selectedSkillIds = updatedIds;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove skill: $e')),
        );
      }
    }
  }

  void _showAddSkillDialog() {
    final unselectedSkills = _availableSkills
        .where((skill) => !_selectedSkillIds.contains(skill.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => _AddSkillDialog(
        availableSkills: unselectedSkills,
        onSkillSelected: (skillId) {
          _addSkill(skillId);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final selectedSkills = _availableSkills
        .where((skill) => _selectedSkillIds.contains(skill.id))
        .toList();

    // Group skills by category
    final groupedSkills = <String, List<_SkillOption>>{};
    for (final skill in selectedSkills) {
      groupedSkills.putIfAbsent(skill.group, () => []).add(skill);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Skills',
                style: AppTextStyles.title,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddSkillDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Skill'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (selectedSkills.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No skills selected. Tap "Add Skill" to get started.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...groupedSkills.entries.map((entry) {
              final groupName = entry.key;
              final skills = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (groupName.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        groupName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  ...skills.map((skill) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(skill.name),
                          subtitle: skill.description.isNotEmpty
                              ? Text(skill.description)
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeSkill(skill.id),
                            tooltip: 'Remove skill',
                          ),
                        ),
                      )),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _AddSkillDialog extends StatefulWidget {
  final List<_SkillOption> availableSkills;
  final Function(String) onSkillSelected;

  const _AddSkillDialog({
    required this.availableSkills,
    required this.onSkillSelected,
  });

  @override
  State<_AddSkillDialog> createState() => _AddSkillDialogState();
}

class _AddSkillDialogState extends State<_AddSkillDialog> {
  String _searchQuery = '';
  List<_SkillOption> _filteredSkills = [];

  @override
  void initState() {
    super.initState();
    _filteredSkills = widget.availableSkills;
  }

  void _filterSkills(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredSkills = widget.availableSkills;
      } else {
        _filteredSkills = widget.availableSkills
            .where((skill) =>
                skill.name.toLowerCase().contains(query.toLowerCase()) ||
                skill.description.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Skill'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search skills',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterSkills,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _filteredSkills.isEmpty
                  ? Center(
                      child: Text(
                        'No skills found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredSkills.length,
                      itemBuilder: (context, index) {
                        final skill = _filteredSkills[index];
                        return ListTile(
                          title: Text(skill.name),
                          subtitle: skill.description.isNotEmpty
                              ? Text(skill.description)
                              : null,
                          onTap: () => widget.onSkillSelected(skill.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _SkillOption {
  final String id;
  final String name;
  final String group;
  final String description;

  _SkillOption({
    required this.id,
    required this.name,
    required this.group,
    required this.description,
  });
}
