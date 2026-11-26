import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static const String _envApiUrl = String.fromEnvironment('API_URL');
  static const String _envSharedUploadsUrl = String.fromEnvironment('SHARED_UPLOADS_URL');
  static const String _envCardApiKey = String.fromEnvironment('CARD_API_KEY');
  static const String _envUseLocalBackend = String.fromEnvironment('USE_LOCAL_BACKEND');
  static const String _envUsePhysicalDevice = String.fromEnvironment('USE_PHYSICAL_DEVICE_FOR_LOCAL');
  static const String _envLocalPhysicalIp = String.fromEnvironment('LOCAL_PHYSICAL_IP');

  static String _readConfig(String compiledValue, String dotenvKey, String fallback) {
    if (compiledValue.trim().isNotEmpty) {
      return compiledValue.trim();
    }
    try {
      if (dotenv.isInitialized) {
        final raw = dotenv.env[dotenvKey];
        if (raw != null && raw.trim().isNotEmpty) {
          return raw.trim();
        }
      }
    } catch (_) {}
    return fallback;
  }

  static String get _liveApiBaseUrl =>
      _readConfig(_envApiUrl, 'API_URL', 'https://thesmartcards.in/api');

  /// Base web origin for public smart card URLs.
  static String get publicWebBaseUrl {
    final base = _liveApiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    return base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  }

  /// Canonical public profile URL for a work profile ID.
  static String cardProfileUrl(String workProfileId) =>
      '$publicWebBaseUrl/profile/$workProfileId';

  /// Short share URL for a card slug / query parameter (`/?sc=...`).
  static String cardShortUrl(String slug) =>
      '$publicWebBaseUrl/?sc=${Uri.encodeComponent(slug)}';

  /// Formats a raw card identifier, query string, path, or full URL into a canonical SmartCard URL.
  static String formatSmartCardUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return publicWebBaseUrl;
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('?sc=') || trimmed.startsWith('sc=')) {
      final q = trimmed.startsWith('?') ? trimmed : '?$trimmed';
      return '$publicWebBaseUrl/$q';
    }
    if (trimmed.startsWith('/c/') || trimmed.startsWith('/')) {
      return '$publicWebBaseUrl$trimmed';
    }
    return '$publicWebBaseUrl/c/$trimmed';
  }

  /// Resolves a live card's public URL from an optional [qrCode], [profileUrl],
  /// or [workProfileId].
  static String resolveLiveCardUrl({
    String? qrCode,
    String? profileUrl,
    required String workProfileId,
  }) {
    final trimmedQr = (qrCode ?? '').trim();
    if (trimmedQr.isNotEmpty) {
      if (trimmedQr.contains('?sc=')) {
        final slug = trimmedQr.split('?sc=').last.split('&').first.trim();
        if (slug.isNotEmpty) {
          return cardShortUrl(slug);
        }
      }
      if (trimmedQr.startsWith('http://') || trimmedQr.startsWith('https://')) {
        return trimmedQr;
      }
      return cardShortUrl(trimmedQr);
    }

    final trimmedProfile = (profileUrl ?? '').trim();
    if (trimmedProfile.isNotEmpty) {
      return trimmedProfile;
    }
    return cardProfileUrl(workProfileId);
  }

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
  static String deleteUserAccountPost(String userId) => '/api/v1/users/$userId/delete';
  static const String deleteUserAccountMe = '/api/v1/users/me';
  static const String deleteUserAccountMePost = '/api/v1/users/me/delete';
  static const String deleteUserAccountConvenience = '/api/v1/users/delete-account';

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
  static String deleteGalleryImage(String userId) => '/api/v1/users/$userId/gallery/images/delete';
  static String galleryYoutubeLinks(String userId) => '/api/v1/users/$userId/gallery/youtube-links';

  // Additional cards
  static String additionalCard(String userId) => '/api/v1/users/$userId/additional-card';
  static String deleteAdditionalCard(String userId, int cardUserId) =>
      '/api/v1/users/$userId/additional-card/$cardUserId';
  static String primaryCard(String userId, int cardUserId) =>
      '/api/v1/users/$userId/primary-card/$cardUserId';

  // Suspension and OTP
  static String selfSuspension(String userId) => '/api/v1/users/$userId/suspension';
  static String cardSuspension(String userId, int workProfileId) =>
      '/api/v1/users/$userId/work-profile/$workProfileId/suspension';
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
  static const String matchPhones = '/api/v1/users/me/contacts/match-phones';
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

  // NFC Physical Orders
  static String nfcOrders(String userId) => '/api/v1/users/$userId/nfc-orders';

  // AI Assistant Endpoints
  static const String aiGenerateBio = '/api/v1/ai/generate-bio';
  static const String aiParseVisitingCard = '/api/v1/ai/parse-visiting-card';
  static const String aiSuggestDesign = '/api/v1/ai/suggest-design';

  // Telemetry Error Reporting
  static const String telemetryAppError = '/api/telemetry/app-error';

  // -------------------------------------------------------------------------
  // Local backend server URLs
  static String get _localIosAndWebUrl =>
      _readConfig(_envApiUrl, 'API_URL', 'http://localhost:5000');

  static String get _localAndroidEmulatorUrl {
    final envUrl = _readConfig(_envApiUrl, 'API_URL', '');
    if (envUrl.isNotEmpty) {
      return envUrl
          .replaceAll('localhost', '10.0.2.2')
          .replaceAll('127.0.0.1', '10.0.2.2');
    }
    return 'http://10.0.2.2:5000';
  }

  static bool get usePhysicalDeviceForLocal =>
      _readConfig(_envUsePhysicalDevice, 'USE_PHYSICAL_DEVICE_FOR_LOCAL', 'false')
          .toLowerCase() ==
      'true';
  static String get _localPhysicalIp =>
      _readConfig(_envLocalPhysicalIp, 'LOCAL_PHYSICAL_IP', '192.168.1.1');

  static bool get useLocalBackend =>
      _readConfig(_envUseLocalBackend, 'USE_LOCAL_BACKEND', 'false')
          .toLowerCase() ==
      'true';

  static String get baseUrl {
    if (!useLocalBackend) {
      final base = _liveApiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
      return base.endsWith('/api') ? base : '$base/api';
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
      : _readConfig(
          _envSharedUploadsUrl,
          'SHARED_UPLOADS_URL',
          '$publicWebBaseUrl/shared-uploads',
        );

  // Card API Key used by server routes
  static String get cardApiKey => _readConfig(
        _envCardApiKey,
        'CARD_API_KEY',
        'scard_api_36ff99e7c6dff83ba97617654a28610096e951e1bea9e833f60f383f40f71897',
      );
}
