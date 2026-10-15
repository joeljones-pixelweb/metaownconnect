import 'package:flutter/foundation.dart';

/// Immutable description of a supported EVM network.
///
/// The chain id uses the CAIP-2 format (`eip155:11155111`) so it can be
/// compared directly against the ids reported by the wallet session.
@immutable
class BlockchainNetwork {
  const BlockchainNetwork({
    required this.chainId,
    required this.name,
    required this.nativeSymbol,
    required this.nativeDecimals,
    required this.rpcUrl,
    required this.explorerUrl,
    this.fallbackRpcUrl,
    this.isTestnet = false,
  });

  /// CAIP-2 chain identifier, e.g. `eip155:11155111`.
  final String chainId;

  /// Human readable network name.
  final String name;

  /// Native token symbol, e.g. `ETH`.
  final String nativeSymbol;

  /// Native token decimals, e.g. `18`.
  final int nativeDecimals;

  /// Primary JSON-RPC endpoint. Must be an HTTPS url.
  final String rpcUrl;

  /// Optional secondary endpoint used when the primary one fails.
  final String? fallbackRpcUrl;

  /// Block explorer base url.
  final String explorerUrl;

  final bool isTestnet;

  /// The `eip155` style namespace part of [chainId].
  String get namespace => chainId.contains(':')
      ? chainId.split(':').first
      : 'eip155';

  /// The reference (non CAIP) part of [chainId], e.g. `11155111`.
  String get referenceChainId => chainId.contains(':')
      ? chainId.split(':').last
      : chainId;

  /// The chain id as a number, or `null` when it cannot be parsed.
  int? get numericChainId => int.tryParse(referenceChainId);

  /// Whether the RPC endpoint uses HTTPS as required for chain reads.
  bool get hasSecureRpcUrl {
    final primary = Uri.tryParse(rpcUrl);
    if (primary == null || primary.scheme != 'https') return false;
    final fallback = fallbackRpcUrl == null ? null : Uri.tryParse(fallbackRpcUrl!);
    return fallback == null || fallback.scheme == 'https';
  }

  @override
  bool operator ==(Object other) =>
      other is BlockchainNetwork && other.chainId == chainId;

  @override
  int get hashCode => chainId.hashCode;

  @override
  String toString() =>
      'BlockchainNetwork(chainId: $chainId, name: $name, symbol: $nativeSymbol)';
}

/// Registry of the networks this application knows how to talk to.
///
/// An unknown chain id always resolves to `null` - it is never silently
/// treated as Ethereum Mainnet.
abstract final class BlockchainNetworkRegistry {
  static const String namespace = 'eip155';

  static const BlockchainNetwork ethereumSepolia = BlockchainNetwork(
    chainId: 'eip155:11155111',
    name: 'Ethereum Sepolia',
    nativeSymbol: 'ETH',
    nativeDecimals: 18,
    rpcUrl: 'https://rpc.walletconnect.org/v1',
    fallbackRpcUrl: 'https://ethereum-sepolia-rpc.publicnode.com',
    explorerUrl: 'https://sepolia.etherscan.io',
    isTestnet: true,
  );

  static const BlockchainNetwork ethereumMainnet = BlockchainNetwork(
    chainId: 'eip155:1',
    name: 'Ethereum',
    nativeSymbol: 'ETH',
    nativeDecimals: 18,
    rpcUrl: 'https://rpc.walletconnect.org/v1',
    fallbackRpcUrl: 'https://ethereum-rpc.publicnode.com',
    explorerUrl: 'https://etherscan.io',
  );

  static const BlockchainNetwork polygon = BlockchainNetwork(
    chainId: 'eip155:137',
    name: 'Polygon',
    nativeSymbol: 'POL',
    nativeDecimals: 18,
    rpcUrl: 'https://rpc.walletconnect.org/v1',
    fallbackRpcUrl: 'https://polygon-bor-rpc.publicnode.com',
    explorerUrl: 'https://polygonscan.com',
  );

  static const BlockchainNetwork base = BlockchainNetwork(
    chainId: 'eip155:8453',
    name: 'Base',
    nativeSymbol: 'ETH',
    nativeDecimals: 18,
    rpcUrl: 'https://rpc.walletconnect.org/v1',
    fallbackRpcUrl: 'https://base-rpc.publicnode.com',
    explorerUrl: 'https://basescan.org',
  );

  static const BlockchainNetwork arbitrumOne = BlockchainNetwork(
    chainId: 'eip155:42161',
    name: 'Arbitrum One',
    nativeSymbol: 'ETH',
    nativeDecimals: 18,
    rpcUrl: 'https://rpc.walletconnect.org/v1',
    fallbackRpcUrl: 'https://arbitrum-one-rpc.publicnode.com',
    explorerUrl: 'https://arbiscan.io',
  );

  /// Development default.
  static const BlockchainNetwork defaultNetwork = ethereumSepolia;

  static const List<BlockchainNetwork> all = <BlockchainNetwork>[
    ethereumSepolia,
    ethereumMainnet,
    polygon,
    base,
    arbitrumOne,
  ];

  /// Resolves a chain id to a supported network.
  ///
  /// Returns `null` when the chain is unknown so callers can surface an
  /// "unsupported network" state instead of guessing.
  static BlockchainNetwork? byChainId(String? chainId) {
    if (chainId == null || chainId.trim().isEmpty) return null;
    final normalized = _normalize(chainId.trim());
    for (final network in all) {
      if (network.chainId == normalized) return network;
    }
    return null;
  }

  static BlockchainNetwork? byNumericChainId(int? numericChainId) {
    if (numericChainId == null) return null;
    return byChainId('$namespace:$numericChainId');
  }

  static String _normalize(String chainId) =>
      chainId.contains(':') ? chainId : '$namespace:$chainId';
}
