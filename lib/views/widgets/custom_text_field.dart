import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Widget? labelWidget;
  final String? hint;
  final String? hintText;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final Widget? suffixIcon;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool obscureText;
  final bool isPassword;
  final bool readOnly;
  final bool? enabled;
  final VoidCallback? onTap;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.labelWidget,
    this.hint,
    this.hintText,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.suffixIcon,
    this.textCapitalization = TextCapitalization.none,
    this.focusNode,
    this.onEditingComplete,
    this.onChanged,
    this.autofocus = false,
    this.obscureText = false,
    this.isPassword = false,
    this.readOnly = false,
    this.enabled,
    this.onTap,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveHint = hintText ?? hint;
    final isObscure = obscureText || isPassword;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labelWidget ??
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
              ),
            ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          onChanged: onChanged,
          autofocus: autofocus,
          obscureText: isObscure,
          readOnly: readOnly,
          enabled: enabled,
          onTap: onTap,
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            counterText: maxLength != null ? '' : null,
            hintText: effectiveHint,
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    size: 20,
                    color: Theme.of(context).primaryColor.withAlpha(180),
                  )
                : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
