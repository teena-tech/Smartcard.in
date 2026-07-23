import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/theme_viewmodel.dart';
import 'contacts_screen.dart';
import 'smart_scanner_screen.dart';
import '../../core/utils/responsive.dart';

class ContactMenuScreen extends StatelessWidget {
  const ContactMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    
    // Simulate active theme properties from React
    final bool isDark = colors.text == const Color(0xFFF8FAFC); // Approximation
    final Color optionMutedTextColor = isDark 
        ? const Color(0xFFE2E8F0).withValues(alpha: 0.15) 
        : const Color(0xFF1E293B).withValues(alpha: 0.15);
    final Color optionIconBg = isDark 
        ? Colors.white.withValues(alpha: 0.2) 
        : Colors.white.withValues(alpha: 0.2);

    return Scaffold(
      backgroundColor: Colors.transparent, // Background from ThemeWrapper
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colors.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Contact',
          style: GoogleFonts.inter(
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMenuOption(
                  context: context,
                  title: 'QR Scan',
                  subtitle: 'Scan QR and save user details',
                  icon: Icons.qr_code_scanner,
                  colors: colors,
                  mutedColor: optionMutedTextColor,
                  iconBg: optionIconBg,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SmartScannerScreen()),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildMenuOption(
                  context: context,
                  title: 'Contacts',
                  subtitle: 'View scanned contacts and personal details',
                  icon: Icons.contacts_outlined,
                  colors: colors,
                  mutedColor: optionMutedTextColor,
                  iconBg: optionIconBg,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ContactsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ));
  }

  Widget _buildMenuOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required dynamic colors,
    required Color mutedColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: colors.text, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: colors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: colors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colors.text, size: 20),
          ],
        ),
      ),
    );
  }
}
