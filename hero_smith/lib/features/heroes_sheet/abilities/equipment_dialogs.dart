// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../../../core/db/providers.dart';
// import '../../../../core/models/component.dart';
// import '../../../../widgets/kits/kit_card.dart';
// import '../../../../widgets/kits/modifier_card.dart';
// import '../../../../widgets/kits/stormwight_kit_card.dart';
// import '../../../../widgets/kits/ward_card.dart';
// import 'equipment_constants.dart';

// /// Dialog for selecting which equipment slot to change when hero has multiple slots
// class EquipmentSlotMenuDialog extends StatelessWidget {
//   const EquipmentSlotMenuDialog({
//     super.key,
//     required this.slots,
//     required this.selectedIds,
//     required this.onFindItem,
//   });

//   final List<EquipmentSlotConfig> slots;
//   final List<String?> selectedIds;
//   final Future<Component?> Function(String) onFindItem;

//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: const Text('Select Equipment to Change'),
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           for (var i = 0; i < slots.length; i++)
//             _buildSlotOption(context, slots[i], i),
//         ],
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.of(context).pop(),
//           child: const Text('Cancel'),
//         ),
//       ],
//     );
//   }
  
//   Widget _buildSlotOption(BuildContext context, EquipmentSlotConfig slot, int index) {
//     final theme = Theme.of(context);
//     final selectedId = index < selectedIds.length ? selectedIds[index] : null;
    
//     return ListTile(
//       leading: Icon(
//         EquipmentConstants.equipmentTypeIcons[slot.allowedTypes.first] ?? Icons.inventory_2_outlined,
//       ),
//       title: Text(slot.label),
//       subtitle: selectedId == null 
//           ? Text('Not selected', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)))
//           : FutureBuilder<Component?>(
//               future: onFindItem(selectedId),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Text('Loading...');
//                 }
//                 return Text(snapshot.data?.name ?? 'Unknown');
//               },
//             ),
//       onTap: () => Navigator.of(context).pop(slot),
//     );
//   }
// }

// /// Equipment selection dialog for the hero sheet (similar to creator but adapted)
// class SheetEquipmentSelectionDialog extends ConsumerStatefulWidget {
//   const SheetEquipmentSelectionDialog({
//     super.key,
//     required this.slotLabel,
//     required this.allowedTypes,
//     required this.currentItemId,
//     required this.canRemove,
//   });

//   final String slotLabel;
//   final List<String> allowedTypes;
//   final String? currentItemId;
//   final bool canRemove;

//   @override
//   ConsumerState<SheetEquipmentSelectionDialog> createState() => _SheetEquipmentSelectionDialogState();
// }

