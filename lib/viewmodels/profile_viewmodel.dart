import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../repositories/user_repository.dart';
import '../core/state/app_loading_service.dart';

enum ProfileState { initial, loading, loaded, error }

class ProfileViewModel extends ChangeNotifier {
  final UserRepository _repository;

  ProfileState _state       = ProfileState.initial;
  String?      _errorMessage;
  String?      _successMessage;
  UserModel?   _user;

  /// Separate flag so the avatar spinner shows independently
  bool _isUploadingImage = false;

  String? _otpRequestId;
  int _imageVersion = 0;

  ProfileViewModel(this._repository);

  // ── Getters ────────────────────────────────────────────────
  ProfileState get state          => _state;
  String?      get errorMessage   => _errorMessage;
  String?      get successMessage => _successMessage;
  UserModel?   get user           => _user;
  bool         get isLoading      => _state == ProfileState.loading;
  bool         get isUploadingImage => _isUploadingImage;
  int          get imageVersion     => _imageVersion;
  String?      get otpRequestId   => _otpRequestId;

  // ── Private helpers ────────────────────────────────────────
  void _setState(ProfileState state, {String? error, String? success}) {
    _state         = state;
    _errorMessage  = error;
    _successMessage = success;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage   = null;
    _successMessage = null;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    _state = ProfileState.initial;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // ── Load profile ───────────────────────────────────────────
  Future<void> loadProfile(String userId) async {
    _setState(ProfileState.loading);
    try {
      final userData = await _repository.getUserProfile(userId);
      _user = userData;
      _setState(ProfileState.loaded);
    } catch (e) {
      _setState(ProfileState.error, error: e.toString());
    }
  }

  // ── Update profile ─────────────────────────────────────────
  Future<bool> updateProfile(
      String userId, Map<String, dynamic> updateData) async {
    _setState(ProfileState.loading);
    try {
      final updatedUser =
          await _repository.updateUserProfile(userId, updateData);
      if (updatedUser != null) {
        _user = updatedUser;
        _setState(ProfileState.loaded,
            success: 'Profile updated successfully.');
        return true;
      }
      _setState(ProfileState.error, error: 'Update returned empty response.');
      return false;
    } catch (e) {
      _setState(ProfileState.error, error: e.toString());
      return false;
    }
  }

  // ── Increment stats (silent) ───────────────────────────────
  Future<void> incrementScanCount(String userId) async {
    if (_user == null) return;
    final currentScans = _user!.contactScans ?? 0;
    _user = _user!.copyWith(contactScans: currentScans + 1);
    notifyListeners();
    try {
      await _repository.updateUserProfile(
        userId,
        {'contact_scans': currentScans + 1},
      );
    } catch (_) {}
  }

  Future<void> incrementShareCount(String userId) async {
    if (_user == null) return;
    final currentShares = _user!.shareCount ?? 0;
    _user = _user!.copyWith(shareCount: currentShares + 1);
    notifyListeners();
    try {
      await _repository.updateUserProfile(
        userId,
        {'share_count': currentShares + 1, 'shares': currentShares + 1},
      );
    } catch (_) {}
  }
  
  Future<void> incrementCardViews(String userId) async {
    if (_user != null && _user!.id == userId) {
       final currentViews = _user!.cardViews ?? 0;
       _user = _user!.copyWith(cardViews: currentViews + 1);
       notifyListeners();
       try {
         await _repository.updateUserProfile(
           userId,
           {'card_views': currentViews + 1, 'views': currentViews + 1},
         );
       } catch (_) {}
    } else {
       try {
         await _repository.updateUserProfile(userId, {'increment_view': true});
       } catch (_) {}
    }
  }

  // ── Upload profile image (crash-safe) ──────────────────────
  /// Returns true on success. Never throws — all errors are
  /// surfaced via [errorMessage] so the UI never crashes.
  Future<bool> uploadProfileImageSafe(
      String userId, String imagePath) async {
    _isUploadingImage = true;
    _errorMessage     = null;
    notifyListeners();
    AppLoadingService.instance.startTask();

    try {
      final response =
          await _repository.uploadProfileImage(userId, imagePath, null);
      if (response != null) {
        // Reload profile to get fresh image URL
        await loadProfile(userId);
        _imageVersion++;
        _successMessage = 'Profile picture updated successfully.';
        notifyListeners();
        _isUploadingImage = false;
        notifyListeners();
        return true;
      }
      _errorMessage     = 'Upload failed — server returned empty response.';
      _isUploadingImage = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage     = 'Image upload failed: ${e.toString()}';
      _isUploadingImage = false;
      notifyListeners();
      return false;
    } finally {
      AppLoadingService.instance.endTask();
    }
  }

  // ── Remove profile image ───────────────────────────────────
  Future<bool> removeProfileImage(String userId) async {
    _isUploadingImage = true;
    notifyListeners();
    AppLoadingService.instance.startTask();
    try {
      // 1. Send update to API to clear profile image on backend
      try {
        await _repository.updateUserProfile(userId, {
          'profile_image': '',
          'image': '',
        });
      } catch (_) {}

      // 2. Clear local profile image state immediately
      if (_user != null) {
        _user = _user!.copyWith(profileImage: '');
      }
      _imageVersion++;
      _successMessage = 'Profile photo removed successfully.';
      _isUploadingImage = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage     = 'Failed to remove image: ${e.toString()}';
      _isUploadingImage = false;
      notifyListeners();
      return false;
    } finally {
      AppLoadingService.instance.endTask();
    }
  }


  // ── Legacy upload (kept for CardViewModel compatibility) ───
  Future<bool> uploadProfileImage(
      String userId, String imagePath) async {
    return uploadProfileImageSafe(userId, imagePath);
  }

  // ── OTP flow ───────────────────────────────────────────────
  Future<bool> sendProfileOtp(String userId, String phone) async {
    _setState(ProfileState.loading);
    try {
      final res = await _repository.sendProfileOtp(userId, phone);
      if (res != null) {
        // Check for explicit failure flags
        if (res['success'] == false || res['error'] != null) {
          final errMsg = (res['message'] ?? res['error'] ?? 'Failed to send OTP').toString();
          _setState(ProfileState.error, error: errMsg);
          return false;
        }
        // Extract request_id from any plausible field name
        final reqId = (res['request_id'] ??
                res['otp_request_id'] ??
                res['requestId'] ??
                res['id'] ??
                res['data']?['request_id'] ??
                res['data']?['otp_request_id'])
            ?.toString();
        _otpRequestId = reqId;
        _setState(ProfileState.loaded, success: 'OTP sent successfully.');
        return true;
      }
      _setState(ProfileState.error, error: 'Failed to send OTP');
      return false;
    } catch (e) {
      _setState(ProfileState.error, error: e.toString());
      return false;
    }
  }

  Future<bool> verifyProfileOtp(String userId, String otp) async {
    // If no request_id, still attempt verification — some backends don't return one
    _setState(ProfileState.loading);
    try {
      final res =
          await _repository.verifyProfileOtp(userId, _otpRequestId ?? '', otp);
      // Accept any non-null 200/201 response as success.
      // Backend may return {success:true}, {status:'verified'}, or {verified:true} etc.
      if (res != null) {
        // Check for explicit failure flags first
        if (res['success'] == false ||
            res['status'] == 'error' ||
            res['error'] != null ||
            res['verified'] == false) {
          final errMsg = (res['message'] ?? res['error'] ?? 'Invalid OTP. Please try again.').toString();
          // Do NOT clear _otpRequestId on failure — user can retry
          _setState(ProfileState.error, error: errMsg);
          return false;
        }
        // Only clear on SUCCESS
        _otpRequestId = null;
        _setState(ProfileState.loaded, success: 'OTP verified successfully.');
        return true;
      }
      // null response = wrong OTP or network issue, preserve _otpRequestId for retry
      _setState(ProfileState.error, error: 'Invalid OTP. Please try again.');
      return false;
    } catch (e) {
      _setState(ProfileState.error, error: e.toString());
      return false;
    }
  }

  // ── Gallery upload ─────────────────────────────────────────
  Future<bool> uploadGalleryImages(
      String userId, List<XFile> files) async {
    _setState(ProfileState.loading);
    try {
      final response =
          await _repository.uploadGalleryImages(userId, files);
      if (response != null) {
        await loadProfile(userId);
        _setState(ProfileState.loaded,
            success: 'Gallery updated successfully.');
        return true;
      }
      return false;
    } catch (e) {
      _setState(ProfileState.error, error: e.toString());
      return false;
    }
  }
}
