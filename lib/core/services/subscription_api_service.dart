import 'package:dio/dio.dart';
import 'dio_client.dart';
import 'api_config.dart';

class SubscriptionApiService {
  SubscriptionApiService._();
  static final SubscriptionApiService instance = SubscriptionApiService._();

  final Dio _dio = DioClient().dio;

  Future<Map<String, dynamic>> getSubscriptionDetails(String userId) async {
    try {
      final response = await _dio.get(ApiConfig.subscriptionDetails(userId));
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
        DioClient.getErrorMessage(e, 'Failed to fetch subscription details'),
      );
    }
  }

  Future<Map<String, dynamic>> applyCoupon(String userId, String code) async {
    try {
      final response = await _dio.post(
        ApiConfig.subscriptionCoupon(userId),
        data: {'code': code},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(DioClient.getErrorMessage(e, 'Failed to apply coupon'));
    }
  }

  Future<Map<String, dynamic>> createPaymentOrder(
    String userId, {
    String? couponCode,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.subscriptionOrder(userId),
        data: {
          if (couponCode != null && couponCode.isNotEmpty) 'coupon_code': couponCode,
          'payment_for': 'subscription',
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(DioClient.getErrorMessage(e, 'Failed to create payment order'));
    }
  }

  Future<Map<String, dynamic>> confirmPayment(
    String userId,
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final response = await _dio.post(
        ApiConfig.subscriptionConfirm(userId),
        data: paymentData,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(DioClient.getErrorMessage(e, 'Failed to confirm payment'));
    }
  }

  Future<void> reportPaymentFailure(
    String userId, {
    String? reason,
    double? amount,
  }) async {
    try {
      await _dio.post(
        ApiConfig.subscriptionFailure(userId),
        data: {
          'error_reason': reason ?? 'Payment failed',
          'total_amount': ?amount,
          'payment_for': 'subscription',
        },
      );
    } catch (_) {
      // Best-effort — don't throw for failure reporting
    }
  }
}
