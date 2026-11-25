import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/core/widgets/company_conflict_warning_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final existingContact = ScannedContactModel(
    id: 'c_existing',
    name: 'Sarah Connor',
    phone: '+1 555-0199',
    email: 'sarah@cyberdyne.com',
    company: 'Cyberdyne Systems',
    designation: 'Security Director',
    website: 'https://cyberdyne.com',
    address: 'Los Angeles, CA',
    socialLinks: const [],
    createdAt: DateTime.now(),
  );

  final incomingContact = ScannedContactModel(
    id: 'c_incoming',
    name: 'Sarah Connor',
    phone: '+1 555-0199',
    email: 'sarah@resistance.org',
    company: 'Resistance Tech',
    designation: 'Operations Lead',
    website: 'https://resistance.org',
    address: 'San Francisco, CA',
    socialLinks: const [],
    createdAt: DateTime.now(),
  );

  testWidgets('CompanyConflictWarningDialog displays WARNING, company comparison, and buttons', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    CompanyConflictAction? chosenAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                chosenAction = await CompanyConflictWarningDialog.show(
                  context: context,
                  incoming: incomingContact,
                  existing: existingContact,
                );
              },
              child: const Text('Open Dialog'),
            );
          },
        ),
      ),
    );

    // Open the dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Title and Supporting text
    expect(find.text('Contact Already Exists'), findsOneWidget);
    expect(
      find.text('An existing contact with this phone number was found.'),
      findsOneWidget,
    );

    // Verify Company details
    expect(find.text('Cyberdyne Systems'), findsOneWidget);
    expect(find.text('Resistance Tech'), findsOneWidget);
    expect(find.text('EXISTING COMPANY'), findsOneWidget);
    expect(find.text('NEW SCANNED COMPANY'), findsOneWidget);

    // Verify action buttons exist
    expect(find.text('View Contact'), findsOneWidget);
    expect(find.text('Add New Company'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap "Add New Company"
    await tester.tap(find.text('Add New Company'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(chosenAction, equals(CompanyConflictAction.addNewCompany));
  });

  testWidgets('CompanyConflictWarningDialog Cancel button dismisses with cancel action', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    CompanyConflictAction? chosenAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                chosenAction = await CompanyConflictWarningDialog.show(
                  context: context,
                  incoming: incomingContact,
                  existing: existingContact,
                );
              },
              child: const Text('Open Dialog'),
            );
          },
        ),
      ),
    );

    // Open the dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap "Cancel"
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(chosenAction, equals(CompanyConflictAction.cancel));
  });
}
