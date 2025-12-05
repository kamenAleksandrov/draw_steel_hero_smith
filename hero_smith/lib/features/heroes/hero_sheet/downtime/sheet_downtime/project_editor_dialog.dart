import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/models/downtime_tracking.dart';

/// Dialog for creating or editing a downtime project
class ProjectEditorDialog extends StatefulWidget {
  const ProjectEditorDialog({
    super.key,
    required this.heroId,
    this.existingProject,
  });

  final String heroId;
  final HeroDowntimeProject? existingProject;

  @override
  State<ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<ProjectEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _goalController;
  late final TextEditingController _currentPointsController;
  late final TextEditingController _prerequisitesController;
  late final TextEditingController _sourceController;
  late final TextEditingController _sourceLanguageController;
  late final TextEditingController _guidesController;
  late final TextEditingController _characteristicsController;
  late final TextEditingController _notesController;
  late List<ProjectEvent> _events;
  
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final project = widget.existingProject;
    
    _nameController = TextEditingController(text: project?.name ?? '');
    _descriptionController = TextEditingController(text: project?.description ?? '');
    _goalController = TextEditingController(text: project?.projectGoal.toString() ?? '');
    _currentPointsController = TextEditingController(
      text: project?.currentPoints.toString() ?? '0',
    );
    _prerequisitesController = TextEditingController(
      text: project?.prerequisites.join(', ') ?? '',
    );
    _sourceController = TextEditingController(text: project?.projectSource ?? '');
    _sourceLanguageController = TextEditingController(text: project?.sourceLanguage ?? '');
    _guidesController = TextEditingController(text: project?.guides.join(', ') ?? '');
    _characteristicsController = TextEditingController(
      text: project?.rollCharacteristics.join(', ') ?? '',
    );
    _notesController = TextEditingController(text: project?.notes ?? '');
    _events = List<ProjectEvent>.from(project?.events ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    _currentPointsController.dispose();
    _prerequisitesController.dispose();
    _sourceController.dispose();
    _sourceLanguageController.dispose();
    _guidesController.dispose();
    _characteristicsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingProject == null ? 'Create Project' : 'Edit Project'),
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
                  labelText: 'Project Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
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
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _goalController,
                decoration: const InputDecoration(
                  labelText: 'Project Goal (points) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a goal';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              if (widget.existingProject != null) ...[
                TextFormField(
                  controller: _currentPointsController,
                  decoration: const InputDecoration(
                    labelText: 'Current Points',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 16),
              ],
              
              TextFormField(
                controller: _prerequisitesController,
                decoration: const InputDecoration(
                  labelText: 'Prerequisites (comma-separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _sourceController,
                decoration: const InputDecoration(
                  labelText: 'Project Source',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _sourceLanguageController,
                decoration: const InputDecoration(
                  labelText: 'Source Language',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _guidesController,
                decoration: const InputDecoration(
                  labelText: 'Guides (comma-separated)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _characteristicsController,
                decoration: const InputDecoration(
                  labelText: 'Roll Characteristics (comma-separated)',
                  hintText: 'e.g., might, reason, presence',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              
              // Events Section
              if (widget.existingProject != null && _events.isNotEmpty) ...[
                Text(
                  'Event Milestones',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _events.asMap().entries.map((entry) {
                      final index = entry.key;
                      final event = entry.value;
                      return _EventEditorTile(
                        event: event,
                        onDescriptionChanged: (description) {
                          setState(() {
                            _events[index] = event.copyWith(eventDescription: description);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Notes Section
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Personal notes, ideas, progress tracking...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveProject,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveProject() {
    if (!_formKey.currentState!.validate()) return;

    final project = widget.existingProject?.copyWith(
      name: _nameController.text,
      description: _descriptionController.text,
      projectGoal: int.parse(_goalController.text),
      currentPoints: int.parse(_currentPointsController.text),
      prerequisites: _parseCommaSeparated(_prerequisitesController.text),
      projectSource: _sourceController.text.isEmpty ? null : _sourceController.text,
      sourceLanguage: _sourceLanguageController.text.isEmpty 
          ? null 
          : _sourceLanguageController.text,
      guides: _parseCommaSeparated(_guidesController.text),
      rollCharacteristics: _parseCommaSeparated(_characteristicsController.text),
      events: _events,
      notes: _notesController.text,
      updatedAt: DateTime.now(),
    ) ?? HeroDowntimeProject(
      id: '',
      heroId: widget.heroId,
      name: _nameController.text,
      description: _descriptionController.text,
      projectGoal: int.parse(_goalController.text),
      currentPoints: 0,
      prerequisites: _parseCommaSeparated(_prerequisitesController.text),
      projectSource: _sourceController.text.isEmpty ? null : _sourceController.text,
      sourceLanguage: _sourceLanguageController.text.isEmpty 
          ? null 
          : _sourceLanguageController.text,
      guides: _parseCommaSeparated(_guidesController.text),
      rollCharacteristics: _parseCommaSeparated(_characteristicsController.text),
      events: HeroDowntimeProject.calculateEventThresholds(
        int.parse(_goalController.text),
      ),
      notes: _notesController.text,
      isCustom: true,
      isCompleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.of(context).pop(project);
  }

  List<String> _parseCommaSeparated(String text) {
    return text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

/// Widget for editing a single event's description
class _EventEditorTile extends StatelessWidget {
  const _EventEditorTile({
    required this.event,
    required this.onDescriptionChanged,
  });

  final ProjectEvent event;
  final ValueChanged<String> onDescriptionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                event.triggered ? Icons.check_circle : Icons.circle_outlined,
                size: 18,
                color: event.triggered ? Colors.amber : theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                'Event at ${event.pointThreshold} points',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: event.triggered ? Colors.amber.shade800 : null,
                ),
              ),
              if (event.triggered) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Triggered',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: event.eventDescription ?? '',
            decoration: InputDecoration(
              hintText: 'Add event notes or outcome...',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            onChanged: onDescriptionChanged,
          ),
        ],
      ),
    );
  }
}
