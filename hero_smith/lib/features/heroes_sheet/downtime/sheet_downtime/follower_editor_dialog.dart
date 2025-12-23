import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/downtime_tracking.dart';
import '../../../../core/theme/text/heroes_sheet/downtime/follower_editor_dialog_text.dart';

class FollowerEditorDialog extends StatefulWidget {
  const FollowerEditorDialog({
    super.key,
    required this.heroId,
    this.existingFollower,
  });

  final String heroId;
  final Follower? existingFollower;

  @override
  State<FollowerEditorDialog> createState() => _FollowerEditorDialogState();
}

class _FollowerEditorDialogState extends State<FollowerEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late final TextEditingController _mightController;
  late final TextEditingController _agilityController;
  late final TextEditingController _reasonController;
  late final TextEditingController _intuitionController;
  late final TextEditingController _presenceController;
  late final TextEditingController _skillsController;
  late final TextEditingController _languagesController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final follower = widget.existingFollower;
    
    _nameController = TextEditingController(text: follower?.name ?? '');
    _typeController = TextEditingController(text: follower?.followerType ?? '');
    _mightController = TextEditingController(text: follower?.might.toString() ?? '0');
    _agilityController = TextEditingController(text: follower?.agility.toString() ?? '0');
    _reasonController = TextEditingController(text: follower?.reason.toString() ?? '0');
    _intuitionController = TextEditingController(text: follower?.intuition.toString() ?? '0');
    _presenceController = TextEditingController(text: follower?.presence.toString() ?? '0');
    _skillsController = TextEditingController(text: follower?.skills.join(', ') ?? '');
    _languagesController = TextEditingController(text: follower?.languages.join(', ') ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _mightController.dispose();
    _agilityController.dispose();
    _reasonController.dispose();
    _intuitionController.dispose();
    _presenceController.dispose();
    _skillsController.dispose();
    _languagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existingFollower == null
            ? FollowerEditorDialogText.titleAddFollower
            : FollowerEditorDialogText.titleEditFollower,
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: FollowerEditorDialogText.nameLabel,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? FollowerEditorDialogText.nameRequiredError
                      : null,
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _typeController,
                  decoration: const InputDecoration(
                    labelText: FollowerEditorDialogText.followerTypeLabel,
                    hintText: FollowerEditorDialogText.followerTypeHint,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? FollowerEditorDialogText.followerTypeRequiredError
                      : null,
                ),
                const SizedBox(height: 16),
                
                const Text(
                  FollowerEditorDialogText.characteristicsLabel,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildStatField(
                        FollowerEditorDialogText.statLabelM,
                        _mightController,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildStatField(
                        FollowerEditorDialogText.statLabelA,
                        _agilityController,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildStatField(
                        FollowerEditorDialogText.statLabelR,
                        _reasonController,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildStatField(
                        FollowerEditorDialogText.statLabelI,
                        _intuitionController,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildStatField(
                        FollowerEditorDialogText.statLabelP,
                        _presenceController,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _skillsController,
                  decoration: const InputDecoration(
                    labelText: FollowerEditorDialogText.skillsLabel,
                    hintText: FollowerEditorDialogText.skillsHint,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _languagesController,
                  decoration: const InputDecoration(
                    labelText: FollowerEditorDialogText.languagesLabel,
                    hintText: FollowerEditorDialogText.languagesHint,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(FollowerEditorDialogText.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text(FollowerEditorDialogText.saveButtonLabel),
        ),
      ],
    );
  }

  Widget _buildStatField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final follower = widget.existingFollower?.copyWith(
      name: _nameController.text,
      followerType: _typeController.text,
      might: int.tryParse(_mightController.text) ?? 0,
      agility: int.tryParse(_agilityController.text) ?? 0,
      reason: int.tryParse(_reasonController.text) ?? 0,
      intuition: int.tryParse(_intuitionController.text) ?? 0,
      presence: int.tryParse(_presenceController.text) ?? 0,
      skills: _parseCommaSeparated(_skillsController.text),
      languages: _parseCommaSeparated(_languagesController.text),
    ) ?? Follower(
      id: '',
      heroId: widget.heroId,
      name: _nameController.text,
      followerType: _typeController.text,
      might: int.tryParse(_mightController.text) ?? 0,
      agility: int.tryParse(_agilityController.text) ?? 0,
      reason: int.tryParse(_reasonController.text) ?? 0,
      intuition: int.tryParse(_intuitionController.text) ?? 0,
      presence: int.tryParse(_presenceController.text) ?? 0,
      skills: _parseCommaSeparated(_skillsController.text),
      languages: _parseCommaSeparated(_languagesController.text),
    );

    Navigator.pop(context, follower);
  }

  List<String> _parseCommaSeparated(String text) {
    return text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
