import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../app/app_config.dart';
import '../data/blockchain_balance_service.dart';
import '../data/wallet_repository.dart';
import '../services/wallet_connection_service.dart';

/// Build time, environment specific configuration.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// Owns the wallet SDK instance for the lifetime of the application.
final walletConnectionServiceProvider = Provider<IWalletConnectionService>((
  ref,
) {
  final service = WalletConnectionService(config: ref.watch(appConfigProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Read-only JSON-RPC access.
final blockchainBalanceServiceProvider = Provider<IBlockchainBalanceService>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return BlockchainBalanceService(
    projectId: ref.watch(appConfigProvider).projectId,
    client: client,
  );
});

/// Coordinates connection and chain reads for the ViewModel.
final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => WalletRepository(
    connectionService: ref.watch(walletConnectionServiceProvider),
    balanceService: ref.watch(blockchainBalanceServiceProvider),
  ),
);
