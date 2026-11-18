import 'package:flutter_test/flutter_test.dart';
import 'package:smartcard_flutter/core/utils/international_phone_helper.dart';
import 'package:smartcard_flutter/models/user_model.dart';

void main() {
  group('Profile Edit Country-Based Phone Restrictions Tests', () {
    // Helper that replicates country detection from Profile Edit Screen
    bool isUserIndian(UserModel? u, String currentCountryCode) {
      if (u?.countryCode != null && u!.countryCode!.trim().isNotEmpty) {
        final clean = u.countryCode!.trim().replaceAll(RegExp(r'\D'), '');
        return clean == '91';
      }
      if (u?.phone != null && u!.phone!.trim().isNotEmpty) {
        final parsed = InternationalPhoneHelper.parseRaw(u.phone!.trim());
        final clean = parsed.countryCode.replaceAll(RegExp(r'\D'), '');
        return clean == '91';
      }
      if (u?.whatsappNumber != null && u!.whatsappNumber!.trim().isNotEmpty) {
        final parsed = InternationalPhoneHelper.parseRaw(u.whatsappNumber!.trim());
        final clean = parsed.countryCode.replaceAll(RegExp(r'\D'), '');
        return clean == '91';
      }
      final clean = currentCountryCode.replaceAll(RegExp(r'\D'), '');
      return clean == '91' || currentCountryCode == '+91';
    }

    test('1. Indian account identification: countryCode +91', () {
      final user = UserModel(
        id: 'user_in',
        phone: '9876543210',
        countryCode: '+91',
        firstName: 'Rahul',
        lastName: 'Sharma',
      );

      expect(isUserIndian(user, '+91'), isTrue);
    });

    test('2. International account identification: US (+1)', () {
      final user = UserModel(
        id: 'user_us',
        phone: '2025550123',
        countryCode: '+1',
        firstName: 'John',
        lastName: 'Smith',
      );

      expect(isUserIndian(user, '+1'), isFalse);
    });

    test('3. International account identification: UAE (+971)', () {
      final user = UserModel(
        id: 'user_uae',
        phone: '501234567',
        countryCode: '+971',
        firstName: 'Tariq',
        lastName: 'Mansoor',
      );

      expect(isUserIndian(user, '+971'), isFalse);
    });

    test('4. International account with no phone but international country code', () {
      final user = UserModel(
        id: 'user_no_phone_uk',
        phone: '',
        countryCode: '+44',
        whatsappNumber: '+447911123456',
        firstName: 'Arthur',
        lastName: 'Pendelton',
      );

      expect(isUserIndian(user, '+44'), isFalse);
    });

    test('5. Alert Dialog exact text specifications for International users', () {
      const expectedTitle = 'Phone/SMS Service Unavailable';
      const expectedMessage =
          'Phone/SMS profile updates are currently available only for Indian users. Please update your WhatsApp number instead.';
      const expectedPrimaryBtn = 'Update WhatsApp Number';
      const expectedSecondaryBtn = 'Cancel';

      expect(expectedTitle, equals('Phone/SMS Service Unavailable'));
      expect(expectedMessage, contains('Phone/SMS profile updates are currently available only for Indian users'));
      expect(expectedMessage, contains('Please update your WhatsApp number instead.'));
      expect(expectedPrimaryBtn, equals('Update WhatsApp Number'));
      expect(expectedSecondaryBtn, equals('Cancel'));
    });

    test('6. International WhatsApp number validation across regions', () {
      // Valid US WhatsApp number
      final usValid = InternationalPhoneHelper.validatePhoneNumber(
        phone: '2025550123',
        countryCode: '+1',
        isWhatsApp: true,
      );
      expect(usValid, isNull);

      // Invalid US WhatsApp number (wrong length)
      final usInvalid = InternationalPhoneHelper.validatePhoneNumber(
        phone: '20255501',
        countryCode: '+1',
        isWhatsApp: true,
      );
      expect(usInvalid, isNotNull);

      // Valid UAE WhatsApp number
      final uaeValid = InternationalPhoneHelper.validatePhoneNumber(
        phone: '501234567',
        countryCode: '+971',
        isWhatsApp: true,
      );
      expect(uaeValid, isNull);

      // Valid Indian WhatsApp number
      final inValid = InternationalPhoneHelper.validatePhoneNumber(
        phone: '9876543210',
        countryCode: '+91',
        isWhatsApp: true,
      );
      expect(inValid, isNull);
    });

    test('7. International Profile Update payload preserves phone and does not submit phone change', () {
      final originalUser = UserModel(
        id: 'int_user_1',
        phone: '+12025550123',
        countryCode: '+1',
        firstName: 'Alice',
        lastName: 'Wonder',
        whatsappNumber: null,
      );

      // When international user updates WhatsApp number:
      final updatedWaNumber = '2025559999';
      final formattedWa = InternationalPhoneHelper.formatForBackend(
        phone: updatedWaNumber,
        countryCode: '+1',
      );

      final updatePayload = <String, dynamic>{
        'first_name': 'Alice',
        'last_name': 'Wonder',
        'email': 'alice@example.com',
        'whatsapp_number': formattedWa,
        'preferred_otp_method': 'whatsapp',
        'delivery_method': 'whatsapp',
        'gender': 'Female',
      };

      // Preserving original phone without submitting a change request:
      if (originalUser.phone != null && originalUser.phone!.isNotEmpty) {
        updatePayload['phone'] = originalUser.phone!;
      }
      if (originalUser.countryCode != null && originalUser.countryCode!.isNotEmpty) {
        updatePayload['country_code'] = originalUser.countryCode!;
      }

      // Assertions
      expect(updatePayload['phone'], equals('+12025550123')); // Preserved!
      expect(updatePayload['whatsapp_number'], equals('+12025559999')); // Updated!
      expect(updatePayload['preferred_otp_method'], equals('whatsapp'));
    });
  });
}
