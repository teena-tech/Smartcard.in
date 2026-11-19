import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EditorToolbar extends StatelessWidget {
  final VoidCallback? onThemeTap;
  final VoidCallback onBgImageTap;
  final VoidCallback onColorsTap;
  final VoidCallback onOverlayTap;
  final VoidCallback onLogoTap;
  final VoidCallback? onAiSuggestTap;
  final Color backgroundColor;
  final Color iconColor;
  final Color textColor;

  const EditorToolbar({
    super.key,
    this.onThemeTap,
    required this.onBgImageTap,
    required this.onColorsTap,
    required this.onOverlayTap,
    required this.onLogoTap,
    this.onAiSuggestTap,
    required this.backgroundColor,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: iconColor.withValues(alpha: 0.15))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (onThemeTap != null)
              _buildToolbarBtn(Icons.view_quilt_outlined, 'Themes', onThemeTap!),
            _buildToolbarBtn(Icons.image_outlined, 'Bg Image', onBgImageTap),
            _buildToolbarBtn(Icons.color_lens_outlined, 'Colors', onColorsTap),
            _buildToolbarBtn(Icons.layers_outlined, 'Overlay', onOverlayTap),
            _buildToolbarBtn(Icons.add_photo_alternate_outlined, 'Logo / Filter', onLogoTap),
            if (onAiSuggestTap != null)
              _buildToolbarBtn(Icons.auto_awesome_outlined, 'AI Suggest', onAiSuggestTap!),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
