import 'package:flutter/material.dart';

/// Narrative, background, and progression notes for the hero.
class SheetStory extends StatelessWidget {
  const SheetStory({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Story, bonds, and goals go here'),
    );
  }
}
