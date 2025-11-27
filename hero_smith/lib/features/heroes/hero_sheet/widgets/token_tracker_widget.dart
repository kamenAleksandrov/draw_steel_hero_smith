import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/complication_grants_service.dart';

/// Widget for tracking complication tokens (e.g., antihero tokens).
/// Shows current/max values with +/- buttons.
class TokenTrackerWidget extends ConsumerStatefulWidget {
  const TokenTrackerWidget({
    super.key,
    required this.heroId,
  });

  final String heroId;

  @override
  ConsumerState<TokenTrackerWidget> createState() => _TokenTrackerWidgetState();
}

class _TokenTrackerWidgetState extends ConsumerState<TokenTrackerWidget> {
  Map<String, int> _maxTokens = {};
  Map<String, int> _currentTokens = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    try {
      final service = ref.read(complicationGrantsServiceProvider);
      final max = await service.loadTokenGrants(widget.heroId);
      final current = await service.loadCurrentTokenValues(widget.heroId);

      if (mounted) {
        setState(() {
          _maxTokens = max;
          _currentTokens = current;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateToken(String tokenType, int delta) async {
    final current = _currentTokens[tokenType] ?? 0;
    final max = _maxTokens[tokenType] ?? 0;
    final newValue = (current + delta).clamp(0, max);

    if (newValue != current) {
      setState(() {
        _currentTokens[tokenType] = newValue;
      });

      final service = ref.read(complicationGrantsServiceProvider);
      await service.updateTokenValue(widget.heroId, tokenType, newValue);
    }
  }

  Future<void> _resetTokens() async {
    final service = ref.read(complicationGrantsServiceProvider);
    await service.resetTokensToMax(widget.heroId);
    await _loadTokens();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_maxTokens.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.token_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Tokens',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _resetTokens,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._maxTokens.entries.map((entry) {
          final tokenType = entry.key;
          final max = entry.value;
          final current = _currentTokens[tokenType] ?? 0;
          final displayName = _formatTokenName(tokenType);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TokenRow(
              name: displayName,
              current: current,
              max: max,
              onDecrement: () => _updateToken(tokenType, -1),
              onIncrement: () => _updateToken(tokenType, 1),
            ),
          );
        }),
      ],
    );
  }

  String _formatTokenName(String tokenType) {
    return tokenType
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');
  }
}

class _TokenRow extends StatelessWidget {
  const _TokenRow({
    required this.name,
    required this.current,
    required this.max,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String name;
  final int current;
  final int max;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canDecrement = current > 0;
    final canIncrement = current < max;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$current / $max',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: canDecrement ? onDecrement : null,
            icon: const Icon(Icons.remove_circle_outline),
            iconSize: 28,
            color: canDecrement ? theme.colorScheme.error : theme.colorScheme.outline.withOpacity(0.3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          Container(
            width: 48,
            alignment: Alignment.center,
            child: Text(
              current.toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: current == 0 
                    ? theme.colorScheme.error 
                    : current == max 
                        ? theme.colorScheme.primary 
                        : null,
              ),
            ),
          ),
          IconButton(
            onPressed: canIncrement ? onIncrement : null,
            icon: const Icon(Icons.add_circle_outline),
            iconSize: 28,
            color: canIncrement ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}
