import 'package:smartcard_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

/// Reusable animated delete confirmation dialog.
/// Shows the delete lottie animation with confirm/cancel buttons.
/// Set [requireTextInput] to true (e.g. for Account Deletion) to require typing "yes" before confirming.
Future<bool?> showDeleteConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Delete',
  String cancelText = 'Cancel',
  bool requireTextInput = false,
  String confirmInputText = 'yes',
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _DeleteConfirmDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      requireTextInput: requireTextInput,
      confirmInputText: confirmInputText,
    ),
  );
}

class _DeleteConfirmDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool requireTextInput;
  final String confirmInputText;

  const _DeleteConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    this.requireTextInput = false,
    this.confirmInputText = 'yes',
  });

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  late final TextEditingController _controller;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _isValid = !widget.requireTextInput;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    if (!widget.requireTextInput) return;
    final normalized = text.trim().toLowerCase();
    final expected = widget.confirmInputText.trim().toLowerCase();
    final valid = normalized == expected;
    if (valid != _isValid) {
      setState(() {
        _isValid = valid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Delete Lottie Animation
            globalDeleteLottieComposition != null
                ? Lottie(
                    composition: globalDeleteLottieComposition,
                    width: 90,
                    height: 90,
                    repeat: false,
                    animate: true,
                    fit: BoxFit.contain,
                  )
                : Lottie.asset(
                    'assets/lottie/Animation - 1733557597592.json',
                    width: 90,
                    height: 90,
                    repeat: false,
                    animate: true,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Delete Lottie error: $error');
                      return const SizedBox(
                        width: 90,
                        height: 90,
                        child: Center(
                            child: Icon(Icons.delete_outline,
                                color: Colors.red, size: 45)),
                      );
                    },
                  ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E233A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.requireTextInput) ...[
              const SizedBox(height: 16),
              Text(
                'Type "${widget.confirmInputText}" below to confirm deletion:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                onChanged: _onChanged,
                autofocus: true,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: const Color(0xFF1E233A),
                ),
                decoration: InputDecoration(
                  hintText: 'Type "${widget.confirmInputText}"',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0,
                    color: Colors.grey.shade400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE30613), width: 1.5),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      widget.cancelText,
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isValid ? const Color(0xFFE30613) : Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      elevation: _isValid ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isValid ? () => Navigator.pop(context, true) : null,
                    child: Text(
                      widget.confirmText,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: _isValid ? Colors.white : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
