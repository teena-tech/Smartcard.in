import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class RichTextEditor extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final int maxLines;
  final int minLines;
  final bool isError;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final int? maxLength;
  final TextInputType keyboardType;
  final dynamic colors;

  const RichTextEditor({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.maxLines = 5,
    this.minLines = 3,
    this.isError = false,
    this.errorText,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.maxLength,
    this.keyboardType = TextInputType.multiline,
    this.colors,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late TextEditingController _controller;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final borderColor = widget.isError
        ? Colors.red.withValues(alpha: 0.15)
        : _isFocused
            ? AppColors.primaryRed
            : colors?.border ?? Colors.grey.withValues(alpha: 0.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors?.text ?? Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borderColor,
              width: _isFocused ? 2 : 1.5,
            ),
            color: widget.readOnly
                ? colors?.muted?.withValues(alpha: 0.15) ?? Colors.grey.withValues(alpha: 0.15)
                : colors?.card ?? Colors.white,
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Focus(
            onFocusChange: (isFocused) {
              setState(() => _isFocused = isFocused);
            },
            child: TextField(
              controller: _controller,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              maxLength: widget.maxLength,
              keyboardType: widget.keyboardType,
              readOnly: widget.readOnly,
              onChanged: widget.onChanged,
              onTap: widget.onTap,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: colors?.text ?? Colors.black,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: colors?.muted?.withValues(alpha: 0.15) ?? Colors.grey,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterText: '',
                isDense: true,
              ),
              cursorColor: AppColors.primaryRed,
            ),
          ),
        ),
        if (widget.isError && widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.red.shade600,
            ),
          ),
        ],
      ],
    );
  }
}

class RichTextEditorWithFormatting extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final bool isError;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final dynamic colors;

  const RichTextEditorWithFormatting({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.isError = false,
    this.errorText,
    this.onChanged,
    this.colors,
  });

  @override
  State<RichTextEditorWithFormatting> createState() =>
      _RichTextEditorWithFormattingState();
}

class _RichTextEditorWithFormattingState
    extends State<RichTextEditorWithFormatting> {
  late TextEditingController _controller;
  final bool _isFocused = false;
  bool _isBold = false;
  bool _isItalic = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _toggleBold() {
    setState(() => _isBold = !_isBold);
  }

  void _toggleItalic() {
    setState(() => _isItalic = !_isItalic);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final borderColor = widget.isError
        ? Colors.red.withValues(alpha: 0.15)
        : _isFocused
            ? AppColors.primaryRed
            : colors?.border ?? Colors.grey.withValues(alpha: 0.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors?.text ?? Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        // Formatting toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: colors?.panel?.withValues(alpha: 0.15) ?? Colors.grey.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              _buildFormatButton(
                icon: Icons.format_bold,
                isActive: _isBold,
                onPressed: _toggleBold,
                colors: colors,
              ),
              const SizedBox(width: 8),
              _buildFormatButton(
                icon: Icons.format_italic,
                isActive: _isItalic,
                onPressed: _toggleItalic,
                colors: colors,
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 24,
                color: colors?.border ?? Colors.grey.withValues(alpha: 0.15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_controller.text.length} characters',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colors?.muted ?? Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            border: Border.all(
              color: borderColor,
              width: _isFocused ? 2 : 1.5,
            ),
            color: colors?.card ?? Colors.white,
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: _controller,
            maxLines: 5,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            onChanged: (value) {
              setState(() {});
              widget.onChanged?.call(value);
            },
            style: GoogleFonts.inter(
              fontSize: 14,
              color: colors?.text ?? Colors.black,
              height: 1.6,
              fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: colors?.muted?.withValues(alpha: 0.15) ?? Colors.grey,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              isDense: true,
            ),
            cursorColor: AppColors.primaryRed,
          ),
        ),
        if (widget.isError && widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.red.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormatButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required dynamic colors,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryRed.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppColors.primaryRed : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? AppColors.primaryRed : colors?.muted ?? Colors.grey,
        ),
      ),
    );
  }
}
