import 'package:flutter/material.dart';

import '../../../core/models/component.dart' as model;
import '../../../widgets/kits/kit_card.dart';
import '../../../widgets/kits/modifier_card.dart';
import '../../../widgets/kits/stormwight_kit_card.dart';
import '../../../widgets/kits/ward_card.dart';

/// Wrapper widget that displays a favorite kit using the appropriate existing kit card
/// and adds action buttons for remove from favorites and swap.
/// Cards start collapsed and expand when clicked.
class FavoriteKitCardWrapper extends StatelessWidget {
  const FavoriteKitCardWrapper({
    super.key,
    required this.kit,
    required this.isEquipped,
    required this.onSwap,
    required this.onRemoveFavorite,
    this.equippedSlotLabel,
  });

  final model.Component kit;
  final bool isEquipped;
  final VoidCallback onSwap;
  final VoidCallback onRemoveFavorite;
  final String? equippedSlotLabel;

  String _getBadgeLabel(String type) {
    switch (type) {
      case 'psionic_augmentation':
        return 'Augmentation';
      case 'prayer':
        return 'Prayer';
      case 'enchantment':
        return 'Enchantment';
      default:
        return type;
    }
  }

  Widget _buildKitCard() {
    // Convert to Component (non-aliased) for the kit widgets
    final component = model.Component(
      id: kit.id,
      name: kit.name,
      type: kit.type,
      data: kit.data,
    );

    switch (kit.type) {
      case 'kit':
        return KitCard(
          component: component,
          initiallyExpanded: false,
        );
      case 'stormwight_kit':
        return StormwightKitCard(
          component: component,
          initiallyExpanded: false,
        );
      case 'ward':
        return WardCard(
          component: component,
          initiallyExpanded: false,
        );
      case 'psionic_augmentation':
      case 'prayer':
      case 'enchantment':
        return ModifierCard(
          component: component,
          badgeLabel: _getBadgeLabel(kit.type),
          initiallyExpanded: false,
        );
      default:
        // Fallback to standard kit card
        return KitCard(
          component: component,
          initiallyExpanded: false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action bar above the card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isEquipped
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Equipped badge with slot label
                if (isEquipped) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          equippedSlotLabel != null
                              ? 'EQUIPPED: $equippedSlotLabel'
                              : 'EQUIPPED',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Swap button when not equipped
                  TextButton.icon(
                    onPressed: onSwap,
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Swap'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
                const Spacer(),
                // Remove from favorites button (always visible)
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red, size: 20),
                  onPressed: onRemoveFavorite,
                  tooltip: 'Remove from favorites',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // The actual kit card (from widgets/kits/)
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: _buildKitCard(),
          ),
        ],
      ),
    );
  }
}

/// Legacy card for reference - kept for backwards compatibility.
@Deprecated('Use FavoriteKitCardWrapper instead')
class KitFavoriteCard extends StatelessWidget {
  const KitFavoriteCard({
    super.key,
    required this.kit,
    required this.isEquipped,
    required this.onSwap,
    required this.onRemoveFavorite,
  });

  final model.Component kit;
  final bool isEquipped;
  final VoidCallback onSwap;
  final VoidCallback onRemoveFavorite;

  @override
  Widget build(BuildContext context) {
    return FavoriteKitCardWrapper(
      kit: kit,
      isEquipped: isEquipped,
      onSwap: onSwap,
      onRemoveFavorite: onRemoveFavorite,
    );
  }
}

/// A small chip displaying a stat bonus.
class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
