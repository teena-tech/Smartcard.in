import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
import 'package:smartcard_flutter/features/groups_screen/presentation/viewmodel/group_notifier.dart';
import 'package:smartcard_flutter/features/login_screen/data/repositories/auth_repository.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/data/repositories/card_repository.dart';
import 'package:smartcard_flutter/features/profile_screen/data/repositories/user_repository.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_viewmodel.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/contact_form_screen/presentation/view/contact_form_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dotenv.loadFromString(
      envString: 'USE_LOCAL_BACKEND=false\nBASE_URL=https://thesmartcards.in\nAPI_BASE_URL=https://thesmartcards.in/api\n',
    );
  });

  Widget buildTestScreen({
    required double width,
    required double height,
    double textScaleFactor = 1.0,
    ScannedContactModel? scannedContact,
    ScannedContactModel? existingContact,
  }) {
    SharedPreferences.setMockInitialValues({});
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: ContactFormScreen(
              scannedContactToEdit: scannedContact,
              existingContact: existingContact,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Test ContactFormScreen layout at various widths without overflow', (tester) async {
    final widths = [320.0, 360.0, 375.0, 390.0, 414.0, 430.0];

    final incomingContact = ScannedContactModel(
      id: 'test_incoming',
      name: 'Dr. Alexander Montgomery-Smith Jr.',
      company: 'International Business Machines & Technologies Corp',
      designation: 'Senior Vice President of Global Software Engineering',
      phone: '+1 555-019-2834',
      email: 'alexander.montgomery.smith@international-technologies.corp',
      website: 'https://international-technologies.corp/team/alexander',
      address: '742 Evergreen Terrace, Suite 500, Sector 12, New Delhi, India',
      socialLinks: const [],
      createdAt: DateTime(2026, 1, 1),
    );

    final existingContact = ScannedContactModel(
      id: 'test_existing',
      name: 'Alex Smith',
      company: 'IBM Corp',
      designation: 'VP of Software Engineering',
      phone: '+1 555-019-2834',
      email: 'asmith@ibm.com',
      website: 'https://ibm.com',
      address: '742 Evergreen Terrace, New Delhi',
      socialLinks: const [],
      createdAt: DateTime(2026, 1, 1),
    );

    for (final width in widths) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestScreen(
          width: width,
          height: 900,
          scannedContact: incomingContact,
          existingContact: existingContact,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final exception = tester.takeException();
      if (exception != null) {
        debugPrint('💥 Overflow or exception at width $width: $exception');
      }
      expect(exception, isNull, reason: 'Overflow occurred at width $width');
    }
  });
}
