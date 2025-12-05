part of 'sheet_story.dart';

// Titles Tab Widget
class _TitlesTab extends ConsumerStatefulWidget {
  final String heroId;

  const _TitlesTab({required this.heroId});

  @override
  ConsumerState<_TitlesTab> createState() => _TitlesTabState();
}

class _TitlesTabState extends ConsumerState<_TitlesTab> {
  List<Map<String, dynamic>> _availableTitles = [];
  Map<String, Map<String, dynamic>> _selectedTitles = {}; // titleId -> {title, selectedBenefitIndex}
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

      // Load titles from JSON
      final titlesData = await rootBundle.loadString('data/story/titles.json');
      final titlesList = json.decode(titlesData) as List;
      _availableTitles = titlesList.cast<Map<String, dynamic>>();

      // Load selected titles for this hero from database
      final db = ref.read(appDatabaseProvider);
      final storedTitles = await db.getHeroComponentIds(widget.heroId, 'title');
      
      // Parse stored titles - format: "titleId:benefitIndex"
      _selectedTitles = {};
      for (final storedTitle in storedTitles) {
        final parts = storedTitle.split(':');
        if (parts.length == 2) {
          final titleId = parts[0];
          final benefitIndex = int.tryParse(parts[1]) ?? 0;
          final title = _availableTitles.firstWhere(
            (t) => t['id'] == titleId,
            orElse: () => <String, dynamic>{},
          );
          if (title.isNotEmpty) {
            _selectedTitles[titleId] = {
              'title': title,
              'selectedBenefitIndex': benefitIndex,
            };
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load titles: $e';
      });
    }
  }

  Future<void> _addTitle(String titleId, int benefitIndex) async {
    if (_selectedTitles.containsKey(titleId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title already added')),
        );
      }
      return;
    }
    try {
      final db = ref.read(appDatabaseProvider);
      final title = _availableTitles.firstWhere((t) => t['id'] == titleId);
      
      _selectedTitles[titleId] = {
        'title': title,
        'selectedBenefitIndex': benefitIndex,
      };
      
      // Store as "titleId:benefitIndex"
      final updatedIds = _selectedTitles.entries
          .map((e) => '${e.key}:${e.value['selectedBenefitIndex']}')
          .toList();
      
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'title',
        componentIds: updatedIds,
      );

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add title: $e')),
        );
      }
    }
  }

  Future<void> _removeTitle(String titleId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      _selectedTitles.remove(titleId);
      
      final updatedIds = _selectedTitles.entries
          .map((e) => '${e.key}:${e.value['selectedBenefitIndex']}')
          .toList();
      
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'title',
        componentIds: updatedIds,
      );

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove title: $e')),
        );
      }
    }
  }

  Future<void> _changeBenefit(String titleId, int newBenefitIndex) async {
    if (_selectedTitles.containsKey(titleId)) {
      _selectedTitles[titleId]!['selectedBenefitIndex'] = newBenefitIndex;
      
      final db = ref.read(appDatabaseProvider);
      final updatedIds = _selectedTitles.entries
          .map((e) => '${e.key}:${e.value['selectedBenefitIndex']}')
          .toList();
      
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'title',
        componentIds: updatedIds,
      );

      setState(() {});
    }
  }

  void _showAddTitleDialog() {
    final unselectedTitles = _availableTitles
        .where((title) => !_selectedTitles.containsKey(title['id']))
        .toList();

    showDialog(
      context: context,
      builder: (context) => _AddTitleDialog(
        availableTitles: unselectedTitles,
        onTitleSelected: (titleId, benefitIndex) {
          _addTitle(titleId, benefitIndex);
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
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Group titles by echelon
    final groupedTitles = <int, List<MapEntry<String, Map<String, dynamic>>>>{};
    for (final entry in _selectedTitles.entries) {
      final echelon = entry.value['title']['echelon'] as int? ?? 1;
      groupedTitles.putIfAbsent(echelon, () => []).add(entry);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Titles',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddTitleDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add Title'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedTitles.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No titles selected'),
              ),
            )
          else
            ...groupedTitles.entries.map((group) {
              final echelon = group.key;
              final titles = group.value;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Echelon $echelon',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  ...titles.map((entry) => _buildTitleCard(context, entry.key, entry.value)),
                  const SizedBox(height: 16),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTitleCard(BuildContext context, String titleId, Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final title = data['title'] as Map<String, dynamic>;
    final selectedBenefitIndex = data['selectedBenefitIndex'] as int;
    final benefits = title['benefits'] as List? ?? [];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title['name'] as String? ?? 'Unknown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (title['prerequisite'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Prerequisite: ${title['prerequisite']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _removeTitle(titleId),
                  tooltip: 'Remove Title',
                ),
              ],
            ),
            if (title['description_text'] != null) ...[
              const SizedBox(height: 12),
              Text(
                title['description_text'] as String,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Selected Benefit:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (benefits.isNotEmpty && selectedBenefitIndex < benefits.length)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBenefitContent(context, benefits[selectedBenefitIndex]),
                    if (benefits.length > 1) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _showChangeBenefitDialog(titleId, benefits),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('Change Benefit'),
                      ),
                    ],
                  ],
                ),
              ),
            if (title['special'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Special: ${title['special']}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitContent(BuildContext context, dynamic benefit) {
    final theme = Theme.of(context);
    if (benefit is! Map<String, dynamic>) return const SizedBox.shrink();
    
    final description = benefit['description'] as String?;
    final ability = benefit['ability'] as String?;
    final grantsRaw = benefit['grants'];
    // Normalize grants to a List (can be Map or List)
    final grants = grantsRaw is List ? grantsRaw : (grantsRaw is Map ? [grantsRaw] : null);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description != null && description.isNotEmpty)
          Text(description, style: theme.textTheme.bodyMedium),
        if (ability != null && ability.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.flash_on, size: 16, color: theme.colorScheme.secondary),
              const SizedBox(width: 4),
              Text(
                'Ability: $ability',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
        if (grants != null && grants.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...grants.map((grant) {
            if (grant is Map<String, dynamic>) {
              final type = grant['type'] as String?;
              final value = grant['value'];
              if (type != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.card_giftcard, size: 16, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 4),
                      Text(
                        'Grants: ${_formatGrant(type, value)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                );
              }
            }
            return const SizedBox.shrink();
          }),
        ],
      ],
    );
  }

  String _formatGrant(String type, dynamic value) {
    switch (type) {
      case 'renown':
        return '+$value Renown';
      case 'wealth':
        return '+$value Wealth';
      case 'followers_cap':
        return '+$value Followers Cap';
      case 'skill_choice':
        return 'Choose $value Skill';
      case 'languages':
        return 'Language: $value';
      default:
        return '$type: $value';
    }
  }

  void _showChangeBenefitDialog(String titleId, List benefits) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Benefit'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: benefits.length,
            itemBuilder: (context, index) {
              final benefit = benefits[index];
              final isSelected = _selectedTitles[titleId]!['selectedBenefitIndex'] == index;
              
              return Card(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: InkWell(
                  onTap: () {
                    _changeBenefit(titleId, index);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Benefit ${index + 1}',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildBenefitContent(context, benefit),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// Add Title Dialog
class _AddTitleDialog extends StatefulWidget {
  final List<Map<String, dynamic>> availableTitles;
  final Function(String, int) onTitleSelected;

  const _AddTitleDialog({
    required this.availableTitles,
    required this.onTitleSelected,
  });

  @override
  State<_AddTitleDialog> createState() => _AddTitleDialogState();
}

class _AddTitleDialogState extends State<_AddTitleDialog> {
  String _searchQuery = '';
  int? _selectedEchelon;
  List<Map<String, dynamic>> _filteredTitles = [];

  @override
  void initState() {
    super.initState();
    _filteredTitles = widget.availableTitles;
  }

  void _filterTitles() {
    setState(() {
      _filteredTitles = widget.availableTitles.where((title) {
        final matchesSearch = _searchQuery.isEmpty ||
            (title['name'] as String?)?.toLowerCase().contains(_searchQuery.toLowerCase()) == true ||
            (title['description_text'] as String?)?.toLowerCase().contains(_searchQuery.toLowerCase()) == true;
        
        final matchesEchelon = _selectedEchelon == null ||
            title['echelon'] == _selectedEchelon;
        
        return matchesSearch && matchesEchelon;
      }).toList();
    });
  }

  void _showBenefitSelectionDialog(Map<String, dynamic> title) {
    final benefits = title['benefits'] as List? ?? [];
    
    if (benefits.isEmpty) {
      widget.onTitleSelected(title['id'] as String, 0);
      return;
    }
    
    if (benefits.length == 1) {
      widget.onTitleSelected(title['id'] as String, 0);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Benefit for ${title['name']}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: benefits.length,
            itemBuilder: (context, index) {
              final benefit = benefits[index];
              
              return Card(
                child: InkWell(
                  onTap: () {
                    widget.onTitleSelected(title['id'] as String, index);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Benefit ${index + 1}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (benefit is Map<String, dynamic>) ...[
                          if (benefit['description'] != null)
                            Text(
                              benefit['description'] as String,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Title'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search titles',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _filterTitles();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedEchelon == null,
                  onSelected: (selected) {
                    _selectedEchelon = null;
                    _filterTitles();
                  },
                ),
                ...List.generate(4, (index) {
                  final echelon = index + 1;
                  return FilterChip(
                    label: Text('Echelon $echelon'),
                    selected: _selectedEchelon == echelon,
                    onSelected: (selected) {
                      _selectedEchelon = selected ? echelon : null;
                      _filterTitles();
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filteredTitles.isEmpty
                  ? const Center(child: Text('No titles found'))
                  : ListView.builder(
                      itemCount: _filteredTitles.length,
                      itemBuilder: (context, index) {
                        final title = _filteredTitles[index];
                        
                        return Card(
                          child: ListTile(
                            title: Text(
                              title['name'] as String? ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (title['description_text'] != null)
                                  Text(
                                    title['description_text'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  'Echelon ${title['echelon']} • ${(title['benefits'] as List?)?.length ?? 0} benefits',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _showBenefitSelectionDialog(title),
                          ),
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
