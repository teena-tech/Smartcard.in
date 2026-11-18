import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcard_flutter/core/services/otp_autofill_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('sms_autofill'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'unregisterListener') return 'success';
        if (methodCall.method == 'listenForCode') return null;
        if (methodCall.method == 'getAppSignature') return '11/FA+9q3Fs';
        return null;
      },
    );
  });

  group('OtpAutofillService', () {
    test('singleton instance returns identical instance', () {
      final s1 = OtpAutofillService();
      final s2 = OtpAutofillService();
      expect(identical(s1, s2), isTrue);
    });

    group('extractOtp', () {
      test('extracts standalone 6-digit OTP', () {
        expect(OtpAutofillService.extractOtp('654291'), equals('654291'));
      });

      test('extracts OTP with whitespace around', () {
        expect(OtpAutofillService.extractOtp('  654291  '), equals('654291'));
      });

      test('extracts OTP from standard Google SMS Retriever template', () {
        const sms = '<#> 654291 is your verification code for Smart Card. 11/FA+9q3Fs';
        expect(OtpAutofillService.extractOtp(sms), equals('654291'));
      });

      test('extracts OTP when preceded by "code:" or "otp:" prefix', () {
        const sms = 'Your verification code is 654291. Do not share it with anyone.';
        expect(OtpAutofillService.extractOtp(sms), equals('654291'));

        const smsOtp = 'Your OTP is 892104. Valid for 10 minutes.';
        expect(OtpAutofillService.extractOtp(smsOtp), equals('892104'));
      });

      test('extracts OTP when followed by expiry duration or other numbers', () {
        const sms = 'Use OTP 431980 to log in. This code expires in 5 minutes.';
        expect(OtpAutofillService.extractOtp(sms), equals('431980'));
      });

      test('prioritizes OTP keyword over phone number in message footer', () {
        const sms = 'Your login OTP is 721543. If you did not request this, contact support at +919876543210.';
        expect(OtpAutofillService.extractOtp(sms), equals('721543'));
      });

      test('falls back to standalone 6 digits if no explicit keyword precedes it', () {
        const sms = 'Welcome to Smart Card! 519284 is your passkey. Have a nice day!';
        expect(OtpAutofillService.extractOtp(sms), equals('519284'));
      });

      test('extracts when OTP is followed by keyword (e.g. 654291 is your OTP)', () {
        const sms = '654291 is your OTP verification code for Smart Card';
        expect(OtpAutofillService.extractOtp(sms), equals('654291'));
      });

      test('extracts OTP with colon and hash formatting', () {
        const sms = 'Verification PIN: #654291. Do not share.';
        expect(OtpAutofillService.extractOtp(sms), equals('654291'));
      });

      test('extracts when message is dirty or has line breaks', () {
        const sms = 'Smart Card Auth\n\nYour OTP: 654291\n\nEnjoy our app!';
        expect(OtpAutofillService.extractOtp(sms), equals('654291'));
      });

      test('ignores invalid short or long sequences when extracting', () {
        expect(OtpAutofillService.extractOtp('Your code is 12345'), isNull);
        expect(OtpAutofillService.extractOtp('Phone: 98765432100'), isNull);
        expect(OtpAutofillService.extractOtp(''), isNull);
        expect(OtpAutofillService.extractOtp('No digits at all here'), isNull);
      });
    });

    group('Lifecycle and state', () {
      test('stopListening resets isListening flag', () async {
        final service = OtpAutofillService();
        await service.stopListening();
        expect(service.isListening, isFalse);
      });

      test('isAutofillInitialized returns false initially when not set', () async {
        final service = OtpAutofillService();
        await service.resetAutofillState();
        final initialized = await service.isAutofillInitialized();
        expect(initialized, isFalse);
      });

      test('markAutofillInitialized stores true in SharedPreferences and memory', () async {
        final service = OtpAutofillService();
        await service.resetAutofillState();
        expect(await service.isAutofillInitialized(), isFalse);

        await service.markAutofillInitialized();
        expect(await service.isAutofillInitialized(), isTrue);

        // Verify across another call
        final checkedAgain = await service.isAutofillInitialized();
        expect(checkedAgain, isTrue);
      });

      test('setAutofillInitialized allows updating persistent state', () async {
        final service = OtpAutofillService();
        await service.setAutofillInitialized(true);
        expect(await service.isAutofillInitialized(), isTrue);

        await service.setAutofillInitialized(false);
        expect(await service.isAutofillInitialized(), isFalse);
      });

      test('persistent flow: first login initializes state, logout preserves it, second login and register read true', () async {
        final service = OtpAutofillService();
        await service.resetAutofillState();

        // 1. First login: not yet initialized
        expect(await service.isAutofillInitialized(), isFalse);

        // 2. User completes OTP or allows autofill -> marked initialized
        await service.markAutofillInitialized();
        expect(await service.isAutofillInitialized(), isTrue);

        // 3. User logs out: stopListening is called, but state is NOT cleared
        await service.stopListening();
        expect(service.isListening, isFalse);
        expect(await service.isAutofillInitialized(), isTrue);

        // 4. Second login: reads true -> no repeated prompt
        expect(await service.isAutofillInitialized(), isTrue);

        // 5. Register flow: reads true -> no repeated prompt
        expect(await service.isAutofillInitialized(), isTrue);

        // 6. Direct SharedPreferences inspection confirms persistence
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(OtpAutofillService.prefKeyOtpAutofillInitialized), isTrue);
      });
    });
  });
}
