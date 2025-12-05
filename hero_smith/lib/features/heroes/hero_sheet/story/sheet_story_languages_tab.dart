part of 'sheet_story.dart';

// Languages Tab Widget
class _LanguagesTab extends ConsumerStatefulWidget {
  final String heroId;

  const _LanguagesTab({required this.heroId});

  @override
  ConsumerState<_LanguagesTab> createState() => _LanguagesTabState();
}

class _LanguagesTabState extends ConsumerState<_LanguagesTab> {
  List<_LanguageOption> _availableLanguages = [];
  List<String> _selectedLanguageIds = [];
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

      // Load languages from JSON - it's a direct array, not wrapped in an object
      final languagesData = await rootBundle.loadString('data/story/languages.json');
      final languagesList = json.decode(languagesData) as List;

      _availableLanguages = languagesList.map((lang) {
        final langMap = lang as Map<String, dynamic>;
        return _LanguageOption(
          id: langMap['id'] as String,
          name: langMap['name'] as String,
          languageType: langMap['language_type'] as String? ?? '',
          region: langMap['region'] as String? ?? '',
          ancestry: langMap['ancestry'] as String? ?? '',
        );
      }).toList();

      // Load selected languages for this hero
      final db = ref.read(appDatabaseProvider);
      _selectedLanguageIds = await db.getHeroComponentIds(widget.heroId, 'language');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load languages: $e';
      });
    }
  }

  Future<void> _addLanguage(String languageId) async {
    if (_selectedLanguageIds.contains(languageId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Language already added')),
        );
      }
      return;
    }
    try {
      final db = ref.read(appDatabaseProvider);
      final updatedIds = [..._selectedLanguageIds, languageId];
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'language',
        componentIds: updatedIds,
      );

      setState(() {
        _selectedLanguageIds = updatedIds;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add language: $e')),
        );
      }
    }
  }

  Future<void> _removeLanguage(String languageId) async {
    try {
      final db = ref.read(appDatabaseProvider);
      final updatedIds = _selectedLanguageIds.where((id) => id != languageId).toList();
      await db.setHeroComponentIds(
        heroId: widget.heroId,
        category: 'language',
        componentIds: updatedIds,
      );

      setState(() {
        _selectedLanguageIds = updatedIds;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove language: $e')),
        );
      }
    }
  }

  void _showAddLanguageDialog() {
    final unselectedLanguages = _availableLanguages
        .where((lang) => !_selectedLanguageIds.contains(lang.id))
        .toList();

    showDialog(
      context: context,
      builder: (context) => _AddLanguageDialog(
        availableLanguages: unselectedLanguages,
        onLanguageSelected: (languageId) {
          _addLanguage(languageId);
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

    final selectedLanguages = _availableLanguages
        .where((lang) => _selectedLanguageIds.contains(lang.id))
        .toList();

    // Group languages by type
    final groupedLanguages = <String, List<_LanguageOption>>{};
    for (final lang in selectedLanguages) {
      final groupKey = lang.languageType.isNotEmpty ? lang.languageType : 'Other';
      groupedLanguages.putIfAbsent(groupKey, () => []).add(lang);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Languages',
                style: AppTextStyles.title,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddLanguageDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Language'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (selectedLanguages.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No languages selected. Tap "Add Language" to get started.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...groupedLanguages.entries.map((entry) {
              final groupName = entry.key;
              final languages = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  ...languages.map((lang) {
                    String subtitle = '';
                    if (lang.region.isNotEmpty) {
                      subtitle = 'Region: ${lang.region}';
                    }
                    if (lang.ancestry.isNotEmpty) {
                      subtitle = subtitle.isEmpty
                          ? 'Ancestry: ${lang.ancestry}'
                          : '$subtitle • Ancestry: ${lang.ancestry}';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(lang.name),
                        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeLanguage(lang.id),
                          tooltip: 'Remove language',
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _AddLanguageDialog extends StatefulWidget {
  final List<_LanguageOption> availableLanguages;
  final Function(String) onLanguageSelected;

  const _AddLanguageDialog({
    required this.availableLanguages,
    required this.onLanguageSelected,
  });

  @override
  State<_AddLanguageDialog> createState() => _AddLanguageDialogState();
}

class _AddLanguageDialogState extends State<_AddLanguageDialog> {
  String _searchQuery = '';
  List<_LanguageOption> _filteredLanguages = [];

  @override
  void initState() {
    super.initState();
    _filteredLanguages = widget.availableLanguages;
  }

  void _filterLanguages(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredLanguages = widget.availableLanguages;
      } else {
        _filteredLanguages = widget.availableLanguages
            .where((lang) =>
                lang.name.toLowerCase().contains(query.toLowerCase()) ||
                lang.region.toLowerCase().contains(query.toLowerCase()) ||
                lang.ancestry.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Language'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search languages',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterLanguages,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: _filteredLanguages.isEmpty
                  ? Center(
                      child: Text(
                        'No languages found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = _filteredLanguages[index];
                        String subtitle = '';
                        if (lang.region.isNotEmpty) {
                          subtitle = 'Region: ${lang.region}';
                        }
                        if (lang.ancestry.isNotEmpty) {
                          subtitle = subtitle.isEmpty
                              ? 'Ancestry: ${lang.ancestry}'
                              : '$subtitle • Ancestry: ${lang.ancestry}';
                        }

                        return ListTile(
                          title: Text(lang.name),
                          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
                          onTap: () => widget.onLanguageSelected(lang.id),
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

class _LanguageOption {
  final String id;
  final String name;
  final String languageType;
  final String region;
  final String ancestry;

  _LanguageOption({
    required this.id,
    required this.name,
    required this.languageType,
    required this.region,
    required this.ancestry,
  });
}
