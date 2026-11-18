import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smartcard_flutter/core/database/hive_scan_database.dart';
import 'package:smartcard_flutter/core/database/sqlite_database.dart';
import 'package:smartcard_flutter/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/viewmodels/contact_viewmodel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dotenv.loadFromString(
      envString: 'USE_LOCAL_BACKEND=false\nBASE_URL=https://thesmartcards.com\nAPI_BASE_URL=https://thesmartcards.com/api\n',
    );
  });

  tearDown(() async {
    await SqliteDatabase.clearAllContacts();
  });

  group('Hive Persistence & Duplicate Profile Deletion Tests', () {
    const sharedPhone = '9999999999';

    test('Test 1: Create Profile A and Profile B with same phone -> 2 separate records exist', () async {
      final vm = ContactViewModel();

      final profileA = ScannedContactModel(
        id: 'scan_profile_A',
        name: 'Profile A',
        company: 'Company A',
        designation: 'CEO',
        phone: sharedPhone,
        email: 'a@companya.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'scanned',
      );

      final profileB = ScannedContactModel(
        id: 'scan_profile_B',
        name: 'Profile B',
        company: 'Company B',
        designation: 'Director',
        phone: sharedPhone,
        email: 'b@companyb.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'scanned',
      );

      await vm.addScannedContact(profileA);
      await vm.addScannedContact(profileB);

      // Verify both records exist and are distinct
      final matches = vm.allContacts.where((c) => c.phone == sharedPhone).toList();
      expect(matches.length, equals(2));
      expect(matches.any((c) => c.id == 'scan_profile_A' && c.company == 'Company A'), isTrue);
      expect(matches.any((c) => c.id == 'scan_profile_B' && c.company == 'Company B'), isTrue);
    });

    test('Test 2: Delete Profile A -> Profile A disappears, Profile B remains intact', () async {
      final vm = ContactViewModel();

      final profileA = ScannedContactModel(
        id: 'scan_profile_A',
        name: 'Profile A',
        company: 'Company A',
        designation: 'CEO',
        phone: sharedPhone,
        email: 'a@companya.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'scanned',
      );

      final profileB = ScannedContactModel(
        id: 'scan_profile_B',
        name: 'Profile B',
        company: 'Company B',
        designation: 'Director',
        phone: sharedPhone,
        email: 'b@companyb.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'scanned',
      );

      await vm.addScannedContact(profileA);
      await vm.addScannedContact(profileB);

      // Delete only Profile A
      await vm.deleteContact('scan_profile_A', target: profileA);

      // Profile A must be gone, Profile B must remain
      expect(vm.allContacts.any((c) => c.id == 'scan_profile_A'), isFalse);
      expect(vm.allContacts.any((c) => c.id == 'scan_profile_B'), isTrue);
      expect(vm.allContacts.where((c) => c.phone == sharedPhone).length, equals(1));
      expect(vm.allContacts.firstWhere((c) => c.phone == sharedPhone).company, equals('Company B'));
    });

    test('Test 3: Edit Profile B -> Only Profile B changes', () async {
      final vm = ContactViewModel();

      final profileA = ScannedContactModel(
        id: 'scan_profile_A',
        name: 'Profile A',
        company: 'Company A',
        designation: 'CEO',
        phone: sharedPhone,
        email: 'a@companya.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'scanned',
      );

      final profileB = ScannedContactModel(
        id: 'scan_profile_B',
        name: 'Profile B',
        company: 'Company B',
        designation: 'Director',
        phone: sharedPhone,
        email: 'b@companyb.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'scanned',
      );

      await vm.addScannedContact(profileA);
      await vm.addScannedContact(profileB);

      // Edit only Profile B
      final updatedB = profileB.copyWith(
        company: 'Company B Updated',
        designation: 'Managing Director',
      );
      await vm.addScannedContact(updatedB);

      final recordA = vm.allContacts.firstWhere((c) => c.id == 'scan_profile_A');
      final recordB = vm.allContacts.firstWhere((c) => c.id == 'scan_profile_B');

      expect(recordA.company, equals('Company A'));
      expect(recordA.designation, equals('CEO'));
      expect(recordB.company, equals('Company B Updated'));
      expect(recordB.designation, equals('Managing Director'));
    });

    test('Test 4 & 5: App restart & Hive reload -> Scan records remain', () async {
      // Session 1: save a scan record
      final scanRecord = ScannedContactModel(
        id: 'scan_session_1',
        name: 'Persistent Contact',
        company: 'Persistent Corp',
        designation: 'VP',
        phone: '9888877777',
        email: 'persist@corp.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'scanned',
      );

      await HiveScanDatabase.saveScannedRecord(scanRecord);
      await SqliteDatabase.saveContact(scanRecord);

      // Session 2: Fresh ViewModel instance simulating app restart / reload
      final freshVm = ContactViewModel();
      final scans = freshVm.scannedContacts;

      expect(scans.any((c) => c.id == 'scan_session_1'), isTrue);
      expect(scans.firstWhere((c) => c.id == 'scan_session_1').company, equals('Persistent Corp'));
    });

    test('Test 6: Device contact sync does NOT delete local Hive Scan records', () async {
      final vm = ContactViewModel();

      final localScan = ScannedContactModel(
        id: 'scan_unique_local_999',
        name: 'Local Card User',
        company: 'Local Business',
        designation: 'Owner',
        phone: '9777766666',
        email: 'owner@local.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'scanned',
      );

      await vm.addScannedContact(localScan);
      expect(vm.scannedContacts.any((c) => c.id == 'scan_unique_local_999'), isTrue);

      // Simulate device sync where validDevicePhones does NOT have 9777766666
      await vm.syncDeletedDeviceContacts({'other_id_123'}, validDevicePhones: {'9111122222'});

      // Local scan MUST NOT be deleted!
      expect(vm.allContacts.any((c) => c.id == 'scan_unique_local_999'), isTrue);
      expect(vm.scannedContacts.any((c) => c.id == 'scan_unique_local_999'), isTrue);
    });

    test('Test 7: Scan tab loads records immediately on startup without user touch', () {
      // Ensure record is saved
      final scanRecord = ScannedContactModel(
        id: 'scan_instant_load',
        name: 'Instant Load User',
        company: 'Speed Corp',
        designation: 'Lead',
        phone: '9666655555',
        email: 'instant@speed.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'scanned',
      );

      HiveScanDatabase.saveScannedRecord(scanRecord);

      // Instantiating ContactViewModel immediately restores Hive scans in constructor (0ms)
      final vm = ContactViewModel(autoLoad: false);
      expect(vm.allContacts.any((c) => c.id == 'scan_instant_load'), isTrue);
      expect(vm.scannedContacts.any((c) => c.id == 'scan_instant_load'), isTrue);
    });

    test('Test 8: 3 profiles with same phone number: deleting 1 deletes ONLY that profile, preserving the others in all tabs', () async {
      final vm = ContactViewModel(autoLoad: false);

      const samePhone = '9444433333';

      final profileGoogle = ScannedContactModel(
        id: 'phone_google_1',
        deviceContactId: 'dev_g1',
        name: 'Aravind Google',
        company: 'Google LLC',
        designation: 'Architect',
        phone: samePhone,
        email: 'aravind@google.com',
        website: '',
        address: '',
        socialLinks: const [],
        isMatched: true,
        matchedUserId: 'usr_g1',
        createdAt: DateTime.now(),
      );

      final profileApple = ScannedContactModel(
        id: 'scan_apple_2',
        deviceContactId: 'dev_a2',
        name: 'Aravind Apple',
        company: 'Apple Inc',
        designation: 'Designer',
        phone: samePhone,
        email: 'aravind@apple.com',
        website: '',
        address: '',
        socialLinks: const [],
        source: 'business_card',
        createdAt: DateTime.now(),
      );

      final profilePersonal = ScannedContactModel(
        id: 'phone_personal_3',
        deviceContactId: 'dev_p3',
        name: 'Aravind Personal',
        company: '',
        designation: '',
        phone: samePhone,
        email: 'aravind@gmail.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'phone',
      );

      await vm.addScannedContact(profileGoogle);
      await vm.addScannedContact(profileApple);
      await vm.addScannedContact(profilePersonal);

      // Verify all 3 exist
      expect(vm.allContacts.where((c) => c.phone == samePhone).length, equals(3));
      expect(vm.smartCardContacts.any((c) => c.id == 'phone_google_1'), isTrue);
      expect(vm.scannedContacts.any((c) => c.id == 'scan_apple_2'), isTrue);

      // Delete ONLY the Google profile
      await vm.deleteContact('phone_google_1', target: profileGoogle);

      // Google profile MUST be gone
      expect(vm.allContacts.any((c) => c.id == 'phone_google_1'), isFalse);
      expect(vm.smartCardContacts.any((c) => c.id == 'phone_google_1'), isFalse);

      // Apple profile and Personal profile MUST REMAIN INTACT!
      expect(vm.allContacts.any((c) => c.id == 'scan_apple_2'), isTrue);
      expect(vm.scannedContacts.any((c) => c.id == 'scan_apple_2'), isTrue);
      expect(vm.allContacts.any((c) => c.id == 'phone_personal_3'), isTrue);
      expect(vm.allContacts.where((c) => c.phone == samePhone).length, equals(2));
    });

    test('Test 9: 2 profiles with same name and same phone: deleting 1 deletes ONLY that profile, preserving the other in all tabs', () async {
      final vm = ContactViewModel(autoLoad: false);
      const duplicatePhone = '9555544444';
      const duplicateName = 'Rahul Kumar';

      final card1 = ScannedContactModel(
        id: 'scan_rahul_card_1',
        name: duplicateName,
        company: 'Freelance',
        designation: 'Developer',
        phone: duplicatePhone,
        email: 'rahul1@gmail.com',
        website: '',
        address: '',
        socialLinks: const [],
        source: 'scanned',
        createdAt: DateTime.now(),
      );

      final card2 = ScannedContactModel(
        id: 'scan_rahul_card_2',
        name: duplicateName,
        company: 'Agency',
        designation: 'Consultant',
        phone: duplicatePhone,
        email: 'rahul2@agency.com',
        website: '',
        address: '',
        socialLinks: const [],
        source: 'scanned',
        createdAt: DateTime.now(),
      );

      await vm.addScannedContact(card1);
      await vm.addScannedContact(card2);

      // Verify both profiles exist
      expect(vm.allContacts.where((c) => c.phone == duplicatePhone).length, equals(2));
      expect(vm.scannedContacts.where((c) => c.phone == duplicatePhone).length, equals(2));

      // Delete only card1
      await vm.deleteContact('scan_rahul_card_1', target: card1);

      // card1 must be deleted
      expect(vm.allContacts.any((c) => c.id == 'scan_rahul_card_1'), isFalse);
      expect(vm.scannedContacts.any((c) => c.id == 'scan_rahul_card_1'), isFalse);

      // card2 MUST remain intact across allContacts and scannedContacts!
      expect(vm.allContacts.any((c) => c.id == 'scan_rahul_card_2'), isTrue);
      expect(vm.scannedContacts.any((c) => c.id == 'scan_rahul_card_2'), isTrue);
      expect(vm.allContacts.where((c) => c.phone == duplicatePhone).length, equals(1));
    });
  });
}
