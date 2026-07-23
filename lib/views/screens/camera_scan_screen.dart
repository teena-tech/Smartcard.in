import 'package:flutter/material.dart';
import 'smart_scanner_screen.dart';

/// Legacy entry point — redirects to unified [SmartScannerScreen].
@Deprecated('Use SmartScannerScreen instead')
class CameraScanScreen extends StatelessWidget {
  const CameraScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SmartScannerScreen();
  }
}
