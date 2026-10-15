import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/wallet_repository.dart';
import '../models/blockchain_network.dart';
import '../models/connected_wallet.dart';
import '../models/native_balance.dart';
import '../models/wallet_failure.dart';
import '../models/wallet_view_state.dart';
import '../services/wallet_service_events.dart';
import 'wallet_providers.dart';

/// The ViewModel of the Wallet MVVM triple.
///
/// It owns every piece of mutable wallet state: connection lifecycle, balance
/// lifecycle, transient notices and typed failures. The view only renders the
/// [WalletViewState] it exposes.
final walletViewModelProvider =
    NotifierProvider<WalletViewModel, WalletViewState>(WalletViewModel.new);

class WalletViewModel extends Notifier<WalletViewState> {
  /// How long we wait for the wallet to approve a connection before failing.
  Duration approvalTimeout = const Duration(seconds: 120);

  WalletRepository? _repository;
  StreamSubscription<WalletServiceEvent>? _events;
  Timer? _approvalTimer;
  int _balanceRequestId = 0;
  bool _started = false;
  bool _disconnecting = false;
  bool _disposed = false;

  @override
  WalletViewState build() {
    _repository = ref.read(walletRepositoryProvider);
    ref.onDispose(_release);
    _listenToConnectionEvents();
    return const WalletViewState();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Idempotent SDK bootstrap. Never throws so views can call it safely.
  Future<void> initialize(BuildContext context) async {
    if (_disposed || _started) return;
    _started = true;

    final repository = _repository;
    if (repository == null) {
      _emit(
        const WalletViewState(
          status: WalletStatus.disconnected,
          connectionFailure: SdkInitializationFailure(),
        ),
      );
      return;
    }

    try {
      await repository.initialize(context);
    } on WalletFailure catch (failure) {
      _emit(
        WalletViewState(
          status: WalletStatus.disconnected,
          connectionFailure: failure,
        ),
      );
      return;
    } catch (_) {
      _emit(
        const WalletViewState(
          status: WalletStatus.disconnected,
          connectionFailure: SdkInitializationFailure(),
        ),
      );
      return;
    }
    if (_disposed) return;

    final restored = repository.currentWallet();
    if (restored != null) {
      await _applySession(restored);
    } else {
      _emit(const WalletViewState(status: WalletStatus.disconnected));
    }
  }

  // ---------------------------------------------------------------------------
  // Connection actions
  // ---------------------------------------------------------------------------

  /// Starts the dedicated MetaMask connection flow.
  Future<void> connect() => _startConnection(useMetaMask: true);

  /// Alternative method: let the SDK present its own wallet sheet.
  Future<void> connectWithWalletSheet() => _startConnection(useMetaMask: false);

  Future<void> _startConnection({required bool useMetaMask}) async {
    final repository = _repository;
    // Duplicate taps are ignored: only one request may ever be in flight.
    if (repository == null || _disposed || !state.canStartConnection) return;

    _approvalTimer?.cancel();
    _emit(
      WalletViewState(
        status: WalletStatus.connecting,
        wallet: null,
        balance: null,
        balanceStatus: BalanceStatus.idle,
      ),
    );

    try {
      if (useMetaMask) {
        await repository.connectWithMetaMask();
      } else {
        await repository.openWalletSheet();
      }
    } on WalletFailure catch (failure) {
      _failConnection(failure);
      return;
    } catch (_) {
      _failConnection(const UnknownWalletFailure());
      return;
    }
    if (_disposed) return;

    final wallet = repository.currentWallet();
    if (wallet != null) {
      await _applySession(wallet);
      return;
    }

    _emit(state.copyWith(status: WalletStatus.awaitingApproval));
    _startApprovalTimer();
  }

  Future<void> disconnect() async {
    final repository = _repository;
    if (repository == null || _disposed || _disconnecting) return;
    if (!state.isConnected) {
      _clearConnection();
      return;
    }

    _disconnecting = true;
    _approvalTimer?.cancel();
    try {
      await repository.disconnect();
    } catch (_) {
      // The authoritative signal is the service's disconnected event.
    } finally {
      _disconnecting = false;
    }
    if (_disposed) return;
    _clearConnection(notice: 'Wallet disconnected');
  }

  // ---------------------------------------------------------------------------
  // Balance
  // ---------------------------------------------------------------------------

  Future<void> refreshBalance() async {
    final wallet = state.wallet;
    if (wallet == null || !state.canRefreshBalance) return;
    await _loadBalance(wallet);
  }

  Future<void> _loadBalance(ConnectedWallet wallet) async {
    final repository = _repository;
    if (repository == null || _disposed) return;

    final network = BlockchainNetworkRegistry.byChainId(wallet.chainId);
    if (network == null) {
      _emit(
        state.copyWith(
          balance: null,
          balanceStatus: BalanceStatus.failed,
          balanceFailure: const UnsupportedNetworkFailure(),
          lastBalanceUpdate: null,
        ),
      );
      return;
    }

    final requestId = ++_balanceRequestId;
    final previous = state.balance;
    final canKeepCached =
        previous != null &&
        state.balanceStatus == BalanceStatus.ready &&
        state.wallet == wallet;

    _emit(
      state.copyWith(
        balance: canKeepCached
            ? NativeBalance(
                wei: previous.wei,
                fetchedAt: previous.fetchedAt,
                source: BalanceSource.cached,
              )
            : null,
        balanceStatus: BalanceStatus.loading,
        balanceFailure: null,
      ),
    );

    try {
      final balance = await repository.fetchNativeBalance(
        address: wallet.address,
        network: network,
      );
      if (!_isCurrentBalanceRequest(requestId, wallet)) return;
      _emit(
        state.copyWith(
          balance: balance,
          balanceStatus: BalanceStatus.ready,
          balanceFailure: null,
          lastBalanceUpdate: balance.fetchedAt,
        ),
      );
    } on WalletFailure catch (failure) {
      if (!_isCurrentBalanceRequest(requestId, wallet)) return;
      _emit(
        state.copyWith(
          balance: null,
          balanceStatus: BalanceStatus.failed,
          balanceFailure: failure,
          lastBalanceUpdate: null,
        ),
      );
    } catch (_) {
      if (!_isCurrentBalanceRequest(requestId, wallet)) return;
      _emit(
        state.copyWith(
          balance: null,
          balanceStatus: BalanceStatus.failed,
          balanceFailure: const RpcFailure(),
          lastBalanceUpdate: null,
        ),
      );
    }
  }

  /// Guards against a slow RPC response for a previous account/chain
  /// overwriting the data of the currently selected one.
  bool _isCurrentBalanceRequest(int requestId, ConnectedWallet wallet) {
    if (_disposed || requestId != _balanceRequestId) return false;
    final current = state.wallet;
    if (current == null) return false;
    return current.address.toLowerCase() == wallet.address.toLowerCase() &&
        current.chainId == wallet.chainId;
  }

  // ---------------------------------------------------------------------------
  // Session handling
  // ---------------------------------------------------------------------------

  Future<void> _applySession(ConnectedWallet wallet) async {
    if (_disposed) return;
    if (!ConnectedWallet.isValidEvmAddress(wallet.address)) {
      _failConnection(const InvalidAccountFailure());
      return;
    }

    _approvalTimer?.cancel();
    final previous = state.wallet;
    // `==` on ConnectedWallet compares the address and the chain id.
    final unchanged = previous == wallet;

    _emit(
      state.copyWith(
        status: WalletStatus.connected,
        wallet: wallet,
        connectionFailure: null,
        // Anything held for another account/chain must never survive.
        balance: unchanged ? state.balance : null,
        balanceStatus: unchanged ? state.balanceStatus : BalanceStatus.idle,
        balanceFailure: unchanged ? state.balanceFailure : null,
        lastBalanceUpdate: unchanged ? state.lastBalanceUpdate : null,
        notice: null,
      ),
    );

    final needsBalance =
        !unchanged ||
        state.balanceStatus == BalanceStatus.idle ||
        state.balanceStatus == BalanceStatus.failed;
    if (needsBalance) {
      await _loadBalance(wallet);
    }
  }

  void _failConnection(WalletFailure failure) {
    if (_disposed) return;
    _approvalTimer?.cancel();

    if (failure is UserCancelledFailure) {
      // A cancelled approval is not an error: go back quietly.
      _clearConnection(notice: failure.message);
      return;
    }
    if (state.isConnected) {
      // Never tear down a live session because of a secondary error.
      _emit(state.copyWith(connectionFailure: failure));
      return;
    }
    _clearConnection(failure: failure);
  }

  void _clearConnection({WalletFailure? failure, String? notice}) {
    _approvalTimer?.cancel();
    _balanceRequestId++;
    _emit(
      WalletViewState(
        status: WalletStatus.disconnected,
        connectionFailure: failure,
        notice: notice,
      ),
    );
  }

  void _startApprovalTimer() {
    _approvalTimer?.cancel();
    _approvalTimer = Timer(approvalTimeout, () {
      if (_disposed || state.status != WalletStatus.awaitingApproval) return;
      _clearConnection(failure: const ConnectionTimeoutFailure());
    });
  }

  void _listenToConnectionEvents() {
    if (_events != null) return;
    final repository = _repository;
    if (repository == null) return;
    _events = repository.connectionEvents.listen(_onServiceEvent);
  }

  void _onServiceEvent(WalletServiceEvent event) {
    if (_disposed) return;
    switch (event) {
      case WalletSessionConnected(:final wallet):
      case WalletSessionUpdated(:final wallet):
        unawaited(_applySession(wallet));
      case WalletSessionDisconnected():
        _clearConnection(notice: state.isConnected ? 'Wallet disconnected' : null);
      case WalletSessionExpired():
        _clearConnection(failure: const SessionExpiredFailure());
      case WalletConnectionFailed(:final failure):
        _failConnection(failure);
    }
  }

  // ---------------------------------------------------------------------------
  // View helpers
  // ---------------------------------------------------------------------------

  void clearNotice() {
    if (_disposed || state.notice == null) return;
    _emit(state.copyWith(notice: null));
  }

  void clearConnectionFailure() {
    if (_disposed || state.connectionFailure == null) return;
    _emit(state.copyWith(connectionFailure: null));
  }

  void _emit(WalletViewState next) {
    if (_disposed) return;
    state = next;
  }

  void _release() {
    _disposed = true;
    _approvalTimer?.cancel();
    _approvalTimer = null;
    _events?.cancel();
    _events = null;
    _repository = null;
  }
}
