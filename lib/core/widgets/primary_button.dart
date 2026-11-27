import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:smartcard_flutter/core/widgets/lottie_loader.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading && onPressed != null;

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: enabled
              ? const [
                  Color(0xFFEF4444),
                  Color(0xFFDC2626),
                  Color(0xFFB91C1C),
                ]
              : const [
                  Color(0xFFFCA5A5),
                  Color(0xFFF87171),
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.34),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(26),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: LottieLoader(size: 24),
                  )
                : Text(
                    text.toUpperCase(),
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
