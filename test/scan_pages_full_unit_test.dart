import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartcard_flutter/features/scanner/models/card_corners.dart';
import 'package:smartcard_flutter/features/scanner/models/qr_result.dart';
import 'package:smartcard_flutter/features/scanner/models/scanner_state.dart';
import 'package:smartcard_flutter/features/scanner/services/contact_parser_service.dart';
import 'package:smartcard_flutter/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/viewmodels/contact_viewmodel.dart';
import 'package:smartcard_flutter/views/screens/contact_preview_screen.dart';

class _MockHttpOverrides extends HttpOverrides {
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _MockHttpOverrides();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Full Scan Pages & OCR Scanner Unit Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dotenv.loadFromString(
        envString: 'USE_LOCAL_BACKEND=false\nBASE_URL=https://thesmartcards.com\nAPI_BASE_URL=https://thesmartcards.com/api\n',
      );
    });

    test('1. ContactPreviewScreen correctly holds contact and imagePath parameters for editing', () {
      final sampleScanned = ScannedContactModel(
        id: 'scan_101',
        name: 'Dr. Hima Chandran',
        company: 'Ayurveda Beauty Clinic',
        designation: 'BAMS, PGDND',
        phone: '7561018857',
        email: 'hima@ayurveda.com',
        website: 'www.ayurvedabeauty.com',
        address: 'Thokkupara, Idukki',
        socialLinks: const [],
        syncStatus: 'pending',
        isFavorite: false,
        createdAt: DateTime.now(),
      );

      final previewScreen = ContactPreviewScreen(
        contact: sampleScanned,
        imagePath: '/tmp/card_sample.png',
      );

      expect(previewScreen.contact, equals(sampleScanned));
      expect(previewScreen.imagePath, equals('/tmp/card_sample.png'));
    });

    test('2. ContactParserService accurately extracts multi-line business card OCR text', () {
      final parser = ContactParserService();
      const rawText = '''
Ramesh Kumar
Managing Director
TechVarna Solutions Pvt Ltd
Mobile: +91 9447012345
WhatsApp: +91 9447012345
Email: ramesh@techvarna.in
Web: https://techvarna.in
Kochi, Kerala - 682001
''';

      final parsed = parser.parseText(rawText);

      expect(parsed.name, contains('Ramesh Kumar'));
      expect(parsed.company, equals('TechVarna Solutions Pvt Ltd'));
      expect(parsed.phone, contains('+91 9447012345'));
      expect(parsed.email, equals('ramesh@techvarna.in'));
      expect(parsed.website, equals('https://techvarna.in'));
      expect(parsed.pinCode, equals('682001'));
    });

    test('3. QrResult handles URL, Phone, Email, and vCard payloads correctly', () {
      // SmartCard URL
      final urlRes = QrResult.fromRawString('https://thesmartcards.in?sc=2002');
      expect(urlRes.type, equals(QrResultType.url));
      expect(urlRes.rawContent, contains('sc=2002'));

      // vCard QR Payload
      final vcardRes = QrResult.fromRawString('''
BEGIN:VCARD
VERSION:3.0
N:Sharma;Amit;;;
FN:Amit Sharma
ORG:Deepmind Tech
TEL;TYPE=CELL:+919811223344
EMAIL:amit@deepmind.com
END:VCARD
''');
      expect(vcardRes.type, equals(QrResultType.vCard));
      expect(vcardRes.parsedFields['name'], equals('Amit Sharma'));
      expect(vcardRes.parsedFields['company'], equals('Deepmind Tech'));
      expect(vcardRes.parsedFields['phone'], equals('+919811223344'));
      expect(vcardRes.parsedFields['email'], equals('amit@deepmind.com'));
    });

    test('4. CardCorners calculates bounding rectangle dimensions properly', () {
      const corners = CardCorners(
        topLeft: Offset(50, 100),
        topRight: Offset(350, 100),
        bottomRight: Offset(350, 300),
        bottomLeft: Offset(50, 300),
      );

      expect(corners.width, equals(300.0));
      expect(corners.height, equals(200.0));
    });

    test('5. ScannerStateEnum provides precise user feedback guidance', () {
      expect(ScannerStateEnum.searching.userFeedbackMessage, contains('Looking for'));
      expect(ScannerStateEnum.tooFar.userFeedbackMessage, equals('Move closer'));
      expect(ScannerStateEnum.tooClose.userFeedbackMessage, equals('Move slightly back'));
      expect(ScannerStateEnum.stable.userFeedbackMessage, contains('Hold steady'));
      expect(ScannerStateEnum.capturing.userFeedbackMessage, contains('Capturing'));
    });

    test('6. ContactViewModel notifies listeners when addScannedContact saves an edited scanned contact', () async {
      final vm = ContactViewModel(autoLoad: false);
      bool notified = false;
      vm.addListener(() {
        notified = true;
      });

      final scanned = ScannedContactModel(
        id: 'edit_test_1',
        name: 'Edited Name',
        company: 'Edited Company',
        designation: 'Manager',
        phone: '9988776655',
        email: 'edited@test.com',
        website: 'www.edited.com',
        address: 'Edited Address',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      await vm.addScannedContact(scanned);
      expect(notified, isTrue);
      expect(vm.allContacts.any((c) => c.id == 'edit_test_1' && c.name == 'Edited Name'), isTrue);
    });
  });
}
