import 'package:flutter/foundation.dart';

/// Typed, user facing wallet errors.
///
/// Raw SDK / RPC exceptions are never surfaced to the UI - they are mapped to
/// one of these cases which carries a human readable [message].
@immutable
sealed class WalletFailure {
  const WalletFailure(this.message, {this.canRetry = true});

  /// Safe to show to the user.
  final String message;

  /// Whether the UI should offer a retry action.
  final bool canRetry;

  @override
  String toString() => '$runtimeType: $message';
}

/// The SDK was never configured correctly (for example a missing project id).
final class ConfigurationFailure extends WalletFailure {
  const ConfigurationFailure()
    : super(
        'Wallet connectivity is not configured. Add a Reown project id and rebuild the app.',
        canRetry: false,
      );
}

/// The wallet SDK could not be initialised.
final class SdkInitializationFailure extends WalletFailure {
  const SdkInitializationFailure()
    : super('Could not start the wallet connection service. Please try again.');
}

/// The requested wallet application cannot be found or opened on this device.
final class WalletUnavailableFailure extends WalletFailure {
  const WalletUnavailableFailure()
    : super('MetaMask is not installed on this device, or it could not be opened.');
}

/// The user backed out of the approval screen. This is not an error state.
final class UserCancelledFailure extends WalletFailure {
  const UserCancelledFailure()
    : super('Connection cancelled. No wallet was connected.');
}

/// The wallet explicitly rejected the connection request.
final class ConnectionRejectedFailure extends WalletFailure {
  const ConnectionRejectedFailure()
    : super('The connection request was rejected in your wallet.');
}

/// The wallet returned something that is not a valid EVM account.
final class InvalidAccountFailure extends WalletFailure {
  const InvalidAccountFailure()
    : super('The wallet returned an invalid account address.');
}

/// The active chain is not part of [BlockchainNetworkRegistry].
final class UnsupportedNetworkFailure extends WalletFailure {
  const UnsupportedNetworkFailure()
    : super(
        'This network is not supported yet. Switch to a supported network in your wallet.',
        canRetry: false,
      );
}

/// The JSON-RPC request failed or timed out.
final class RpcFailure extends WalletFailure {
  const RpcFailure()
    : super('Could not reach the network to read your balance. Check your connection and try again.');
}

/// The node replied with something that could not be parsed as an integer.
final class BalanceParsingFailure extends WalletFailure {
  const BalanceParsingFailure()
    : super('The balance returned by the network could not be read.');
}

/// No response from the wallet within the expected time window.
final class ConnectionTimeoutFailure extends WalletFailure {
  const ConnectionTimeoutFailure()
    : super('The wallet did not respond in time. Please try again.');
}

/// The session expired or was revoked by the wallet.
final class SessionExpiredFailure extends WalletFailure {
  const SessionExpiredFailure()
    : super('Your wallet session expired. Please connect again.');
}

/// The device appears to be offline.
final class NetworkUnavailableFailure extends WalletFailure {
  const NetworkUnavailableFailure()
    : super('You appear to be offline. Check your connection and try again.');
}

/// Anything the SDK reported that has no dedicated mapping.
final class UnknownWalletFailure extends WalletFailure {
  const UnknownWalletFailure()
    : super('Something went wrong while connecting. Please try again.');
}
