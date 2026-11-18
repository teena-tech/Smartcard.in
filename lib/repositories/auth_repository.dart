import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../core/services/dio_client.dart';
import '../core/services/api_config.dart';
import '../models/user_model.dart';
import '../core/utils/international_phone_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  final DioClient _dioClient = DioClient();

  /// Sends a login OTP request
  Future<String> sendLoginOtp(
    String phone, {
    String channel = 'phone',
    String countryCode = '+91',
    String? whatsappNumber,
  }) async {
    try {
      final formattedPhone = InternationalPhoneHelper.formatForBackend(
        phone: phone,
        countryCode: countryCode,
      );
      final e164 = InternationalPhoneHelper.toE164(
        phone: phone,
        countryCode: countryCode,
      );

      final isWhatsApp = channel.toLowerCase() == 'whatsapp';
      final deliveryChannel = isWhatsApp ? 'whatsapp' : 'phone';

      final Map<String, dynamic> body = {
        'phone': formattedPhone,
        'country_code': countryCode,
        'full_phone': e164,
        'otp_check_only': false,
        'channel': deliveryChannel,
        'otp_channel': deliveryChannel,
        'delivery_method': deliveryChannel,
      };

      if (isWhatsApp) {
        if (whatsappNumber != null && whatsappNumber.trim().isNotEmpty) {
          body['whatsapp_number'] = InternationalPhoneHelper.formatForBackend(
            phone: whatsappNumber,
            countryCode: countryCode,
          );
        } else {
          body['whatsapp_number'] = formattedPhone;
        }
      }

      final response = await _dioClient.dio.post(
        ApiConfig.login,
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data['request_id'] != null) {
          return data['request_id'].toString();
        }
      }
      throw 'Failed to send OTP';
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to send OTP');
    }
  }

  /// Verifies login OTP and saves tokens
  /// 
  /// Returns UserModel if OTP is valid and verified successfully.
  /// Throws exception if OTP is invalid, network error, or API returns error.
  /// NEVER returns null or silently fails - always either succeeds or throws.
  Future<UserModel?> verifyLoginOtp(String requestId, String code) async {
    if (requestId.isEmpty || code.length != 6) {
      throw 'Invalid OTP request';
    }
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.verifyOtp,
        data: {'request_id': requestId, 'otp': code},
      );

      // Validate HTTP status first
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw 'Invalid OTP. Please try again.';
      }

      final data = response.data;
      
      // Strict validation: data must be a Map
      if (data is! Map) {
        throw 'Invalid OTP. Please try again.';
      }

      // Check for explicit error conditions from backend
      if (data['success'] == false) {
        throw data['message'] ?? 'Invalid OTP. Please try again.';
      }
      if (data['status'] == 'error') {
        throw data['message'] ?? data['error'] ?? 'Invalid OTP. Please try again.';
      }
      if (data['error'] != null) {
        throw data['message'] ?? data['error'] ?? 'Invalid OTP. Please try again.';
      }

      // Verify success is explicitly true (not just "not false")
      if (data['success'] != true) {
        throw 'Invalid OTP. Please try again.';
      }

      // Extract user data - REQUIRED for successful OTP verification
      final rawUser = data['user'] ?? data['data'];
      if (rawUser == null || rawUser is! Map) {
        throw 'Invalid OTP. Please try again.';
      }

      // Parse user model
      final user = UserModel.fromJson(Map<String, dynamic>.from(rawUser));
      
      // User must have an ID
      if (user.id == null || user.id.toString().isEmpty) {
        throw 'Invalid OTP. Please try again.';
      }

      // CRITICAL: Verify tokens are present before saving any user data
      final token = data['token']?.toString();
      final sessionId = data['session_id']?.toString();
      
      if (token == null || token.isEmpty || sessionId == null || sessionId.isEmpty) {
        throw 'Invalid OTP. Please try again.';
      }

      // Save tokens FIRST
      try {
        await _dioClient.saveTokens(token, sessionId);
      } catch (e) {
        throw 'Failed to save session. Please try again.';
      }

      // Save user_id to secure storage
      try {
        const storage = FlutterSecureStorage();
        await storage.write(key: 'user_id', value: user.id.toString());
      } catch (e) {
        // Fallback to shared preferences if secure storage fails
        debugPrint('Secure storage write failed: $e, using shared preferences');
      }

      // Save user_id and profile to shared preferences as fallback
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', user.id.toString());
        await prefs.setString('cached_user_profile', jsonEncode(user.toJson()));
      } catch (e) {
        debugPrint('SharedPreferences write failed: $e');
        // Don't fail completely if this fails
      }

      return user;
    } on DioException catch (e) {
      // Handle network errors gracefully
      final errorMsg = DioClient.getErrorMessage(e, 'OTP verification failed');
      
      // Distinguish between network errors and API errors
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw 'No internet connection. Please check your connection and try again.';
      }
      
      throw errorMsg;
    } catch (e) {
      // Always clear any partial user data on failure
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_id');
        await prefs.remove('cached_user_profile');
      } catch (_) {
        // Ignore cleanup errors
      }
      rethrow;
    }
  }

  /// Checks if a phone number is already registered
  Future<bool> checkPhone(String phone, {String countryCode = '+91'}) async {
    try {
      final formattedPhone = InternationalPhoneHelper.formatForBackend(
        phone: phone,
        countryCode: countryCode,
      );
      final e164 = InternationalPhoneHelper.toE164(
        phone: phone,
        countryCode: countryCode,
      );
      final response = await _dioClient.dio.post(
        ApiConfig.checkPhone,
        data: {
          'phone': formattedPhone,
          'country_code': countryCode,
          'full_phone': e164,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Phone check failed');
    }
  }

  /// Logs out the user
  Future<void> logout() async {
    try {
      await _dioClient.dio.post(ApiConfig.logout).timeout(
        const Duration(seconds: 3),
        onTimeout: () => Response(
          requestOptions: RequestOptions(path: ApiConfig.logout),
          statusCode: 408,
        ),
      );
    } catch (e) {
      // Ignore errors on logout
    } finally {
      await clearTokens();
    }
  }

  /// Sends an OTP for registration
  Future<String> sendOtp(
    String identifier, {
    String channel = 'phone',
    String countryCode = '+91',
    String? whatsappNumber,
  }) async {
    try {
      final formattedPhone = InternationalPhoneHelper.formatForBackend(
        phone: identifier,
        countryCode: countryCode,
      );
      final e164 = InternationalPhoneHelper.toE164(
        phone: identifier,
        countryCode: countryCode,
      );

      final isWhatsApp = channel.toLowerCase() == 'whatsapp';
      final deliveryChannel = isWhatsApp ? 'whatsapp' : 'phone';

      final Map<String, dynamic> body = {
        'phone': formattedPhone,
        'country_code': countryCode,
        'full_phone': e164,
        'channel': deliveryChannel,
        'otp_channel': deliveryChannel,
        'delivery_method': deliveryChannel,
      };

      if (isWhatsApp) {
        if (whatsappNumber != null && whatsappNumber.trim().isNotEmpty) {
          body['whatsapp_number'] = InternationalPhoneHelper.formatForBackend(
            phone: whatsappNumber,
            countryCode: countryCode,
          );
        } else {
          body['whatsapp_number'] = formattedPhone;
        }
      }

      final response = await _dioClient.dio.post(
        ApiConfig.sendRegistrationOtp,
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final reqId = response.data['request_id']?.toString();
        if (reqId == null || reqId.isEmpty) {
          throw 'Failed to send OTP: no request ID received';
        }
        return reqId;
      }
      throw 'Failed to send OTP';
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to send OTP');
    }
  }

  /// Verifies an OTP
  Future<String?> verifyOtp(String requestId, String code) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.verifyRegistrationOtp,
        data: {'request_id': requestId, 'otp': code},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map) {
          if (data['success'] == false || data['status'] == 'error' || data['error'] != null) {
            throw data['message'] ?? data['error'] ?? 'Invalid OTP';
          }
        }
        return data['verification_token']?.toString();
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Invalid OTP');
    }
  }

  /// Completes the registration process
  Future<UserModel?> register(Map<String, dynamic> registrationData) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConfig.completeRegistration,
        data: registrationData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        // Save tokens
        if (data['token'] != null && data['session_id'] != null) {
          await _dioClient.saveTokens(data['token'], data['session_id']);
        }

        final userData = data['user'] ?? data['data'] ?? data;
        final user = UserModel.fromJson(userData);
        if (user.id != null) {
          try {
            const storage = FlutterSecureStorage();
            await storage.write(key: 'user_id', value: user.id.toString());
          } catch (_) {
            // Secure storage may fail on Web/Windows, fallback to shared preferences
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', user.id.toString());
          await prefs.setString('cached_user_profile', jsonEncode(user.toJson()));
        }
        return user;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Registration failed');
    }
  }

  /// Fetches pincode details (city, district, state, offices) from database
  Future<Map<String, dynamic>?> fetchPincodeDetails(String pincode) async {
    try {
      final response = await _dioClient.dio.get(
        ApiConfig.pincode(pincode),
        options: Options(headers: {'x-background-sync': 'true'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to fetch pincode details');
    }
  }

  /// Fetches welcome slides from API
  Future<List<Map<String, dynamic>>> fetchWelcomeSlides() async {
    try {
      final response = await _dioClient.dio.get(ApiConfig.welcomeSlides);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is List) {
          return List<Map<String, dynamic>>.from(response.data);
        }
      }
      return [];
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to fetch welcome slides');
    } catch (e) {
      return [];
    }
  }

  // UI Proxy Methods
  Future<String?> getStoredUserId() async {
    try {
      const storage = FlutterSecureStorage();
      final secureUserId = await storage.read(key: 'user_id');
      if (secureUserId != null) return secureUserId;
    } catch (e) {
      // Secure storage might fail on Windows/Web, fall back to shared preferences
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_id');
    } catch (_) {}
    return null;
  }

  Future<String> sendRegisterOtp(
    String phone, {
    String channel = 'phone',
    String countryCode = '+91',
    String? whatsappNumber,
  }) {
    return sendOtp(
      phone,
      channel: channel,
      countryCode: countryCode,
      whatsappNumber: whatsappNumber,
    );
  }

  Future<String?> verifyRegisterOtp(String requestId, String code) {
    return verifyOtp(requestId, code);
  }

  Future<void> saveCachedUser(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile', jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<UserModel?> getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('cached_user_profile');
      if (userStr != null) {
        return UserModel.fromJson(jsonDecode(userStr));
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearTokens() async {
    await _dioClient.clearTokens();
    const storage = FlutterSecureStorage();
    try {
      await storage.deleteAll();
    } catch (_) {
      await storage.delete(key: 'user_id');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('cached_user_profile');
    await prefs.remove('cached_device_app_contacts_v1');
    await prefs.remove('cached_smart_card_count_v1');
    await prefs.remove('cached_scanned_count_v1');
    await prefs.remove('cached_phone_count_v1');
    await prefs.remove('stats_lifetime_scan_count');
    await prefs.remove('stats_scanned_cards');
  }
}

