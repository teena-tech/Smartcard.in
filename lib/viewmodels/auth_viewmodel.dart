import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../core/state/app_loading_service.dart';
enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final UserRepository _userRepository = UserRepository();
  
  AuthState _state = AuthState.initial;
  String? _errorMessage;
  String? _successMessage;
  UserModel? _currentUser;
  
  // OTP flow specific
  String _otpRequestId = '';
  bool _showOtp = false;
  String _verificationToken = '';

  AuthViewModel(this._authRepository) {
    checkAuthStatus();
  }

  AuthState get state => _state;
  String get error => _errorMessage ?? '';
  String get message => _successMessage ?? '';
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _state == AuthState.authenticated && _currentUser != null;
  bool get isLoading => _state == AuthState.loading;
  
  bool get showOtp => _showOtp;
  String get verificationToken => _verificationToken;

  void resetOtpState() {
    _showOtp = false;
    _otpRequestId = '';
    _verificationToken = '';
    clearMessages();
  }

  void _setState(AuthState state, {String? error, String? success}) {
    _state = state;
    _errorMessage = error;
    _successMessage = success;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    AppLoadingService.instance.startTask();
    _setState(AuthState.loading);
    try {
      final userId = await _authRepository.getStoredUserId();
      if (userId != null) {
        // Fast path: load cached user profile first for instant app launch
        final cachedUser = await _authRepository.getCachedUser();
        if (cachedUser != null && cachedUser.id != null) {
          _currentUser = cachedUser;
          _setState(AuthState.authenticated);

          // Background revalidation
          _userRepository.getUserProfile(userId).then((user) async {
            if (user != null) {
              _currentUser = user;
              await _authRepository.saveCachedUser(user);
              notifyListeners();
            }
          }).catchError((e) async {
            if (e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
              await _authRepository.clearTokens();
              _currentUser = null;
              _setState(AuthState.unauthenticated);
            }
          });
          return;
        }

        // Slow path: try network profile if no cache exists
        try {
          final user = await _userRepository.getUserProfile(userId);
          if (user != null) {
            _currentUser = user;
            await _authRepository.saveCachedUser(user);
            _setState(AuthState.authenticated);
          } else {
            await _authRepository.clearTokens();
            _currentUser = null;
            _setState(AuthState.unauthenticated);
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
            _currentUser = null;
          }
          _setState(AuthState.unauthenticated);
        }
      } else {
        _setState(AuthState.unauthenticated);
      }
    } catch (e) {
      _setState(AuthState.unauthenticated);
    } finally {
      AppLoadingService.instance.endTask();
    }
  }


  Future<bool> sendLoginOtp(String phone) async {
    if (phone.isEmpty || phone.length < 10) {
      _setState(AuthState.error, error: 'Please enter a valid 10-digit phone number.');
      return false;
    }

    _setState(AuthState.loading);
    try {
      _otpRequestId = await _authRepository.sendLoginOtp(phone);
      
      if (_otpRequestId.isEmpty) {
        _setState(AuthState.error, error: 'Failed to send OTP. Please try again.');
        return false;
      }

      _showOtp = true;
      _setState(AuthState.unauthenticated, success: 'OTP sent successfully. Check your SMS.');
      return true;
    } catch (e) {
      String errorMsg = e.toString()
          .replaceAll('Exception: ', '')
          .replaceAll('DioException:', '')
          .trim();
      
      // Provide user-friendly error messages
      if (errorMsg.contains('Phone')) {
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

      _setState(AuthState.error, error: errorMsg);
      return false;
    } finally {
      // AppLoadingService removed
    }
  }

  Future<bool> verifyLoginOtp(String otp) async {
    _setState(AuthState.loading);
    try {
      final user = await _authRepository.verifyLoginOtp(_otpRequestId, otp);
      
      // User should never be null on success, but check anyway
      if (user == null) {
        _currentUser = null;
        _showOtp = true;
        _setState(
          AuthState.unauthenticated,
          error: 'Invalid OTP. Please try again.',
        );
        return false;
      }

      // Verify user has required ID
      if (user.id == null || user.id.toString().isEmpty) {
        _currentUser = null;
        _showOtp = true;
        _setState(
          AuthState.unauthenticated,
          error: 'Invalid OTP. Please try again.',
        );
        return false;
      }

      // OTP verified successfully
      _currentUser = user;
      _showOtp = false;
      _setState(AuthState.authenticated, success: 'Welcome back!');
      return true;
    } catch (e) {
      // OTP verification failed — keep user on OTP screen
      _currentUser = null;
      _showOtp = true;
      
      // Extract clean error message
      String errorMsg = e.toString()
          .replaceAll('Exception: ', '')
          .replaceAll('DioException:', '')
          .trim();
      
      // Provide user-friendly error messages
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
      
      _setState(AuthState.unauthenticated, error: errorMsg);
      return false;
    }
  }

  Future<bool> sendRegistrationOtp(String phone) async {
    if (phone.isEmpty || phone.length < 10) {
      _setState(AuthState.error, error: 'Please enter a valid 10-digit phone number.');
      return false;
    }

    _setState(AuthState.loading);
    try {
      _otpRequestId = await _authRepository.sendRegisterOtp(phone);
      
      if (_otpRequestId.isEmpty) {
        _setState(AuthState.error, error: 'Failed to send OTP. Please try again.');
        return false;
      }

      _showOtp = true;
      _setState(AuthState.unauthenticated, success: 'OTP sent successfully. Check your SMS.');
      return true;
    } catch (e) {
      String errorMsg = e.toString()
          .replaceAll('Exception: ', '')
          .replaceAll('DioException:', '')
          .trim();
      
      // Provide user-friendly error messages
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

      _setState(AuthState.error, error: errorMsg);
      return false;
    }
  }

  Future<bool> verifyRegistrationOtp(String otp) async {
    _setState(AuthState.loading);
    try {
      final token = await _authRepository.verifyRegisterOtp(_otpRequestId, otp);
      if (token != null) {
        _verificationToken = token;
        _setState(AuthState.unauthenticated, success: 'OTP Verified successfully.');
        return true;
      } else {
        _setState(AuthState.error, error: 'Invalid OTP');
        return false;
      }
    } catch (e) {
      _setState(AuthState.error, error: e.toString());
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> payload) async {
    _setState(AuthState.loading);
    try {
      // Add verification token to payload if needed
      final data = Map<String, dynamic>.from(payload);
      data['verification_token'] = _verificationToken;
      
      final user = await _authRepository.register(data);
      if (user != null) {
        _currentUser = user;
        _setState(AuthState.authenticated, success: 'Registration successful!');
        return true;
      }
      return false;
    } catch (e) {
      _setState(AuthState.error, error: e.toString());
      return false;
    }
  }

  Future<bool> checkPhone(String phone) async {
    try {
      return await _authRepository.checkPhone(phone);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
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
    _setState(AuthState.loading);
    try {
      await _authRepository.logout();
    } catch (_) {
      await _authRepository.clearTokens();
    } finally {
      _currentUser = null;
      _setState(AuthState.unauthenticated);
      AppLoadingService.instance.endTask();
    }
  }

  Future<bool> deleteAccount([String? targetUserId]) async {
    final userId = (targetUserId != null && targetUserId.trim().isNotEmpty)
        ? targetUserId.trim()
        : _currentUser?.id;
    if (userId == null || userId.isEmpty) {
      _errorMessage = 'User ID not found.';
      _setState(AuthState.authenticated);
      return false;
    }
    _setState(AuthState.loading);
    try {
      final success = await _userRepository.deleteUserAccount(userId);
      if (success) {
        await _authRepository.clearTokens();
        _currentUser = null;
        _setState(AuthState.unauthenticated);
        return true;
      } else {
        _errorMessage = 'Failed to delete account. Please try again.';
        _setState(AuthState.authenticated);
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _setState(AuthState.authenticated);
      return false;
    }
  }

  void updateUser(UserModel newUser) {
    _currentUser = newUser;
    notifyListeners();
  }
}

