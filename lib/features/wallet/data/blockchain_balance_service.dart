import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/blockchain_network.dart';
import '../models/connected_wallet.dart';
import '../models/native_balance.dart';
import '../models/wallet_failure.dart';

/// Read-only access to on-chain data.
abstract interface class IBlockchainBalanceService {
  /// Reads the native token [balance] of [address] on [network].
  ///
  /// Throws a [WalletFailure] on any error so callers never have to parse
  /// raw exceptions.
  Future<NativeBalance> fetchNativeBalance({
    required String address,
    required BlockchainNetwork network,
  });
}

/// JSON-RPC based implementation of [IBlockchainBalanceService].
///
/// Only performs `eth_getBalance` reads - no transaction or signature is ever
/// requested from this class.
class BlockchainBalanceService implements IBlockchainBalanceService {
  BlockchainBalanceService({
    required String projectId,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _projectId = projectId,
       _client = client ?? http.Client();

  final http.Client _client;
  final String _projectId;
  final Duration requestTimeout;

  /// Hosts that require the public Reown project id as a query parameter.
  static const String _walletConnectHost = 'rpc.walletconnect.org';

  @override
  Future<NativeBalance> fetchNativeBalance({
    required String address,
    required BlockchainNetwork network,
  }) async {
    if (!ConnectedWallet.isValidEvmAddress(address)) {
      throw const InvalidAccountFailure();
    }
    if (!network.hasSecureRpcUrl) {
      throw const RpcFailure();
    }

    final endpoints = _endpointsFor(network);
    if (endpoints.isEmpty) throw const RpcFailure();

    Object? lastFailure;
    for (final endpoint in endpoints) {
      try {
        final wei = await _requestBalance(
          endpoint: endpoint,
          address: address,
          network: network,
        );
        return NativeBalance(wei: wei, fetchedAt: DateTime.now());
      } on WalletFailure catch (failure) {
        // A parsing error means the endpoint answered, so do not retry.
        if (failure is BalanceParsingFailure) rethrow;
        lastFailure = failure;
      } on TimeoutException {
        lastFailure = const RpcFailure();
      } on http.ClientException {
        lastFailure = const NetworkUnavailableFailure();
      } on FormatException {
        lastFailure = const BalanceParsingFailure();
      } catch (error) {
        lastFailure = error is WalletFailure ? error : const RpcFailure();
      }
    }
    if (lastFailure is WalletFailure) throw lastFailure;
    throw const RpcFailure();
  }

  List<Uri> _endpointsFor(BlockchainNetwork network) {
    final uris = <Uri>[];
    final primary = Uri.tryParse(network.rpcUrl);
    if (primary != null && _isUsable(primary)) uris.add(primary);
    final fallback = network.fallbackRpcUrl == null
        ? null
        : Uri.tryParse(network.fallbackRpcUrl!);
    if (fallback != null && _isUsable(fallback)) uris.add(fallback);
    return uris;
  }

  bool _isUsable(Uri uri) {
    if (uri.scheme != 'https') return false;
    if (uri.host == _walletConnectHost && _projectId.isEmpty) return false;
    return true;
  }

  Uri _withParameters(Uri endpoint, BlockchainNetwork network) {
    if (endpoint.host != _walletConnectHost) return endpoint;
    final numeric = network.numericChainId;
    return endpoint.replace(
      queryParameters: <String, String>{
        ...endpoint.queryParameters,
        if (numeric != null) 'chainId': '$numeric',
        'projectId': _projectId,
      },
    );
  }

  Future<BigInt> _requestBalance({
    required Uri endpoint,
    required String address,
    required BlockchainNetwork network,
  }) async {
    final uri = _withParameters(endpoint, network);
    final response = await _client
        .post(
          uri,
          headers: const <String, String>{
            'content-type': 'application/json',
            'accept': 'application/json',
          },
          body: jsonEncode(<String, Object>{
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'eth_getBalance',
            // `latest` keeps the value tied to the chain the wallet selected.
            'params': <String>[address.toLowerCase(), 'latest'],
          }),
        )
        .timeout(requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const RpcFailure();
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const BalanceParsingFailure();
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BalanceParsingFailure();
    }
    if (decoded['error'] != null) throw const RpcFailure();

    final result = decoded['result'];
    if (result is! String) throw const BalanceParsingFailure();

    try {
      return BalanceFormatter.parseWeiFromHex(result);
    } on FormatException {
      throw const BalanceParsingFailure();
    }
  }
}
