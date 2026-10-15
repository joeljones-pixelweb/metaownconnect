import 'package:flutter/material.dart';

import '../../models/native_balance.dart';
import '../../models/wallet_failure.dart';
import '../../models/wallet_view_state.dart';

class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.refreshing,
  });

  final WalletViewState state;
  final VoidCallback onRefresh;
  final bool refreshing;

  String get _valueLabel {
    if (state.hasBalance) {
      return BalanceFormatter.formatWithSymbol(
        wei: state.balance!.wei,
        decimals: state.network?.nativeDecimals ?? 18,
        symbol: state.network?.nativeSymbol ?? '',
      );
    }
    if (state.isBalanceLoading) return 'Fetching balance…';
    if (state.isUnsupportedNetwork) return 'Unavailable';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = _buildCaption();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Balance',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('refresh_balance_button'),
                  tooltip: 'Refresh balance',
                  onPressed: state.canRefreshBalance && !refreshing ? onRefresh : null,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _valueLabel,
              key: const Key('balance_value'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (state.isUnsupportedNetwork) ...[
              const SizedBox(height: 12),
              Text(
                state.balanceFailure?.message ??
                    const UnsupportedNetworkFailure().message,
                style: TextStyle(color: Colors.orange.shade800),
              ),
            ] else if (state.balanceFailure != null) ...[
              const SizedBox(height: 12),
              Text(
                state.balanceFailure!.message,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              if (state.balanceFailure!.canRetry)
                TextButton(onPressed: onRefresh, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }

  String? _buildCaption() {
    if (!state.hasBalance || state.lastBalanceUpdate == null) return null;
    final local = state.lastBalanceUpdate!.toLocal();
    final source = state.balance!.source == BalanceSource.rpc
        ? ' · Live from RPC'
        : ' · Cached value';
    return 'Updated ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}:${_twoDigits(local.second)}$source';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
