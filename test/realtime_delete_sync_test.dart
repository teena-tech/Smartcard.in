import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_viewmodel.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dotenv.loadFromString(
      envString: 'USE_LOCAL_BACKEND=false\nBASE_URL=https://thesmartcards.in\nAPI_BASE_URL=https://thesmartcards.in/api\n',
    );
  });

  group('Real-time Deletion Sync Across All 3 Tabs Test', () {
    test('syncDeletedDeviceContacts purges deleted contacts from all tabs instantly regardless of source tag', () async {
      final vm = ContactViewModel();

      final phoneContact = ScannedContactModel(
        id: 'phone_test_9999',
        name: 'Unique User 9999',
        company: 'Company A',
        designation: 'Engineer',
        phone: '9999000111',
        email: 'user9999@example.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'phone',
      );

      final scannedContact = ScannedContactModel(
        id: 'scan_test_8888',
        name: 'Unique Scanned User 8888',
        company: 'Scan Co',
        designation: 'Manager',
        phone: '9999000111',
        email: 'scan8888@example.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'scanned', // double 'n' scanned tag test
      );

      await vm.addScannedContact(phoneContact);
      await vm.addScannedContact(scannedContact);

      // Verify the added contacts exist
      expect(vm.allContacts.any((c) => c.phone == '9999000111'), isTrue);

      // Simulate device contact deletion: validDeviceIds does not contain phone_test_9999
      await vm.syncDeletedDeviceContacts({'111'}, validDevicePhones: {'2223334444'});

      // The device phone contact is purged, but the scanned Hive card MUST REMAIN!
      expect(vm.allContacts.any((c) => c.id == 'phone_test_9999'), isFalse);
      expect(vm.allContacts.any((c) => c.id == 'scan_test_8888'), isTrue);
    });

    test('3 profiles with same phone number on device: when 2 are deleted, exactly those 2 are deleted in ALL tab', () async {
      final vm = ContactViewModel();

      final profile1 = ScannedContactModel(
        id: 'phone_dev_101',
        deviceContactId: 'dev_101',
        name: 'Rahul Google',
        company: 'Google LLC',
        designation: 'Staff Engineer',
        phone: '9876543210',
        email: 'rahul@google.com',
        website: 'https://google.com',
        address: 'Mountain View',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'phone',
      );

      final profile2 = ScannedContactModel(
        id: 'phone_dev_102',
        deviceContactId: 'dev_102',
        name: 'Rahul Antz',
        company: 'Antz Media',
        designation: 'Director',
        phone: '9876543210',
        email: 'rahul@antz.com',
        website: 'https://antz.com',
        address: 'Bangalore',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'phone',
      );

      final profile3 = ScannedContactModel(
        id: 'phone_dev_103',
        deviceContactId: 'dev_103',
        name: 'Rahul Tech',
        company: 'Tech Solutions',
        designation: 'Consultant',
        phone: '9876543210',
        email: 'rahul@tech.com',
        website: 'https://tech.com',
        address: 'Kochi',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'phone',
      );

      await vm.addScannedContact(profile1);
      await vm.addScannedContact(profile2);
      await vm.addScannedContact(profile3);

      // Verify all 3 exist initially
      final initialProfiles = vm.getContactsForPhone('9876543210');
      expect(initialProfiles.length, equals(3));

      // Now simulate deleting 2 of them (dev_102 and dev_103) in device contacts
      // validDeviceIds only contains dev_101
      await vm.syncDeletedDeviceContacts({'dev_101'}, validDevicePhones: {'9876543210'});

      // Verify dev_102 and dev_103 are strictly deleted, but dev_101 remains
      expect(vm.allContacts.any((c) => c.id == 'phone_dev_101'), isTrue);
      expect(vm.allContacts.any((c) => c.id == 'phone_dev_102'), isFalse);
      expect(vm.allContacts.any((c) => c.id == 'phone_dev_103'), isFalse);

      final remaining = vm.getContactsForPhone('9876543210');
      expect(remaining.length, equals(1));
      expect(remaining.first.company, equals('Google LLC'));
    });

    test('deleteContact removes card simultaneously from ALL contacts, Smart Card tab, and Scans tab', () async {
      final vm = ContactViewModel();

      // Add a smart card
      final smartCard = ScannedContactModel(
        id: 'phone_dev_201',
        deviceContactId: 'dev_201',
        name: 'Smart User 201',
        company: 'Smart Co',
        designation: 'CTO',
        phone: '9112233445',
        email: 'smart201@smartcards.com',
        website: 'https://thesmartcards.in',
        address: 'Bangalore',
        socialLinks: const [],
        isMatched: true,
        matchedUserId: 'usr_201',
        createdAt: DateTime.now(),
      );

      // Add a scanned card
      final scannedCard = ScannedContactModel(
        id: 'scan_202_card',
        deviceContactId: 'dev_202',
        name: 'Scanned User 202',
        company: 'Paper Co',
        designation: 'Sales',
        phone: '9223344556',
        email: 'scanned202@paper.com',
        website: '',
        address: '',
        socialLinks: const [],
        source: 'business_card',
        createdAt: DateTime.now(),
      );

      await vm.addScannedContact(smartCard);
      await vm.addScannedContact(scannedCard);

      // Verify they are present in their respective tabs
      expect(vm.smartCardContacts.any((c) => c.phone == '9112233445'), isTrue);
      expect(vm.scannedContacts.any((c) => c.phone == '9223344556'), isTrue);

      // Simulate deleting smartCard from Contact tab using native device contact ID 'dev_201'
      await vm.deleteContact(
        'dev_201',
        target: ScannedContactModel(
          id: 'dev_201',
          deviceContactId: 'dev_201',
          name: 'Smart User 201',
          company: 'Smart Co',
          designation: 'CTO',
          phone: '9112233445',
          email: 'smart201@smartcards.com',
          website: '',
          address: '',
          socialLinks: const [],
          createdAt: DateTime.now(),
        ),
      );

      // Verify smart card is GONE from allContacts AND smartCardContacts!
      expect(vm.allContacts.any((c) => c.phone == '9112233445'), isFalse);
      expect(vm.smartCardContacts.any((c) => c.phone == '9112233445'), isFalse);

      // Simulate deleting scannedCard from Contact tab using its actual card ID 'scan_202_card'
      await vm.deleteContact(
        'scan_202_card',
        target: ScannedContactModel(
          id: 'scan_202_card',
          deviceContactId: 'dev_202',
          name: 'Scanned User 202',
          company: 'Paper Co',
          designation: 'Sales',
          phone: '9223344556',
          email: 'scanned202@paper.com',
          website: '',
          address: '',
          socialLinks: const [],
          source: 'business_card',
          createdAt: DateTime.now(),
        ),
      );

      // Verify scanned card is GONE from allContacts AND scannedContacts!
      expect(vm.allContacts.any((c) => c.phone == '9223344556'), isFalse);
      expect(vm.scannedContacts.any((c) => c.phone == '9223344556'), isFalse);
    });
  });
}
