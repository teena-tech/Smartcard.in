import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:smartcard_flutter/core/utils/international_phone_helper.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/view/widgets/country_code_dropdown_dialog.dart';
import 'package:smartcard_flutter/features/register_screen/presentation/view/widgets/whatsapp_toggle_switch.dart';

/// Reusable International Phone Number & OTP Delivery Channel Component.
/// Used consistently across Login and Register screens.
/// Guarantees that:
/// - When Phone is selected: OTP is routed via SMS only (+91).
/// - When WhatsApp is selected: OTP is routed via WhatsApp only (international).
class InternationalPhoneInput extends StatefulWidget {
  final TextEditingController phoneController;
  final TextEditingController? whatsappController;
  final bool isWhatsAppMode;
  final ValueChanged<bool> onWhatsAppModeChanged;
  final String selectedCountryCode;
  final ValueChanged<CountryData> onCountryCodeChanged;
  final String? whatsappCountryCode;
  final ValueChanged<CountryData>? onWhatsappCountryCodeChanged;
  final bool allowSeparateWhatsApp;
  final bool enabled;
  final bool isWhatsAppToggleEnabled;
  final ValueChanged<String>? onChanged;
  final String? phoneLabel;
  final String? whatsappLabel;
  final bool showModeSelector;
  final bool showChannelStatusBanner;
  final bool disableCountryPicker;

  const InternationalPhoneInput({
    super.key,
    required this.phoneController,
    this.whatsappController,
    required this.isWhatsAppMode,
    required this.onWhatsAppModeChanged,
    required this.selectedCountryCode,
    required this.onCountryCodeChanged,
    this.whatsappCountryCode,
    this.onWhatsappCountryCodeChanged,
    this.allowSeparateWhatsApp = true,
    this.enabled = true,
    this.isWhatsAppToggleEnabled = true,
    this.onChanged,
    this.phoneLabel,
    this.whatsappLabel,
    this.showModeSelector = true,
    this.showChannelStatusBanner = true,
    this.disableCountryPicker = false,
  });

  @override
  State<InternationalPhoneInput> createState() =>
      _InternationalPhoneInputState();
}

class _InternationalPhoneInputState extends State<InternationalPhoneInput> {
  final GlobalKey _phoneCountryKey = GlobalKey();
  final GlobalKey _whatsappCountryKey = GlobalKey();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _whatsappFocusNode = FocusNode();

