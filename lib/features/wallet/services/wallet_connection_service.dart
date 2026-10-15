import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:reown_appkit/modal/services/explorer_service/i_explorer_service.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../../../app/app_config.dart';
import '../models/connected_wallet.dart';
import '../models/wallet_failure.dart';
import 'wallet_service_events.dart';

/// Well known WalletConnect explorer id for MetaMask.
const String kMetaMaskWalletId =
    'c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96';

/// Owns the wallet SDK: initialisation, connect, disconnect and session events.
///
/// Everything the SDK returns is normalised to [WalletServiceEvent] /
/// [ConnectedWallet] so no SDK type escapes this boundary.
abstract interface class IWalletConnectionService {
  /// True once the SDK reported a successful initialisation.
  bool get isInitialized;

  /// Whether the SDK connection sheet is currently on screen.
  bool get isConnectionSheetOpen;

  /// Stream of connection lifecycle events.
  Stream<WalletServiceEvent> get events;

  /// Initialises the SDK exactly once. Safe to call repeatedly.
  ///
  /// [context] must live below the application `Navigator` so the SDK is able
  /// to present its modal UI.
  Future<void> initialize(BuildContext context);

  /// Starts a real MetaMask connection. Falls back to the SDK wallet sheet when
  /// MetaMask cannot be resolved from the wallet explorer.
  Future<void> connectMetaMask();

  /// Opens the SDK wallet sheet, which is the supported alternative connection
  /// method (QR code, all wallets, ...).
  Future<void> openConnectionSheet();

  /// Closes the active session.
  Future<void> disconnect();

  /// The currently verified session, or `null` when not connected.
  ConnectedWallet? peekSession();

  /// Releases listeners and SDK resources.
  void dispose();
}

class WalletConnectionService implements IWalletConnectionService {
  WalletConnectionService({required AppConfig config}) : _config = config;

  final AppConfig _config;

  final StreamController<WalletServiceEvent> _events =
      StreamController<WalletServiceEvent>.broadcast();
  final List<void Function()> _detachHandlers = <void Function()>[];

  ReownAppKitModal? _modal;
  Future<void>? _pendingInitialization;
  bool _initialized = false;
  bool _disposed = false;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isConnectionSheetOpen => _modal?.isOpen ?? false;

  @override
  Stream<WalletServiceEvent> get events => _events.stream;

  @override
  Future<void> initialize(BuildContext context) {
    if (_disposed) return Future<void>.value();
    if (_initialized) return Future<void>.value();
    return _pendingInitialization ??= _doInitialize(context).whenComplete(() {
      _pendingInitialization = null;
    });
  }

  Future<void> _doInitialize(BuildContext context) async {
    if (!_config.isConfigured) throw const ConfigurationFailure();

    try {
      final modal = _modal ??= ReownAppKitModal(
        context: context,
        projectId: _config.projectId,
        metadata: PairingMetadata(
          name: _config.appName,
          description: _config.appDescription,
          url: _config.websiteUrl,
          icons: <String>[_config.iconUrl],
          redirect: Redirect(
            native: _config.nativeRedirectUrl,
            universal: _config.universalRedirectUrl,
            linkMode: _config.linkModeEnabled,
          ),
        ),
        featuredWalletIds: <String>{kMetaMaskWalletId},
        enableAnalytics: _config.enableAnalytics,
        logLevel: LogLevel.nothing,
        // The user stays connected across hot restarts / rebuilds; only an
        // explicit disconnect() call tears the session down.
        disconnectOnDispose: false,
      );

      _attachHandlers(modal);
      await modal.init();

      if (modal.status.isError) throw const SdkInitializationFailure();
      _initialized = true;
    } on WalletFailure {
      rethrow;
    } catch (_) {
      // Never leak raw SDK exceptions to the UI or the logs.
      throw const SdkInitializationFailure();
    }
  }

  @override
  Future<void> connectMetaMask() async {
    final modal = _requireInitialized();
    if (modal.isConnected) return;

    final metaMask = await _resolveMetaMaskWallet(modal);
    if (metaMask == null) {
      // The explorer could not provide MetaMask; let the SDK present its own
      // supported wallet connection interface instead.
      await _openSheet(modal, const ReownAppKitModalAllWalletsPage());
      return;
    }

    modal.selectWallet(metaMask);
    // selectWallet() is `async` without awaiting anything on this path, but a
    // turn of the event loop guarantees the selection is stored first.
    await Future<void>.delayed(Duration.zero);
    await modal.connectSelectedWallet();
  }

  @override
  Future<void> openConnectionSheet() async {
    final modal = _requireInitialized();
    if (modal.isConnected) return;
    await _openSheet(modal, null);
  }

  Future<void> _openSheet(ReownAppKitModal modal, Widget? startWidget) async {
    try {
      await modal.openModalView(startWidget);
    } on ReownAppKitModalException {
      throw const SdkInitializationFailure();
    } catch (_) {
      throw const UnknownWalletFailure();
    }
  }

  @override
  Future<void> disconnect() async {
    final modal = _modal;
    if (modal == null || !modal.isConnected) return;
    try {
      await modal.disconnect();
    } catch (_) {
      // Fall through: the state is re-read from the session below, and an
      // onModalDisconnect event is the authoritative signal.
    }
    if (!modal.isConnected) {
      _emit(const WalletSessionDisconnected());
    }
  }

