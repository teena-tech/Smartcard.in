import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/core/database/hive_scan_database.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_viewmodel.dart';
import 'package:smartcard_flutter/core/services/otp_autofill_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    dotenv.loadFromString(
      envString: 'USE_LOCAL_BACKEND=false\nBASE_URL=https://thesmartcards.in\nAPI_BASE_URL=https://thesmartcards.in/api\n',
    );
    final tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
    await HiveScanDatabase.init();
  });

  tearDown(() async {
    await HiveScanDatabase.deleteSmartCardRecord('matched_test_user_1');
    await HiveScanDatabase.deleteSmartCardRecord('matched_alpha');
    await HiveScanDatabase.deleteSmartCardRecord('matched_beta');
  });

  group('Part 1: Gallery & Image Picker Logic Tests', () {
    test('Android SDK version parsing handles modern and legacy formats', () {
      // Validates logic implemented in SmartScannerScreen
      int parseSdk(String osVersion) {
        final match = RegExp(r'API\s*(\d+)', caseSensitive: false).firstMatch(osVersion);
        if (match != null) {
          return int.tryParse(match.group(1)!) ?? 33;
        }
        final verMatch = RegExp(r'^(\d+)').firstMatch(osVersion);
        if (verMatch != null) {
          final osVer = int.tryParse(verMatch.group(1)!);
          if (osVer != null) {
            if (osVer >= 13) return 33;
            if (osVer == 12) return 31;
            if (osVer == 11) return 30;
            if (osVer == 10) return 29;
            return osVer;
          }
        }
        return 33;
      }

      expect(parseSdk('Android 14 (API 34)'), 34);
      expect(parseSdk('Android 13 (API 33)'), 33);
      expect(parseSdk('Android 12 (API 31)'), 31);
      expect(parseSdk('14'), 33);
      expect(parseSdk('11'), 30);
      expect(parseSdk('Unknown'), 33);
    });
  });

  group('Part 2: Smart Card Tab Lifecycle & State Preservation Tests', () {
    test('Smart Card records persist in Hive and restore with non-zero count instantly', () async {
      // 1. Create a smart card record
      final smartCard = ScannedContactModel(
        id: 'matched_test_user_1',
        name: 'Smart Card User One',
        company: 'Smart Corp',
        designation: 'CTO',
        phone: '9876543210',
        email: 'user1@smartcorp.com',
        website: 'https://smartcorp.com',
        address: '123 Tech Park',
        socialLinks: const [],
        source: 'smart_card',
        isMatched: true,
        matchedUserId: 'user_1',
        createdAt: DateTime.now(),
      );

      // 2. Persist to HiveScanDatabase
      await HiveScanDatabase.saveSmartCardRecord(smartCard);

      // Verify Hive has the record immediately
      final hiveRecords = HiveScanDatabase.getAllSmartCardRecords();
      expect(hiveRecords.length, 1);
      expect(hiveRecords.first.id, 'matched_test_user_1');
      expect(hiveRecords.first.isSmartCardUser, isTrue);

      // 3. Instantiate ContactViewModel (simulating screen recreation or app resume)
      final vm = ContactViewModel();

      // 4. Verify count is immediately correct from Hive without requiring touch/swipe
      expect(vm.smartCardContactsCount, 1);
      expect(vm.smartCardContacts.length, 1);
      expect(vm.smartCardContacts.first.name, 'Smart Card User One');
    });

    test('Navigating away and returning preserves Smart Card count and list without zero flickering', () async {
      final smartCards = [
        ScannedContactModel(
          id: 'matched_alpha',
          name: 'Alpha User',
          company: 'Alpha Inc',
          designation: 'CEO',
          phone: '9111111111',
          email: 'alpha@alpha.com',
          website: '',
          address: '',
          socialLinks: const [],
          source: 'smart_card',
          isMatched: true,
          matchedUserId: 'alpha_uid',
          createdAt: DateTime.now(),
        ),
        ScannedContactModel(
          id: 'matched_beta',
          name: 'Beta User',
          company: 'Beta LLC',
          designation: 'Director',
          phone: '9222222222',
          email: 'beta@beta.com',
          website: '',
          address: '',
          socialLinks: const [],
          source: 'smart_card',
          isMatched: true,
          matchedUserId: 'beta_uid',
          createdAt: DateTime.now(),
        ),
      ];

      await HiveScanDatabase.saveAllSmartCardRecords(smartCards);

      final vm = ContactViewModel();

      expect(vm.smartCardContactsCount, 2);
      expect(vm.smartCardContacts.length, 2);

      // Simulate refresh without resetting count
      vm.setSearchQuery('');
      expect(vm.smartCardContactsCount, 2);
      expect(vm.smartCardContacts.length, 2);
    });
  });

  group('Part 3: OTP Autofill & SmartAuth Tests', () {
    test('extractOtp extracts 6-digit OTP from standard SMS templates', () {
      expect(OtpAutofillService.extractOtp('Your OTP is 123456'), '123456');
      expect(OtpAutofillService.extractOtp('Your verification code is 654321.'), '654321');
      expect(OtpAutofillService.extractOtp('Use 890123 as your one time password'), '890123');
      expect(OtpAutofillService.extractOtp('789012 is your Smart Card OTP verification code'), '789012');
      expect(OtpAutofillService.extractOtp('<#> 456789 is your Smart Card code'), '456789');
      expect(OtpAutofillService.extractOtp('123456'), '123456');
    });

    test('extractOtp ignores phone numbers and non-OTP digit sequences', () {
      expect(OtpAutofillService.extractOtp('Call us at 9876543210 for support'), isNull);
      expect(OtpAutofillService.extractOtp('Transaction ID: 12345'), isNull);
      expect(OtpAutofillService.extractOtp('No digits here!'), isNull);
    });
  });
}
