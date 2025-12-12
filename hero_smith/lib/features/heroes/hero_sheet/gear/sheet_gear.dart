import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'inventory_tab.dart';
import 'kits_tab.dart';
import 'treasures_tab.dart';

// Re-export utilities and widgets for external use
export 'gear_dialogs.dart';
export 'gear_utils.dart';
export 'gear_widgets.dart';
export 'inventory_widgets.dart';
export 'kit_widgets.dart';

/// Gear and treasures management for the hero with tabbed interface.
class SheetGear extends ConsumerStatefulWidget {
  const SheetGear({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<SheetGear> createState() => _SheetGearState();
}

class _SheetGearState extends ConsumerState<SheetGear>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'Treasures'),
            Tab(icon: Icon(Icons.shield), text: 'Kits'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Inventory'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              TreasuresTab(heroId: widget.heroId),
              KitsTab(heroId: widget.heroId),
              InventoryTab(heroId: widget.heroId),
            ],
          ),
        ),
      ],
    );
  }
}
