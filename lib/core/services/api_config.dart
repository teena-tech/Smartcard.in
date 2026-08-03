import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get _liveApiBaseUrl =>
      dotenv.env['API_URL'] ?? 'https://api.thesmartcards.in';
  // Public accessor for the API base URL used throughout the app.


  // =========================================================================
  // General API Routes
  // =========================================================================
  static const String welcomeSlides = '/api/v1/users/welcome-slides';
  static const String getMessages = '/api/v1/users/messages';
  static const String dashboardLanding = '/api/v1/users/dashboard/landing';
  static const String recentActivity = '/api/v1/users/recent-activity';
  static String updateMessageAction(String messageId) => '/api/v1/users/messages/$messageId/action';

  // Authentication
  static const String login = '/api/v1/users/login';
  static const String verifyOtp = '/api/v1/users/verify-otp';
  static const String logout = '/api/v1/users/logout';

  // Registration
  static const String checkPhone = '/api/v1/users/register/check-phone';
  static const String sendRegistrationOtp = '/api/v1/users/register/send-otp';
  static const String verifyRegistrationOtp = '/api/v1/users/register/verify-otp';
  static const String completeRegistration = '/api/v1/users/register/complete';

  // User & Profile
  static String userProfile(String userId) => '/api/v1/users/$userId/profile';
  static String passwordChange(String userId) => '/api/v1/users/$userId/password-change';
  static String userGallery(String userId) => '/api/v1/users/$userId/gallery';
  static String userProfileImage(String userId) => '/api/v1/users/$userId/profile-image';
  static String companyLogo(String userId) => '/api/v1/users/$userId/company-logo';
  static String deleteUserAccount(String userId) => '/api/v1/users/$userId';

  // Support
  static String supportContext(String userId) => '/api/v1/users/$userId/support/context';
  static String supportMessages(String userId) => '/api/v1/users/$userId/support/messages';
  static String supportUnreadCount(String userId) => '/api/v1/users/$userId/support/unread-count';

  // Reports
  static const String userReports = '/api/v1/user-reports';
  static String userReport(String reportId) => '/api/v1/user-reports/$reportId';
  static String replyUserReport(String reportId) => '/api/v1/user-reports/$reportId/reply';

  // Gallery Management
  static String galleryImages(String userId) => '/api/v1/users/$userId/gallery/images';
  static String galleryYoutubeLinks(String userId) => '/api/v1/users/$userId/gallery/youtube-links';

  // Additional cards
  static String additionalCard(String userId) => '/api/v1/users/$userId/additional-card';
  static String deleteAdditionalCard(String userId, int cardUserId) =>
      '/api/v1/users/$userId/additional-card/$cardUserId';
  static String primaryCard(String userId, int cardUserId) =>
      '/api/v1/users/$userId/primary-card/$cardUserId';

  // Suspension and OTP
  static String selfSuspension(String userId) => '/api/v1/users/$userId/suspension';
  static String sendProfileOtp(String userId) => '/api/v1/users/$userId/phone-otp/send';
  static String verifyProfileOtp(String userId) => '/api/v1/users/$userId/phone-otp/verify';

  // Theme
  static String theme(String userId) => '/api/v1/themes/$userId';
  static const String backgroundImages = '/api/v1/themes/background-images';
  static String themeSolidColors(String userId) => '/api/v1/themes/$userId/solid-colors';
  static String themeBackground(String userId) => '/api/v1/themes/$userId/background';
  static String themeBackgroundUpload(String userId) =>
      '/api/v1/themes/$userId/background-upload';
  static String themeLogoColors(String userId) => '/api/v1/themes/$userId/logo-colors';
  static String clearBackground(String userId) => '/api/v1/themes/$userId/clear-background';
  static const String templates = '/api/v1/themes/templates';
  static String themeTemplate(String userId) => '/api/v1/themes/$userId/template';

  // QR / Contact
  static const String qrContacts = '/api/v1/users/me/contacts';
  static const String qrPreview = '/api/v1/users/me/contacts/preview';
  static String qrDelete(int contactId) => '/api/v1/users/me/contacts/$contactId';

  // Subscription
  static String subscriptionDetails(String userId) =>
      '/api/v1/users/$userId/subscription-details';
  static String subscriptionCoupon(String userId) =>
      '/api/v1/users/$userId/subscription-coupon';
  static String subscriptionOrder(String userId) =>
      '/api/v1/users/$userId/subscription-payment/order';
  static String subscriptionConfirm(String userId) =>
      '/api/v1/users/$userId/subscription-payment/confirm';
  static String subscriptionFailure(String userId) =>
      '/api/v1/users/$userId/subscription-payment/failure';

  // Pincode
  static String pincode(String pincode) => '/api/v1/pincode/$pincode';

  // -------------------------------------------------------------------------
  // Local backend server URLs
  static String get _localIosAndWebUrl =>
      dotenv.env['API_URL'] ?? 'http://localhost:5000';

  static String get _localAndroidEmulatorUrl {
    final envUrl = dotenv.env['API_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return envUrl
          .replaceAll('localhost', '10.0.2.2')
          .replaceAll('127.0.0.1', '10.0.2.2');
    }
    return 'http://10.0.2.2:5000';
  }


  // =========================================================================
  // 📱 PHYSICAL DEVICE LOCAL TESTING CONFIGURATION
  // If you are testing your local backend server on a PHYSICAL phone (real Android/iOS),
  // set 'usePhysicalDeviceForLocal' to 'true' and update '_localPhysicalIp'
  // with your computer's local Wi-Fi IP address (e.g., 192.168.1.5 or 192.168.29.X).
  // =========================================================================
  static bool get usePhysicalDeviceForLocal =>
      (dotenv.env['USE_PHYSICAL_DEVICE_FOR_LOCAL']?.toLowerCase() ?? 'false') == 'true';
  static String get _localPhysicalIp =>
      dotenv.env['LOCAL_PHYSICAL_IP'] ?? '192.168.1.1';

  // =========================================================================
  // ⚡ CONFIGURATION SWITCH
  // Set this to 'false' to connect to the LIVE server.
  // Set this to 'true' to connect to your LOCAL backend server.
  static bool get useLocalBackend =>
      (dotenv.env['USE_LOCAL_BACKEND']?.toLowerCase() ?? 'true') == 'true';

  static String get baseUrl {
    if (!useLocalBackend) {
      return _liveApiBaseUrl;
    }

    if (kIsWeb) {
      return _localIosAndWebUrl;
    }

    // For Mobile Devices
    try {
      if (usePhysicalDeviceForLocal) {
        return 'http://$_localPhysicalIp:5000';
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        return _localAndroidEmulatorUrl;
      }
    } catch (_) {}

    return _localIosAndWebUrl;
  }

  // Uploads directory mapping
  static String get sharedUploadsUrl => useLocalBackend
      ? '$baseUrl/shared-uploads'
      : (dotenv.env['SHARED_UPLOADS_URL'] ?? 'https://api.thesmartcards.in/shared-uploads');

  // Required only for /api/v1/agents/* routes because server uses CARD_API_KEY.
  static String get cardApiKey =>
      dotenv.env['CARD_API_KEY'] ?? 'SET_PRODUCTION_CARD_API_KEY';
}
