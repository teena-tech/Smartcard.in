import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:smartcard_flutter/core/di/app_loading_notifier.dart';
import 'package:smartcard_flutter/core/services/otp_autofill_service.dart';
import 'package:smartcard_flutter/core/services/firebase_contact_sync_service.dart';
import 'package:smartcard_flutter/core/utils/international_phone_helper.dart';
import 'package:smartcard_flutter/features/profile_screen/data/models/user_model.dart';
import 'package:smartcard_flutter/features/profile_screen/data/repositories/user_repository.dart';
import 'package:smartcard_flutter/features/login_screen/data/repositories/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

@immutable
class AuthUiState {
  final AuthStatus status;
  final String? errorMessage;
  final String? successMessage;
  final UserModel? currentUser;
  final String otpRequestId;
  final bool showOtp;
  final String verificationToken;

  const AuthUiState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.successMessage,
    this.currentUser,
    this.otpRequestId = '',
    this.showOtp = false,
    this.verificationToken = '',
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && currentUser != null;
  bool get isLoading => status == AuthStatus.loading;
  String get error => errorMessage ?? '';
  String get message => successMessage ?? '';
  void clearMessages() {}
  void resetOtpState() {}

  AuthUiState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? successMessage,
    UserModel? currentUser,
    String? otpRequestId,
    bool? showOtp,
    String? verificationToken,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearUser = false,
  }) {
    return AuthUiState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      otpRequestId: otpRequestId ?? this.otpRequestId,
      showOtp: showOtp ?? this.showOtp,
      verificationToken: verificationToken ?? this.verificationToken,
    );
  }
}

class AuthViewModel extends Notifier<AuthUiState> {
  late final AuthRepository _authRepository;
  late final UserRepository _userRepository;

  @override
  AuthUiState build() {
    _authRepository = AuthRepository();
    _userRepository = UserRepository();
    Future.microtask(() => checkAuthStatus());
    return const AuthUiState();
  }

  // Getters for convenience
  AuthStatus get status => state.status;
  AuthStatus get authState => state.status;
  String get error => state.error;
  String get message => state.message;
  String? get errorMessage => state.errorMessage;
  String? get successMessage => state.successMessage;
  UserModel? get currentUser => state.currentUser;
  bool get isAuthenticated => state.isAuthenticated;
  bool get isLoading => state.isLoading;
  bool get showOtp => state.showOtp;
  String get verificationToken => state.verificationToken;

  void resetOtpState() {
    state = state.copyWith(
      showOtp: false,
      otpRequestId: '',
      verificationToken: '',
      clearError: true,
      clearSuccess: true,
    );
  }

