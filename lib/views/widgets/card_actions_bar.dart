import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/theme_viewmodel.dart';
import 'package:provider/provider.dart';

class CardActionsBar extends StatelessWidget {
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const CardActionsBar({
    super.key,
    required this.onView,
    required this.onEdit,
    required this.onShare,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(Icons.visibility_outlined, 'View', colors, onView),
          _buildActionButton(null, 'Edit', colors, onEdit, assetPath: 'assets/images/edit.png'),
          _buildActionButton(Icons.share_outlined, 'Share', colors, onShare),
          _buildActionButton(Icons.download_outlined, 'Download', colors, onDownload),
          _buildActionButton(Icons.delete_outline, 'Delete', AppColors.primaryRed, onDelete, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData? icon, String label, dynamic colorOrColors, VoidCallback onTap, {bool isDestructive = false, String? assetPath}) {
    final Color iconColor = colorOrColors is AppColors ? colorOrColors.text : colorOrColors;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDestructive ? AppColors.primaryRed.withValues(alpha: 0.15) : (colorOrColors is AppColors ? colorOrColors.panel : colorOrColors.withValues(alpha: 0.15)),
                shape: BoxShape.circle,
              ),
              child: assetPath != null
                  ? Image.asset(assetPath, width: 20, height: 20, color: isDestructive ? AppColors.primaryRed : iconColor)
                  : Icon(icon, size: 20, color: isDestructive ? AppColors.primaryRed : iconColor),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDestructive ? AppColors.primaryRed : (colorOrColors is AppColors ? colorOrColors.muted : iconColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
