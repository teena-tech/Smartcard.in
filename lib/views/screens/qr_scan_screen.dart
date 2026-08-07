import 'package:flutter/material.dart';
import '../../features/scanner/screens/qr_scanner_screen.dart';

/// Legacy wrapper redirecting to modern QrScannerScreen feature.
class QrScanScreen extends StatelessWidget {
  const QrScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const QrScannerScreen();
  }
}
