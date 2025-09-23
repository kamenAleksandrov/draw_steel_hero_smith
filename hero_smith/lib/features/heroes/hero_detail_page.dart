import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/providers.dart';
import '../../core/models/hero_model.dart';

class HeroDetailPage extends ConsumerStatefulWidget {
  const HeroDetailPage({super.key, required this.heroId});
  final String heroId;

  @override
  ConsumerState<HeroDetailPage> createState() => _HeroDetailPageState();
}

class _HeroDetailPageState extends ConsumerState<HeroDetailPage> {
  HeroModel? _model;
  final _nameCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(heroRepositoryProvider);
    final m = await repo.load(widget.heroId);
    setState(() {
      _model = m ?? HeroModel(id: widget.heroId, name: 'Hero');
      _nameCtrl.text = _model!.name;
      _levelCtrl.text = _model!.level.toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_model == null) return;
    final repo = ref.read(heroRepositoryProvider);
    _model!
      ..name = _nameCtrl.text.trim()
      ..level = int.tryParse(_levelCtrl.text.trim()) ?? _model!.level;
    await repo.save(_model!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _levelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hero Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _levelCtrl,
                    decoration: const InputDecoration(labelText: 'Level'),
                    keyboardType: TextInputType.number,
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ),
    );
  }
}
