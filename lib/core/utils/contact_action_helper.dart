import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../network/api_config.dart';
import 'intent_launcher.dart';
import '../../models/app_contact.dart';
import '../../models/scanned_contact_model.dart';
import '../../models/card_model.dart';
import '../../models/contact_model.dart';

class ContactActionItem {
  final String value;
  final String label;
  final IconData? icon;
  final bool isPrimary;

  const ContactActionItem({
    required this.value,
    this.label = '',
    this.icon,
    this.isPrimary = false,
  });
}

enum ContactActionType {
  call,
  sms,
  whatsApp,
  email,
  website,
}

class ContactActionHelper {
  /// Deduplicate and split multi-value strings (e.g. separated by comma, slash, newline)
  static List<String> splitAndCleanValues(List<String?> rawList) {
    final Set<String> cleaned = {};
    for (final item in rawList) {
      if (item == null || item.trim().isEmpty) continue;
      final tokens = item.split(RegExp(r'[\n/,;]'));
      for (final t in tokens) {
        final val = t.trim();
        if (val.isNotEmpty && val.toLowerCase() != 'null' && val.toLowerCase() != 'undefined') {
          cleaned.add(val);
        }
      }
    }
    return cleaned.toList();
  }

  /// Format phone number for clean, professional user display (+91 XXXXX XXXXX)
  static String formatDisplayPhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');

    // Landline or area-code number starting with 0 (e.g. 044-2400155)
    if (trimmed.startsWith('0') && !digits.startsWith('09') && digits.length <= 11) {
      return trimmed;
    }

