import 'package:flutter/material.dart';

class TreasurePage extends StatelessWidget {
  const TreasurePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Treasure')),
      body: const Center(
        child: Text('Treasure list will appear here'),
      ),
    );
  }
}