// class _SheetEquipmentSelectionDialogState extends ConsumerState<SheetEquipmentSelectionDialog> {
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   List<String> _normalizeAllowedTypes() {
//     final normalized = <String>{};
//     for (final type in widget.allowedTypes) {
//       final trimmed = type.trim().toLowerCase();
//       if (trimmed.isNotEmpty) {
//         normalized.add(trimmed);
//       }
//     }
//     if (normalized.isEmpty) {
//       normalized.addAll(EquipmentConstants.allEquipmentTypes);
//     }
//     return normalized.toList();
//   }

//   List<String> _sortEquipmentTypes(Iterable<String> types) {
//     final seen = <String>{};
//     final sorted = <String>[];
//     for (final type in EquipmentConstants.allEquipmentTypes) {
//       if (types.contains(type) && seen.add(type)) {
//         sorted.add(type);
//       }
//     }
//     for (final type in types) {
//       if (seen.add(type)) {
//         sorted.add(type);
//       }
//     }
//     return sorted;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final normalized = _normalizeAllowedTypes();
//     final sorted = _sortEquipmentTypes(normalized);
    
//     final categories = <({String type, String label, IconData icon, AsyncValue<List<Component>> data})>[];
//     for (final type in sorted) {
//       categories.add((
//         type: type,
//         label: EquipmentConstants.equipmentTypeTitles[type] ?? EquipmentConstants.titleize(type),
//         icon: EquipmentConstants.equipmentTypeIcons[type] ?? Icons.inventory_2_outlined,
//         data: ref.watch(componentsByTypeProvider(type)),
//       ));
//     }
    
//     final navigator = Navigator.of(context);
//     final hasMultipleCategories = categories.length > 1;

//     if (categories.isEmpty) {
//       return Dialog(
//         child: SizedBox(
//           width: 400,
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               AppBar(
//                 title: Text('Select ${widget.slotLabel}'),
//                 automaticallyImplyLeading: false,
//                 actions: [
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => navigator.pop(),
//                   ),
//                 ],
//               ),
//               const Padding(
//                 padding: EdgeInsets.all(24.0),
//                 child: Text('No items available'),
//               ),
//             ],
//           ),
//         ),
//       );
//     }

//     return DefaultTabController(
//       length: categories.length,
//       child: Dialog(
//         child: SizedBox(
//           width: MediaQuery.of(context).size.width * 0.9,
//           height: MediaQuery.of(context).size.height * 0.85,
//           child: Column(
//             children: [
//               AppBar(
//                 title: Text('Select ${widget.slotLabel}'),
//                 automaticallyImplyLeading: false,
//                 actions: [
//                   if (widget.canRemove)
//                     TextButton.icon(
//                       onPressed: () => navigator.pop('__remove_item__'),
//                       icon: const Icon(Icons.clear, color: Colors.white),
//                       label: const Text('Remove', style: TextStyle(color: Colors.white)),
//                     ),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => navigator.pop(),
//                   ),
//                 ],
//               ),
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
//                 child: TextField(
//                   controller: _searchController,
//                   autofocus: true,
//                   decoration: InputDecoration(
//                     hintText: 'Search equipment...',
//                     prefixIcon: const Icon(Icons.search),
//                     suffixIcon: _searchQuery.isEmpty
//                         ? null
//                         : IconButton(
//                             icon: const Icon(Icons.clear),
//                             onPressed: () {
//                               setState(() {
//                                 _searchQuery = '';
//                                 _searchController.clear();
//                               });
//                             },
//                           ),
//                     border: const OutlineInputBorder(),
//                     isDense: true,
//                   ),
//                   onChanged: (value) {
//                     setState(() {
//                       _searchQuery = value.trim().toLowerCase();
//                     });
//                   },
//                 ),
//               ),
//               if (hasMultipleCategories)
//                 Material(
//                   color: Theme.of(context).colorScheme.surface,
//                   child: TabBar(
//                     isScrollable: true,
//                     tabs: categories.map((cat) {
//                       final count = cat.data.maybeWhen(
//                         data: (items) => items.length,
//                         orElse: () => null,
//                       );
//                       final label = count == null ? cat.label : '${cat.label} ($count)';
//                       return Tab(text: label, icon: Icon(cat.icon, size: 18));
//                     }).toList(),
//                   ),
//                 ),
//               Expanded(
//                 child: hasMultipleCategories
//                     ? TabBarView(
//                         children: [
//                           for (final category in categories)
//                             _buildCategoryList(context, category.type, category.label, category.data),
//                         ],
//                       )
//                     : _buildCategoryList(context, categories.first.type, categories.first.label, categories.first.data),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildCategoryList(
//     BuildContext context,
//     String type,
//     String label,
//     AsyncValue<List<Component>> data,
//   ) {
//     final query = _searchQuery;
//     final theme = Theme.of(context);

//     return data.when(
//       data: (items) {
//         final filtered = query.isEmpty
//             ? items
//             : items.where((item) {
//                 final name = item.name.toLowerCase();
//                 final description = (item.data['description'] as String?)?.toLowerCase() ?? '';
//                 return name.contains(query) || description.contains(query);
//               }).toList();

//         if (filtered.isEmpty) {
//           return Center(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Text(
//                 query.isEmpty
//                     ? 'No ${label.toLowerCase()} available'
//                     : 'No results for "${_searchController.text}"',
//               ),
//             ),
//           );
//         }

//         return ListView.builder(
//           padding: const EdgeInsets.all(16),
//           itemCount: filtered.length,
//           itemBuilder: (context, index) {
//             final item = filtered[index];
//             final isSelected = item.id == widget.currentItemId;
//             final description = item.data['description'] as String?;

//             return Padding(
//               padding: const EdgeInsets.only(bottom: 12),
//               child: InkWell(
//                 onTap: () => Navigator.of(context).pop(item.id),
//                 borderRadius: BorderRadius.circular(8),
//                 child: Container(
//                   padding: const EdgeInsets.all(16),
//                   decoration: BoxDecoration(
//                     color: isSelected
//                         ? theme.colorScheme.primaryContainer.withOpacity(0.3)
//                         : theme.colorScheme.surface,
//                     border: Border.all(
//                       color: isSelected
//                           ? theme.colorScheme.primary
//                           : theme.colorScheme.outline.withOpacity(0.5),
//                       width: isSelected ? 2 : 1,
//                     ),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           if (isSelected)
//                             Padding(
//                               padding: const EdgeInsets.only(right: 8),
//                               child: Icon(
//                                 Icons.check_circle,
//                                 color: theme.colorScheme.primary,
//                                 size: 20,
//                               ),
//                             ),
//                           Expanded(
//                             child: Text(
//                               item.name,
//                               style: theme.textTheme.titleMedium?.copyWith(
//                                 fontWeight: FontWeight.bold,
//                                 color: isSelected ? theme.colorScheme.primary : null,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       if (description != null && description.isNotEmpty) ...[
//                         const SizedBox(height: 8),
//                         Text(
//                           description,
//                           style: theme.textTheme.bodyMedium?.copyWith(
//                             color: theme.colorScheme.onSurface.withOpacity(0.8),
//                           ),
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           },
//         );
//       },
//       loading: () => const Center(child: CircularProgressIndicator()),
//       error: (error, stack) => Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24.0),
//           child: Text('Error loading ${label.toLowerCase()}: $error'),
//         ),
//       ),
//     );
//   }
// }

// /// Dialog for previewing a kit/equipment item
// class KitPreviewDialog extends StatelessWidget {
//   const KitPreviewDialog({
//     super.key,
//     required this.item,
//   });

//   final Component item;

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       child: ConstrainedBox(
//         constraints: BoxConstraints(
//           maxWidth: 600,
//           maxHeight: MediaQuery.of(context).size.height * 0.8,
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             AppBar(
//               title: Text(item.name),
//               automaticallyImplyLeading: false,
//               actions: [
//                 IconButton(
//                   icon: const Icon(Icons.close),
//                   onPressed: () => Navigator.of(context).pop(),
//                 ),
//               ],
//             ),
//             Flexible(
//               child: SingleChildScrollView(
//                 child: _buildCardForComponent(item),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCardForComponent(Component item) {
//     switch (item.type) {
//       case 'kit':
//         return KitCard(component: item, initiallyExpanded: true);
//       case 'stormwight_kit':
//         return StormwightKitCard(component: item, initiallyExpanded: true);
//       case 'ward':
//         return WardCard(component: item, initiallyExpanded: true);
//       case 'psionic_augmentation':
//       case 'enchantment':
//       case 'prayer':
//         return ModifierCard(component: item, badgeLabel: item.type, initiallyExpanded: true);
//       default:
//         return KitCard(component: item, initiallyExpanded: true);
//     }
//   }
// }
