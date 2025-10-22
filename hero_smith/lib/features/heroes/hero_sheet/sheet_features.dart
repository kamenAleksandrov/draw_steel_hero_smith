import 'package:flutter/material.dart';

/// Highlights class features, perks, and other unique hero traits.
class SheetFeatures extends StatelessWidget {
  const SheetFeatures({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Features details will appear here'),
    );
  }
}
