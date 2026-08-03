import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/core/utils/contact_parser.dart';

void main() {
  group('ContactParser Multiple Phone & Field Formatting Tests', () {
    test('Parses slash-separated mobile numbers into phone and alternativePhone', () {
      final rawOcr = '''
AKHIL RAJ R
Marketing Manager
Funriders Entertainment Pvt. Ltd.
+91 90728 63555 / 90720 20000
info@peppeplanet.com
www.peppeplanet.com
Mezhukkattil Matrix, MG Road, Chitoor Road, Mullassery Canal Junction, Shenoys, Kochi, Kerala 682011
''';

      final contact = ContactParser.parse(rawOcr);

      expect(contact.name, equals('AKHIL RAJ R'));
      expect(contact.designation, equals('Marketing Manager'));
      expect(contact.company, equals('Funriders Entertainment Pvt. Ltd.'));

      // Check primary phone number
      expect(contact.phone.replaceAll(RegExp(r'\s+'), ''), contains('9072863555'));

      // Check alternative phone number is parsed separately
      expect(contact.alternativePhone, isNotNull);
      expect(contact.alternativePhone!.replaceAll(RegExp(r'\s+'), ''), contains('9072020000'));

      // Ensure address does NOT contain the phone number string
      expect(contact.address, isNot(contains('90728 63555')));
      expect(contact.address, isNot(contains('90720 20000')));
    });

    test('Parses email, website, and PIN code cleanly', () {
      final rawOcr = '''
JOHN DOE
Software Engineer
Tech Solutions Ltd.
+91 9876543210
john@example.com
www.example.com
MG Road, Bangalore, 560001
''';

      final contact = ContactParser.parse(rawOcr);

      expect(contact.email, equals('john@example.com'));
      expect(contact.website, equals('www.example.com'));
      expect(contact.pinCode, equals('560001'));
    });
  });
}
