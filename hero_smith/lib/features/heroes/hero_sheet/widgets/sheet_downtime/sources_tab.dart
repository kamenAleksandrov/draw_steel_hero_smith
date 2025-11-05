import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/db/providers.dart';
import '../../../../../core/models/downtime_tracking.dart';
import '../../../../../core/theme/hero_theme.dart';

/// Provider for hero project sources
final heroSourcesProvider =
    FutureProvider.family<List<ProjectSource>, String>((ref, heroId) async {
  final repo = ref.read(downtimeRepositoryProvider);
  return await repo.getHeroSources(heroId);
});

class SourcesTab extends ConsumerWidget {
  const SourcesTab({super.key, required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(heroSourcesProvider(heroId));

    return sourcesAsync.when(
      data: (sources) => _buildContent(context, ref, sources),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<ProjectSource> sources,
  ) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeader(context),
        ),
        SliverToBoxAdapter(
          child: _buildAddButton(context, ref),
        ),
        if (sources.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyState(context, ref),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSourceCard(
                context,
                ref,
                sources[index],
              ),
              childCount: sources.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: HeroTheme.heroCardRadius,
        gradient: HeroTheme.headerGradient(context),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.book,
            size: 40,
            color: HeroTheme.primarySection,
          ),
          const SizedBox(height: 12),
          Text(
            'Project Sources',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: HeroTheme.primarySection,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Books, items, and guides for your projects',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FilledButton.icon(
        onPressed: () => _addSource(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Source'),
        style: HeroTheme.primaryActionButtonStyle(context),
      ),
    );
  }

  Widget _buildSourceCard(BuildContext context, WidgetRef ref, ProjectSource source) {
    final theme = Theme.of(context);
    IconData icon;
    Color iconColor;

    switch (source.type) {
      case 'source':
        icon = Icons.menu_book;
        iconColor = Colors.blue;
        break;
      case 'item':
        icon = Icons.inventory_2;
        iconColor = Colors.amber;
        break;
      case 'guide':
        icon = Icons.person;
        iconColor = Colors.green;
        break;
      default:
        icon = Icons.help_outline;
        iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.2),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          source.name,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.type.toUpperCase()),
            if (source.language != null) ...[
              const SizedBox(height: 2),
              Text('Language: ${source.language}'),
            ],
            if (source.description != null && source.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                source.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _editSource(context, ref, source);
            } else if (value == 'delete') {
              _deleteSource(context, ref, source);
            }
          },
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return HeroTheme.buildEmptyState(
      context,
      icon: Icons.book_outlined,
      title: 'No Sources Yet',
      subtitle: 'Add books, items, or guides to help with projects',
      action: FilledButton.icon(
        onPressed: () => _addSource(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add First Source'),
        style: HeroTheme.primaryActionButtonStyle(context),
      ),
    );
  }

  void _addSource(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<ProjectSource>(
      context: context,
      builder: (context) => _SourceEditorDialog(heroId: heroId),
    );

    if (result != null) {
      final repo = ref.read(downtimeRepositoryProvider);
      await repo.createSource(
        heroId: heroId,
        name: result.name,
        type: result.type,
        language: result.language,
        description: result.description,
      );
      ref.invalidate(heroSourcesProvider(heroId));
    }
  }

  void _editSource(BuildContext context, WidgetRef ref, ProjectSource source) async {
    final result = await showDialog<ProjectSource>(
      context: context,
      builder: (context) => _SourceEditorDialog(
        heroId: heroId,
        existingSource: source,
      ),
    );

    if (result != null) {
      final repo = ref.read(downtimeRepositoryProvider);
      await repo.updateSource(result);
      ref.invalidate(heroSourcesProvider(heroId));
    }
  }

  void _deleteSource(BuildContext context, WidgetRef ref, ProjectSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Source'),
        content: Text('Remove ${source.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(downtimeRepositoryProvider);
      await repo.deleteSource(source.id);
      ref.invalidate(heroSourcesProvider(heroId));
    }
  }
}

class _SourceEditorDialog extends StatefulWidget {
  const _SourceEditorDialog({
    required this.heroId,
    this.existingSource,
  });

  final String heroId;
  final ProjectSource? existingSource;

  @override
  State<_SourceEditorDialog> createState() => _SourceEditorDialogState();
}

class _SourceEditorDialogState extends State<_SourceEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _languageController;
  late final TextEditingController _descriptionController;
  late String _selectedType;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final source = widget.existingSource;
    
    _nameController = TextEditingController(text: source?.name ?? '');
    _languageController = TextEditingController(text: source?.language ?? '');
    _descriptionController = TextEditingController(text: source?.description ?? '');
    _selectedType = source?.type ?? 'source';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _languageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingSource == null ? 'Add Source' : 'Edit Source'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'source', child: Text('Source (Book/Text)')),
                  DropdownMenuItem(value: 'item', child: Text('Item')),
                  DropdownMenuItem(value: 'guide', child: Text('Guide (Person)')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _languageController,
                decoration: const InputDecoration(
                  labelText: 'Language',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final source = widget.existingSource?.copyWith(
      name: _nameController.text,
      type: _selectedType,
      language: _languageController.text.isEmpty ? null : _languageController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
    ) ?? ProjectSource(
      id: '',
      heroId: widget.heroId,
      name: _nameController.text,
      type: _selectedType,
      language: _languageController.text.isEmpty ? null : _languageController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
    );

    Navigator.pop(context, source);
  }
}