    // 12 digits starting with 91 (e.g. 919789054326)
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    }

    // 10 digits standard mobile (e.g. 9789054326)
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }

    // 11 digits starting with 0 (e.g. 09789054326)
    if (digits.length == 11 && digits.startsWith('0')) {
      final sub = digits.substring(1);
      return '+91 ${sub.substring(0, 5)} ${sub.substring(5)}';
    }

    // Standard + format (e.g. +91 9894065437 -> +91 98940 65437)
    if (digits.length > 10 && digits.startsWith('91')) {
      final ten = digits.substring(digits.length - 10);
      return '+91 ${ten.substring(0, 5)} ${ten.substring(5)}';
    }

    return trimmed;
  }

  /// Extract all phone numbers from any contact model object
  static List<ContactActionItem> extractPhoneItems(dynamic contact, {AppContact? appContact}) {
    final List<ContactActionItem> items = [];
    final Set<String> seenDigits = {};

    void addPhone(String? num, String label, {bool isPrimary = false}) {
      if (num == null || num.trim().isEmpty) return;
      final cleanedList = splitAndCleanValues([num]);
      for (int i = 0; i < cleanedList.length; i++) {
        final val = cleanedList[i];
        final digits = val.replaceAll(RegExp(r'[^\d]'), '');
        final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
        if (digits.isNotEmpty && !seenDigits.contains(last10)) {
          seenDigits.add(last10);
          final effectiveLabel = label.trim().isNotEmpty ? label.trim() : 'Mobile';
          items.add(ContactActionItem(
            value: val,
            label: effectiveLabel,
            icon: Icons.phone_rounded,
            isPrimary: isPrimary,
          ));
        }
      }
    }

    // 1. If an associated AppContact exists with native device phones, add those with exact device labels
    if (appContact != null && appContact.phones.isNotEmpty) {
      for (final p in appContact.phones) {
        final label = p.label.trim().isNotEmpty ? p.label.trim() : 'Mobile';
        addPhone(p.number, label, isPrimary: p.isPrimary);
      }
    }

    if (contact is AppContact) {
      for (final p in contact.phones) {
        final label = p.label.trim().isNotEmpty ? p.label.trim() : 'Mobile';
        addPhone(p.number, label, isPrimary: p.isPrimary);
      }
    } else if (contact is ScannedContactModel) {
      if (contact.phone.isNotEmpty) {
        addPhone(contact.phone, 'Mobile');
      }

      if (contact.alternativePhone != null && contact.alternativePhone!.trim().isNotEmpty) {
        final alt = contact.alternativePhone!.trim();
        if (alt.contains(':') && !alt.startsWith('http')) {
          final parts = alt.split(':');
          final lbl = parts[0].trim();
          final num = parts.sublist(1).join(':').trim();
          addPhone(num, lbl.isNotEmpty ? lbl : 'Home');
        } else {
          addPhone(alt, 'Home');
        }
      }

      for (final extra in contact.additionalPhones) {
        if (extra.trim().isNotEmpty) {
          if (extra.contains(':') && !extra.startsWith('http')) {
            final parts = extra.split(':');
            final lbl = parts[0].trim();
            final num = parts.sublist(1).join(':').trim();
            addPhone(num, lbl.isNotEmpty ? lbl : 'Work');
          } else {
            addPhone(extra, 'Work');
          }
        }
      }

      addPhone(contact.whatsApp, 'WhatsApp');
      addPhone(contact.landline, 'Landline');

      if (contact.matchedCards != null) {
        for (int i = 0; i < contact.matchedCards!.length; i++) {
          final card = contact.matchedCards![i];
          final comp = card['company']?.toString() ?? card['companyName']?.toString() ?? 'Card ${i + 1}';
          addPhone(card['phone']?.toString(), '$comp (Phone)');
          addPhone(
            card['alternativePhone']?.toString() ??
                card['alternative_phone']?.toString() ??
                card['alternate_phone']?.toString() ??
                card['alt_phone']?.toString() ??
                card['phone2']?.toString() ??
                card['secondary_phone']?.toString(),
            '$comp (Alternative)',
          );
          addPhone(card['whatsappNumber']?.toString() ?? card['whatsapp_number']?.toString(), '$comp (WhatsApp)');
        }
      }
    } else if (contact is CardModel) {
      addPhone(contact.phone, contact.companyName.isNotEmpty ? contact.companyName : 'Card Phone');
    } else if (contact is CardProfileDetails) {
      addPhone(contact.phone, 'User Mobile');
      for (final num in contact.contactNumbers) {
        addPhone(num, 'Company Phone');
      }
      for (final num in contact.whatsappNumbers) {
        addPhone(num, 'Company WhatsApp');
      }
    } else if (contact is ContactModel) {
      addPhone(contact.phone, 'Mobile');
    } else if (contact is Map) {
      addPhone(contact['phone']?.toString(), 'Phone');
      addPhone(contact['alternativePhone']?.toString() ?? contact['alternative_phone']?.toString(), 'Alternative');
      addPhone(contact['whatsApp']?.toString() ?? contact['whatsapp']?.toString(), 'WhatsApp');
    }

    return items;
  }

  /// Extract all WhatsApp numbers from any contact model object
  static List<ContactActionItem> extractWhatsAppItems(dynamic contact) {
    final List<ContactActionItem> items = [];
    final Set<String> seenDigits = {};

    void addWa(String? num, String label) {
      if (num == null) return;
      final cleanedList = splitAndCleanValues([num]);
      for (final val in cleanedList) {
        final digits = val.replaceAll(RegExp(r'[^\d]'), '');
        final last10 = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
        if (digits.isNotEmpty && !seenDigits.contains(last10)) {
          seenDigits.add(last10);
          items.add(ContactActionItem(value: val, label: label, icon: Icons.chat_bubble_rounded));
        }
      }
    }

    if (contact is ScannedContactModel) {
      addWa(contact.whatsApp, 'WhatsApp');
      addWa(contact.phone, 'Mobile');
      addWa(contact.alternativePhone, 'Alternative');
      if (contact.matchedCards != null) {
        for (int i = 0; i < contact.matchedCards!.length; i++) {
          final card = contact.matchedCards![i];
          final comp = card['company']?.toString() ?? card['companyName']?.toString() ?? 'Card ${i + 1}';
          addWa(card['whatsappNumber']?.toString() ?? card['whatsapp_number']?.toString(), '$comp (WhatsApp)');
          addWa(card['phone']?.toString(), '$comp (Phone)');
        }
      }
    } else if (contact is AppContact) {
      for (final p in contact.phones) {
        addWa(p.number, p.label.isNotEmpty ? p.label : 'Mobile');
      }
    } else if (contact is CardProfileDetails) {
      for (final num in contact.whatsappNumbers) {
        addWa(num, 'Company WhatsApp');
      }
      addWa(contact.phone, 'Mobile');
      for (final num in contact.contactNumbers) {
        addWa(num, 'Contact Number');
      }
    } else if (contact is CardModel) {
      addWa(contact.phone, contact.companyName.isNotEmpty ? contact.companyName : 'Card Phone');
    } else if (contact is ContactModel) {
      addWa(contact.phone, 'Mobile');
    } else if (contact is Map) {
      addWa(contact['whatsApp']?.toString() ?? contact['whatsapp']?.toString(), 'WhatsApp');
      addWa(contact['phone']?.toString(), 'Phone');
    }

    return items;
  }

  /// Extract all email addresses from any contact model object
  static List<ContactActionItem> extractEmailItems(dynamic contact) {
    final List<ContactActionItem> items = [];
    final Set<String> seen = {};

    void addEmail(String? em, String label) {
      if (em == null) return;
      final cleanedList = splitAndCleanValues([em]);
      for (final val in cleanedList) {
        final lower = val.toLowerCase();
        if (lower.contains('@') && !seen.contains(lower)) {
          seen.add(lower);
          items.add(ContactActionItem(value: val, label: label, icon: Icons.email_rounded));
        }
      }
    }

    if (contact is AppContact) {
      for (final e in contact.emails) {
        addEmail(e.address, e.label.isNotEmpty ? e.label : 'Email');
      }
    } else if (contact is ScannedContactModel) {
      addEmail(contact.email, 'Primary Email');
      if (contact.matchedCards != null) {
        for (int i = 0; i < contact.matchedCards!.length; i++) {
          final card = contact.matchedCards![i];
          final comp = card['company']?.toString() ?? card['companyName']?.toString() ?? 'Card ${i + 1}';
          addEmail(card['email']?.toString(), '$comp Email');
        }
      }
    } else if (contact is CardProfileDetails) {
      addEmail(contact.email, 'User Email');
      for (final em in contact.companyEmails) {
        addEmail(em, 'Company Email');
      }
    } else if (contact is CardModel) {
      addEmail(contact.email, contact.companyName.isNotEmpty ? contact.companyName : 'Email');
    } else if (contact is ContactModel) {
      addEmail(contact.email, 'Email');
    } else if (contact is Map) {
      addEmail(contact['email']?.toString(), 'Email');
    }

    return items;
  }

  /// Extract all website URLs from any contact model object
  static List<ContactActionItem> extractWebsiteItems(dynamic contact) {
    final List<ContactActionItem> items = [];
    final Set<String> seen = {};

    void addUrl(String? u, String label) {
      if (u == null) return;
      final cleanedList = splitAndCleanValues([u]);
      for (final val in cleanedList) {
        final lower = val.toLowerCase().replaceFirst(RegExp(r'^https?:\/\/'), '').replaceFirst(RegExp(r'\/$'), '');
        if (lower.isNotEmpty && !seen.contains(lower)) {
          seen.add(lower);
          items.add(ContactActionItem(value: val, label: label, icon: Icons.language_rounded));
        }
      }
    }

    if (contact is AppContact) {
      for (final w in contact.websites) {
        addUrl(w.url, w.label.isNotEmpty ? w.label : 'Website');
      }
    } else if (contact is ScannedContactModel) {
      addUrl(contact.website, 'Company Website');
      if (contact.cardUrl != null && contact.cardUrl!.isNotEmpty) {
        addUrl(ApiConfig.formatSmartCardUrl(contact.cardUrl), 'SmartCard Profile');
      }
      if (contact.matchedCards != null) {
        for (int i = 0; i < contact.matchedCards!.length; i++) {
          final card = contact.matchedCards![i];
          final comp = card['company']?.toString() ?? card['companyName']?.toString() ?? 'Card ${i + 1}';
          addUrl(card['website']?.toString(), '$comp Website');
          addUrl(card['cardUrl']?.toString(), '$comp SmartCard');
        }
      }
      for (final s in contact.socialLinks) {
        addUrl(s, 'Social Link');
      }
    } else if (contact is CardProfileDetails) {
      for (final map in contact.website) {
        final name = map['name']?.isNotEmpty == true ? map['name']! : 'Website';
        addUrl(map['url'], name);
      }
      addUrl(contact.fbLink, 'Facebook');
      addUrl(contact.instaLink, 'Instagram');
      addUrl(contact.linkedin, 'LinkedIn');
      addUrl(contact.xLink, 'X (Twitter)');
    } else if (contact is CardModel) {
      addUrl(contact.profileUrl ?? contact.qrData, 'SmartCard Link');
    } else if (contact is ContactModel) {
      addUrl(contact.website, 'Website');
    }

    return items;
  }

  // =========================================================================
  // HIGH-LEVEL ACTION HANDLERS WITH MULTI-SELECT POPUPS
  // =========================================================================

  /// Handle Phone Call action (direct dial or multi-select popup)
  static Future<void> handleCall(
    BuildContext context, {
    required dynamic contact,
    String? contactName,
  }) async {
    final items = extractPhoneItems(contact);
    if (items.isEmpty) {
      _showToast(context, 'No phone number available for ${contactName ?? 'this contact'}');
      return;
    }

    if (items.length == 1) {
      await IntentLauncher.makePhoneCall(context, items.first.value);
      return;
    }

    showActionPicker(
      context,
      title: 'Select Phone Number to Call',
      subtitle: contactName,
      actionType: ContactActionType.call,
      icon: Icons.phone_forwarded_rounded,
      iconColor: AppColors.callGreen,
      items: items,
      onSelected: (item) {
        IntentLauncher.makePhoneCall(context, item.value);
      },
    );
  }

  /// Handle SMS action (direct SMS or multi-select popup)
  static Future<void> handleSms(
    BuildContext context, {
    required dynamic contact,
    String? contactName,
    String? body,
  }) async {
    final items = extractPhoneItems(contact);
    if (items.isEmpty) {
      _showToast(context, 'No phone number available for ${contactName ?? 'this contact'}');
      return;
    }

    if (items.length == 1) {
      await IntentLauncher.sendSms(context, items.first.value, body: body);
      return;
    }

    showActionPicker(
      context,
      title: 'Select Phone Number for SMS',
      subtitle: contactName,
      actionType: ContactActionType.sms,
      icon: Icons.message_rounded,
      iconColor: AppColors.smsBlue,
      items: items,
      onSelected: (item) {
        IntentLauncher.sendSms(context, item.value, body: body);
      },
    );
  }

  /// Handle WhatsApp action (country-code sanitization & multi-select popup)
  static Future<void> handleWhatsApp(
    BuildContext context, {
    required dynamic contact,
    String? contactName,
    String? message,
    String defaultCountryCode = '91',
  }) async {
    final items = extractWhatsAppItems(contact);
    if (items.isEmpty) {
      _showToast(context, 'No WhatsApp number available for ${contactName ?? 'this contact'}');
      return;
    }

    if (items.length == 1) {
      await IntentLauncher.openWhatsApp(
        context,
        items.first.value,
        message: message,
        defaultCountryCode: defaultCountryCode,
      );
      return;
    }

    showActionPicker(
      context,
      title: 'Select WhatsApp Number',
      subtitle: contactName,
      actionType: ContactActionType.whatsApp,
      icon: Icons.chat_bubble_rounded,
      iconColor: AppColors.whatsappGreen,
      items: items,
      onSelected: (item) {
        IntentLauncher.openWhatsApp(
          context,
          item.value,
          message: message,
          defaultCountryCode: defaultCountryCode,
        );
      },
    );
  }

  /// Handle Email action (direct compose or multi-select popup)
  static Future<void> handleEmail(
    BuildContext context, {
    required dynamic contact,
    String? contactName,
    String? subject,
    String? body,
  }) async {
    final items = extractEmailItems(contact);
    if (items.isEmpty) {
      _showToast(context, 'No email address available for ${contactName ?? 'this contact'}');
      return;
    }

    if (items.length == 1) {
      await IntentLauncher.sendEmail(context, items.first.value, subject: subject, body: body);
      return;
    }

    showActionPicker(
      context,
      title: 'Select Email Address',
      subtitle: contactName,
      actionType: ContactActionType.email,
      icon: Icons.email_rounded,
      iconColor: AppColors.emailOrange,
      items: items,
      onSelected: (item) {
        IntentLauncher.sendEmail(context, item.value, subject: subject, body: body);
      },
    );
  }

  /// Handle Website action (direct browser open or multi-select popup)
  static Future<void> handleWebsite(
    BuildContext context, {
    required dynamic contact,
    String? contactName,
  }) async {
    final items = extractWebsiteItems(contact);
    if (items.isEmpty) {
      _showToast(context, 'No website available for ${contactName ?? 'this contact'}');
      return;
    }

    if (items.length == 1) {
      await IntentLauncher.openWebsite(context, items.first.value);
      return;
    }

    showActionPicker(
      context,
      title: 'Select Website to Open',
      subtitle: contactName,
      actionType: ContactActionType.website,
      icon: Icons.language_rounded,
      iconColor: AppColors.primary,
      items: items,
      onSelected: (item) {
        IntentLauncher.openWebsite(context, item.value);
      },
    );
  }

  // =========================================================================
  // MODERN SELECTION POPUP MODAL BOTTOM SHEET
  // =========================================================================

  static void showActionPicker(
    BuildContext context, {
    required String title,
    String? subtitle,
    required ContactActionType actionType,
    required IconData icon,
    required Color iconColor,
    required List<ContactActionItem> items,
    required Function(ContactActionItem selectedItem) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pull handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle.trim(),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: isDark ? Colors.white54 : Colors.grey[400]),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Items list
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final bool isPhoneAction = actionType == ContactActionType.call ||
                          actionType == ContactActionType.sms ||
                          actionType == ContactActionType.whatsApp;
                      final displayValue = isPhoneAction
                          ? formatDisplayPhone(item.value)
                          : item.value;

                      return Material(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            onSelected(item);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(item.icon ?? icon, color: iconColor, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayValue,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF111827),
                                        ),
                                      ),
                                      if (item.label.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.label,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.grey[400] : Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: isDark ? Colors.white38 : Colors.grey[400],
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String formatWhatsAppPreview(String raw) {
    final sanitized = IntentLauncher.sanitizeForWhatsApp(raw);
    if (sanitized.length == 12 && sanitized.startsWith('91')) {
      return '+91 ${sanitized.substring(2, 7)} ${sanitized.substring(7)}';
    } else if (sanitized.startsWith('+')) {
      return sanitized;
    } else if (sanitized.length == 10) {
      return '+91 ${sanitized.substring(0, 5)} ${sanitized.substring(5)}';
    }
    return '+$sanitized';
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
