import 'package:flutter/foundation.dart';

import '../models/connected_wallet.dart';
import '../models/wallet_failure.dart';

/// Events published by the wallet connection service.
///
/// The service never exposes SDK types to the rest of the application so the
/// ViewModel can be unit tested with fakes.
@immutable
sealed class WalletServiceEvent {
  const WalletServiceEvent();
}

/// A session was established (or an existing one became active).
final class WalletSessionConnected extends WalletServiceEvent {
  const WalletSessionConnected(this.wallet);

  final ConnectedWallet wallet;
}

/// The active account and/or chain changed inside the wallet.
final class WalletSessionUpdated extends WalletServiceEvent {
  const WalletSessionUpdated(this.wallet);

  final ConnectedWallet wallet;
}

/// The wallet (or the SDK) closed the session.
final class WalletSessionDisconnected extends WalletServiceEvent {
  const WalletSessionDisconnected();
}

/// The session reached its expiry date.
final class WalletSessionExpired extends WalletServiceEvent {
  const WalletSessionExpired();
}

/// A connection attempt failed.
final class WalletConnectionFailed extends WalletServiceEvent {
  const WalletConnectionFailed(this.failure);

  final WalletFailure failure;
}
