import 'package:smartcard_flutter/core/services/api_config.dart';

class ApiPaths {
  static const String qrPreview = ApiConfig.qrPreview;
  static const String qrSave = ApiConfig.qrContacts;

  static String profile(String userId) => ApiConfig.userProfile(userId);
  static String profileImage(String userId) => ApiConfig.userProfileImage(userId);
  static String subscriptionDetailsFor(String userId) => ApiConfig.subscriptionDetails(userId);
  static String subscriptionCouponFor(String userId) => ApiConfig.subscriptionCoupon(userId);
  static String subscriptionOrderFor(String userId) => ApiConfig.subscriptionOrder(userId);
  static String subscriptionConfirmFor(String userId) => ApiConfig.subscriptionConfirm(userId);
}
