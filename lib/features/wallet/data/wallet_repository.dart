import 'package:flutter/widgets.dart';

import '../models/blockchain_network.dart';
import '../models/connected_wallet.dart';
import '../models/native_balance.dart';
import '../services/wallet_connection_service.dart';
import '../services/wallet_service_events.dart';
import 'blockchain_balance_service.dart';

/// Single point of access to wallet related data.
///
/// Coordinates the connection service and the read-only chain service so the
/// ViewModel never talks to either SDK or HTTP directly.
class WalletRepository {
  WalletRepository({
    required IWalletConnectionService connectionService,
    required IBlockchainBalanceService balanceService,
  }) : _connection = connectionService,
       _balance = balanceService;

  final IWalletConnectionService _connection;
  final IBlockchainBalanceService _balance;

  Stream<WalletServiceEvent> get connectionEvents => _connection.events;

  bool get isConnectionSheetOpen => _connection.isConnectionSheetOpen;

  /// Idempotent; see [IWalletConnectionService.initialize].
  Future<void> initialize(BuildContext context) => _connection.initialize(context);

  /// Verified session for the currently selected account and chain.
  ConnectedWallet? currentWallet() => _connection.peekSession();

  Future<void> connectWithMetaMask() => _connection.connectMetaMask();

  Future<void> openWalletSheet() => _connection.openConnectionSheet();

  Future<void> disconnect() => _connection.disconnect();

  /// Reads the native balance of [address] on [network] over JSON-RPC.
  Future<NativeBalance> fetchNativeBalance({
    required String address,
    required BlockchainNetwork network,
  }) => _balance.fetchNativeBalance(address: address, network: network);
}
