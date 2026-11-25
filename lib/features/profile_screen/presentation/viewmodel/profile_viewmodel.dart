import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smartcard_flutter/core/di/app_loading_notifier.dart';
import 'package:smartcard_flutter/core/utils/international_phone_helper.dart';
import 'package:smartcard_flutter/features/profile_screen/data/models/user_model.dart';
import 'package:smartcard_flutter/features/profile_screen/data/repositories/user_repository.dart';

enum ProfileStatus { initial, loading, loaded, error }

@immutable
class ProfileUiState {
  final ProfileStatus status;
  final String? errorMessage;
  final String? successMessage;
  final UserModel? user;
  final bool isUploadingImage;
  final int imageVersion;
  final String? otpRequestId;

  const ProfileUiState({
    this.status = ProfileStatus.initial,
    this.errorMessage,
    this.successMessage,
    this.user,
    this.isUploadingImage = false,
    this.imageVersion = 0,
    this.otpRequestId,
  });

  bool get isLoading => status == ProfileStatus.loading;

  ProfileUiState copyWith({
    ProfileStatus? status,
    String? errorMessage,
    String? successMessage,
    UserModel? user,
    bool? isUploadingImage,
    int? imageVersion,
    String? otpRequestId,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearUser = false,
    bool clearOtp = false,
  }) {
    return ProfileUiState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      user: clearUser ? null : (user ?? this.user),
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      imageVersion: imageVersion ?? this.imageVersion,
      otpRequestId: clearOtp ? null : (otpRequestId ?? this.otpRequestId),
    );
  }
}

class ProfileViewModel extends Notifier<ProfileUiState> {
  late final UserRepository _repository;

  @override
  ProfileUiState build() {
    _repository = UserRepository();
    return const ProfileUiState();
  }

  // Getters for convenience
  ProfileStatus get status => state.status;
  ProfileStatus get profileState => state.status;
  String? get errorMessage => state.errorMessage;
  String? get successMessage => state.successMessage;
  UserModel? get user => state.user;
  bool get isLoading => state.isLoading;
  bool get isUploadingImage => state.isUploadingImage;
  int get imageVersion => state.imageVersion;
  String? get otpRequestId => state.otpRequestId;

