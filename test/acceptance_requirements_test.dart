import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartcard_flutter/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/models/card_duplicate_check.dart';
import 'package:smartcard_flutter/models/app_contact.dart';
import 'package:smartcard_flutter/viewmodels/contact_viewmodel.dart';
import 'package:smartcard_flutter/core/database/sqlite_database.dart';
import 'package:smartcard_flutter/core/database/hive_scan_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dotenv.loadFromString(envString: 'USE_LOCAL_BACKEND=false\nBASE_URL=https://thesmartcards.in\nAPI_BASE_URL=https://thesmartcards.in/api\n');
    try {
      final dbPath = await getDatabasesPath();
      await databaseFactory.deleteDatabase('$dbPath/smartcards_app.db');
    } catch (_) {}
  });

  tearDownAll(() async {
    await SqliteDatabase.clearAllContacts();
    await HiveScanDatabase.clearAll();
  });

  setUp(() async {
    await SqliteDatabase.clearAllContacts();
    await HiveScanDatabase.clearAll();
    ContactViewModel.resetGlobalMemoryCacheForTesting();
  });

  group('Final Acceptance Tests (Requirements 1 - 24)', () {
    // -------------------------------------------------------------
    // Test 1: Save one profile with 4 phone numbers.
    // Expected:
    //   - 1 Contact screen profile
    //   - 4 phone numbers inside that contact
    // -------------------------------------------------------------
    test('Test 1: Save one profile with 4 phone numbers -> 1 Contact screen profile, 4 phones', () async {
      final vm = ContactViewModel(autoLoad: false);

      final profileWith4Phones = ScannedContactModel(
        id: 'profile_multi_phone_1',
        name: 'John Doe',
        company: 'ABC Company',
        designation: 'Managing Director',
        phone: '9876543210',
        alternativePhone: '9876543211',
        additionalPhones: const ['Work:9876543212', 'Home:9876543213'],
        email: 'john@abc.com',
        website: 'https://abc.com',
        address: '123 Business Way',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      // Verify model supports all 4 phone numbers cleanly
      expect(profileWith4Phones.allPhoneNumbers.length, equals(4));
      expect(profileWith4Phones.allPhoneNumbers, contains('9876543210'));
      expect(profileWith4Phones.allPhoneNumbers, contains('9876543211'));
      expect(profileWith4Phones.allPhoneNumbers, contains('9876543212'));
      expect(profileWith4Phones.allPhoneNumbers, contains('9876543213'));

      // Save via ViewModel
      await vm.saveOrUpdateProfile(profileWith4Phones);

      // Check ViewModel contact list
      final all = vm.allContacts.where((c) => c.id == 'profile_multi_phone_1').toList();
      expect(all.length, equals(1), reason: 'One profile with 4 phones must appear as exactly 1 contact screen item');
      expect(all.first.allPhoneNumbers.length, equals(4));
    });

    // -------------------------------------------------------------
    // Test 2: Save 5 different company profiles using the same phone number.
    // Expected:
    //   - 5 separate Contact screen profiles
    //   - 5 separate Scan profiles
    //   - No accidental merging
    //   - No profile overwritten
    // -------------------------------------------------------------
    test('Test 2: Save 5 different company profiles using same phone number -> 5 separate profiles', () async {
      final vm = ContactViewModel(autoLoad: false);
      const sharedNumber = '9876543210';

      final companies = ['ABC Company', 'XYZ Company', 'PQR Company', 'LMN Company', 'DEF Company'];

      for (int i = 0; i < companies.length; i++) {
        final profile = ScannedContactModel(
          id: 'profile_comp_${i + 1}',
          name: 'John',
          company: companies[i],
          designation: 'Executive',
          phone: sharedNumber,
          email: 'john@${companies[i].replaceAll(' ', '').toLowerCase()}.com',
          website: '',
          address: '',
          socialLinks: const [],
          createdAt: DateTime.now().add(Duration(seconds: i)),
        );
        await vm.saveOrUpdateProfile(profile);
      }

      // Check contacts for this phone
      final phoneProfiles = vm.getContactsForPhone(sharedNumber);
      expect(phoneProfiles.length, equals(5), reason: 'All 5 company profiles must remain distinct');

      final savedCompanyNames = phoneProfiles.map((p) => p.company).toSet();
      expect(savedCompanyNames.length, equals(5));
      for (final comp in companies) {
        expect(savedCompanyNames, contains(comp));
      }
    });

    // -------------------------------------------------------------
    // Test 3: Save the exact same card twice.
    // Expected:
    //   - Duplicate detection
    //   - Existing alert
    //   - No identical duplicate profile
    // -------------------------------------------------------------
    test('Test 3: Save exact same card twice -> Duplicate detection flags exactDuplicate', () async {
      final vm = ContactViewModel(autoLoad: false);

      final card1 = ScannedContactModel(
        id: 'card_dup_test_1',
        name: 'Sarah Connor',
        company: 'Cyberdyne Systems',
        designation: 'Security Officer',
        phone: '9988776655',
        email: 'sarah@cyberdyne.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      await vm.saveOrUpdateProfile(card1);

      // Incoming identical card (same phone + same company)
      final incomingSameCard = ScannedContactModel(
        id: 'card_dup_test_2',
        name: 'Sarah Connor',
        company: 'Cyberdyne Systems',
        designation: 'Security Officer',
        phone: '9988776655',
        email: 'sarah@cyberdyne.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      final check = vm.checkCardDuplicate(incomingSameCard);
      expect(check.isDuplicate, isTrue, reason: 'Same phone and same company must be detected as duplicate');
      expect(check.type, equals(CardDuplicateType.exactDuplicate));
      expect(check.existingContact, isNotNull);
      expect(check.existingContact!.id, equals('card_dup_test_1'));
    });

    // -------------------------------------------------------------
    // Test 4: Same phone number + different company.
    // Expected:
    //   - Allow saving as a new profile
    //   - Keep the old company profile
    //   - Both profiles visible
    // -------------------------------------------------------------
    test('Test 4: Same phone number + different company -> Not duplicate, allows separate saving', () async {
      final vm = ContactViewModel(autoLoad: false);
      const sharedPhone = '9876543210';

      final oldProfile = ScannedContactModel(
        id: 'profile_old_comp',
        name: 'John',
        company: 'ABC Company',
        designation: 'Consultant',
        phone: sharedPhone,
        email: 'john@abc.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );
      await vm.saveOrUpdateProfile(oldProfile);

      final newCompanyProfile = ScannedContactModel(
        id: 'profile_new_comp',
        name: 'John',
        company: 'XYZ Company', // Different company!
        designation: 'Director',
        phone: sharedPhone,
        email: 'john@xyz.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      // Check duplicate
      final check = vm.checkCardDuplicate(newCompanyProfile);
      expect(check.isDuplicate, isFalse, reason: 'Different company with same phone must NOT be flagged as duplicate');
      expect(check.type, equals(CardDuplicateType.sameNumberDifferentCard));

      // Save new company profile
      await vm.saveOrUpdateProfile(newCompanyProfile);

      final allProfiles = vm.getContactsForPhone(sharedPhone);
      expect(allProfiles.length, equals(2));
      expect(allProfiles.map((p) => p.company).toList(), containsAll(['ABC Company', 'XYZ Company']));
    });

    // -------------------------------------------------------------
    // Test 5: Delete one of the 5 company profiles.
    // Expected:
    //   - Only the selected profile is deleted
    //   - Other 4 profiles remain
    // -------------------------------------------------------------
    test('Test 5: Delete one profile among 5 companies with same phone -> Only that profile deleted', () async {
      final vm = ContactViewModel(autoLoad: false);
      const phone = '9876543210';

      final List<ScannedContactModel> profiles = [
        ScannedContactModel(id: 'del_p1', name: 'John', company: 'ABC', designation: 'D1', phone: phone, email: '', website: '', address: '', socialLinks: const [], createdAt: DateTime.now()),
        ScannedContactModel(id: 'del_p2', name: 'John', company: 'XYZ', designation: 'D2', phone: phone, email: '', website: '', address: '', socialLinks: const [], createdAt: DateTime.now()),
        ScannedContactModel(id: 'del_p3', name: 'John', company: 'PQR', designation: 'D3', phone: phone, email: '', website: '', address: '', socialLinks: const [], createdAt: DateTime.now()),
        ScannedContactModel(id: 'del_p4', name: 'John', company: 'LMN', designation: 'D4', phone: phone, email: '', website: '', address: '', socialLinks: const [], createdAt: DateTime.now()),
        ScannedContactModel(id: 'del_p5', name: 'John', company: 'DEF', designation: 'D5', phone: phone, email: '', website: '', address: '', socialLinks: const [], createdAt: DateTime.now()),
      ];

      for (final p in profiles) {
        await vm.saveOrUpdateProfile(p);
      }

      expect(vm.getContactsForPhone(phone).length, equals(5));

      // Delete only XYZ ('del_p2')
      await vm.deleteContact('del_p2', target: profiles[1]);

      final remaining = vm.getContactsForPhone(phone);
      expect(remaining.length, equals(4));
      expect(remaining.any((p) => p.id == 'del_p2'), isFalse);
      expect(remaining.any((p) => p.company == 'XYZ'), isFalse);

      final remainingCompanies = remaining.map((p) => p.company).toSet();
      expect(remainingCompanies, containsAll(['ABC', 'PQR', 'LMN', 'DEF']));
    });

    // -------------------------------------------------------------
    // Test 6: Delete one phone number from the device contact.
    // Expected:
    //   - App detects the change during sync
    //   - Does not delete the entire profile
    //   - Other phone numbers remain
    // -------------------------------------------------------------
    test('Test 6: Delete one phone number from device contact -> Profile kept with remaining phone', () async {
      final vm = ContactViewModel(autoLoad: false);

      final originalProfile = ScannedContactModel(
        id: 'profile_device_sync_1',
        name: 'James Bond',
        company: 'MI6',
        designation: 'Agent 007',
        phone: '9876543210',
        alternativePhone: '9876543211',
        deviceContactId: 'native_contact_007',
        email: 'james@mi6.gov.uk',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      await vm.saveOrUpdateProfile(originalProfile);
      expect(vm.allContacts.any((c) => c.id == 'profile_device_sync_1'), isTrue);

      // Simulate native device contact where user deleted 9876543211, keeping only 9876543210
      final updatedDeviceContact = AppContact(
        id: 'native_contact_007',
        displayName: 'James Bond - MI6',
        company: 'MI6',
        phones: [ContactPhone(number: '9876543210', isPrimary: true)],
      );

      // Perform reactive sync with the updated device contacts
      await vm.syncDeletedDeviceContacts(
        {'native_contact_007'},
        validDevicePhones: {'9876543210'},
        currentDeviceContacts: [updatedDeviceContact],
      );

      // Profile must STILL exist!
      final profileAfterSync = vm.allContacts.firstWhere((c) => c.id == 'profile_device_sync_1');
      expect(profileAfterSync, isNotNull);
      expect(profileAfterSync.company, equals('MI6'));
      expect(profileAfterSync.phone, equals('9876543210'));
      expect(profileAfterSync.alternativePhone, isNull, reason: 'Deleted secondary phone should be removed');
      expect(profileAfterSync.additionalPhones, isEmpty);
    });

    // -------------------------------------------------------------
    // Test 7: Close and reopen Contact screen.
    // Expected:
    //   - Data appears immediately from Hive
    //   - No temporary 0 count
    // -------------------------------------------------------------
    test('Test 7: Fast loading from Hive cache -> Instant non-zero count, no flickering to 0', () async {
      // 1. Pre-seed Hive with 3 scanned profiles
      final p1 = ScannedContactModel(id: 'hive_p1', name: 'Alpha', company: 'Co 1', designation: 'D1', phone: '1111111111', email: '', website: '', address: '', socialLinks: const [], createdAt: DateTime.now());
      final p2 = ScannedContactModel(id: 'hive_p2', name: 'Beta', company: 'Co 2', designation: 'D2', phone: '2222222222', email: '', website: '', address: '', socialLinks: const [], createdAt: DateTime.now());
      final p3 = ScannedContactModel(id: 'hive_p3', name: 'Gamma', company: 'Co 3', designation: 'D3', phone: '3333333333', email: '', website: '', address: '', socialLinks: const [], createdAt: DateTime.now());

      await HiveScanDatabase.saveAllScannedRecords([p1, p2, p3]);

      // 2. Initialize a fresh ContactViewModel (simulating app or screen reopen)
      final newVm = ContactViewModel(autoLoad: false);

      // Count is available immediately synchronously without waiting for network
      expect(newVm.scannedContactsCount, equals(3), reason: 'Scanned count must be immediately read from Hive');
      expect(newVm.allContacts.length, equals(3));
      expect(newVm.allContacts.map((c) => c.name).toList(), containsAll(['Alpha', 'Beta', 'Gamma']));
    });

    // -------------------------------------------------------------
    // Test 8: Account restoration / restore profiles.
    // Expected:
    //   - Restores profiles using stable profileId
    //   - No duplicates created during restoration
    // -------------------------------------------------------------
    test('Test 8: Restore profiles with stable profileId -> No duplicates created', () async {
      final vm = ContactViewModel(autoLoad: false);

      final cloudRecords = [
        ScannedContactModel(id: 'cloud_p1', name: 'Restore 1', company: 'Comp A', designation: 'D1', phone: '9876543210', email: '', website: '', address: '', socialLinks: const [], createdAt: DateTime.now()),
        ScannedContactModel(id: 'cloud_p2', name: 'Restore 2', company: 'Comp B', designation: 'D2', phone: '9876543210', email: '', website: '', address: '', socialLinks: const [], createdAt: DateTime.now()),
      ];

      // Simulate first restore
      for (final r in cloudRecords) {
        await vm.saveOrUpdateProfile(r);
      }
      expect(vm.allContacts.where((c) => c.id.startsWith('cloud_p')).length, equals(2));

      // Simulate re-running restore (same profileIds)
      for (final r in cloudRecords) {
        await vm.saveOrUpdateProfile(r);
      }

      // Should still be exactly 2, not duplicated
      final restored = vm.allContacts.where((c) => c.id.startsWith('cloud_p')).toList();
      expect(restored.length, equals(2), reason: 'Restoration using stable profileId must not duplicate records');
    });
  });
}
