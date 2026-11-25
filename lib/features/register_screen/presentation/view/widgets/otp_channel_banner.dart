import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

/// High-professional single-line OTP channel pill displaying only the SMS/WhatsApp
/// icon, flag + hairline divider + phone number, and pencil "Change" action.
class OtpChannelBanner extends StatelessWidget {
  final bool isWhatsAppMode;
  final String phoneDisplay;
  final VoidCallback onChangePressed;

  const OtpChannelBanner({
    super.key,
    required this.isWhatsAppMode,
    required this.phoneDisplay,
    required this.onChangePressed,
  });

  ({String? flag, String number}) _splitFlagAndNumber(String raw) {
    final trimmed = raw.trim();
    final spaceIdx = trimmed.indexOf(' ');
    if (spaceIdx > 0) {
      final head = trimmed.substring(0, spaceIdx);
      final tail = trimmed.substring(spaceIdx + 1).trim();
      final hasDigitsOrPlus = RegExp(r'[0-9+]').hasMatch(head);
      if (!hasDigitsOrPlus && tail.isNotEmpty) {
        return (flag: head, number: tail);
      }
    }
    return (flag: null, number: trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor =
        isWhatsAppMode ? const Color(0xFF15803D) : const Color(0xFF9E1C24);
    final bgColor =
        isWhatsAppMode ? const Color(0xFFEDFBF3) : const Color(0xFFFCF0F0);
    final borderColor =
        isWhatsAppMode ? const Color(0xFFC5ECD6) : const Color(0xFFEBD2D2);
    final parsed = _splitFlagAndNumber(phoneDisplay);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        children: [
          isWhatsAppMode
              ? FaIcon(FontAwesomeIcons.whatsapp, color: accentColor, size: 19)
              : Icon(Icons.smartphone_rounded, color: accentColor, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (parsed.flag != null) ...[
                    Text(
                      parsed.flag!,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(fontSize: 16),
                    ),
                    Container(
                      width: 1,
                      height: 15,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: Colors.black.withValues(alpha: 0.14),
                    ),
                  ],
                  Text(
                    parsed.number,
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                      letterSpacing: 0.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onChangePressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 14, color: accentColor),
                  const SizedBox(width: 4),
                  Text(
                    'Change',
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
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

/// Shared feedback notice + subtitle placed below the 6-digit OTP boxes
/// in both Login and Register screens.
class OtpStatusNotice extends StatelessWidget {
  final String statusMessage;
  final String errorMessage;
  final bool isWhatsAppMode;

  const OtpStatusNotice({
    super.key,
    required this.statusMessage,
    required this.errorMessage,
    required this.isWhatsAppMode,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage.isNotEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red[600], size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              errorMessage,
              style: GoogleFonts.inter(
                color: Colors.red[600],
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    final helperText = isWhatsAppMode
        ? 'Enter the 6-digit OTP sent to your WhatsApp.'
        : 'Enter the 6-digit OTP sent to your mobile number.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (statusMessage.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: isWhatsAppMode
                    ? const Color(0xFF15803D)
                    : const Color(0xFF4B5563),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusMessage,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF374151),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Text(
          helperText,
          style: GoogleFonts.inter(
            color: const Color(0xFF6B7280),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Centered channel-switch row placed cleanly above VERIFY OTP so users can
/// switch immediately between SMS OTP and WhatsApp OTP on both Login & Register.
class OtpSwitchChannelLink extends StatelessWidget {
  final bool isWhatsAppMode;
  final bool isLoading;
  final VoidCallback onSwitchPressed;

  const OtpSwitchChannelLink({
    super.key,
    required this.isWhatsAppMode,
    required this.isLoading,
    required this.onSwitchPressed,
  });

  @override
  Widget build(BuildContext context) {
    final targetWhatsApp = !isWhatsAppMode;
    final badgeColor =
        targetWhatsApp ? const Color(0xFF25D366) : const Color(0xFF9E1C24);
    final label =
        targetWhatsApp ? 'Get OTP via WhatsApp' : 'Get OTP via SMS';

    return Center(
      child: Opacity(
        opacity: isLoading ? 0.55 : 1.0,
        child: InkWell(
          onTap: isLoading ? null : onSwitchPressed,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badgeColor,
                  ),
                  child: Center(
                    child: targetWhatsApp
                        ? const FaIcon(
                            FontAwesomeIcons.whatsapp,
                            color: Colors.white,
                            size: 13,
                          )
                        : const Icon(
                            Icons.sms_outlined,
                            color: Colors.white,
                            size: 13,
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
