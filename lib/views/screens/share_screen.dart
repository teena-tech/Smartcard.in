import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../widgets/common_drawer.dart';
import '../widgets/global_bottom_nav.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    
    return Scaffold(
      backgroundColor: colors.backgroundStart,
      drawer: const CommonDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: colors.text, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Share Card',
          style: GoogleFonts.inter(
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: ResponsiveCenter(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.share, size: 80, color: AppColors.primaryRed.withValues(alpha: 0.15)),
            const SizedBox(height: 24),
            Text(
              'Share Screen',
              style: GoogleFonts.inter(
                color: colors.text,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share your card with others',
              style: GoogleFonts.inter(
                color: colors.muted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
