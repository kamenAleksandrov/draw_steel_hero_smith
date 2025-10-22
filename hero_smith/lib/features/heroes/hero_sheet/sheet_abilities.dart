import 'package:flutter/material.dart';

/// Shows active, passive, and situational abilities available to the hero.
class SheetAbilities extends StatelessWidget {
  const SheetAbilities({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Abilities overview coming soon'),
    );
  }
}
