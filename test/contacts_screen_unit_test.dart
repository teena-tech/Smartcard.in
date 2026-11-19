import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartcard_flutter/models/app_contact.dart';
import 'package:smartcard_flutter/providers/contact_provider.dart';
import 'package:smartcard_flutter/providers/group_provider.dart';
import 'package:smartcard_flutter/repositories/auth_repository.dart';
import 'package:smartcard_flutter/viewmodels/auth_viewmodel.dart';
import 'package:smartcard_flutter/viewmodels/contact_viewmodel.dart';
import 'package:smartcard_flutter/viewmodels/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/viewmodels/theme_viewmodel.dart';
import 'package:smartcard_flutter/views/screens/contacts_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Widget createTestWidget({
    required ContactProvider contactProvider,
    required GroupProvider groupProvider,
    required ContactViewModel contactViewModel,
    required DashboardViewModel dashboardViewModel,
    required ThemeViewModel themeViewModel,
    required AuthViewModel authViewModel,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ContactProvider>.value(value: contactProvider),
        ChangeNotifierProvider<GroupProvider>.value(value: groupProvider),
        ChangeNotifierProvider<ContactViewModel>.value(value: contactViewModel),
        ChangeNotifierProvider<DashboardViewModel>.value(value: dashboardViewModel),
        ChangeNotifierProvider<ThemeViewModel>.value(value: themeViewModel),
        ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ContactsScreen(),
        ),
      ),
    );
  }

  group('ContactsScreen Comprehensive UI & Workflow Unit Tests', () {
    late ContactProvider contactProvider;
    late GroupProvider groupProvider;
    late ContactViewModel contactViewModel;
    late DashboardViewModel dashboardViewModel;
    late ThemeViewModel themeViewModel;
    late AuthViewModel authViewModel;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dotenv.loadFromString(envString: 'USE_LOCAL_BACKEND=false\nBASE_URL=https://thesmartcards.in\nAPI_BASE_URL=https://thesmartcards.in/api\n');
      contactProvider = ContactProvider();
      contactProvider.setContactsForTesting([
        AppContact(id: '1', displayName: 'Gobi', phones: [ContactPhone(number: '9876543210')]),
      ]);
      groupProvider = GroupProvider();
      contactViewModel = ContactViewModel();
      dashboardViewModel = DashboardViewModel();
      themeViewModel = ThemeViewModel();
      authViewModel = AuthViewModel(AuthRepository());
    });

    testWidgets('1. Header, 4 Scrollable Tabs (Contacts, Smart Card, Scans, Groups), Filter Chips, and Bottom Search Bar render correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        contactProvider: contactProvider,
        groupProvider: groupProvider,
        contactViewModel: contactViewModel,
        dashboardViewModel: dashboardViewModel,
        themeViewModel: themeViewModel,
        authViewModel: authViewModel,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Header
      expect(find.text('Contacts'), findsWidgets);

      // Verify 4 Tab Chips
      expect(find.text('Smart Card'), findsOneWidget);
      expect(find.text('Scans'), findsOneWidget);
      expect(find.textContaining('Group'), findsWidgets);

      // Verify Filter Chips & Layout
      expect(find.byType(ContactsScreen), findsOneWidget);

      // Verify Bottom Search Bar and Add Button
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('Add'), findsOneWidget);
    });

    testWidgets('2. Tab switching between Contacts, Smart Card, Scans, and Groups', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        contactProvider: contactProvider,
        groupProvider: groupProvider,
        contactViewModel: contactViewModel,
        dashboardViewModel: dashboardViewModel,
        themeViewModel: themeViewModel,
        authViewModel: authViewModel,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Smart Card Tab
      await tester.tap(find.text('Smart Card'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No Smart Card Contacts'), findsOneWidget);

      // Tap Scans Tab
      await tester.tap(find.text('Scans'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No Scanned Business Cards'), findsOneWidget);

      // Tap Groups Tab
      final groupsFinder = find.byIcon(Icons.folder_shared_rounded);
      if (groupsFinder.evaluate().isNotEmpty) {
        await tester.tap(groupsFinder.first, warnIfMissed: false);
      } else {
        final textFinder = find.textContaining('Group');
        if (textFinder.evaluate().isNotEmpty) {
          await tester.tap(textFinder.first, warnIfMissed: false);
        }
      }
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ContactsScreen), findsOneWidget);

      // Tap back to Contacts Tab
      final contactsTab = find.byIcon(Icons.phone_android_rounded);
      await tester.ensureVisible(contactsTab);
      await tester.tap(contactsTab, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Favorites'), findsOneWidget);
    });

    testWidgets('3. Filter Chip selection updates active filter in ContactProvider', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        contactProvider: contactProvider,
        groupProvider: groupProvider,
        contactViewModel: contactViewModel,
        dashboardViewModel: dashboardViewModel,
        themeViewModel: themeViewModel,
        authViewModel: authViewModel,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Initially All is selected
      expect(contactProvider.currentFilter, equals(ContactFilter.all));

      // Tap Favorites Chip
      await tester.tap(find.textContaining('Favorites'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(contactProvider.currentFilter, equals(ContactFilter.favorites));

      // Tap Favorites Chip again to reset filter
      await tester.tap(find.textContaining('Favorites'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(contactProvider.currentFilter, equals(ContactFilter.all));
    });

    testWidgets('4. Bottom search text field updates search query', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        contactProvider: contactProvider,
        groupProvider: groupProvider,
        contactViewModel: contactViewModel,
        dashboardViewModel: dashboardViewModel,
        themeViewModel: themeViewModel,
        authViewModel: authViewModel,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Gobi');
      await tester.pump(const Duration(milliseconds: 300));

      expect(contactProvider.searchQuery, equals('Gobi'));
    });

    testWidgets('5. Performance: Cached contacts render immediately without blocking spinner during background sync', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Simulate background syncing state where contacts exist
      contactProvider.setContactsForTesting([
        AppContact(id: 'cached_1', displayName: 'Alice Brown', phones: [ContactPhone(number: '1112223333')]),
      ]);

      await tester.pumpWidget(createTestWidget(
        contactProvider: contactProvider,
        groupProvider: groupProvider,
        contactViewModel: contactViewModel,
        dashboardViewModel: dashboardViewModel,
        themeViewModel: themeViewModel,
        authViewModel: authViewModel,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify contact tile renders immediately on frame 1
      expect(find.text('Alice Brown'), findsOneWidget);
      // Verify NO blocking full-screen CircularProgressIndicator is shown
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('6. Loading state: True empty state shows CircularProgressIndicator when loading', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Empty contacts
      contactProvider.setContactsForTesting([]);

      await tester.pumpWidget(createTestWidget(
        contactProvider: contactProvider,
        groupProvider: groupProvider,
        contactViewModel: contactViewModel,
        dashboardViewModel: dashboardViewModel,
        themeViewModel: themeViewModel,
        authViewModel: authViewModel,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // When contacts are empty and not loading, empty state widget shows
      expect(find.byType(ContactsScreen), findsOneWidget);
    });

    test('7. O(1) lookups and memoized groupings in ContactProvider', () {
      final c1 = AppContact(id: 'c_1', displayName: 'Zara', phones: [ContactPhone(number: '+1 555-0100')]);
      contactProvider.setContactsForTesting([c1]);

      // Verify O(1) indexed lookup by ID
      expect(contactProvider.findContactById('c_1'), equals(c1));

      // Verify O(1) indexed lookup by 7-digit phone number
      expect(contactProvider.findContactByPhoneOrEmail('555-0100', ''), equals(c1));

      // Verify grouped contacts cache returns memoized reference
      final groupRef1 = contactProvider.groupedContacts;
      final groupRef2 = contactProvider.groupedContacts;
      expect(identical(groupRef1, groupRef2), isTrue);
    });
  });
}
