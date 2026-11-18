import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

/// Interactive field comparison widget with swipe / tap toggle support
/// for resolving duplicate business card fields (Company, Email, Designation, Website, etc.).
class DuplicateFieldSwipeWidget extends StatefulWidget {
  final String label;
  final String existingValue;
  final String newValue;
  final bool useNew;
  final ValueChanged<bool> onSelectionChanged;

  const DuplicateFieldSwipeWidget({
    super.key,
    required this.label,
    required this.existingValue,
    required this.newValue,
    required this.useNew,
    required this.onSelectionChanged,
  });

  @override
  State<DuplicateFieldSwipeWidget> createState() => _DuplicateFieldSwipeWidgetState();
}

class _DuplicateFieldSwipeWidgetState extends State<DuplicateFieldSwipeWidget> {
  double _dragPosition = 0.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryRed = AppColors.primaryRed;

    final existingClean = widget.existingValue.trim();
    final newClean = widget.newValue.trim();
    final hasDifference = (existingClean.isNotEmpty || newClean.isNotEmpty) &&
        existingClean.toLowerCase() != newClean.toLowerCase();

    // If there's no difference at all, do not show comparison swipe
    if (!hasDifference) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.useNew
              ? const Color(0xFF16A34A).withValues(alpha: 0.5)
              : primaryRed.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (widget.useNew ? const Color(0xFF16A34A) : primaryRed).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Field Label & Status Badge
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.useNew
                          ? const Color(0xFF16A34A).withValues(alpha: 0.15)
                          : primaryRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.useNew ? 'NEW SCANNED' : 'EXISTING',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: widget.useNew ? const Color(0xFF16A34A) : primaryRed,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Two selectable option cards
          Row(
            children: [
              // Existing Detail Card
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (widget.useNew) {
                      HapticFeedback.selectionClick();
                      widget.onSelectionChanged(false);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: !widget.useNew
                          ? primaryRed.withValues(alpha: isDark ? 0.25 : 0.1)
                          : (isDark ? Colors.black26 : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !widget.useNew ? primaryRed : (isDark ? Colors.white12 : Colors.grey.shade300),
                        width: !widget.useNew ? 1.6 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Existing',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: !widget.useNew ? primaryRed : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          existingClean.isNotEmpty ? existingClean : '(Not set)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontStyle: existingClean.isEmpty ? FontStyle.italic : FontStyle.normal,
                            fontWeight: !widget.useNew ? FontWeight.w700 : FontWeight.w500,
                            color: existingClean.isEmpty ? (isDark ? Colors.white38 : Colors.grey) : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // New Scanned Detail Card
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (!widget.useNew) {
                      HapticFeedback.selectionClick();
                      widget.onSelectionChanged(true);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.useNew
                          ? const Color(0xFF16A34A).withValues(alpha: isDark ? 0.25 : 0.1)
                          : (isDark ? Colors.black26 : Colors.white),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.useNew ? const Color(0xFF16A34A) : (isDark ? Colors.white12 : Colors.grey.shade300),
                        width: widget.useNew ? 1.6 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Scanned',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: widget.useNew ? const Color(0xFF16A34A) : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          newClean.isNotEmpty ? newClean : '(Not set)',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontStyle: newClean.isEmpty ? FontStyle.italic : FontStyle.normal,
                            fontWeight: widget.useNew ? FontWeight.w700 : FontWeight.w500,
                            color: newClean.isEmpty ? (isDark ? Colors.white38 : Colors.grey) : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Interactive Swipe Track
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragPosition += details.primaryDelta ?? 0.0;
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragPosition > 30 && !widget.useNew) {
                HapticFeedback.mediumImpact();
                widget.onSelectionChanged(true);
              } else if (_dragPosition < -30 && widget.useNew) {
                HapticFeedback.mediumImpact();
                widget.onSelectionChanged(false);
              }
              setState(() {
                _dragPosition = 0.0;
              });
            },
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onSelectionChanged(!widget.useNew);
            },
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.black38 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                  width: 0.8,
                ),
              ),
              child: Stack(
                children: [
                  // Center Guidance Text
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 42.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.useNew ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                              size: 14,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.useNew ? 'Swipe left for Existing' : 'Swipe right to use New',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Animated Sliding Thumb Indicator
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    alignment: widget.useNew ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 38,
                      height: 26,
                      decoration: BoxDecoration(
                        color: widget.useNew ? const Color(0xFF16A34A) : primaryRed,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.useNew ? const Color(0xFF16A34A) : primaryRed).withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.useNew ? Icons.check_rounded : Icons.history_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
