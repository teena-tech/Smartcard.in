import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../../viewmodels/theme_viewmodel.dart';


class BgSwitchPill extends StatelessWidget {
  final String label;
  final bool value;
  final VoidCallback onTap;

  const BgSwitchPill({super.key, 
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.watch<ThemeViewModel>().colors.text,
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
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
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

class BgColorField extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double size;
  final bool isDisabled;

  const BgColorField({super.key, 
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

class BgNavigatorTile extends StatelessWidget {
  final String label;
  final String imageUrl;
  final VoidCallback onTap;

  const BgNavigatorTile({super.key, 
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