import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/core/utils/contact_action_helper.dart';
import 'package:smartcard_flutter/core/utils/intent_launcher.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/app_contact.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';

void main() {
  group('WhatsApp Sanitization and Country Code Tests', () {
    test('10-digit standard Indian phone receives 91 country code', () {
      expect(IntentLauncher.sanitizeForWhatsApp('9789199999'), '919789199999');
      expect(IntentLauncher.sanitizeForWhatsApp('9876543210'), '919876543210');
    });

    test('Trunk zero (0-prefixed 11-digit) stripped and receives 91 country code', () {
      expect(IntentLauncher.sanitizeForWhatsApp('09789199999'), '919789199999');
    });

    test('International + prefixed numbers preserve country code without double 91', () {
      expect(IntentLauncher.sanitizeForWhatsApp('+91 97891 99999'), '919789199999');
      expect(IntentLauncher.sanitizeForWhatsApp('+1 (415) 555-2671'), '14155552671');
      expect(IntentLauncher.sanitizeForWhatsApp('+44 7911 123456'), '447911123456');
    });

    test('12-digit number already starting with 91 is preserved', () {
      expect(IntentLauncher.sanitizeForWhatsApp('919789199999'), '919789199999');
    });
  });

  group('ContactActionHelper Extraction Tests', () {
    test('Extracts multiple phone numbers from ScannedContactModel with matchedCards', () {
      final contact = ScannedContactModel(
        id: 'test_1',
        name: 'B DHAMOTHARAN',
        company: 'Antzmedia',
        designation: 'Director',
        phone: '9789199999',
        alternativePhone: '9876543210',
        whatsApp: '9789199999',
        landline: '0442345678',
        email: 'test@example.com',
        website: 'https://antzmedia.com',
        address: 'Chennai',
        socialLinks: const [],
        createdAt: DateTime.now(),
        matchedCards: const [
          {
            'company': 'Antzmedia Tech',
            'phone': '9123456789',
            'whatsappNumber': '9988776655',
            'email': 'work@antzmedia.com',
          }
        ],
      );

      final phoneItems = ContactActionHelper.extractPhoneItems(contact);
      // Expected distinct phone numbers: 9789199999, 9876543210, 0442345678, 9123456789, 9988776655
      expect(phoneItems.length, 5);

      final emailItems = ContactActionHelper.extractEmailItems(contact);
      expect(emailItems.length, 2);
      expect(emailItems.map((e) => e.value).toList(), containsAll(['test@example.com', 'work@antzmedia.com']));
    });

    test('Extracts phones and emails from AppContact', () {
      final appContact = AppContact(
        id: 'app_1',
        displayName: 'John Doe',
        phones: [
          ContactPhone(number: '9876543210', label: 'Mobile'),
          ContactPhone(number: '9123456789', label: 'Work'),
        ],
        emails: [
          ContactEmail(address: 'john@example.com', label: 'Home'),
          ContactEmail(address: 'john@work.com', label: 'Work'),
        ],
      );

      final phones = ContactActionHelper.extractPhoneItems(appContact);
      expect(phones.length, 2);

      final emails = ContactActionHelper.extractEmailItems(appContact);
      expect(emails.length, 2);
    });

    test('formatDisplayPhone formats 12-digit, 10-digit, trunk-0, and landlines correctly', () {
      expect(ContactActionHelper.formatDisplayPhone('919789054326'), '+91 97890 54326');
      expect(ContactActionHelper.formatDisplayPhone('9789054326'), '+91 97890 54326');
      expect(ContactActionHelper.formatDisplayPhone('09789054326'), '+91 97890 54326');
      expect(ContactActionHelper.formatDisplayPhone('+91 9894065437'), '+91 98940 65437');
      expect(ContactActionHelper.formatDisplayPhone('044-2400155'), '044-2400155');
    });
  });
}
