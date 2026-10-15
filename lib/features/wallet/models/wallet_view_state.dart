import 'package:flutter/foundation.dart';

import 'blockchain_network.dart';
import 'connected_wallet.dart';
import 'native_balance.dart';
import 'wallet_failure.dart';

/// Lifecycle of the wallet connection itself.
enum WalletStatus {
  /// The SDK is starting up.
  initializing,

  /// No active session.
  disconnected,

  /// A connection request has been handed to the wallet.
  connecting,

  /// The wallet application is open and waiting for the user to approve.
  awaitingApproval,

  /// A verified session with a valid account exists.
  connected,
}

/// Lifecycle of the balance read, kept separate from the connection state so a
/// successful connection never implies a successful balance request.
enum BalanceStatus { idle, loading, ready, failed }

const Object _keep = Object();

/// Everything the Wallet view needs to render, in a single immutable value.
@immutable
class WalletViewState {
  const WalletViewState({
    this.status = WalletStatus.initializing,
    this.wallet,
    this.balance,
    this.balanceStatus = BalanceStatus.idle,
    this.connectionFailure,
    this.balanceFailure,
    this.notice,
    this.lastBalanceUpdate,
  });

  final WalletStatus status;

  /// Account returned by the wallet session.
  final ConnectedWallet? wallet;

  /// Native token balance for [wallet] on [network].
  final NativeBalance? balance;

  final BalanceStatus balanceStatus;

  /// Connection level failure (initialisation, rejection, timeout, ...).
  final WalletFailure? connectionFailure;

  /// Balance read failure, independent from [connectionFailure].
  final WalletFailure? balanceFailure;

  /// Transient, non alarming message such as a user cancellation.
  final String? notice;

  final DateTime? lastBalanceUpdate;

  /// Resolved network for the active session, or `null` when unsupported.
  BlockchainNetwork? get network =>
      wallet == null ? null : BlockchainNetworkRegistry.byChainId(wallet!.chainId);

  bool get hasWallet => wallet != null;

  bool get isConnected => status == WalletStatus.connected && wallet != null;

  bool get isInitializing => status == WalletStatus.initializing;

  bool get isConnecting =>
      status == WalletStatus.connecting ||
      status == WalletStatus.awaitingApproval;

  /// True when the session is alive but the chain is not in the registry.
  bool get isUnsupportedNetwork => isConnected && network == null;

  bool get isBalanceLoading => balanceStatus == BalanceStatus.loading;

  bool get hasBalance => balance != null && balanceStatus == BalanceStatus.ready;

  /// Chain specific actions stay disabled on unsupported networks.
  bool get canRefreshBalance => isConnected && network != null && !isBalanceLoading;

  /// Blocks duplicate connection requests while one is already in flight.
  bool get canStartConnection => !isConnecting && !isConnected && !isInitializing;

  String get statusLabel => switch (status) {
    WalletStatus.initializing => 'Initializing',
    WalletStatus.disconnected => 'Disconnected',
    WalletStatus.connecting => 'Connecting',
    WalletStatus.awaitingApproval => 'Awaiting wallet approval',
    WalletStatus.connected => 'Connected',
  };

  WalletViewState copyWith({
    WalletStatus? status,
    Object? wallet = _keep,
    Object? balance = _keep,
    BalanceStatus? balanceStatus,
    Object? connectionFailure = _keep,
    Object? balanceFailure = _keep,
    Object? notice = _keep,
    Object? lastBalanceUpdate = _keep,
  }) => WalletViewState(
    status: status ?? this.status,
    wallet: wallet == _keep ? this.wallet : wallet as ConnectedWallet?,
    balance: balance == _keep ? this.balance : balance as NativeBalance?,
    balanceStatus: balanceStatus ?? this.balanceStatus,
    connectionFailure: connectionFailure == _keep
        ? this.connectionFailure
        : connectionFailure as WalletFailure?,
    balanceFailure: balanceFailure == _keep
        ? this.balanceFailure
        : balanceFailure as WalletFailure?,
    notice: notice == _keep ? this.notice : notice as String?,
    lastBalanceUpdate: lastBalanceUpdate == _keep
        ? this.lastBalanceUpdate
        : lastBalanceUpdate as DateTime?,
  );

  @override
  String toString() =>
      'WalletViewState(status: $status, wallet: ${wallet?.shortAddress}, balanceStatus: $balanceStatus)';
}
