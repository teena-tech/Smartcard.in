import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.isDark ? colors.border : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                style: AppFonts.poppins(
                  color: colors.isDark ? Colors.white : const Color(0xFF1E293B),
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
                          style: AppFonts.poppins(
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
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: row.iconBg ??
                            (colors.isDark
                                ? const Color(0xFFE53935).withValues(alpha: 0.15)
                                : const Color(0xFFFCF0F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: row.icon is IconData
                            ? Icon(row.icon as IconData, color: row.iconColor ?? const Color(0xFFD32F2F), size: 20)
                            : FaIcon(row.icon, color: row.iconColor ?? const Color(0xFFD32F2F), size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.label,
                            style: AppFonts.poppins(
                              fontSize: 10,
                              color: colors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            row.value,
                            style: AppFonts.poppins(
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
                      const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 18),
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
  final dynamic icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;
  final Color? iconBg;
  const RowData(this.icon, this.label, this.value, {this.onTap, this.trailing, this.iconColor, this.iconBg});
}
