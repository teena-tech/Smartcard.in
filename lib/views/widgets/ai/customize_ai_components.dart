import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../viewmodels/theme_viewmodel.dart';


class AiSwitchPill extends StatelessWidget {
  final String label;
  final bool value;
  final VoidCallback onTap;

  const AiSwitchPill({super.key, 
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              color: value ? const Color(0xFF65A30D) : const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    value ? 'ON' : 'OFF',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AiColorField extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final bool isDisabled;

  const AiColorField({super.key, 
    required this.label,
    required this.color,
    required this.onTap,
    this.size = 46,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (label.isNotEmpty)
          Text(
            label,
            style: GoogleFonts.inter(
              color: colors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (label.isNotEmpty) const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDisabled ? const Color(0xFFEF4444) : colors.border,
                width: 1.4,
              ),
            ),
            child: isDisabled
                ? const Center(
                    child: Text(
                      'X',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class AiMiniActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AiMiniActionButton({super.key, 
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: colors.text),
        ),
      ),
    );
  }
}

class AiTargetButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool isActive;
  final VoidCallback onTap;

  const AiTargetButton({super.key, 
    required this.label,
    required this.color,
    required this.textColor,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? AppColors.primaryRed : colors.border, width: 1.8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class AiNavigatorTile extends StatelessWidget {
  final String label;
  final String imageUrl;
  final VoidCallback onTap;

  const AiNavigatorTile({super.key, 
    required this.label,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 54,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: colors.border.withValues(alpha: 0.15),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : Container(color: colors.border.withValues(alpha: 0.15)),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: colors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}