import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';

class AlphabetScrollBar extends StatefulWidget {
  final List<String> availableAlphabets;
  final ValueChanged<String> onLetterSelected;
  final ValueChanged<bool>? onDragStateChanged;

  const AlphabetScrollBar({
    super.key,
    required this.availableAlphabets,
    required this.onLetterSelected,
    this.onDragStateChanged,
  });

  static const List<String> allLetters = [
    '↑', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  State<AlphabetScrollBar> createState() => _AlphabetScrollBarState();
}

class _AlphabetScrollBarState extends State<AlphabetScrollBar> {
  final GlobalKey _barKey = GlobalKey();
  String? _currentTouchedLetter;

  void _handleTouch(Offset localPosition, double totalHeight) {
    if (totalHeight <= 0) return;

    final double itemHeight = totalHeight / AlphabetScrollBar.allLetters.length;
    final int index = (localPosition.dy / itemHeight).floor().clamp(
      0,
      AlphabetScrollBar.allLetters.length - 1,
    );

    final letter = AlphabetScrollBar.allLetters[index];
    if (letter != _currentTouchedLetter) {
      setState(() => _currentTouchedLetter = letter);
      HapticFeedback.selectionClick();
      widget.onLetterSelected(letter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragDown: (details) {
            widget.onDragStateChanged?.call(true);
            _handleTouch(details.localPosition, constraints.maxHeight);
          },
          onVerticalDragUpdate: (details) {
            _handleTouch(details.localPosition, constraints.maxHeight);
          },
          onVerticalDragEnd: (_) {
            widget.onDragStateChanged?.call(false);
            setState(() => _currentTouchedLetter = null);
          },
          onVerticalDragCancel: () {
            widget.onDragStateChanged?.call(false);
            setState(() => _currentTouchedLetter = null);
          },
          onTapDown: (details) {
            widget.onDragStateChanged?.call(true);
            _handleTouch(details.localPosition, constraints.maxHeight);
          },
          onTapUp: (_) {
            widget.onDragStateChanged?.call(false);
            setState(() => _currentTouchedLetter = null);
          },
          child: Container(
            key: _barKey,
            width: 22,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              mainAxisSize: MainAxisSize.max,
              children: AlphabetScrollBar.allLetters.map((letter) {
                final isAvailable = letter == '↑' || widget.availableAlphabets.contains(letter);
                final isSelected = letter == _currentTouchedLetter;

                return Flexible(
                  child: Center(
                    child: Container(
                      width: isSelected ? 16 : 14,
                      height: isSelected ? 16 : 14,
                      decoration: isSelected
                          ? const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      alignment: Alignment.center,
                      child: Text(
                        letter,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : (isAvailable ? FontWeight.w700 : FontWeight.w400),
                          color: isSelected
                              ? Colors.white
                              : (isAvailable
                                  ? AppColors.primary
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : Colors.black.withValues(alpha: 0.25))),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
