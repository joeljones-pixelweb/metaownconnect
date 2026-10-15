import 'package:flutter/foundation.dart';

/// Typed representation of the account returned by the connected wallet.
///
/// Only ever contains public, on-chain information. This class must never hold
/// a seed phrase, a private key or any other wallet secret.
@immutable
class ConnectedWallet {
  ConnectedWallet({
    required this.address,
    required this.chainId,
    this.walletName,
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? DateTime.now();

  /// The EVM public address exactly as the wallet returned it.
  final String address;

  /// CAIP-2 chain id of the active session, e.g. `eip155:11155111`.
  final String chainId;

  /// Display name reported by the wallet when available.
  final String? walletName;

  /// When this session became active in the application.
  final DateTime connectedAt;

  static final RegExp _evmAddressPattern = RegExp(r'^0x[0-9a-fA-F]{40}$');

  /// Basic sanity check for an EVM account address.
  static bool isValidEvmAddress(String? value) =>
      value != null && _evmAddressPattern.hasMatch(value.trim());

  /// Chain id without the CAIP-2 namespace, e.g. `11155111`.
  String get referenceChainId => chainId.contains(':')
      ? chainId.split(':').last
      : chainId;

  /// Chain id parsed as a number, or `null` when unparsable.
  int? get numericChainId => int.tryParse(referenceChainId);

  /// `0x71C7...976F` style abbreviation used for display only.
  String get shortAddress {
    final value = address;
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}...${value.substring(value.length - 4)}';
  }

  ConnectedWallet copyWith({
    String? address,
    String? chainId,
    String? walletName,
  }) => ConnectedWallet(
    address: address ?? this.address,
    chainId: chainId ?? this.chainId,
    walletName: walletName ?? this.walletName,
    connectedAt: connectedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is ConnectedWallet &&
      other.address.toLowerCase() == address.toLowerCase() &&
      other.chainId == chainId;

  @override
  int get hashCode => Object.hash(address.toLowerCase(), chainId);

  @override
  String toString() => 'ConnectedWallet(address: $shortAddress, chainId: $chainId)';
}
