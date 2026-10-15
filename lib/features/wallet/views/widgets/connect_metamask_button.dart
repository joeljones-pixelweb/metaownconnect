import 'package:flutter/material.dart';

import 'meta_mask_mark.dart';

class ConnectMetaMaskButton extends StatelessWidget {
  const ConnectMetaMaskButton({
    super.key,
    required this.onPressed,
    required this.busy,
    required this.enabled,
  });

  final VoidCallback onPressed;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      key: const Key('connect_metamask_button'),
      onPressed: enabled && !busy ? onPressed : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const MetaMaskMark(size: 20),
          const SizedBox(width: 10),
          Text(busy ? 'Connecting…' : 'Connect MetaMask'),
        ],
      ),
    );
  }
}
