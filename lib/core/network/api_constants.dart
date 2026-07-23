import '../services/api_config.dart';

class ApiConstants {
  static String _stripApiPrefix(String path) {
    if (path.startsWith('/api/v1')) return path.substring(7);
    if (path.startsWith('/api')) return path.substring(4);
    return path;
  }

  // Local backend server
  static String get baseUrl {
    return '${ApiConfig.baseUrl}/api/v1';
  }
  
  static String getFullImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = baseUrl.replaceAll('/api/v1', '').replaceAll('/api', '');
    return '$base/$path';
  }
  
  // Auth & User Endpoints
  static String get login => _stripApiPrefix(ApiConfig.login);
  static String get verifyOtp => _stripApiPrefix(ApiConfig.verifyOtp);
  static String get logout => _stripApiPrefix(ApiConfig.logout);
  static const String access = '/users/access';
  
  static const String passwordResetRequest = '/users/password-reset/request';
  static const String passwordResetComplete = '/users/password-reset';
  
  static String passwordChange(int userId) => _stripApiPrefix(ApiConfig.passwordChange(userId.toString()));
  
  // Registration
  static String get sendRegOtp => _stripApiPrefix(ApiConfig.sendRegistrationOtp);
  static const String checkRegPhone = '/users/register/check-phone';
  static String get verifyRegOtp => _stripApiPrefix(ApiConfig.verifyRegistrationOtp);
  static String get registerComplete => _stripApiPrefix(ApiConfig.completeRegistration);

  // Profile Endpoints
  static String userProfile(int userId) => _stripApiPrefix(ApiConfig.userProfile(userId.toString()));
  static String userSubscription(int userId) => _stripApiPrefix(ApiConfig.subscriptionDetails(userId.toString()));
  static String userSuspension(int userId) => _stripApiPrefix(ApiConfig.selfSuspension(userId.toString()));
  static String profileImage(int userId) => _stripApiPrefix(ApiConfig.userProfileImage(userId.toString()));
  static String companyLogo(int userId) => _stripApiPrefix(ApiConfig.companyLogo(userId.toString()));
  
  // Additional Cards
  static String additionalCard(int userId) => _stripApiPrefix(ApiConfig.additionalCard(userId.toString()));
  static String deleteAdditionalCard(int userId, int cardUserId) =>
      _stripApiPrefix(ApiConfig.deleteAdditionalCard(userId.toString(), cardUserId));
  static String primaryCard(int userId, int cardUserId) =>
      _stripApiPrefix(ApiConfig.primaryCard(userId.toString(), cardUserId));
  
  // Subscription / Payments
  static String subscriptionCoupon(int userId) =>
      _stripApiPrefix(ApiConfig.subscriptionCoupon(userId.toString()));
  static String subscriptionPaymentConfirm(int userId) =>
      _stripApiPrefix(ApiConfig.subscriptionConfirm(userId.toString()));
  static String subscriptionPaymentFailure(int userId) =>
      _stripApiPrefix(ApiConfig.subscriptionFailure(userId.toString()));
  
  // Gallery Endpoints
  static String gallery(int userId) => _stripApiPrefix(ApiConfig.userGallery(userId.toString()));
  static String galleryImages(int userId) =>
      _stripApiPrefix(ApiConfig.galleryImages(userId.toString()));
  static String galleryYoutube(int userId) =>
      _stripApiPrefix(ApiConfig.galleryYoutubeLinks(userId.toString()));
  
  // NFC Orders
  static String nfcOrders(int userId) => '/users/$userId/nfc-orders';
  
  // Theme Endpoints
  static String theme(int userId) => _stripApiPrefix(ApiConfig.theme(userId.toString()));
  static String get backgroundImages =>
      _stripApiPrefix(ApiConfig.backgroundImages);
  static String get templates => _stripApiPrefix(ApiConfig.templates);
  static String themeSolidColors(int userId) =>
      _stripApiPrefix(ApiConfig.themeSolidColors(userId.toString()));
  static String themeBackground(int userId) =>
      _stripApiPrefix(ApiConfig.themeBackground(userId.toString()));
  static String themeBackgroundUpload(int userId) =>
      _stripApiPrefix(ApiConfig.themeBackgroundUpload(userId.toString()));
  static String themeLogoColors(int userId) =>
      _stripApiPrefix(ApiConfig.themeLogoColors(userId.toString()));
  static String clearBackground(int userId) =>
      _stripApiPrefix(ApiConfig.clearBackground(userId.toString()));
  
  // Support & Reports
  static String supportMessages(String userId) =>
      _stripApiPrefix(ApiConfig.supportMessages(userId));
  static String supportContext(String userId) =>
      _stripApiPrefix(ApiConfig.supportContext(userId));
  static String supportUnreadCount(String userId) =>
      _stripApiPrefix(ApiConfig.supportUnreadCount(userId));
  static const String dashboardMessages = '/users/messages';
  static String messageAction(int messageId) =>
      _stripApiPrefix(ApiConfig.updateMessageAction(messageId.toString()));
  
  static String get userReports => _stripApiPrefix(ApiConfig.userReports);
}
