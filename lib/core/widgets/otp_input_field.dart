import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OTPInputField extends StatefulWidget {
  const OTPInputField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.fieldWidth = 40,
    this.fieldHeight = 48,
    this.accentColor = const Color(0xFFA81C24),
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final double fieldWidth;
  final double fieldHeight;
  final Color accentColor;

  @override
  State<OTPInputField> createState() => _OTPInputFieldState();
}

class _OTPInputFieldState extends State<OTPInputField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _isSyncing = false;

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) {
      final node = FocusNode();
      node.addListener(_onFocusChanged);
      return node;
    });
    _syncFromController();
    widget.controller.addListener(_syncFromController);
  }

  @override
  void didUpdateWidget(covariant OTPInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromController);
      widget.controller.addListener(_syncFromController);
      _syncFromController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.removeListener(_onFocusChanged);
      focusNode.dispose();
    }
    super.dispose();
  }

  void _syncFromController() {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final value = widget.controller.text;
      for (var i = 0; i < widget.length; i++) {
        final char = i < value.length ? value[i] : '';
        if (_controllers[i].text != char) {
          _controllers[i].text = char;
        }
      }
      if (value.length == widget.length) {
        widget.onChanged?.call(value);
        widget.onCompleted?.call(value);
      }
    } finally {
      _isSyncing = false;
    }
  }

  void _updateCode() {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final code = _controllers.map((controller) => controller.text).join();
      if (widget.controller.text != code) {
        widget.controller.text = code;
      }
      widget.onChanged?.call(code);
      if (code.length == widget.length) {
        widget.onCompleted?.call(code);
      }
    } finally {
      _isSyncing = false;
    }
  }

  void _handleChanged(String value, int index) {
    if (value.isEmpty) {
      if (index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
      }
      _updateCode();
      return;
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      // Multi-character autofill / paste distribution
      for (var i = 0; i < digits.length && (index + i) < widget.length; i++) {
        _controllers[index + i].text = digits[i];
      }
      final targetIndex = (index + digits.length).clamp(0, widget.length - 1);
      _focusNodes[targetIndex].requestFocus();
      _updateCode();
      return;
    }

    final sanitized = digits.isNotEmpty ? digits.substring(0, 1) : '';
    if (sanitized.isEmpty) {
      _updateCode();
      return;
    }

    if (_controllers[index].text != sanitized) {
      _controllers[index].text = sanitized;
    }

    if (index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    _updateCode();
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : widget.length * (widget.fieldWidth + 6);
          final boxWidth =
              ((maxW - (widget.length - 1) * 6) / widget.length).clamp(28.0, widget.fieldWidth);

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.length, (index) {
              return SizedBox(
                width: boxWidth,
                height: widget.fieldHeight,
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                  if (_controllers[index].text.isEmpty && index > 0) {
                    _controllers[index - 1].clear();
                    _focusNodes[index - 1].requestFocus();
                    _updateCode();
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                autofocus: index == 0, // Automatically focus the first OTP digit field
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                cursorColor: const Color(0xFF111827),
                maxLength: widget.length, // Allow any box to receive full pasted/autofilled code
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  hintText: (!_focusNodes[index].hasFocus && _controllers[index].text.isEmpty)
                      ? '•'
                      : null,
                  hintStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFCBD5E1),
                    height: 1.0,
                  ),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide(color: widget.accentColor, width: 1.8),
                  ),
                ),
                onChanged: (value) => _handleChanged(value, index),
              ),
            ),
          );
        }),
          );
        },
      ),
    );
  }
}
