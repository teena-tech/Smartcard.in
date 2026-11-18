import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/features/scanner/models/card_corners.dart';
import 'package:smartcard_flutter/features/scanner/models/qr_result.dart';
import 'package:smartcard_flutter/features/scanner/models/scanner_state.dart';
import 'package:smartcard_flutter/features/scanner/services/contact_parser_service.dart';
import 'package:smartcard_flutter/models/card_model.dart';
import 'package:smartcard_flutter/bloc/scan_bloc.dart';

void main() {
  group('SmartCards Scanner Unit Tests', () {
    late ContactParserService contactParser;

    setUp(() {
      contactParser = ContactParserService();
    });

    test('ContactParserService correctly extracts phone, email, website and company', () {
      const rawOcrText = '''
John Smith
Senior Software Architect
TechCorp Solutions Pvt Ltd
Phone: +91 9876543210
Email: john.smith@techcorp.com
Web: www.techcorp.com
Chennai, Tamil Nadu - 600001
''';

      final result = contactParser.parseText(rawOcrText);

      expect(result.name, contains('John Smith'));
      expect(result.designation, equals('Senior Software Architect'));
      expect(result.company, equals('TechCorp Solutions Pvt Ltd'));
      expect(result.phone, contains('+91 9876543210'));
      expect(result.email, equals('john.smith@techcorp.com'));
      expect(result.website, equals('www.techcorp.com'));
      expect(result.pinCode, equals('600001'));
    });

    test('QrResult classifies URL, Phone, Email and vCard correctly', () {
      final urlResult = QrResult.fromRawString('https://thesmartcards.in/profile/123');
      expect(urlResult.type, equals(QrResultType.url));
      expect(urlResult.rawContent, equals('https://thesmartcards.in/profile/123'));

      final phoneResult = QrResult.fromRawString('tel:+919876543210');
      expect(phoneResult.type, equals(QrResultType.phone));

      final emailResult = QrResult.fromRawString('mailto:support@thesmartcards.in');
      expect(emailResult.type, equals(QrResultType.email));

      final vcardResult = QrResult.fromRawString('''
BEGIN:VCARD
VERSION:3.0
N:Doe;Jane;;;
FN:Jane Doe
ORG:SmartCards Inc
TEL;TYPE=CELL:+919876543210
EMAIL:jane@smartcards.in
END:VCARD
''');
      expect(vcardResult.type, equals(QrResultType.vCard));
      expect(vcardResult.parsedFields['name'], equals('Jane Doe'));
    });

    test('ScannerStateEnum returns clear human-readable user guidance messages', () {
      expect(ScannerStateEnum.searching.userFeedbackMessage, equals('Looking for a business card...'));
      expect(ScannerStateEnum.tooFar.userFeedbackMessage, equals('Move closer'));
      expect(ScannerStateEnum.tooClose.userFeedbackMessage, equals('Move slightly back'));
      expect(ScannerStateEnum.stable.userFeedbackMessage, equals('Perfect! Hold steady...'));
      expect(ScannerStateEnum.capturing.userFeedbackMessage, equals('Capturing ✓'));
    });

    test('CardCorners boundingBox calculates correct width and height', () {
      const corners = CardCorners(
        topLeft: Offset(10, 20),
        topRight: Offset(210, 20),
        bottomRight: Offset(210, 140),
        bottomLeft: Offset(10, 140),
      );

      expect(corners.width, equals(200.0));
      expect(corners.height, equals(120.0));
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
