import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet_view_state.dart';
import '../viewmodels/wallet_view_model.dart';
import 'widgets/connect_metamask_button.dart';
import 'widgets/connected_wallet_card.dart';
import 'widgets/wallet_balance_card.dart';
import 'widgets/wallet_connection_status.dart';
import 'widgets/wallet_messages.dart';

class WalletPage extends ConsumerStatefulWidget {
  const WalletPage({super.key});

  @override
  ConsumerState<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends ConsumerState<WalletPage> {
  @override
  void initState() {
    super.initState();
    ref.read(walletViewModelProvider);
    unawaited(
      ref.read(walletViewModelProvider.notifier).initialize(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletViewModelProvider);
    final viewModel = ref.read(walletViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WalletConnectionStatus(state: state),
              const SizedBox(height: 16),
              if (state.notice != null) ...[
                NoticeBanner(
                  message: state.notice!,
                  onDismiss: viewModel.clearNotice,
                ),
                const SizedBox(height: 12),
              ],
              if (state.connectionFailure != null) ...[
                ErrorBanner(
                  failure: state.connectionFailure!,
                  onRetry: state.connectionFailure!.canRetry
                      ? viewModel.connect
                      : null,
                  onDismiss: viewModel.clearConnectionFailure,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              if (state.isInitializing)
                const Card(
                  key: Key('initializing_card'),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(height: 16),
                        Text('Setting up wallet connectivity…'),
                      ],
                    ),
                  ),
                )
              else if (!state.isConnected)
                _buildDisconnectedSection(state, viewModel)
              else ...[
                ConnectedWalletCard(
                  state: state,
                  onCopy: () => _copyAddress(context, state.wallet!.address),
                ),
                const SizedBox(height: 16),
                WalletBalanceCard(
                  state: state,
                  onRefresh: viewModel.refreshBalance,
                  refreshing: state.isBalanceLoading,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  key: const Key('disconnect_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: viewModel.disconnect,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Disconnect Wallet'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedSection(WalletViewState state, WalletViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Card(
          key: Key('disconnected_card'),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect your wallet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Connect through WalletConnect or MetaMask to use this app. '
                  'You will approve the connection inside your wallet. '
                  'This app never asks for your password, seed phrase or private key.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        ConnectMetaMaskButton(
          onPressed: viewModel.connect,
          busy: state.isConnecting,
          enabled: state.canStartConnection,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('browse_wallets_button'),
          onPressed: state.canStartConnection
              ? viewModel.connectWithWalletSheet
              : null,
          icon: const Icon(Icons.widgets_outlined),
          label: const Text('Browse all wallets'),
        ),
        if (state.status == WalletStatus.awaitingApproval) ...[
          const SizedBox(height: 12),
          const Text(
            'Waiting for approval in MetaMask…',
            key: Key('awaiting_approval'),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Future<void> _copyAddress(BuildContext context, String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
