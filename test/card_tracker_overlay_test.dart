import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/views/widgets/card_tracker_overlay.dart';

void main() {
  group('CardTrackerOverlay Tests', () {
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

      // Verify searching text is present
      expect(find.text('Searching for card or QR code...'), findsOneWidget);
      expect(find.textContaining('Card detected'), findsNothing);
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

      // Allow the AnimatedSwitcher to complete its transition
      await tester.pump(const Duration(milliseconds: 300));

      // Verify detected text is present
      expect(find.textContaining('Card detected'), findsOneWidget);
      expect(find.text('Searching for card or QR code...'), findsNothing);
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

      // Fast-forward time by 3 seconds for 3-2-1 countdown
      await tester.pump(const Duration(seconds: 4));

      expect(onLockedCalled, isTrue);
    });
  });

  group('ScannerPainter Tests', () {
    test('ScannerPainter shouldRepaint returns correct values', () {
      final painter1 = ScannerPainter(
        detectedRect: null,
        isLocked: false,
        laserProgress: 0.5,
      );

      final painter2 = ScannerPainter(
        detectedRect: null,
        isLocked: false,
        laserProgress: 0.5,
      );

      final painter3 = ScannerPainter(
        detectedRect: const Rect.fromLTWH(0, 0, 10, 10),
        isLocked: false,
        laserProgress: 0.5,
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
      expect(painter1.shouldRepaint(painter3), isTrue);
    });
  });
}
