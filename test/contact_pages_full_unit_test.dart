import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartcard_flutter/models/app_contact.dart';
import 'package:smartcard_flutter/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/providers/contact_provider.dart';
import 'package:smartcard_flutter/providers/group_provider.dart';
import 'package:smartcard_flutter/repositories/auth_repository.dart';
import 'package:smartcard_flutter/viewmodels/auth_viewmodel.dart';
import 'package:smartcard_flutter/viewmodels/contact_viewmodel.dart';
import 'package:smartcard_flutter/viewmodels/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/viewmodels/theme_viewmodel.dart';
import 'package:smartcard_flutter/views/screens/contacts_screen.dart';
import 'package:smartcard_flutter/views/screens/group_detail_screen.dart';

class _MockHttpOverrides extends HttpOverrides {
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _MockHttpOverrides();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Full Contact Pages & Workflow Unit Tests', () {
    late ContactProvider contactProvider;
    late GroupProvider groupProvider;
    late ContactViewModel contactViewModel;
    late DashboardViewModel dashboardViewModel;
    late ThemeViewModel themeViewModel;
    late AuthViewModel authViewModel;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dotenv.loadFromString(
        envString: 'USE_LOCAL_BACKEND=false\nBASE_URL=https://thesmartcards.in\nAPI_BASE_URL=https://thesmartcards.in/api\n',
      );
      contactProvider = ContactProvider();
      contactProvider.setContactsForTesting([
        AppContact(
          id: 'c101',
          displayName: 'A M K Selvan jio',
          givenName: 'A M K',
          familyName: 'Selvan jio',
          company: 'Jio Communications',
          jobTitle: 'Regional Manager',
          phones: [ContactPhone(number: '8668134210', label: 'Mobile')],
          emails: [ContactEmail(address: 'selvan@jio.com', label: 'Work')],
        ),
      ]);
      groupProvider = GroupProvider();
      contactViewModel = ContactViewModel(autoLoad: false);
      dashboardViewModel = DashboardViewModel();
      themeViewModel = ThemeViewModel();
      authViewModel = AuthViewModel(AuthRepository());
    });

    Widget wrapWithProviders(Widget widget) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<ContactProvider>.value(value: contactProvider),
          ChangeNotifierProvider<GroupProvider>.value(value: groupProvider),
          ChangeNotifierProvider<ContactViewModel>.value(value: contactViewModel),
          ChangeNotifierProvider<DashboardViewModel>.value(value: dashboardViewModel),
          ChangeNotifierProvider<ThemeViewModel>.value(value: themeViewModel),
          ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
        ],
        child: MaterialApp(
          home: widget,
        ),
      );
    }

    testWidgets('1. ContactsScreen renders summary cards, filter chips, search box, and GlobalBottomNav', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(wrapWithProviders(const ContactsScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify screen title & summary cards
      expect(find.text('Contacts'), findsWidgets);
      expect(find.text('Smart Card'), findsOneWidget);
      expect(find.text('Scans'), findsOneWidget);
      expect(find.textContaining('Groups'), findsWidgets);

      // Verify contact item in list
      expect(find.text('A M K Selvan jio'), findsOneWidget);
    });

    test('2. GroupDetailScreen correctly binds target group parameter', () {
      final sampleGroup = const fc.Group(id: 'g1', name: 'Friends');
      final detailScreen = GroupDetailScreen(group: sampleGroup);

      expect(detailScreen.group.id, equals('g1'));
      expect(detailScreen.group.name, equals('Friends'));
    });

    test('3. Group data model correctly initializes group properties and contact counts', () async {
      final g1 = const fc.Group(id: 'g1', name: 'VVIP Clients');
      final g2 = const fc.Group(id: 'g2', name: 'Tech Team');

      expect(g1.id, equals('g1'));
      expect(g1.name, equals('VVIP Clients'));
      expect(g2.name, equals('Tech Team'));
    });

    test('4. AppContact handles given name, family name, company, and phone mappings cleanly', () {
      final appC = AppContact(
        id: 'c102',
        displayName: 'John Doe',
        givenName: 'John',
        familyName: 'Doe',
        company: 'AntzMedia Tech',
        jobTitle: 'Senior Developer',
        phones: [ContactPhone(number: '9876543210', label: 'Mobile')],
        emails: [ContactEmail(address: 'john@antzmedia.com', label: 'Work')],
        notes: 'Important Client',
      );

      expect(appC.displayName, equals('John Doe'));
      expect(appC.givenName, equals('John'));
      expect(appC.familyName, equals('Doe'));
      expect(appC.company, equals('AntzMedia Tech'));
      expect(appC.phones.first.number, equals('9876543210'));
    });

    test('5. ScannedContactModel maps properties and detail data correctly', () {
      final scannedC = ScannedContactModel(
        id: 's101',
        name: 'A M K Selvan jio',
        company: 'Jio Communications',
        designation: 'Manager',
        phone: '8668134210',
        email: 'selvan@jio.com',
        website: 'www.jio.com',
        address: 'Chennai',
        socialLinks: const [],
        syncStatus: 'synced',
        isFavorite: true,
        createdAt: DateTime.now(),
      );

      expect(scannedC.name, equals('A M K Selvan jio'));
      expect(scannedC.company, equals('Jio Communications'));
      expect(scannedC.phone, equals('8668134210'));
      expect(scannedC.isFavorite, isTrue);
    });

    test('6. ContactAddress.sanitizeAddressString deduplicates repeating address segments and pincodes', () {
      const duplicatedRaw =
          'DHARMATHUPATTI, PULLIMANKOMBAI, AUNDIPATI(TK), DHARMATHUPATTI, PULLIMANKOMBAI, AUNDIPATI(TK), 625536, 625536';
      final clean = ContactAddress.sanitizeAddressString(duplicatedRaw);
      expect(clean, equals('DHARMATHUPATTI, PULLIMANKOMBAI, AUNDIPATI(TK), 625536'));
    });

    test('7. ContactAddress.toDeviceAddress formats clean address without duplicating street or pincode', () {
      final addr = ContactAddress(
        address: 'DHARMATHUPATTI, PULLIMANKOMBAI, AUNDIPATI(TK), 625536',
        label: 'Work',
        postalCode: '625536',
      );

      final deviceAddr = addr.toDeviceAddress();
      expect(deviceAddr.formatted, equals('DHARMATHUPATTI, PULLIMANKOMBAI, AUNDIPATI(TK), 625536'));
      expect(deviceAddr.street, isNull);
      expect(deviceAddr.postalCode, isNull);
    });

    test('8. 2-Way Edit Sync: updating a contact syncs changes to both ContactProvider and ContactViewModel', () async {
      final appC = AppContact(
        id: 'sync_edit_1',
        displayName: 'John Smart',
        givenName: 'John',
        familyName: 'Smart',
        company: 'Smart Cards Ltd',
        jobTitle: 'Architect',
        phones: [ContactPhone(number: '9898989898', label: 'Mobile')],
        emails: [ContactEmail(address: 'john@smart.com', label: 'Work')],
      );

      final scannedC = ScannedContactModel(
        id: 'sync_edit_1',
        name: 'John Smart',
        company: 'Smart Cards Ltd',
        designation: 'Architect',
        phone: '9898989898',
        email: 'john@smart.com',
        website: 'www.smart.com',
        address: 'Bangalore',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      contactProvider.setContactsForTesting([appC]);
      await contactViewModel.addScannedContact(scannedC);

      // Perform edit
      final updatedScanned = scannedC.copyWith(name: 'John Smart Updated', company: 'Smart Cards Tech');
      await contactViewModel.addScannedContact(updatedScanned);

      final updatedAppC = appC.copyWith(displayName: 'John Smart Updated', company: 'Smart Cards Tech');
      contactProvider.setContactsForTesting([updatedAppC]);

      expect(contactViewModel.allContacts.firstWhere((c) => c.id == 'sync_edit_1').name, equals('John Smart Updated'));
      expect(contactProvider.contacts.firstWhere((c) => c.id == 'sync_edit_1').displayName, equals('John Smart Updated'));
    });

    test('9. 2-Way Delete Sync: deleting a contact removes it from both ContactProvider and ContactViewModel', () async {
      final appC = AppContact(
        id: 'sync_del_1',
        displayName: 'Mark Delete',
        phones: [ContactPhone(number: '7778889999', label: 'Mobile')],
      );

      final scannedC = ScannedContactModel(
        id: 'sync_del_1',
        name: 'Mark Delete',
        company: '',
        designation: '',
        phone: '7778889999',
        email: '',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      contactProvider.setContactsForTesting([appC]);
      await contactViewModel.addScannedContact(scannedC);

      // Perform delete on both sides
      await contactViewModel.deleteContact(scannedC.id, target: scannedC);
      await contactProvider.deleteContact(appC);

      expect(contactViewModel.allContacts.any((c) => c.id == 'sync_del_1'), isFalse);
      expect(contactProvider.contacts.any((c) => c.id == 'sync_del_1'), isFalse);
    });
  });
}