  void _setState(AuthStatus status, {String? error, String? success}) {
    state = state.copyWith(
      status: status,
      errorMessage: error,
      successMessage: success,
      clearError: error == null,
      clearSuccess: success == null,
    );
    if (status == AuthStatus.authenticated && state.currentUser?.id != null && state.currentUser!.id!.isNotEmpty) {
      FirebaseContactSyncService().syncAllLocalScansToFirebase(userId: state.currentUser!.id);
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  Future<void> checkAuthStatus() async {
    AppLoadingService.instance.startTask();
    _setState(AuthStatus.loading);
    try {
      final userId = await _authRepository.getStoredUserId();
      if (userId != null) {
        final cachedUser = await _authRepository.getCachedUser();
        if (cachedUser != null && cachedUser.id != null) {
          state = state.copyWith(currentUser: cachedUser);
          _setState(AuthStatus.authenticated);

          _userRepository.getUserProfile(userId).then((user) async {
            if (user != null) {
              state = state.copyWith(currentUser: user);
              await _authRepository.saveCachedUser(user);
            }
          }).catchError((e) async {
            if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
              await _authRepository.clearTokens();
              state = state.copyWith(clearUser: true);
              _setState(AuthStatus.unauthenticated);
            }
          });
          return;
        }

        try {
          final user = await _userRepository.getUserProfile(userId);
          if (user != null) {
            state = state.copyWith(currentUser: user);
            await _authRepository.saveCachedUser(user);
            _setState(AuthStatus.authenticated);
          } else {
            await _authRepository.clearTokens();
            state = state.copyWith(clearUser: true);
            _setState(AuthStatus.unauthenticated);
          }
        } catch (e) {
          bool isSessionExpired = false;
          if (e is DioException) {
            final statusCode = e.response?.statusCode;
            if (statusCode == 401 || statusCode == 403) {
              isSessionExpired = true;
            }
          }
          if (isSessionExpired) {
            await _authRepository.clearTokens();
            state = state.copyWith(clearUser: true);
          }
          _setState(AuthStatus.unauthenticated);
        }
      } else {
        _setState(AuthStatus.unauthenticated);
      }
    } catch (e) {
      _setState(AuthStatus.unauthenticated);
    } finally {
      AppLoadingService.instance.endTask();
    }
  }

  Future<bool> sendLoginOtp(
    String phone, {
    String channel = 'phone',
    String countryCode = '+91',
    String? whatsappNumber,
  }) async {
    final isWhatsApp = channel.toLowerCase() == 'whatsapp';
    final targetNumber = (isWhatsApp && whatsappNumber != null && whatsappNumber.trim().isNotEmpty)
        ? whatsappNumber
        : phone;

    final validationError = InternationalPhoneHelper.validatePhoneNumber(
      phone: targetNumber,
      countryCode: countryCode,
      isWhatsApp: isWhatsApp,
    );
    if (validationError != null) {
      _setState(AuthStatus.error, error: validationError);
      return false;
    }

    _setState(AuthStatus.loading);
    try {
      final reqId = await _authRepository.sendLoginOtp(
        phone,
        channel: channel,
        countryCode: countryCode,
        whatsappNumber: whatsappNumber,
      );

      if (reqId.isEmpty) {
        _setState(AuthStatus.error, error: 'Failed to send OTP. Please try again.');
        return false;
      }

      final successMsg = isWhatsApp
          ? 'OTP sent successfully to your WhatsApp.'
          : 'OTP sent successfully. Check your SMS.';
      state = state.copyWith(
        otpRequestId: reqId,
        showOtp: true,
        status: AuthStatus.unauthenticated,
        successMessage: successMsg,
        clearError: true,
      );
      return true;
    } catch (e) {
      String errorMsg = e.toString()
          .replaceAll('Exception: ', '')
          .replaceAll('DioException:', '')
          .trim();

      if (errorMsg.toLowerCase().contains('user not found') ||
          errorMsg.toLowerCase().contains('not registered')) {
        errorMsg = 'This phone number is not registered. Please register first.';
      } else if (errorMsg.contains('401')) {
        errorMsg = 'Authentication failed. Please try again.';
      } else if (errorMsg.contains('500')) {
        errorMsg = 'Server error. Please try again later.';
      } else if (errorMsg.contains('No internet') ||
          errorMsg.contains('Connection') ||
          errorMsg.contains('timeout')) {
        errorMsg = 'No internet connection. Please check your connection and try again.';
      } else if (errorMsg.contains('Network')) {
        errorMsg = 'Network error. Please check your connection and try again.';
      } else if (errorMsg.isEmpty) {
        errorMsg = 'Failed to send OTP. Please try again.';
      }

      _setState(AuthStatus.error, error: errorMsg);
      return false;
    }
  }

  Future<bool> verifyLoginOtp(String otp) async {
    _setState(AuthStatus.loading);
    try {
      final user = await _authRepository.verifyLoginOtp(state.otpRequestId, otp);

      if (user == null || user.id == null || user.id.toString().isEmpty) {
        state = state.copyWith(
          clearUser: true,
          showOtp: true,
          status: AuthStatus.unauthenticated,
          errorMessage: 'Invalid OTP. Please try again.',
        );
        return false;
      }

      state = state.copyWith(
        currentUser: user,
        showOtp: false,
        status: AuthStatus.authenticated,
        successMessage: 'Welcome back!',
        clearError: true,
      );
      return true;
    } catch (e) {
      String errorMsg = e.toString()
          .replaceAll('Exception: ', '')
          .replaceAll('DioException:', '')
          .trim();

      if (errorMsg.contains('401')) {
        errorMsg = 'Invalid OTP. Please try again.';
      } else if (errorMsg.contains('500')) {
        errorMsg = 'Server error. Please try again later.';
      } else if (errorMsg.contains('No internet') ||
          errorMsg.contains('Connection') ||
          errorMsg.contains('timeout')) {
        errorMsg = 'No internet connection. Please check and try again.';
      } else if (errorMsg.isEmpty) {
        errorMsg = 'Invalid OTP. Please try again.';
      }

      state = state.copyWith(
        clearUser: true,
        showOtp: true,
        status: AuthStatus.unauthenticated,
        errorMessage: errorMsg,
      );
      return false;
    }
  }

  Future<bool> sendRegistrationOtp(
    String phone, {
    String channel = 'phone',
    String countryCode = '+91',
    String? whatsappNumber,
  }) async {
    final isWhatsApp = channel.toLowerCase() == 'whatsapp';
    final targetNumber = (isWhatsApp && whatsappNumber != null && whatsappNumber.trim().isNotEmpty)
        ? whatsappNumber
        : phone;

    final validationError = InternationalPhoneHelper.validatePhoneNumber(
      phone: targetNumber,
      countryCode: countryCode,
      isWhatsApp: isWhatsApp,
    );
    if (validationError != null) {
      _setState(AuthStatus.error, error: validationError);
      return false;
    }

    _setState(AuthStatus.loading);
    try {
      final reqId = await _authRepository.sendRegisterOtp(
        phone,
        channel: channel,
        countryCode: countryCode,
        whatsappNumber: whatsappNumber,
      );

      if (reqId.isEmpty) {
        _setState(AuthStatus.error, error: 'Failed to send OTP. Please try again.');
        return false;
      }

      final successMsg = isWhatsApp
          ? 'OTP sent successfully to your WhatsApp.'
          : 'OTP sent successfully. Check your SMS.';
      state = state.copyWith(
        otpRequestId: reqId,
        showOtp: true,
        status: AuthStatus.unauthenticated,
        successMessage: successMsg,
        clearError: true,
      );
      return true;
    } catch (e) {
      String errorMsg = e.toString()
          .replaceAll('Exception: ', '')
          .replaceAll('DioException:', '')
          .trim();

      if (errorMsg.contains('already')) {
        errorMsg = 'This phone number is already registered. Please login instead.';
      } else if (errorMsg.contains('401')) {
        errorMsg = 'Authentication failed. Please try again.';
      } else if (errorMsg.contains('500')) {
        errorMsg = 'Server error. Please try again later.';
      } else if (errorMsg.contains('No internet') ||
          errorMsg.contains('Connection') ||
          errorMsg.contains('timeout')) {
        errorMsg = 'No internet connection. Please check your connection and try again.';
      } else if (errorMsg.contains('Network')) {
        errorMsg = 'Network error. Please check your connection and try again.';
      } else if (errorMsg.isEmpty) {
        errorMsg = 'Failed to send OTP. Please try again.';
      }

      _setState(AuthStatus.error, error: errorMsg);
      return false;
    }
  }

  Future<bool> verifyRegistrationOtp(String otp) async {
    _setState(AuthStatus.loading);
    try {
      final token = await _authRepository.verifyRegisterOtp(state.otpRequestId, otp);
      if (token != null) {
        state = state.copyWith(
          verificationToken: token,
          status: AuthStatus.unauthenticated,
          successMessage: 'OTP Verified successfully.',
          clearError: true,
        );
        return true;
      } else {
        _setState(AuthStatus.error, error: 'Invalid OTP');
        return false;
      }
    } catch (e) {
      _setState(AuthStatus.error, error: e.toString());
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> payload) async {
    _setState(AuthStatus.loading);
    try {
      final data = Map<String, dynamic>.from(payload);
      data['verification_token'] = state.verificationToken;

      final user = await _authRepository.register(data);
      if (user != null) {
        state = state.copyWith(
          currentUser: user,
          status: AuthStatus.authenticated,
          successMessage: 'Registration successful!',
          clearError: true,
        );
        return true;
      }
      return false;
    } catch (e) {
      _setState(AuthStatus.error, error: e.toString());
      return false;
    }
  }

  Future<bool> checkPhone(String phone, {String countryCode = '+91'}) async {
    try {
      return await _authRepository.checkPhone(phone, countryCode: countryCode);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchPincodeDetails(String pincode) async {
    try {
      return await _authRepository.fetchPincodeDetails(pincode);
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    AppLoadingService.instance.startTask();
    _setState(AuthStatus.loading);
    try {
      await _authRepository.logout();
    } catch (_) {
      await _authRepository.clearTokens();
    } finally {
      resetOtpState();
      try {
        await OtpAutofillService().stopListening();
      } catch (_) {}
      state = state.copyWith(clearUser: true, status: AuthStatus.unauthenticated);
      AppLoadingService.instance.endTask();
    }
  }

  Future<bool> deleteAccount([String? targetUserId]) async {
    final userId = (targetUserId != null && targetUserId.trim().isNotEmpty)
        ? targetUserId.trim()
        : state.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _setState(AuthStatus.authenticated, error: 'User ID not found.');
      return false;
    }
    _setState(AuthStatus.loading);
    try {
      final success = await _userRepository.deleteUserAccount(userId);
      if (success) {
        await _authRepository.clearTokens();
        state = state.copyWith(clearUser: true, status: AuthStatus.unauthenticated);
        return true;
      } else {
        _setState(AuthStatus.authenticated, error: 'Failed to delete account. Please try again.');
        return false;
      }
    } catch (e) {
      String err = e.toString().replaceAll('Exception: ', '').trim();
      if (err.isEmpty) err = 'Failed to delete account. Please try again.';
      _setState(AuthStatus.authenticated, error: err);
      return false;
    }
  }

  void updateUser(UserModel newUser) {
    state = state.copyWith(currentUser: newUser);
  }
}

final authViewModelProvider =
    NotifierProvider<AuthViewModel, AuthUiState>(AuthViewModel.new);