  @override
  ConnectedWallet? peekSession() {
    final modal = _modal;
    if (modal == null || !modal.isConnected) return null;
    final session = modal.session;
    if (session == null) return null;
    return _toWallet(session);
  }

  ReownAppKitModal _requireInitialized() {
    final modal = _modal;
    if (modal == null || !_initialized) {
      throw const SdkInitializationFailure();
    }
    return modal;
  }

  /// Looks MetaMask up in the WalletConnect explorer listings.
  ///
  /// Returns `null` after [timeout] when it cannot be found, which lets the
  /// caller fall back to the SDK sheet instead of failing.
  Future<ReownAppKitModalWalletInfo?> _resolveMetaMaskWallet(
    ReownAppKitModal modal, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    IExplorerService explorer;
    try {
      explorer = GetIt.I<IExplorerService>();
    } catch (_) {
      return null;
    }

    try {
      if (!explorer.initialized.value) await explorer.init();
    } catch (_) {
      return null;
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_disposed) return null;
      final match = _findMetaMask(explorer.listings.value);
      if (match != null) return match;
      if (!modal.status.isLoading && !modal.status.isInitialized) return null;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return _findMetaMask(explorer.listings.value);
  }

  ReownAppKitModalWalletInfo? _findMetaMask(
    List<ReownAppKitModalWalletInfo> listings,
  ) {
    for (final wallet in listings) {
      if (wallet.listing.id == kMetaMaskWalletId) return wallet;
      if (wallet.listing.name.trim().toLowerCase() == 'metamask') return wallet;
    }
    return null;
  }

  void _attachHandlers(ReownAppKitModal modal) {
    if (_detachHandlers.isNotEmpty) return;

    void listen<T extends EventArgs>(Event<T> event, void Function(T? event) handler) {
      event.subscribe(handler);
      _detachHandlers.add(() => event.unsubscribe(handler));
    }

    listen<ModalConnect>(modal.onModalConnect, (event) {
      final wallet = event == null ? null : _toWallet(event.session);
      if (wallet == null) {
        _emit(const WalletConnectionFailed(InvalidAccountFailure()));
      } else {
        _emit(WalletSessionConnected(wallet));
      }
    });

    listen<ModalConnect>(modal.onModalUpdate, (event) {
      final wallet = event == null ? null : _toWallet(event.session);
      if (wallet != null) _emit(WalletSessionUpdated(wallet));
    });

    listen<ModalNetworkChange>(modal.onModalNetworkChange, (_) {
      final wallet = peekSession();
      if (wallet != null) {
        _emit(WalletSessionUpdated(wallet));
      } else {
        _emit(const WalletSessionDisconnected());
      }
    });

    listen<ModalDisconnect>(modal.onModalDisconnect, (_) {
      _emit(const WalletSessionDisconnected());
    });

    listen<ModalError>(modal.onModalError, (event) {
      if (event == null) return;
      _emit(WalletConnectionFailed(mapModalError(event)));
    });

    listen<SessionExpire>(modal.onSessionExpireEvent, (_) {
      _emit(const WalletSessionExpired());
    });

    listen<SessionUpdate>(modal.onSessionUpdateEvent, (_) {
      final wallet = peekSession();
      if (wallet != null) _emit(WalletSessionUpdated(wallet));
    });
  }

  /// Converts an SDK error into a typed, user friendly failure.
  @visibleForTesting
  WalletFailure mapModalError(ModalError error) {
    if (error is WalletNotInstalled) return const WalletUnavailableFailure();
    if (error is UserRejectedConnection) return const UserCancelledFailure();
    if (error is UserRejectedRequest) return const ConnectionRejectedFailure();
    if (error is ErrorOpeningWallet) return const WalletUnavailableFailure();

    final message = error.message.toLowerCase();
    if (message.contains('reject') ||
        message.contains('denied') ||
        message.contains('cancel')) {
      return const ConnectionRejectedFailure();
    }
    if (message.contains('not installed') || message.contains('unavailable')) {
      return const WalletUnavailableFailure();
    }
    if (message.contains('offline') || message.contains('network')) {
      return const NetworkUnavailableFailure();
    }
    return const UnknownWalletFailure();
  }

  ConnectedWallet? _toWallet(ReownAppKitModalSession session) {
    try {
      final chainId = session.chainId;
      if (chainId.isEmpty) return null;
      final namespace = NamespaceUtils.getNamespaceFromChain(chainId);
      final address = session.getAddress(namespace);
      if (address == null || !ConnectedWallet.isValidEvmAddress(address)) {
        return null;
      }
      String? walletName;
      try {
        walletName = session.connectedWalletName;
      } catch (_) {
        walletName = null;
      }
      return ConnectedWallet(
        address: address.trim(),
        chainId: chainId,
        walletName: walletName,
      );
    } catch (_) {
      return null;
    }
  }

  void _emit(WalletServiceEvent event) {
    if (_disposed || _events.isClosed) return;
    _events.add(event);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final detach in _detachHandlers) {
      detach();
    }
    _detachHandlers.clear();
    final modal = _modal;
    _modal = null;
    if (modal != null) {
      unawaited(modal.dispose());
    }
    _events.close();
  }
}
