import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/core/utils/contact_parser.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/data/models/card_model.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/presentation/viewmodel/scan_notifier.dart';

void main() {
  group('SmartCards Scanner Unit Tests', () {
    test('ContactParser correctly extracts phone, email, website and company', () {
      const rawOcrText = '''
John Smith
Senior Software Architect
TechCorp Solutions Pvt Ltd
Phone: +91 9876543210
Email: john.smith@techcorp.com
Web: www.techcorp.com
Chennai, Tamil Nadu - 600001
''';

      final result = ContactParser.parse(rawOcrText);

      expect(result.name, contains('John Smith'));
      expect(result.designation, equals('Senior Software Architect'));
      expect(result.company, equals('TechCorp Solutions Pvt Ltd'));
      expect(result.phone.replaceAll(' ', ''), contains('9876543210'));
      expect(result.email, equals('john.smith@techcorp.com'));
      expect(result.website, equals('www.techcorp.com'));
      expect(result.pinCode, equals('600001'));
    });

    test('ContactParser.parseQrCode classifies URL, Phone, Email and vCard correctly', () {
      final urlResult = ContactParser.parseQrCode('https://thesmartcards.in/profile/123');
      expect(urlResult.website, contains('https://thesmartcards.in/profile/123'));

      final phoneResult = ContactParser.parseQrCode('tel:+919876543210');
      expect(phoneResult.phone, equals('+919876543210'));

      final emailResult = ContactParser.parseQrCode('mailto:support@thesmartcards.in');
      expect(emailResult.email, equals('support@thesmartcards.in'));

      final vcardResult = ContactParser.parseQrCode('''
BEGIN:VCARD
VERSION:3.0
N:Doe;Jane;;;
FN:Jane Doe
ORG:SmartCards Inc
TEL;TYPE=CELL:+919876543210
EMAIL:jane@smartcards.in
END:VCARD
''');
      expect(vcardResult.name, equals('Jane Doe'));
      expect(vcardResult.company, equals('SmartCards Inc'));
      expect(vcardResult.phone, contains('919876543210'));
      expect(vcardResult.email, equals('jane@smartcards.in'));
    });

    test('CardModel handles suspension status and qrData correctly', () {
      final activeCard = CardModel(
        userId: 1,
        cardId: 101,
        workProfileId: 5,
        accountUserId: 1,
        cardNo: 1001,
        name: 'Alex Rivera',
        companyName: 'SmartCards Digital',
        phone: '+91 99953 77877',
        email: 'alex@smartcards.in',
        qrCode: 'https://thesmartcards.in?sc=1001',
        isPrimary: true,
        tabLabel: 'Primary Card',
        captionName: 'Alex',
        isSuspended: false,
      );

      final suspendedCard = activeCard.copyWith(isSuspended: true);

      expect(activeCard.isSuspended, isFalse);
      expect(activeCard.qrData, equals('https://thesmartcards.in?sc=1001'));
      expect(suspendedCard.isSuspended, isTrue);
    });

    test('ScanProcessing state emits message and cropped imagePath correctly', () {
      const state = ScanProcessing(
        message: 'Processing business card OCR...',
        imagePath: '/tmp/cropped_card_123.jpg',
      );

      expect(state.message, equals('Processing business card OCR...'));
      expect(state.imagePath, equals('/tmp/cropped_card_123.jpg'));
    });
  });
}
