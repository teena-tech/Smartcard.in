import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';

Widget buildSummaryCard({
    required String title,
    required bool hasContent,
    required VoidCallback onEdit,
    required AppColors colors,
    required Widget child,
    String? customButtonText,
    Color? customButtonBg,
    Color? customButtonTextCol,
    IconData? customButtonIcon,
  }) {
    return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.15), width: 0.5),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: colors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: customButtonBg ?? const Color(0xFFFCF0F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      (customButtonIcon == null || customButtonIcon == Icons.edit_outlined || customButtonIcon == Icons.edit)
                          ? Image.asset(
                              'assets/images/edit.png',
                              width: 12,
                              height: 12,
                              color: customButtonTextCol ?? AppColors.primaryRed,
                            )
                          : Icon(customButtonIcon, color: customButtonTextCol ?? AppColors.primaryRed, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        customButtonText ?? (hasContent ? 'Edit' : 'Add'),
                        style: GoogleFonts.inter(
                          color: customButtonTextCol ?? AppColors.primaryRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasContent)
            child
          else
            Text(
              'No $title added yet. Tap the button to add.',
              style: GoogleFonts.inter(
                color: colors.muted,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

Widget buildMetaRow(String label, String value, AppColors colors) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(fontSize: 13, color: colors.text),
          children: [
            TextSpan(
              text: '$label: ',
              style: GoogleFonts.inter(
                color: colors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

Widget buildFieldRow({
  IconData? icon,
  dynamic faIcon, // FontAwesome icon (use one or the other)
  required String label,
  required String value,
  Color iconColor = const Color(0xFF888888),
  Color iconBg = const Color(0xFFF2F2F2),
}) {
  if (value.trim().isEmpty) return const SizedBox.shrink();

  Widget iconWidget;
  if (faIcon != null) {
    iconWidget = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: FaIcon(faIcon, color: iconColor, size: 20),
      ),
    );
  } else {
    iconWidget = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Row(
      children: [
        iconWidget,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFAAAAAA), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: const Color(0xFF1A1A1A),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 18),
      ],
    ),
  );
}