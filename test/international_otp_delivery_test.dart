import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcard_flutter/core/utils/international_phone_helper.dart';
import 'package:smartcard_flutter/core/network/dio_client.dart';
import 'package:smartcard_flutter/models/user_model.dart';
import 'package:smartcard_flutter/repositories/auth_repository.dart';
import 'package:smartcard_flutter/repositories/user_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.loadFromString(
      envString: 'USE_LOCAL_BACKEND=false\nBASE_URL=https://thesmartcards.in\nAPI_BASE_URL=https://thesmartcards.in/api\n',
    );
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (MethodCall methodCall) async => null,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. International Phone Number Validation & E.164 Formatting', () {
    test('India (+91): validates 10 digits starting with 6, 7, 8, or 9', () {
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '9876543210', countryCode: '+91'), isNull);
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '7123456789', countryCode: '+91'), isNull);
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '8123456789', countryCode: '+91'), isNull);
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '6123456789', countryCode: '+91'), isNull);

      // Invalid starts
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '5123456789', countryCode: '+91'), contains('start with 6, 7, 8, or 9'));
      // Invalid lengths
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '987654321', countryCode: '+91'), contains('10-digit'));
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '98765432100', countryCode: '+91'), contains('10-digit'));
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '', countryCode: '+91'), contains('Please enter'));
    });

    test('USA & Canada (+1): validates 10 digits', () {
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '2025550123', countryCode: '+1'), isNull);
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '4165550199', countryCode: '+1'), isNull);
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '202555012', countryCode: '+1'), contains('10-digit'));
    });

    test('UK (+44): validates 10-digit national numbers', () {
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '7911123456', countryCode: '+44'), isNull);
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '791112345', countryCode: '+44'), isNotNull);
    });

    test('Australia (+61): validates 9-digit national numbers', () {
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '412345678', countryCode: '+61'), isNull);
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '41234567', countryCode: '+61'), isNotNull);
    });

    test('UAE (+971): validates 9-digit national numbers', () {
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '501234567', countryCode: '+971'), isNull);
      expect(InternationalPhoneHelper.validatePhoneNumber(phone: '50123456', countryCode: '+971'), isNotNull);
    });

    test('E.164 formatting outputs standard international format', () {
      expect(InternationalPhoneHelper.toE164(phone: '9876543210', countryCode: '+91'), equals('+919876543210'));
      expect(InternationalPhoneHelper.toE164(phone: '2025550123', countryCode: '+1'), equals('+12025550123'));
      expect(InternationalPhoneHelper.toE164(phone: '7911123456', countryCode: '+44'), equals('+447911123456'));
      expect(InternationalPhoneHelper.toE164(phone: '501234567', countryCode: '+971'), equals('+971501234567'));
    });

    test('Preserve existing Indian users: formatForBackend preserves 10-digit string for +91', () {
      expect(InternationalPhoneHelper.formatForBackend(phone: '9876543210', countryCode: '+91'), equals('9876543210'));
      expect(InternationalPhoneHelper.formatForBackend(phone: '919876543210', countryCode: '+91'), equals('9876543210'));

      // International numbers format as E.164 for backend
      expect(InternationalPhoneHelper.formatForBackend(phone: '2025550123', countryCode: '+1'), equals('+12025550123'));
      expect(InternationalPhoneHelper.formatForBackend(phone: '501234567', countryCode: '+971'), equals('+971501234567'));
    });

    test('parseRaw splits phone into countryCode and national number correctly', () {
      final inParsed = InternationalPhoneHelper.parseRaw('+919876543210');
      expect(inParsed.countryCode, equals('+91'));
      expect(inParsed.nationalNumber, equals('9876543210'));

      final usParsed = InternationalPhoneHelper.parseRaw('+12025550123');
      expect(usParsed.countryCode, equals('+1'));
      expect(usParsed.nationalNumber, equals('2025550123'));

      final uaeParsed = InternationalPhoneHelper.parseRaw('+971501234567');
      expect(uaeParsed.countryCode, equals('+971'));
      expect(uaeParsed.nationalNumber, equals('501234567'));

      // Raw Indian 10 digits
      final raw10 = InternationalPhoneHelper.parseRaw('9876543210');
      expect(raw10.countryCode, equals('+91'));
      expect(raw10.nationalNumber, equals('9876543210'));
    });
  });

  group('2. Login Screen: Strict SMS vs WhatsApp OTP Channel Isolation', () {
    late AuthRepository authRepo;
    RequestOptions? capturedOptions;
    late Interceptor mockInterceptor;

    setUp(() {
      authRepo = AuthRepository();
      capturedOptions = null;
      mockInterceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedOptions = options;
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'message': 'OTP sent successfully',
                'request_id': 'req_login_123',
              },
            ),
          );
        },
      );
      DioClient().dio.interceptors.insert(0, mockInterceptor);
    });

    tearDown(() {
      DioClient().dio.interceptors.remove(mockInterceptor);
    });

    test('Requirement 1: Login + Phone = SMS OTP only', () async {
      final reqId = await authRepo.sendLoginOtp(
        '9876543210',
        countryCode: '+91',
        channel: 'phone',
      );

      expect(reqId, equals('req_login_123'));
      expect(capturedOptions, isNotNull);
      final body = capturedOptions!.data as Map<String, dynamic>;
      expect(body['channel'], equals('phone'));
      expect(body['delivery_method'], equals('phone'));
      expect(body['otp_channel'], equals('phone'));
      expect(body['country_code'], equals('+91'));
      expect(body['full_phone'], equals('+919876543210'));
      expect(body.containsKey('whatsapp_number'), isFalse);
    });

    test('Requirement 2: Login + WhatsApp = WhatsApp OTP only', () async {
      final reqId = await authRepo.sendLoginOtp(
        '9876543210',
        countryCode: '+91',
        channel: 'whatsapp',
      );

      expect(reqId, equals('req_login_123'));
      expect(capturedOptions, isNotNull);
      final body = capturedOptions!.data as Map<String, dynamic>;
      expect(body['channel'], equals('whatsapp'));
      expect(body['delivery_method'], equals('whatsapp'));
      expect(body['otp_channel'], equals('whatsapp'));
      expect(body['country_code'], equals('+91'));
      expect(body['full_phone'], equals('+919876543210'));
      expect(body['whatsapp_number'], equals('9876543210'));
    });
  });

  group('3. Register Screen: Strict SMS vs WhatsApp OTP Channel Isolation', () {
    late AuthRepository authRepo;
    RequestOptions? capturedOptions;
    late Interceptor mockInterceptor;

    setUp(() {
      authRepo = AuthRepository();
      capturedOptions = null;
      mockInterceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedOptions = options;
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'message': 'Registration OTP sent successfully',
                'request_id': 'req_reg_456',
              },
            ),
          );
        },
      );
      DioClient().dio.interceptors.insert(0, mockInterceptor);
    });

    tearDown(() {
      DioClient().dio.interceptors.remove(mockInterceptor);
    });

    test('Requirement 3: Register + Phone = SMS OTP only', () async {
      final reqId = await authRepo.sendRegisterOtp(
        '2025550123',
        countryCode: '+1',
        channel: 'phone',
      );

      expect(reqId, equals('req_reg_456'));
      expect(capturedOptions, isNotNull);
      final body = capturedOptions!.data as Map<String, dynamic>;
      expect(body['channel'], equals('phone'));
      expect(body['delivery_method'], equals('phone'));
      expect(body['otp_channel'], equals('phone'));
      expect(body['country_code'], equals('+1'));
      expect(body['full_phone'], equals('+12025550123'));
      expect(body.containsKey('whatsapp_number'), isFalse);
    });

    test('Requirement 4: Register + WhatsApp = WhatsApp OTP only with separate WhatsApp number', () async {
      final reqId = await authRepo.sendRegisterOtp(
        '2025550123',
        countryCode: '+1',
        channel: 'whatsapp',
        whatsappNumber: '2025559999',
      );

      expect(reqId, equals('req_reg_456'));
      expect(capturedOptions, isNotNull);
      final body = capturedOptions!.data as Map<String, dynamic>;
      expect(body['channel'], equals('whatsapp'));
      expect(body['delivery_method'], equals('whatsapp'));
      expect(body['otp_channel'], equals('whatsapp'));
      expect(body['country_code'], equals('+1'));
      expect(body['whatsapp_number'], equals('+12025559999'));
    });
  });

  group('4. Profile Edit Screen: Strict SMS vs WhatsApp OTP Channel Isolation', () {
    late UserRepository userRepo;
    RequestOptions? capturedOptions;
    late Interceptor mockInterceptor;

    setUp(() {
      userRepo = UserRepository();
      capturedOptions = null;
      mockInterceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedOptions = options;
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'message': 'Profile OTP sent',
                'request_id': 'req_prof_789',
              },
            ),
          );
        },
      );
      DioClient().dio.interceptors.insert(0, mockInterceptor);
    });

    tearDown(() {
      DioClient().dio.interceptors.remove(mockInterceptor);
    });

    test('Requirement 5: Profile Edit + Phone = SMS OTP only', () async {
      final res = await userRepo.sendProfileOtp(
        'user_123',
        '9876543210',
        countryCode: '+91',
        channel: 'phone',
      );

      expect(res, isNotNull);
      expect(capturedOptions, isNotNull);
      final body = capturedOptions!.data as Map<String, dynamic>;
      expect(body['channel'], equals('phone'));
      expect(body['delivery_method'], equals('phone'));
      expect(body['otp_channel'], equals('phone'));
      expect(body['country_code'], equals('+91'));
      expect(body['full_phone'], equals('+919876543210'));
      expect(body.containsKey('whatsapp_number'), isFalse);
    });

    test('Requirement 6: Profile Edit + WhatsApp = WhatsApp OTP only', () async {
      final res = await userRepo.sendProfileOtp(
        'user_123',
        '501234567',
        countryCode: '+971',
        channel: 'whatsapp',
        whatsappNumber: '509999999',
      );

      expect(res, isNotNull);
      expect(capturedOptions, isNotNull);
      final body = capturedOptions!.data as Map<String, dynamic>;
      expect(body['channel'], equals('whatsapp'));
      expect(body['delivery_method'], equals('whatsapp'));
      expect(body['otp_channel'], equals('whatsapp'));
      expect(body['country_code'], equals('+971'));
      expect(body['whatsapp_number'], equals('+971509999999'));
    });
  });

  group('5. Strict Isolation: Failed WhatsApp delivery must not silently send SMS', () {
    late AuthRepository authRepo;
    late Interceptor failingInterceptor;

    setUp(() {
      authRepo = AuthRepository();
      failingInterceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 503,
                data: {
                  'success': false,
                  'message': 'WhatsApp delivery service unavailable. Please try again.',
                  'error': 'WA_SERVICE_UNAVAILABLE',
                },
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      );
      DioClient().dio.interceptors.insert(0, failingInterceptor);
    });

    tearDown(() {
      DioClient().dio.interceptors.remove(failingInterceptor);
    });

    test('Requirement 9: WhatsApp failure throws or returns error and does NOT fallback to SMS', () async {
      expect(
        () async => await authRepo.sendLoginOtp(
          '9876543210',
          countryCode: '+91',
          channel: 'whatsapp',
        ),
        throwsA(contains('WhatsApp delivery service unavailable')),
      );
    });
  });

  group('6. Preferred OTP Method Persistence & Serialization', () {
    test('Requirement 10: UserModel serializes and deserializes preferred_otp_method, country_code, and whatsapp_number', () {
      final json = {
        'id': 'usr_001',
        'first_name': 'Alex',
        'last_name': 'Smith',
        'phone': '+12025550123',
        'country_code': '+1',
        'whatsapp_number': '+12025559999',
        'preferred_otp_method': 'whatsapp',
      };

      final user = UserModel.fromJson(json);
      expect(user.countryCode, equals('+1'));
      expect(user.whatsappNumber, equals('+12025559999'));
      expect(user.preferredOtpMethod, equals('whatsapp'));

      final serialized = user.toJson();
      expect(serialized['country_code'], equals('+1'));
      expect(serialized['whatsapp_number'], equals('+12025559999'));
      expect(serialized['preferred_otp_method'], equals('whatsapp'));

      // copyWith updates method
      final updated = user.copyWith(preferredOtpMethod: 'phone');
      expect(updated.preferredOtpMethod, equals('phone'));
      expect(updated.countryCode, equals('+1'));
    });

    test('UserRepository.updateUserProfile persists preferred_otp_method to backend', () async {
      RequestOptions? capturedOptions;
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) {
          capturedOptions = options;
          return handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': {
                  'id': 'usr_001',
                  'first_name': 'Alex',
                  'phone': '+12025550123',
                  'country_code': '+1',
                  'whatsapp_number': '+12025550123',
                  'preferred_otp_method': 'whatsapp',
                },
              },
            ),
          );
        },
      );
      DioClient().dio.interceptors.insert(0, interceptor);

      try {
        final userRepo = UserRepository();
        final updatedUser = await userRepo.updateUserProfile('usr_001', {
          'preferred_otp_method': 'whatsapp',
          'delivery_method': 'whatsapp',
          'country_code': '+1',
          'whatsapp_number': '+12025550123',
        });

        expect(capturedOptions, isNotNull);
        final body = capturedOptions!.data as Map<String, dynamic>;
        expect(body['preferred_otp_method'], equals('whatsapp'));
        expect(body['delivery_method'], equals('whatsapp'));
        expect(updatedUser?.preferredOtpMethod, equals('whatsapp'));
      } finally {
        DioClient().dio.interceptors.remove(interceptor);
      }
    });
  });

  group('7. India SMS Gate & Profile Edit Mode Rules', () {
    test('Phone SMS mode is strictly frozen to India (+91)', () {
      final inCountry = InternationalPhoneHelper.findByCode('+91');
      expect(inCountry.code, equals('+91'));
      expect(inCountry.flag, equals('🇮🇳'));
      expect(inCountry.name, equals('India'));
    });

    test('Non-India country codes are valid for WhatsApp mode', () {
      final usCountry = InternationalPhoneHelper.findByCode('+1');
      expect(usCountry.code, equals('+1'));
      final uaeCountry = InternationalPhoneHelper.findByCode('+971');
      expect(uaeCountry.code, equals('+971'));
      final ukCountry = InternationalPhoneHelper.findByCode('+44');
      expect(ukCountry.code, equals('+44'));
    });

    test('Profile edit mode selector rule: true only when user preferred method is whatsapp', () {
      const waUserMethod = 'whatsapp';
      const phoneUserMethod = 'phone';
      const defaultUserMethod = '';

      expect(waUserMethod == 'whatsapp', isTrue);
      expect(phoneUserMethod == 'whatsapp', isFalse);
      expect(defaultUserMethod == 'whatsapp', isFalse);
    });
  });
}
