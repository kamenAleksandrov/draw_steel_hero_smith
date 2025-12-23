import 'package:flutter/material.dart';

import '../../../core/theme/text/heroes_sheet/gear/inventory_widgets_text.dart';

/// Card displaying an inventory container with its items.
class ContainerCard extends StatefulWidget {
  const ContainerCard({
    super.key,
    required this.container,
    required this.onAddItem,
    required this.onDeleteContainer,
    required this.onDeleteItem,
    required this.onEditItem,
    required this.onEditContainer,
    required this.onUpdateItemQuantity,
  });

  final Map<String, dynamic> container;
  final VoidCallback onAddItem;
  final VoidCallback onDeleteContainer;
  final Function(String) onDeleteItem;
  final Function(String, Map<String, dynamic>) onEditItem;
  final VoidCallback onEditContainer;
  final Function(String, int) onUpdateItemQuantity;

  @override
  State<ContainerCard> createState() => _ContainerCardState();
}

class _ContainerCardState extends State<ContainerCard> {
  bool _isExpanded = true;

  Future<void> _showQuantityDialog(BuildContext context, String itemId, int currentQuantity) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _QuantityInputDialog(currentQuantity: currentQuantity),
    );
    
    if (result != null && result != currentQuantity) {
      widget.onUpdateItemQuantity(itemId, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items =
        widget.container['items'] as List<dynamic>? ?? <Map<String, dynamic>>[];
    final name = widget.container['name'] as String? ??
        InventoryWidgetsText.defaultContainerName;

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
            subtitle: Text(
              '${items.length}${InventoryWidgetsText.containerItemsSuffix}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: widget.onAddItem,
                  tooltip: InventoryWidgetsText.addItemTooltip,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: widget.onEditContainer,
                  tooltip: InventoryWidgetsText.editContainerTooltip,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDeleteContainer,
                  tooltip: InventoryWidgetsText.deleteContainerTooltip,
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
                  final itemId = itemMap['id'] as String;
                  final qty = itemMap['quantity'];
                  final quantity = qty is int ? qty : int.tryParse(qty?.toString() ?? '1') ?? 1;
                  
                  return ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            itemMap['name'] as String? ??
                                InventoryWidgetsText.defaultItemName,
                          ),
                        ),
                        // Quantity controls
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                onTap: quantity > 1
                                    ? () => widget.onUpdateItemQuantity(itemId, quantity - 1)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: quantity > 1 ? null : Colors.grey,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => _showQuantityDialog(context, itemId, quantity),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    '$quantity',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                onTap: quantity < 999
                                    ? () => widget.onUpdateItemQuantity(itemId, quantity + 1)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.add,
                                    size: 16,
                                    color: quantity < 999 ? null : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    subtitle: itemMap['description'] != null &&
                            (itemMap['description'] as String).isNotEmpty
                        ? Text(itemMap['description'] as String)
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => widget.onEditItem(itemId, itemMap),
                          tooltip: InventoryWidgetsText.editItemTooltip,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => widget.onDeleteItem(itemId),
                          tooltip: InventoryWidgetsText.deleteItemTooltip,
                        ),
                      ],
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
                InventoryWidgetsText.emptyItemsMessage,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dialog for inputting a quantity value.
class _QuantityInputDialog extends StatefulWidget {
  const _QuantityInputDialog({required this.currentQuantity});

  final int currentQuantity;

  @override
  State<_QuantityInputDialog> createState() => _QuantityInputDialogState();
}

class _QuantityInputDialogState extends State<_QuantityInputDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentQuantity}');
    _focusNode = FocusNode();
    // Request focus after the dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = int.tryParse(_controller.text);
    if (qty != null && qty >= 1 && qty <= 999) {
      Navigator.of(context).pop(qty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(InventoryWidgetsText.quantityDialogTitle),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: InventoryWidgetsText.quantityDialogLabel,
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(InventoryWidgetsText.quantityDialogCancelAction),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text(InventoryWidgetsText.quantityDialogSetAction),
        ),
      ],
    );
  }
}
