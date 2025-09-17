import 'package:flutter/material.dart';

class TitlesPage extends StatelessWidget {
  const TitlesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Titles')),
      body: const Center(child: Text('Titles (coming soon)')),
    );
  }
}
