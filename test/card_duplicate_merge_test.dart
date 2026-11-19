import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartcard_flutter/core/database/sqlite_database.dart';
import 'package:smartcard_flutter/core/utils/phone_normalizer.dart';
import 'package:smartcard_flutter/core/utils/company_normalizer.dart';
import 'package:smartcard_flutter/models/card_duplicate_check.dart';
import 'package:smartcard_flutter/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/viewmodels/contact_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dotenv.loadFromString(envString: 'USE_LOCAL_BACKEND=false\nBASE_URL=https://thesmartcards.in\nAPI_BASE_URL=https://thesmartcards.in/api\n');
  });

  tearDownAll(() async {
    await SqliteDatabase.clearAllContacts();
  });

  group('Phone & Company Normalization Unit Tests', () {
    test('1. normalizePhoneNumber handles country codes, spaces, and hyphens consistently', () {
      expect(normalizePhoneNumber('+91 98765 43210'), equals('9876543210'));
      expect(normalizePhoneNumber('+919876543210'), equals('9876543210'));
      expect(normalizePhoneNumber('09876543210'), equals('9876543210'));
      expect(normalizePhoneNumber('98765-43210'), equals('9876543210'));
      expect(PhoneNormalizer.isSame('+91 98765 43210', '98765-43210'), isTrue);
    });

    test('2. CompanyNormalizer handles case, punctuation, whitespace, and legal suffixes', () {
      expect(
        CompanyNormalizer.isSimilar('ABC Technologies Pvt. Ltd.', 'abc technologies'),
        isTrue,
      );
      expect(
        CompanyNormalizer.isSimilar('Apex Health Corp', 'apex health private limited'),
        isTrue,
      );
      expect(
        CompanyNormalizer.isSimilar('Google LLC', 'Microsoft Corporation'),
        isFalse,
      );
      // Missing company should not automatically trigger mismatch
      expect(CompanyNormalizer.isSimilar('', 'Google'), isTrue);
      expect(CompanyNormalizer.isSimilar('Google', ''), isTrue);
    });
  });

  group('Scam Alert & Duplicate Detection Flow Tests', () {
    late ContactViewModel contactVm;

    final existingCard = ScannedContactModel(
      id: 'card_master_1',
      name: 'Dr. John Doe',
      company: 'Apex Health Corp',
      designation: 'Chief Surgeon',
      phone: '+91 98765 43210',
      email: 'john.doe@apexhealth.com',
      website: 'https://apexhealth.com',
      address: '123 Medical Center Way, Suite 400',
      socialLinks: const ['https://linkedin.com/in/johndoe'],
      createdAt: DateTime(2025, 1, 1),
      cardUrl: 'https://thesmartcards.com/c/johndoe123',
    );

    setUp(() async {
      contactVm = ContactViewModel();
      await SqliteDatabase.init();
      await SqliteDatabase.clearAllContacts();
      await SqliteDatabase.saveContact(existingCard);
      await contactVm.loadContactsFromBackend();
    });

    test('3. CASE A — Same Phone + Same/Similar Company -> Scam Alert (exactDuplicate)', () {
      final scanSameCard = ScannedContactModel(
        id: 'new_scan_same',
        name: 'John Doe',
        company: 'Apex Health Private Limited', // Similar company
        designation: 'Surgeon',
        phone: '98765-43210', // Same phone
        email: 'john@apexhealth.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      final check = contactVm.checkCardDuplicate(scanSameCard);
      expect(check.type, equals(CardDuplicateType.exactDuplicate));
      expect(check.isExact, isTrue);
      expect(check.existingContact?.id, equals('card_master_1'));
    });

    test('4. CASE B — Same Phone + Different Company -> Existing Number Found (sameNumberDifferentCard)', () {
      final scanDiffCompany = ScannedContactModel(
        id: 'new_scan_diff_company',
        name: 'Samantha Ray',
        company: 'Venture Solar Inc', // Completely different company
        designation: 'Sales Director',
        phone: '+91 9876543210', // Same phone number
        email: 'samantha@venturesolar.com',
        website: 'https://venturesolar.com',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      final check = contactVm.checkCardDuplicate(scanDiffCompany);
      expect(check.type, equals(CardDuplicateType.sameNumberDifferentCard));
      expect(check.isSameNumberDifferentCard, isTrue);
      expect(check.existingContact?.name, equals('Dr. John Doe'));
      expect(check.existingContact?.company, equals('Apex Health Corp'));
    });

    test('5. Unique Card Detection -> Returns CardDuplicateType.none', () {
      final uniqueScan = ScannedContactModel(
        id: 'unique_card_99',
        name: 'Robert Stark',
        company: 'Winterfell Logic',
        designation: 'Architect',
        phone: '+91 91234 56789',
        email: 'robert@winterfell.org',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      final check = contactVm.checkCardDuplicate(uniqueScan);
      expect(check.type, equals(CardDuplicateType.none));
      expect(check.isDuplicate, isFalse);
    });

    test('6. Merge Functionality: Safely combines records and keeps master card', () async {
      final newCardToMerge = ScannedContactModel(
        id: 'incoming_to_merge_id',
        name: 'Dr. John Doe',
        company: 'Apex Health Corp',
        designation: 'Chief of Surgery',
        phone: '9876543210',
        alternativePhone: '9111122222',
        additionalPhones: const ['9333344444'],
        email: 'johndoe.md@gmail.com',
        website: 'https://drjohndoe.com',
        address: '500 Park Avenue, NY',
        socialLinks: const ['https://twitter.com/drjohndoe'],
        createdAt: DateTime.now(),
      );

      await contactVm.mergeScannedContact(existingCard, newCardToMerge);

      final all = await SqliteDatabase.getAllContactsAsync();
      final masterInDb = all.firstWhere((c) => c.id == existingCard.id);

      expect(masterInDb.id, equals('card_master_1'));
      expect(masterInDb.phone, equals('+91 98765 43210'));
      expect(masterInDb.additionalPhones.any((p) => p.contains('9111122222')), isTrue);
      expect(masterInDb.additionalPhones.any((p) => p.contains('9333344444')), isTrue);
      expect(masterInDb.socialLinks, contains('https://linkedin.com/in/johndoe'));
      expect(masterInDb.socialLinks, contains('https://twitter.com/drjohndoe'));

      final duplicateExists = all.any((c) => c.id == 'incoming_to_merge_id');
      expect(duplicateExists, isFalse);
    });

    test('6b. recordScan & addScannedContact updates lifetimeScanCount and scannedContactsCount', () async {
      final initialLifetime = contactVm.lifetimeScanCount;
      final initialScanned = contactVm.scannedContactsCount;

      await contactVm.recordScan();
      expect(contactVm.lifetimeScanCount, greaterThan(initialLifetime));

      final newScanned = ScannedContactModel(
        id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Alex Hunter',
        company: 'Apex Media',
        designation: 'Producer',
        phone: '+91 99988 77766',
        email: 'alex@apexmedia.com',
        website: '',
        address: '',
        socialLinks: const [],
        source: 'scanned',
        createdAt: DateTime.now(),
      );

      await contactVm.addScannedContact(newScanned);
      expect(contactVm.scannedContactsCount, greaterThan(initialScanned));
    });
  });
}
