import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';

import 'package:smartcard_flutter/core/constants/app_colors.dart';

IconData? _getSectionIcon(String t) {
  final lower = t.toLowerCase();
  if (lower.contains('personal')) return Icons.person_outline;
  if (lower.contains('company')) return Icons.business_outlined;
  if (lower.contains('contact')) return Icons.contact_phone_outlined;
  if (lower.contains('social')) return Icons.share_outlined;
  if (lower.contains('about')) return Icons.description_outlined;
  if (lower.contains('video')) return Icons.video_collection_outlined;
  if (lower.contains('gallery')) return Icons.photo_library_outlined;
  return null;
}

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
    bool isEditable = true,
    Widget? footerWidget,
  }) {
    final sectionIcon = _getSectionIcon(title);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditable
              ? const Color(0xFFE5E7EB)
              : const Color(0xFFBAE6FD),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
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
                style: AppFonts.poppins(
                  color: isEditable ? const Color(0xFF1E293B) : const Color(0xFF0369A1),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              if (isEditable)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: customButtonBg ?? const Color(0xFFFCF0F0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: (customButtonTextCol ?? AppColors.primaryRed).withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          (customButtonIcon == null ||
                                  customButtonIcon == Icons.edit_outlined ||
                                  customButtonIcon == Icons.edit)
                              ? Image.asset(
                                  'assets/images/edit.png',
                                  width: 12,
                                  height: 12,
                                  color: customButtonTextCol ?? AppColors.primaryRed,
                                )
                              : Icon(
                                  customButtonIcon,
                                  color: customButtonTextCol ?? AppColors.primaryRed,
                                  size: 13,
                                ),
                          const SizedBox(width: 4),
                          Text(
                            customButtonText ?? (hasContent ? 'Edit' : 'Add'),
                            style: AppFonts.poppins(
                              color: customButtonTextCol ?? AppColors.primaryRed,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBAE6FD), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, size: 11, color: Color(0xFF0284C7)),
                      const SizedBox(width: 4),
                      Text(
                        'Locked',
                        style: AppFonts.poppins(
                          color: const Color(0xFF0369A1),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasContent)
            child
          else
            Text(
              isEditable
                  ? 'No $title added yet. Tap the button to add.'
                  : 'No $title specified by organization.',
              style: AppFonts.poppins(
                color: colors.muted,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          if (footerWidget != null) ...[
            const SizedBox(height: 8),
            footerWidget,
          ],
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
          style: AppFonts.poppins(fontSize: 13, color: colors.text),
          children: [
            TextSpan(
              text: '$label: ',
              style: AppFonts.poppins(
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
                style: AppFonts.poppins(fontSize: 10, color: const Color(0xFFAAAAAA), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppFonts.poppins(
                  fontSize: 13.5,
                  color: const Color(0xFF1A1A1A),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 18),
      ],
    ),
  );
}