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
