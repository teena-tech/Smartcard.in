import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class IntentLauncher {
  /// Sanitize phone number for tel: or sms: URI
  static String sanitizePhoneNumber(String rawNumber) {
    return rawNumber.replaceAll(RegExp(r'[^\d+]'), '');
  }

  /// Format phone number specifically for WhatsApp wa.me links with robust country code handling
  static String sanitizeForWhatsApp(String rawNumber, {String defaultCountryCode = '91'}) {
    final trimmed = rawNumber.trim();
    if (trimmed.isEmpty) return '';

    final bool hadPlus = trimmed.startsWith('+');

    // Strip everything except digits
    String digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return '';

    // Handle 00 international prefix (e.g., 00919789199999 -> 919789199999)
    if (digitsOnly.startsWith('00')) {
      digitsOnly = digitsOnly.substring(2);
    }

    // Strip trunk zeros (e.g. 09789199999 -> 9789199999)
    if (digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.replaceFirst(RegExp(r'^0+'), '');
    }

    // If it started with +, it already includes the country code
    if (hadPlus) {
      return digitsOnly;
    }

    // Standard 10-digit mobile number (e.g. 9789199999 in India)
    if (digitsOnly.length == 10) {
      return '$defaultCountryCode$digitsOnly';
    }

    // If 12-digit number already prefixed with defaultCountryCode (e.g. 919789199999)
    if (digitsOnly.length == 12 && digitsOnly.startsWith(defaultCountryCode)) {
      return digitsOnly;
    }

    // If 11-digit US number (starts with 1)
    if (digitsOnly.length == 11 && digitsOnly.startsWith('1')) {
      return digitsOnly;
    }

    // If digits length > 10, assume country code already present
    if (digitsOnly.length > 10) {
      return digitsOnly;
    }

    // Fallback for shorter numbers
    return '$defaultCountryCode$digitsOnly';
  }

  /// Launch phone call dialer
  static Future<bool> makePhoneCall(BuildContext context, String phoneNumber) async {
    final clean = sanitizePhoneNumber(phoneNumber);
    if (clean.isEmpty) {
      _showToast(context, 'Invalid phone number');
      return false;
    }

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: clean,
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        return await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        return await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching dialer: $e');
      if (context.mounted) {
        _showToast(context, 'Could not open phone dialer');
      }
      return false;
    }
  }

  /// Launch SMS message application
  static Future<bool> sendSms(BuildContext context, String phoneNumber, {String? body}) async {
    final clean = sanitizePhoneNumber(phoneNumber);
    if (clean.isEmpty) {
      _showToast(context, 'Invalid phone number');
      return false;
    }

    final Uri launchUri = Uri(
      scheme: 'sms',
      path: clean,
      queryParameters: body != null && body.isNotEmpty ? {'body': body} : null,
    );

    try {
      return await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching SMS: $e');
      if (context.mounted) {
        _showToast(context, 'Could not open messaging app');
      }
      return false;
    }
  }

  /// Open WhatsApp Chat directly using wa.me deep link with country code fallback
  static Future<bool> openWhatsApp(
    BuildContext context,
    String phoneNumber, {
    String? message,
    String defaultCountryCode = '91',
  }) async {
    final clean = sanitizeForWhatsApp(phoneNumber, defaultCountryCode: defaultCountryCode);
    if (clean.isEmpty) {
      _showToast(context, 'Invalid phone number for WhatsApp');
      return false;
    }

    final urlString = message != null && message.isNotEmpty
        ? 'https://wa.me/$clean?text=${Uri.encodeComponent(message)}'
        : 'https://wa.me/$clean';

    final Uri launchUri = Uri.parse(urlString);

    try {
      final success = await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
      if (!success && context.mounted) {
        _showToast(context, 'Could not launch WhatsApp. Is WhatsApp installed?');
      }
      return success;
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
      if (context.mounted) {
        _showToast(context, 'WhatsApp could not be opened: $e');
      }
      return false;
    }
  }

  /// Send email via default email client
  static Future<bool> sendEmail(
    BuildContext context,
    String email, {
    String? subject,
    String? body,
  }) async {
    if (email.trim().isEmpty) {
      _showToast(context, 'Invalid email address');
      return false;
    }

    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email.trim(),
      queryParameters: {
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (body != null && body.isNotEmpty) 'body': body,
      },
    );

    try {
      return await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching Email: $e');
      if (context.mounted) {
        _showToast(context, 'Could not open email client');
      }
      return false;
    }
  }

  /// Open Website URL in default browser
  static Future<bool> openWebsite(BuildContext context, String rawUrl) async {
    final clean = rawUrl.trim();
    if (clean.isEmpty) {
      _showToast(context, 'Invalid website URL');
      return false;
    }

    String formatted = clean;
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'https://$formatted';
    }

    final Uri? launchUri = Uri.tryParse(formatted);
    if (launchUri == null) {
      _showToast(context, 'Invalid website URL format');
      return false;
    }

    try {
      return await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error launching website: $e');
      if (context.mounted) {
        _showToast(context, 'Could not open website');
      }
      return false;
    }
  }

  /// Open Address in Google Maps or default map app
  static Future<bool> openMap(BuildContext context, String address) async {
    final clean = address.trim();
    if (clean.isEmpty) {
      _showToast(context, 'Invalid address');
      return false;
    }

    final Uri launchUri = Uri.parse('geo:0,0?q=${Uri.encodeComponent(clean)}');

    try {
      if (await canLaunchUrl(launchUri)) {
        return await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(clean)}');
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Map: $e');
      if (context.mounted) {
        _showToast(context, 'Could not open map');
      }
      return false;
    }
  }

  /// Share contact information as text or vCard string
  static Future<void> shareContact(String shareText, {String? subject}) async {
    // ignore: deprecated_member_use
    await Share.share(shareText, subject: subject);
  }

  static void _showToast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
