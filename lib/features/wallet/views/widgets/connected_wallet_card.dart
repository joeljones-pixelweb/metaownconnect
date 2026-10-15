import 'package:flutter/material.dart';

import '../../models/wallet_view_state.dart';

class ConnectedWalletCard extends StatelessWidget {
  const ConnectedWalletCard({super.key, required this.state, required this.onCopy});

  final WalletViewState state;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final wallet = state.wallet;
    if (wallet == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Semantics(
      label: 'Connected wallet account',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      wallet.shortAddress,
                      key: const Key('wallet_address'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('copy_address_button'),
                    tooltip: 'Copy address',
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
              const Divider(),
              _DetailRow(
                label: 'Network',
                value: state.network?.name ?? 'Unsupported network',
              ),
              _DetailRow(label: 'Chain ID', value: wallet.referenceChainId),
              if (wallet.walletName != null)
                _DetailRow(label: 'Wallet', value: wallet.walletName!),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: labelStyle)),
          Expanded(child: Text(value, style: valueStyle)),
        ],
      ),
    );
  }
}
