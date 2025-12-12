import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/providers.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'gear_dialogs.dart';
import 'inventory_widgets.dart';

/// Inventory tab for the gear sheet.
class InventoryTab extends ConsumerStatefulWidget {
  const InventoryTab({super.key, required this.heroId});

  final String heroId;

  @override
  ConsumerState<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends ConsumerState<InventoryTab> {
  List<Map<String, dynamic>> _containers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    try {
      final heroRepo = ref.read(heroRepositoryProvider);
      final containers = await heroRepo.getInventoryContainers(widget.heroId);
      if (mounted) {
        setState(() {
          _containers = containers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load inventory: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createContainer() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const CreateContainerDialog(),
    );

    if (name == null || name.isEmpty) return;

    try {
      final heroRepo = ref.read(heroRepositoryProvider);
      final newContainer = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'items': <Map<String, dynamic>>[],
      };
      final updated = [..._containers, newContainer];
      await heroRepo.saveInventoryContainers(widget.heroId, updated);
      setState(() {
        _containers = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create container: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteContainer(String containerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Container'),
        content: const Text(
            'Delete this container and all items inside? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final heroRepo = ref.read(heroRepositoryProvider);
      final updated =
          _containers.where((c) => c['id'] != containerId).toList();
      await heroRepo.saveInventoryContainers(widget.heroId, updated);
      setState(() {
        _containers = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete container: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addItemToContainer(String containerId) async {
    final itemData = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const CreateItemDialog(),
    );

    if (itemData == null) return;

    try {
      final heroRepo = ref.read(heroRepositoryProvider);
      final containerIndex =
          _containers.indexWhere((c) => c['id'] == containerId);
      if (containerIndex == -1) return;

      final container =
          Map<String, dynamic>.from(_containers[containerIndex]);
      final items =
          List<Map<String, dynamic>>.from(container['items'] as List? ?? []);

      items.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': itemData['name'],
        'description': itemData['description'],
      });

      container['items'] = items;

      final updated = List<Map<String, dynamic>>.from(_containers);
      updated[containerIndex] = container;

      await heroRepo.saveInventoryContainers(widget.heroId, updated);
      setState(() {
        _containers = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(String containerId, String itemId) async {
    try {
      final heroRepo = ref.read(heroRepositoryProvider);
      final containerIndex =
          _containers.indexWhere((c) => c['id'] == containerId);
      if (containerIndex == -1) return;

      final container =
          Map<String, dynamic>.from(_containers[containerIndex]);
      final items =
          List<Map<String, dynamic>>.from(container['items'] as List? ?? []);

      items.removeWhere((item) => item['id'] == itemId);
      container['items'] = items;

      final updated = List<Map<String, dynamic>>.from(_containers);
      updated[containerIndex] = container;

      await heroRepo.saveInventoryContainers(widget.heroId, updated);
      setState(() {
        _containers = updated;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                'Inventory',
                style: AppTextStyles.subtitle,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _createContainer,
                icon: const Icon(Icons.create_new_folder),
                label: const Text('New Container'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _containers.isEmpty
              ? const Center(
                  child: Text(
                    'No containers yet.\nCreate a container to organize your items.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _containers.length,
                  itemBuilder: (context, index) {
                    final container = _containers[index];
                    return ContainerCard(
                      container: container,
                      onAddItem: () =>
                          _addItemToContainer(container['id'] as String),
                      onDeleteContainer: () =>
                          _deleteContainer(container['id'] as String),
                      onDeleteItem: (itemId) =>
                          _deleteItem(container['id'] as String, itemId),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
