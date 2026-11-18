import 'package:flutter/material.dart';

/// Stub: Corporate/Personal mode toggle has been removed.
/// Kept as empty widgets so existing references don't break at compile-time.
class WorkspaceModeToggle extends StatelessWidget {
  final double width;
  final double height;
  final bool showIcons;

  const WorkspaceModeToggle({
    super.key,
    this.width = 160,
    this.height = 32,
    this.showIcons = true,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Stub: Corporate banner has been removed.
class CorporateWorkspaceBanner extends StatelessWidget {
  const CorporateWorkspaceBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
