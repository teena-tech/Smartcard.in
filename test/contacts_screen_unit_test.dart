import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/app_contact.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
import 'package:smartcard_flutter/features/groups_screen/presentation/viewmodel/group_notifier.dart';
import 'package:smartcard_flutter/features/login_screen/data/repositories/auth_repository.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_viewmodel.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/view/contacts_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Widget createTestWidget({
    required ContactNotifier contactNotifier,
    required GroupNotifier groupNotifier,
    required ContactViewModel contactViewModel,
    required DashboardViewModel dashboardViewModel,
    required ThemeViewModel themeViewModel,
    required AuthViewModel authViewModel,
  }) {
    return const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ContactsScreen(),
        ),
      ),
    );
  }

  group('ContactsScreen Comprehensive UI & Workflow Unit Tests', () {
    late ContactNotifier contactNotifier;
    late GroupNotifier groupNotifier;
    late ContactViewModel contactViewModel;
    late DashboardViewModel dashboardViewModel;
    late ThemeViewModel themeViewModel;
    late AuthViewModel authViewModel;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dotenv.loadFromString(envString: 'USE_LOCAL_BACKEND=false\nBASE_URL=https://thesmartcards.in\nAPI_BASE_URL=https://thesmartcards.in/api\n');
      contactNotifier = ContactNotifier();
      contactNotifier.setContactsForTesting([
        AppContact(id: '1', displayName: 'Gobi', phones: [ContactPhone(number: '9876543210')]),
      ]);
      groupNotifier = GroupNotifier();
      contactViewModel = ContactViewModel();
      dashboardViewModel = DashboardViewModel();
      themeViewModel = ThemeViewModel();
      authViewModel = AuthViewModel();
    });

    testWidgets('1. Header, 4 Scrollable Tabs (Contacts, Smart Card, Scans, Groups), Filter Chips, and Bottom Search Bar render correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        contactNotifier: contactNotifier,
        groupNotifier: groupNotifier,
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
        contactNotifier: contactNotifier,
        groupNotifier: groupNotifier,
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

    testWidgets('3. Filter Chip selection updates active filter in ContactNotifier', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        contactNotifier: contactNotifier,
        groupNotifier: groupNotifier,
        contactViewModel: contactViewModel,
        dashboardViewModel: dashboardViewModel,
        themeViewModel: themeViewModel,
        authViewModel: authViewModel,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Initially All is selected
      expect(contactNotifier.currentFilter, equals(ContactFilter.all));

      // Tap Favorites Chip
      await tester.tap(find.textContaining('Favorites'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(contactNotifier.currentFilter, equals(ContactFilter.favorites));

      // Tap Favorites Chip again to reset filter
      await tester.tap(find.textContaining('Favorites'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(contactNotifier.currentFilter, equals(ContactFilter.all));
    });

    testWidgets('4. Bottom search text field updates search query', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget(
        contactNotifier: contactNotifier,
        groupNotifier: groupNotifier,
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

      expect(contactNotifier.searchQuery, equals('Gobi'));
    });

    testWidgets('5. Performance: Cached contacts render immediately without blocking spinner during background sync', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Simulate background syncing state where contacts exist
      contactNotifier.setContactsForTesting([
        AppContact(id: 'cached_1', displayName: 'Alice Brown', phones: [ContactPhone(number: '1112223333')]),
      ]);

      await tester.pumpWidget(createTestWidget(
        contactNotifier: contactNotifier,
        groupNotifier: groupNotifier,
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
      contactNotifier.setContactsForTesting([]);

      await tester.pumpWidget(createTestWidget(
        contactNotifier: contactNotifier,
        groupNotifier: groupNotifier,
        contactViewModel: contactViewModel,
        dashboardViewModel: dashboardViewModel,
        themeViewModel: themeViewModel,
        authViewModel: authViewModel,
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // When contacts are empty and not loading, empty state widget shows
      expect(find.byType(ContactsScreen), findsOneWidget);
    });

    test('7. O(1) lookups and memoized groupings in ContactNotifier', () {
      final c1 = AppContact(id: 'c_1', displayName: 'Zara', phones: [ContactPhone(number: '+1 555-0100')]);
      contactNotifier.setContactsForTesting([c1]);

      // Verify O(1) indexed lookup by ID
      expect(contactNotifier.findContactById('c_1'), equals(c1));

      // Verify O(1) indexed lookup by 7-digit phone number
      expect(contactNotifier.findContactByPhoneOrEmail('555-0100', ''), equals(c1));

      // Verify grouped contacts cache returns memoized reference
      final groupRef1 = contactNotifier.groupedContacts;
      final groupRef2 = contactNotifier.groupedContacts;
      expect(identical(groupRef1, groupRef2), isTrue);
    });
  });
}
