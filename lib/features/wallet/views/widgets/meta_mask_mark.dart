import 'package:flutter/material.dart';

class MetaMaskMark extends StatelessWidget {
  const MetaMaskMark({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'MetaMask',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE2761B),
          borderRadius: BorderRadius.circular(size * 0.22),
        ),
        child: Text(
          'M',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}
