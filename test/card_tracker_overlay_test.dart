import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/presentation/view/widgets/card_tracker_overlay.dart';

void main() {
  group('CardTrackerOverlay Tests', () {
    tearDown(() async {
      // Clean up repeat animation timers
    });
    testWidgets('renders searching text when detectedRect is null', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CardTrackerOverlay(
              detectedRect: null,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify searching instruction is present
      expect(find.text('Place business card inside frame'), findsOneWidget);
    });

    testWidgets('renders detected text when detectedRect is provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CardTrackerOverlay(
              detectedRect: Rect.fromLTWH(50, 50, 200, 100),
              locked: true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Verify capturing text is present when locked
      expect(find.text('Capturing image...'), findsOneWidget);
    });

    testWidgets('calls onLocked callback after countdown when card is detected', (WidgetTester tester) async {
      bool onLockedCalled = false;

      // Start with no card detected
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: CardTrackerOverlay(
                  detectedRect: null,
                  onLocked: () {
                    onLockedCalled = true;
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(onLockedCalled, isFalse);

      // Update widget to have a detected card
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: CardTrackerOverlay(
                  detectedRect: const Rect.fromLTWH(50, 50, 200, 100),
                  onLocked: () {
                    onLockedCalled = true;
                  },
                ),
              ),
            );
          },
        ),
      );

      await tester.pump(const Duration(seconds: 4));

      // Reset detectedRect to null to cancel active countdown timer before unmounting widget
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: CardTrackerOverlay(
                  detectedRect: null,
                  onLocked: () {
                    onLockedCalled = true;
                  },
                ),
              ),
            );
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(onLockedCalled, isTrue);
    });
  });
}
