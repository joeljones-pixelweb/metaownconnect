import 'package:flutter/material.dart';

import '../../models/wallet_failure.dart';

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(Icons.info_outline, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          IconButton(
            key: const Key('dismiss_notice'),
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.failure,
    required this.onRetry,
    required this.onDismiss,
  });

  final WalletFailure failure;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Icon(Icons.error_outline, color: Colors.red.shade700),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(failure.message)),
          if (failure.canRetry && onRetry != null)
            TextButton(
              key: const Key('retry_button'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          IconButton(
            key: const Key('dismiss_error'),
            tooltip: 'Dismiss',
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