  bool _useDifferentWhatsAppNumber = false;

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(_onFocusChanged);
    _whatsappFocusNode.addListener(_onFocusChanged);
    if (widget.whatsappController != null &&
        widget.whatsappController!.text.trim().isNotEmpty &&
        widget.whatsappController!.text.trim() !=
            widget.phoneController.text.trim()) {
      _useDifferentWhatsAppNumber = true;
    }
  }

  @override
  void dispose() {
    _phoneFocusNode.removeListener(_onFocusChanged);
    _whatsappFocusNode.removeListener(_onFocusChanged);
    _phoneFocusNode.dispose();
    _whatsappFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InternationalPhoneInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Freeze to +91 whenever in SMS (Phone) mode
    if (!widget.isWhatsAppMode && widget.selectedCountryCode != '+91') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onCountryCodeChanged(InternationalPhoneHelper.findByCode('+91'));
        }
      });
    }
  }

  CountryData _getPhoneCountry() {
    if (widget.disableCountryPicker || !widget.isWhatsAppMode) {
      return InternationalPhoneHelper.findByCode('+91');
    }
    return InternationalPhoneHelper.findByCode(widget.selectedCountryCode);
  }

  CountryData _getWhatsappCountry() {
    final code = widget.whatsappCountryCode ?? widget.selectedCountryCode;
    return InternationalPhoneHelper.findByCode(code);
  }

  void _showSmsIndiaOnlyNotice({CountryData? pendingCountry}) {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.showModeSelector
                        ? 'Now this service is only available for Indian users (+91). Please change to WhatsApp mode to login.'
                        : 'Now this service is only available for Indian users (+91).',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.showModeSelector) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () {
                    messenger.hideCurrentSnackBar();
                    widget.onWhatsAppModeChanged(true);
                    if (pendingCountry != null) {
                      widget.onCountryCodeChanged(pendingCountry);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Change to WhatsApp',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF22C55E),
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFF22C55E),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: Color(0xFF22C55E),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedPhoneBox({
    required GlobalKey countryKey,
    required CountryData country,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isWhatsAppStyle,
    required bool showCountryDropdownArrow,
    required String hintText,
    required VoidCallback? onCountryTap,
  }) {
    final hasFocus = focusNode.hasFocus;
    final bgColor =
        isWhatsAppStyle ? const Color(0xFFEDF7EF) : Colors.white;
    final borderColor = isWhatsAppStyle
        ? (hasFocus ? const Color(0xFF15803D) : const Color(0xFF81C784))
        : (hasFocus ? const Color(0xFF9E1C24) : const Color(0xFFD6CEC8));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 52,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: hasFocus ? 1.5 : 1.2,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            key: countryKey,
            onTap: (widget.enabled && onCountryTap != null) ? onCountryTap : null,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(13),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 8, top: 8, bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(country.flag, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    country.code,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  if (showCountryDropdownArrow) ...[
                    const SizedBox(width: 1),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: Color(0xFF4B5563),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 22,
            color: Colors.black.withValues(alpha: 0.14),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.enabled,
              keyboardType: TextInputType.phone,
              maxLength: 15,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
              onChanged: (val) => widget.onChanged?.call(val),
              cursorColor: const Color(0xFF111827),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
                letterSpacing: 0.2,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9CA3AF),
                ),
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              ),
            ),
          ),
          IconButton(
            onPressed: widget.enabled
                ? () {
                    focusNode.requestFocus();
                    controller.selection = TextSelection.collapsed(
                      offset: controller.text.length,
                    );
                  }
                : null,
            icon: const Icon(
              Icons.edit_outlined,
              size: 16,
              color: Color(0xFF4B5563),
            ),
            padding: const EdgeInsets.only(right: 8, left: 2),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phoneCountry = _getPhoneCountry();
    final whatsappCountry = _getWhatsappCountry();
    final isWhatsApp = widget.isWhatsAppMode;

    const crimsonLabel = Color(0xFF9E1C24);
    const greenAccent = Color(0xFF25D366);
    const greenText = Color(0xFF2E7D32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header / Delivery Selector Row ───────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                isWhatsApp
                    ? (widget.whatsappLabel ?? 'WhatsApp Number')
                    : (widget.phoneLabel ?? 'Phone Number'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isWhatsApp ? greenText : const Color(0xFF1F2937),
                ),
              ),
            ),
            if (widget.showModeSelector) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SMS OTP',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: isWhatsApp ? FontWeight.w500 : FontWeight.w600,
                      color: isWhatsApp
                          ? const Color(0xFF6B7280)
                          : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 8),
                  WhatsAppToggleSwitch(
                    value: isWhatsApp,
                    enabled: widget.enabled && widget.isWhatsAppToggleEnabled,
                    onChanged: (widget.enabled && widget.isWhatsAppToggleEnabled)
                        ? (val) {
                            widget.onWhatsAppModeChanged(val);
                            if (!val && widget.selectedCountryCode != '+91') {
                              widget.onCountryCodeChanged(
                                  InternationalPhoneHelper.findByCode('+91'));
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // ── Unified Primary Phone Input Box ──────────────────
        _buildUnifiedPhoneBox(
          countryKey: _phoneCountryKey,
          country: phoneCountry,
          controller: widget.phoneController,
          focusNode: _phoneFocusNode,
          isWhatsAppStyle: isWhatsApp,
          showCountryDropdownArrow: !widget.disableCountryPicker,
          hintText: isWhatsApp
              ? 'Enter WhatsApp number'
              : 'Enter mobile number',
          onCountryTap: widget.disableCountryPicker
              ? null
              : () {
                  CountryCodeDropdownDialog.show(
                    context,
                    anchorKey: _phoneCountryKey,
                    selectedCode: isWhatsApp ? widget.selectedCountryCode : '+91',
                    isWhatsAppMode: isWhatsApp,
                    onSelectCountry: (item) {
                      final chosen = InternationalPhoneHelper.findByCode(item.code);
                      if (!isWhatsApp && item.code != '+91') {
                        _showSmsIndiaOnlyNotice(pendingCountry: chosen);
                        return;
                      }
                      widget.onCountryCodeChanged(chosen);
                    },
                  );
                },
        ),

        // ── WhatsApp Mode Separate Number Option (if enabled) ──
        if (isWhatsApp &&
            widget.allowSeparateWhatsApp &&
            widget.whatsappController != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _useDifferentWhatsAppNumber,
                  activeColor: greenAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  onChanged: widget.enabled
                      ? (val) {
                          setState(() {
                            _useDifferentWhatsAppNumber = val ?? false;
                            if (!_useDifferentWhatsAppNumber) {
                              widget.whatsappController?.text =
                                  widget.phoneController.text;
                            }
                          });
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: GestureDetector(
                  onTap: widget.enabled
                      ? () {
                          setState(() {
                            _useDifferentWhatsAppNumber =
                                !_useDifferentWhatsAppNumber;
                            if (!_useDifferentWhatsAppNumber) {
                              widget.whatsappController?.text =
                                  widget.phoneController.text;
                            }
                          });
                        }
                      : null,
                  child: Text(
                    'Use a different WhatsApp number for OTP',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_useDifferentWhatsAppNumber) ...[
            const SizedBox(height: 8),
            _buildUnifiedPhoneBox(
              countryKey: _whatsappCountryKey,
              country: whatsappCountry,
              controller: widget.whatsappController!,
              focusNode: _whatsappFocusNode,
              isWhatsAppStyle: true,
              showCountryDropdownArrow: true,
              hintText: 'Enter separate WhatsApp number',
              onCountryTap: () {
                CountryCodeDropdownDialog.show(
                  context,
                  anchorKey: _whatsappCountryKey,
                  selectedCode:
                      widget.whatsappCountryCode ?? widget.selectedCountryCode,
                  isWhatsAppMode: true,
                  onSelectCountry: (item) {
                    final cData =
                        InternationalPhoneHelper.findByCode(item.code);
                    if (widget.onWhatsappCountryCodeChanged != null) {
                      widget.onWhatsappCountryCodeChanged!(cData);
                    } else {
                      widget.onCountryCodeChanged(cData);
                    }
                  },
                );
              },
            ),
          ],
        ],

        // ── Channel Status Indicator Banner ───────────────────
        if (widget.showChannelStatusBanner) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1.5),
                child: isWhatsApp
                    ? const FaIcon(
                        FontAwesomeIcons.whatsapp,
                        color: greenAccent,
                        size: 15,
                      )
                    : const Icon(
                        Icons.info_outline_rounded,
                        color: crimsonLabel,
                        size: 15,
                      ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  isWhatsApp
                      ? 'WhatsApp OTP mode active. OTP will arrive via WhatsApp only.'
                      : 'SMS OTP mode active. OTP will arrive via SMS only.',
                  style: GoogleFonts.inter(
                    color: isWhatsApp
                        ? const Color(0xFF1F2937)
                        : crimsonLabel,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
