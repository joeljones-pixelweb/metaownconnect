import 'package:flutter/material.dart';

import '../../models/wallet_view_state.dart';

class WalletConnectionStatus extends StatelessWidget {
  const WalletConnectionStatus({super.key, required this.state});

  final WalletViewState state;

  @override
  Widget build(BuildContext context) {
    final busy = state.isConnecting || state.isInitializing;
    final statusColor = switch (state.status) {
      WalletStatus.connected => Colors.green,
      WalletStatus.connecting || WalletStatus.awaitingApproval => Colors.orange.shade700,
      WalletStatus.initializing => Colors.blueGrey,
      WalletStatus.disconnected => Colors.grey,
    };

    return Semantics(
      label: 'Wallet status: ${state.statusLabel}',
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: statusColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                state.statusLabel,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
