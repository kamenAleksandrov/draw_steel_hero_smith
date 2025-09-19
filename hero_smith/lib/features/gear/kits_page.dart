import 'package:flutter/material.dart';

class KitsPage extends StatelessWidget {
  const KitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kits')),
      body: const Center(
        child: Text('Kits list will appear here'),
      ),
    );
  }
}
