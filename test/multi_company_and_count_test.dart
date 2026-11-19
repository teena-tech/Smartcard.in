import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartcard_flutter/core/database/sqlite_database.dart';
import 'package:smartcard_flutter/models/card_duplicate_check.dart';
import 'package:smartcard_flutter/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/models/app_contact.dart';
import 'package:smartcard_flutter/viewmodels/contact_viewmodel.dart';
import 'package:smartcard_flutter/views/widgets/duplicate_field_swipe_widget.dart';
import 'package:smartcard_flutter/views/widgets/duplicate_scan_popup_dialog.dart';

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
  });

  group('ScannedContactModel & Single Source of Truth Tests', () {
    test('isSmartCardUser correctly identifies smart card users from all indicators', () {
      final normalScan = ScannedContactModel(
        id: '1',
        name: 'Alice',
        company: 'Corp A',
        designation: 'Dev',
        phone: '1234567890',
        email: 'alice@corpa.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'scanned',
      );
      expect(normalScan.isSmartCardUser, isFalse);

      final matchedScan = normalScan.copyWith(isMatched: true);
      expect(matchedScan.isSmartCardUser, isTrue);

      final sourceSmartCard = normalScan.copyWith(source: 'smart_card');
      expect(sourceSmartCard.isSmartCardUser, isTrue);

      final matchedUser = normalScan.copyWith(matchedUserId: 'usr_999');
      expect(matchedUser.isSmartCardUser, isTrue);

      final matchedCards = normalScan.copyWith(matchedCards: [{'card_id': 'c1'}]);
      expect(matchedCards.isSmartCardUser, isTrue);
    });

    test('allCompanies combines primary and additionalCompanies without duplicates', () {
      final contact = ScannedContactModel(
        id: '2',
        name: 'Bob',
        company: 'Apex Global',
        designation: 'Manager',
        phone: '9876543210',
        email: 'bob@apex.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
        additionalCompanies: const [
          {'company': 'Zenith Solutions', 'designation': 'Consultant'},
          {'company': 'Apex Global', 'designation': 'Advisor'}, // duplicate company name
          {'company': 'Quantum Dynamics', 'designation': 'Director'},
        ],
      );

      final companies = contact.allCompanies;
      expect(companies.length, equals(3));
      expect(companies, contains('Apex Global'));
      expect(companies, contains('Zenith Solutions'));
      expect(companies, contains('Quantum Dynamics'));
    });

    test('SQLite serialization preserves additional_companies column', () async {
      await SqliteDatabase.init();

      final contact = ScannedContactModel(
        id: 'test_save_sqlite',
        name: 'Charlie',
        company: 'Innovate LLC',
        designation: 'CTO',
        phone: '9988776655',
        email: 'charlie@innovate.com',
        website: 'https://innovate.com',
        address: '100 Silicon Way',
        socialLinks: const [],
        createdAt: DateTime.now(),
        additionalCompanies: const [
          {'company': 'NextGen AI', 'designation': 'Founder', 'email': 'charlie@nextgen.ai'},
        ],
      );

      await SqliteDatabase.saveContact(contact);
      final retrieved = await SqliteDatabase.getContactByIdOrPhone('test_save_sqlite');

      expect(retrieved, isNotNull);
      expect(retrieved!.company, equals('Innovate LLC'));
      expect(retrieved.additionalCompanies.length, equals(1));
      expect(retrieved.additionalCompanies.first['company'], equals('NextGen AI'));
      expect(retrieved.additionalCompanies.first['designation'], equals('Founder'));
      expect(retrieved.allCompanies, containsAll(['Innovate LLC', 'NextGen AI']));
    });
  });

  group('Multi-Company Save & Duplicate Detection Tests', () {
    late ContactViewModel contactVm;

    final existingCard = ScannedContactModel(
      id: 'existing_card_1',
      name: 'David Miller',
      company: 'Miller & Co',
      designation: 'Senior Partner',
      phone: '+91 98765 00000',
      email: 'david@miller.com',
      website: 'https://miller.com',
      address: 'Law Street 1',
      socialLinks: const [],
      createdAt: DateTime.now(),
      source: 'card_scan',
    );

    setUp(() async {
      contactVm = ContactViewModel(autoLoad: false);
      await SqliteDatabase.init();
      contactVm.allContacts.clear();
      await SqliteDatabase.saveContact(existingCard);
      contactVm.allContacts.add(existingCard);
    });

    test('checkCardDuplicate identifies same phone + different company as sameNumberDifferentCard', () {
      final newScanDiffComp = ScannedContactModel(
        id: 'new_scan_diff',
        name: 'David Miller',
        company: 'Vanguard Ventures',
        designation: 'Managing Director',
        phone: '9876500000',
        email: 'dmiller@vanguard.com',
        website: 'https://vanguard.com',
        address: 'Wall Street 42',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'card_scan',
      );

      final check = contactVm.checkCardDuplicate(newScanDiffComp);
      expect(check.type, equals(CardDuplicateType.sameNumberDifferentCard));
      expect(check.isSameNumberDifferentCard, isTrue);
      expect(check.existingContact, isNotNull);
      expect(check.existingContact!.phone.replaceAll(RegExp(r'\D'), ''), contains('9876500000'));
    });

    test('saveMultiCompanyScan preserves both company details under same phone number', () async {
      final newScan = ScannedContactModel(
        id: 'new_scan_diff_2',
        name: 'David Miller',
        company: 'Vanguard Ventures',
        designation: 'Managing Director',
        phone: '+91 98765 00000',
        email: 'dmiller@vanguard.com',
        website: 'https://vanguard.com',
        address: 'Wall Street 42',
        socialLinks: const [],
        createdAt: DateTime.now(),
        source: 'card_scan',
      );

      final saved = await contactVm.saveMultiCompanyScan(
        incoming: newScan,
        existing: existingCard,
        chosenFields: {
          'company': 'Vanguard Ventures',
          'designation': 'Managing Director',
          'email': 'dmiller@vanguard.com',
        },
      );

      expect(saved.phone, equals(existingCard.phone));
      expect(saved.company, equals('Vanguard Ventures'));
      expect(saved.additionalCompanies.any((c) => c['company'] == 'Miller & Co'), isTrue);

      // Verify all contacts sharing this phone
      final phoneRecords = contactVm.getContactsForPhone(existingCard.phone);
      expect(phoneRecords.length, greaterThanOrEqualTo(2));
      final companies = phoneRecords.map((r) => r.company).toList();
      expect(companies, contains('Miller & Co'));
      expect(companies, contains('Vanguard Ventures'));
    });

    test('Prevent identical duplicate when company already in additionalCompanies', () {
      final contactWithExtras = existingCard.copyWith(
        additionalCompanies: [
          {'company': 'Vanguard Ventures', 'designation': 'Advisor'},
        ],
      );

      final incomingDuplicate = ScannedContactModel(
        id: 'incoming_dup_secondary',
        name: 'David',
        company: 'vanguard ventures', // Case-insensitive match in additionalCompanies
        designation: 'Advisor',
        phone: '9876500000',
        email: 'd@v.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      // Add to VM
      contactVm.allContacts.removeWhere((c) => c.id == existingCard.id);
      contactVm.allContacts.add(contactWithExtras);

      final check = contactVm.checkCardDuplicate(incomingDuplicate);
      expect(check.type, equals(CardDuplicateType.exactDuplicate));
      expect(check.isExact, isTrue);
    });
  });

  group('UI Components Widget Tests', () {
    testWidgets('DuplicateFieldSwipeWidget provides interactive comparison and toggle', (tester) async {
      bool selectedNew = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return DuplicateFieldSwipeWidget(
                  label: 'Company',
                  existingValue: 'Apex Health Corp',
                  newValue: 'Vanguard Solar Inc',
                  useNew: selectedNew,
                  onSelectionChanged: (val) {
                    setState(() => selectedNew = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Apex Health Corp'), findsOneWidget);
      expect(find.text('Vanguard Solar Inc'), findsOneWidget);
      expect(find.text('New Scanned'), findsOneWidget);
      expect(find.text('Existing'), findsOneWidget);

      // Tap "Existing" card
      await tester.tap(find.text('Existing'));
      await tester.pumpAndSettle();

      expect(selectedNew, isFalse);

      // Tap "New Scanned" card
      await tester.tap(find.text('New Scanned'));
      await tester.pumpAndSettle();

      expect(selectedNew, isTrue);
    });

    test('Duplicate phone check detects match inside device phone contacts', () {
      final vm = ContactViewModel();
      final phoneContact = AppContact(
        id: 'phone_c1',
        displayName: 'John Smith',
        company: 'Wayne Enterprises',
        phones: [ContactPhone(number: '+91 91122 33445', isPrimary: true)],
      );

      final incomingCard = ScannedContactModel(
        id: 'new_card_2',
        name: 'John Smith',
        phone: '9112233445',
        company: 'Stark Industries',
        designation: 'CEO',
        email: 'john@stark.com',
        website: 'https://stark.com',
        address: 'Bangalore',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      final check = vm.checkCardDuplicate(incomingCard, phoneContacts: [phoneContact]);
      expect(check.isDuplicate, isFalse);
      expect(check.type, equals(CardDuplicateType.sameNumberDifferentCard));
      expect(check.existingContact, isNotNull);
      expect(check.existingContact!.name, equals('John Smith'));
      expect(check.existingContact!.company, equals('Wayne Enterprises'));
    });

    testWidgets('DuplicateScanPopupDialog renders 10s countdown and big swipe button', (tester) async {
      final existing = ScannedContactModel(
        id: 'c_exist',
        name: 'Bruce Wayne',
        company: 'Wayne Enterprises',
        designation: 'CEO',
        phone: '+91 99887 76655',
        email: 'bruce@wayne.com',
        website: 'https://wayne.com',
        address: 'Gotham City',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      final incoming = ScannedContactModel(
        id: 'c_inc',
        name: 'Bruce Wayne',
        company: 'Gotham Security',
        designation: 'Director',
        phone: '+91 99887 76655',
        email: 'bruce@gotham.com',
        website: 'https://gotham.com',
        address: 'Gotham City',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      bool updated = false;
      bool continueScan = false;
      bool exited = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuplicateScanPopupDialog(
              incoming: incoming,
              existing: existing,
              onUpdate: () => updated = true,
              onContinueScan: () => continueScan = true,
              onExit: () => exited = true,
              autoDismissDuration: const Duration(seconds: 10),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Existing Contact Found'), findsOneWidget);
      expect(find.text('Bruce Wayne'), findsWidgets);
      expect(find.text('+91 99887 76655'), findsWidgets);
      expect(find.text('10s'), findsOneWidget);
      expect(find.text('SWIPE TO UPDATE / EDIT'), findsOneWidget);
      expect(find.text('Continue Scan'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      // Tap on the big swipe button to trigger update
      await tester.tap(find.text('SWIPE TO UPDATE / EDIT'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(updated, isTrue);
      expect(continueScan, isFalse);
      expect(exited, isFalse);
    });

    test('Deleting a single profile among 3 cards with same phone number deletes only that profile', () async {
      final vm = ContactViewModel();
      const sharedPhone = '+91 91234 56789';

      final card1 = ScannedContactModel(
        id: 'scan_profile_1',
        name: 'Alex Rivera',
        company: 'Company Alpha',
        designation: 'VP',
        phone: sharedPhone,
        email: 'alex@alpha.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      final card2 = ScannedContactModel(
        id: 'scan_profile_2',
        name: 'Alex Rivera',
        company: 'Company Beta',
        designation: 'Director',
        phone: sharedPhone,
        email: 'alex@beta.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      final card3 = ScannedContactModel(
        id: 'scan_profile_3',
        name: 'Alex Rivera',
        company: 'Company Gamma',
        designation: 'Advisor',
        phone: sharedPhone,
        email: 'alex@gamma.com',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      await vm.addScannedContact(card1);
      await vm.addScannedContact(card2);
      await vm.addScannedContact(card3);

      expect(vm.allContacts.where((c) => c.phone == sharedPhone).length, equals(3));

      // Now delete ONLY card2
      await vm.deleteContact('scan_profile_2', target: card2);

      // card2 must be removed, but card1 and card3 must still exist!
      expect(vm.allContacts.any((c) => c.id == 'scan_profile_2'), isFalse);
      expect(vm.allContacts.any((c) => c.id == 'scan_profile_1'), isTrue);
      expect(vm.allContacts.any((c) => c.id == 'scan_profile_3'), isTrue);
      expect(vm.allContacts.where((c) => c.phone == sharedPhone).length, equals(2));
    });
  });
}
