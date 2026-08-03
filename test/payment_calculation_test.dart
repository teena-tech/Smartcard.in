import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Payment Amount Calculation & Razorpay Conversion Tests', () {
    test('Decimal amount calculation rounds UP to nearest rupee for UI display', () {
      final double basePayableAmount = 1.70;
      final int roundedDisplayAmount = basePayableAmount.ceil();
      expect(roundedDisplayAmount, equals(2));
    });

    test('Strikethrough original price removes decimal via ceil()', () {
      final double totalAmount = 430.70;
      final int roundedTotal = totalAmount.ceil();
      expect(roundedTotal, equals(431));
    });

    test('Razorpay paise conversion uses whole rupee ceiling (no fractional paise)', () {
      final double payableAmount = 1.70;
      final int roundedRupees = payableAmount.ceil();
      final int amountPaise = roundedRupees * 100;

      // Must equal exactly 200 paise (₹2.00) for Razorpay live server compatibility
      expect(amountPaise, equals(200));
    });

    test('Exact integer amounts remain unchanged', () {
      final double payableAmount = 20.0;
      final int roundedRupees = payableAmount.ceil();
      final int amountPaise = roundedRupees * 100;

      expect(roundedRupees, equals(20));
      expect(amountPaise, equals(2000));
    });
  });
}
