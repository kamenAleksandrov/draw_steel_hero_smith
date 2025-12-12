import 'package:flutter/material.dart';

/// Card displaying an inventory container with its items.
class ContainerCard extends StatefulWidget {
  const ContainerCard({
    super.key,
    required this.container,
    required this.onAddItem,
    required this.onDeleteContainer,
    required this.onDeleteItem,
  });

  final Map<String, dynamic> container;
  final VoidCallback onAddItem;
  final VoidCallback onDeleteContainer;
  final Function(String) onDeleteItem;

  @override
  State<ContainerCard> createState() => _ContainerCardState();
}

class _ContainerCardState extends State<ContainerCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items =
        widget.container['items'] as List<dynamic>? ?? <Map<String, dynamic>>[];
    final name = widget.container['name'] as String? ?? 'Container';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              _isExpanded ? Icons.folder_open : Icons.folder,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text('${items.length} items'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: widget.onAddItem,
                  tooltip: 'Add item',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDeleteContainer,
                  tooltip: 'Delete container',
                ),
                IconButton(
                  icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
          ),
          if (_isExpanded && items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: items.map((item) {
                  final itemMap = item as Map<String, dynamic>;
                  return ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(itemMap['name'] as String? ?? 'Item'),
                    subtitle: itemMap['description'] != null &&
                            (itemMap['description'] as String).isNotEmpty
                        ? Text(itemMap['description'] as String)
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          widget.onDeleteItem(itemMap['id'] as String),
                    ),
                    dense: true,
                  );
                }).toList(),
              ),
            ),
          if (_isExpanded && items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No items. Tap + to add one.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