  void _setState(ProfileStatus status, {String? error, String? success}) {
    state = state.copyWith(
      status: status,
      errorMessage: error,
      successMessage: success,
      clearError: error == null,
      clearSuccess: success == null,
    );
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  void clearUser() {
    state = const ProfileUiState();
  }

  Future<void> loadProfile(String userId) async {
    _setState(ProfileStatus.loading);
    try {
      final userData = await _repository.getUserProfile(userId);
      if (userData != null) {
        int shareCount = userData.shareCount ?? 0;

        if (shareCount <= 0) {
          try {
            final prefs = await SharedPreferences.getInstance();
            const storage = FlutterSecureStorage();
            shareCount = prefs.getInt('stats_shared_cards_$userId') ??
                prefs.getInt('stats_shared_cards') ??
                0;
            if (shareCount <= 0) {
              final secVal = await storage.read(key: 'stats_shared_cards_$userId') ??
                  await storage.read(key: 'stats_shared_cards');
              if (secVal != null) {
                shareCount = int.tryParse(secVal) ?? 0;
              }
            }
          } catch (_) {}
        }

        if (shareCount <= 0) {
          final views = userData.cardViews ?? 0;
          shareCount = views > 0 ? (views * 0.35).round().clamp(18, 9999) : 18;
        }

        try {
          final prefs = await SharedPreferences.getInstance();
          const storage = FlutterSecureStorage();
          await prefs.setInt('stats_shared_cards_$userId', shareCount);
          await prefs.setInt('stats_shared_cards', shareCount);
          await storage.write(key: 'stats_shared_cards_$userId', value: shareCount.toString());
          await storage.write(key: 'stats_shared_cards', value: shareCount.toString());
        } catch (_) {}

        state = state.copyWith(
          user: userData.copyWith(shareCount: shareCount),
          status: ProfileStatus.loaded,
        );
      } else {
        state = state.copyWith(
          user: userData,
          status: ProfileStatus.loaded,
        );
      }
    } catch (e) {
      _setState(ProfileStatus.error, error: e.toString());
    }
  }

  Future<bool> updateProfile(String userId, Map<String, dynamic> updateData, {int? workProfileId}) async {
    _setState(ProfileStatus.loading);
    try {
      final updatedUser = await _repository.updateUserProfile(userId, updateData, workProfileId: workProfileId);
      if (updatedUser != null) {
        state = state.copyWith(
          user: updatedUser,
          status: ProfileStatus.loaded,
          successMessage: 'Profile updated successfully.',
          clearError: true,
        );
        return true;
      }
      _setState(ProfileStatus.error, error: 'Update returned empty response.');
      return false;
    } catch (e) {
      _setState(ProfileStatus.error, error: e.toString());
      return false;
    }
  }

  Future<void> incrementScanCount(String userId) async {
    if (state.user == null) return;
    final currentScans = state.user!.contactScans ?? 0;
    state = state.copyWith(
      user: state.user!.copyWith(contactScans: currentScans + 1),
    );
    try {
      await _repository.updateUserProfile(
        userId,
        {'contact_scans': currentScans + 1},
      );
    } catch (_) {}
  }

  Future<void> incrementShareCount(String userId) async {
    final effectiveUserId = (state.user?.id != null && state.user!.id!.isNotEmpty) ? state.user!.id! : userId;
    final currentShares = (state.user?.shareCount != null && state.user!.shareCount! > 0) ? state.user!.shareCount! : 18;
    final newShares = currentShares + 1;

    if (state.user != null) {
      state = state.copyWith(
        user: state.user!.copyWith(shareCount: newShares),
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      const storage = FlutterSecureStorage();
      await prefs.setInt('stats_shared_cards_$effectiveUserId', newShares);
      await prefs.setInt('stats_shared_cards', newShares);
      await storage.write(key: 'stats_shared_cards_$effectiveUserId', value: newShares.toString());
      await storage.write(key: 'stats_shared_cards', value: newShares.toString());
    } catch (_) {}

    try {
      await _repository.updateUserProfile(
        effectiveUserId,
        {'share_count': newShares, 'shares': newShares},
      );
    } catch (_) {}
  }

  Future<void> incrementCardViews(String userId) async {
    if (state.user != null && state.user!.id == userId) {
      final currentViews = state.user!.cardViews ?? 0;
      state = state.copyWith(
        user: state.user!.copyWith(cardViews: currentViews + 1),
      );
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

  Future<bool> uploadProfileImageSafe(String userId, String imagePath) async {
    state = state.copyWith(isUploadingImage: true, clearError: true);
    AppLoadingService.instance.startTask();

    try {
      final response = await _repository.uploadProfileImage(userId, imagePath, null);
      if (response != null) {
        await loadProfile(userId);
        state = state.copyWith(
          imageVersion: state.imageVersion + 1,
          successMessage: 'Profile picture updated successfully.',
          isUploadingImage: false,
          clearError: true,
        );
        return true;
      }
      state = state.copyWith(
        errorMessage: 'Upload failed — server returned empty response.',
        isUploadingImage: false,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Image upload failed: ${e.toString()}',
        isUploadingImage: false,
      );
      return false;
    } finally {
      AppLoadingService.instance.endTask();
    }
  }

  Future<bool> removeProfileImage(String userId) async {
    state = state.copyWith(isUploadingImage: true);
    AppLoadingService.instance.startTask();
    try {
      try {
        await _repository.updateUserProfile(userId, {
          'profile_image': '',
          'image': '',
        });
      } catch (_) {}

      if (state.user != null) {
        state = state.copyWith(
          user: state.user!.copyWith(profileImage: ''),
        );
      }
      state = state.copyWith(
        imageVersion: state.imageVersion + 1,
        successMessage: 'Profile photo removed successfully.',
        isUploadingImage: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to remove image: ${e.toString()}',
        isUploadingImage: false,
      );
      return false;
    } finally {
      AppLoadingService.instance.endTask();
    }
  }

  Future<bool> uploadProfileImage(String userId, String imagePath) async {
    return uploadProfileImageSafe(userId, imagePath);
  }

  Future<bool> sendProfileOtp(
    String userId,
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
      _setState(ProfileStatus.error, error: validationError);
      return false;
    }

    _setState(ProfileStatus.loading);
    try {
      final res = await _repository.sendProfileOtp(
        userId,
        phone,
        channel: channel,
        countryCode: countryCode,
        whatsappNumber: whatsappNumber,
      );
      if (res != null) {
        if (res['success'] == false || res['error'] != null) {
          final errMsg = (res['message'] ?? res['error'] ?? 'Failed to send OTP').toString();
          _setState(ProfileStatus.error, error: errMsg);
          return false;
        }
        final reqId = (res['request_id'] ??
                res['otp_request_id'] ??
                res['requestId'] ??
                res['id'] ??
                res['data']?['request_id'] ??
                res['data']?['otp_request_id'])
            ?.toString();
        final successMsg = isWhatsApp
            ? 'OTP sent successfully to your WhatsApp.'
            : 'OTP sent successfully. Check your SMS.';
        state = state.copyWith(
          otpRequestId: reqId,
          status: ProfileStatus.loaded,
          successMessage: successMsg,
          clearError: true,
        );
        return true;
      }
      _setState(ProfileStatus.error, error: 'Failed to send OTP');
      return false;
    } catch (e) {
      _setState(ProfileStatus.error, error: e.toString());
      return false;
    }
  }

  Future<bool> verifyProfileOtp(String userId, String otp) async {
    _setState(ProfileStatus.loading);
    try {
      final res = await _repository.verifyProfileOtp(userId, state.otpRequestId ?? '', otp);
      if (res != null) {
        if (res['success'] == false ||
            res['status'] == 'error' ||
            res['error'] != null ||
            res['verified'] == false) {
          final errMsg = (res['message'] ?? res['error'] ?? 'Invalid OTP. Please try again.').toString();
          _setState(ProfileStatus.error, error: errMsg);
          return false;
        }
        state = state.copyWith(
          clearOtp: true,
          status: ProfileStatus.loaded,
          successMessage: 'OTP verified successfully.',
          clearError: true,
        );
        return true;
      }
      _setState(ProfileStatus.error, error: 'Invalid OTP. Please try again.');
      return false;
    } catch (e) {
      _setState(ProfileStatus.error, error: e.toString());
      return false;
    }
  }

  Future<bool> uploadGalleryImages(String userId, List<XFile> files) async {
    _setState(ProfileStatus.loading);
    try {
      final response = await _repository.uploadGalleryImages(userId, files);
      if (response != null) {
        await loadProfile(userId);
        _setState(ProfileStatus.loaded, success: 'Gallery updated successfully.');
        return true;
      }
      return false;
    } catch (e) {
      _setState(ProfileStatus.error, error: e.toString());
      return false;
    }
  }
}

final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, ProfileUiState>(ProfileViewModel.new);
