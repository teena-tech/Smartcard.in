import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/theme_viewmodel.dart';

class FeaturePlaceholderScreen extends StatelessWidget {
  final String title;
  const FeaturePlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: colors.menuBg,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: colors.muted),
            const SizedBox(height: 16),
            Text(
              '$title Feature',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is coming soon...',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
