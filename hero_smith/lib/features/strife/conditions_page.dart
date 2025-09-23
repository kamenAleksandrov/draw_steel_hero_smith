import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/db/providers.dart';
import '../../widgets/conditions/condition_card.dart';

class ConditionsPage extends ConsumerWidget {
  const ConditionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conditionsAsync = ref.watch(componentsByTypeProvider('condition'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conditions'),
      ),
      body: conditionsAsync.when(
        data: (conditions) {
          if (conditions.isEmpty) {
            return const Center(
              child: Text('No conditions available'),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conditions (${conditions.length})',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: conditions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final condition = conditions[index];
                      return ConditionCard(condition: condition);
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading conditions: $error'),
            ],
          ),
        ),
      ),
    );
  }
}