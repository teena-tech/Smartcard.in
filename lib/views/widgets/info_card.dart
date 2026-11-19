import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_riverpod_providers.dart';

class InfoCard extends ConsumerWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onEdit;
  final List<RowData> rows;

  const InfoCard({
    super.key,
    required this.title,
    required this.icon,
    this.onEdit,
    required this.rows,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeViewModelProvider).colors;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.isDark ? Colors.black38 : Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.isDark
                          ? const Color(0xFFE53935).withValues(alpha: 0.2)
                          : const Color(0xFFFCF0F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/edit.png',
                          width: 12,
                          height: 12,
                          color: AppColors.primaryRed,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: GoogleFonts.inter(
                            color: AppColors.primaryRed,
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
          const SizedBox(height: 16),
          ...rows.asMap().entries.map((entry) {
            final idx = entry.key;
            final row = entry.value;
            return InkWell(
              onTap: row.onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: idx == rows.length - 1
                          ? Colors.transparent
                          : (colors.isDark ? Colors.white12 : const Color(0xFFEEEEEE)),
                      width: 1,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.isDark
                            ? const Color(0xFFE53935).withValues(alpha: 0.15)
                            : const Color(0xFFFCF0F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(row.icon, color: const Color(0xFFD32F2F), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: colors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            row.value,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              color: colors.text,
                              height: 1.5,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (row.trailing != null)
                      row.trailing!
                    else
                      const Icon(Icons.chevron_right, color: Color(0xFFE53935), size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class RowData {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  const RowData(this.icon, this.label, this.value, {this.onTap, this.trailing});
}
