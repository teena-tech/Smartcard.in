import 'package:flutter/foundation.dart';
import '../models/subscription_model.dart';
import '../models/coupon_model.dart';
import '../models/payment_confirm_model.dart';
import '../core/services/subscription_api_service.dart';

enum SubscriptionStatus { initial, loading, loaded, error }
enum PaymentStatus { initial, processing, success, failed, cancelled }

class SubscriptionViewModel extends ChangeNotifier {
  final SubscriptionApiService _api = SubscriptionApiService.instance;

  SubscriptionStatus _status = SubscriptionStatus.initial;
  PaymentStatus _paymentStatus = PaymentStatus.initial;
  SubscriptionModel? _subscription;
  CouponModel? _appliedCoupon;
  PaymentConfirmModel? _paymentConfirm;
  String? _errorMessage;
  String? _successMessage;
  String _appliedCouponCode = '';
  bool _isPaymentButtonDisabled = false;

  // Getters
  SubscriptionStatus get status => _status;
  PaymentStatus get paymentStatus => _paymentStatus;
  SubscriptionModel? get subscription => _subscription;
  CouponModel? get appliedCoupon => _appliedCoupon;
  PaymentConfirmModel? get paymentConfirm => _paymentConfirm;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String get appliedCouponCode => _appliedCouponCode;
  bool get isPaymentButtonDisabled => _isPaymentButtonDisabled;

  // Pricing constants
  static const double baseAmount = 360.0;
  static const double gstPercent = 18.0;

  double get gstAmount => (baseAmount * gstPercent) / 100;
  double get totalAmount => baseAmount + gstAmount;

  double get discountedAmount {
    if (_appliedCoupon?.success == true && _appliedCoupon?.coupon?.type == 'discount') {
      final coupon = _appliedCoupon!.coupon!;
      if (coupon.discountAmount != null && coupon.discountAmount! > 0) {
        return coupon.discountAmount!;
      } else if (coupon.discountPercentage != null && coupon.discountPercentage! > 0) {
        return (baseAmount * coupon.discountPercentage!) / 100;
      }
    }
    return 0.0;
  }

  double get payableAmount {
    if (!isPaymentRequired) return 0.0;
    return (totalAmount - discountedAmount).clamp(0, double.infinity);
  }

  bool get isPaymentRequired {
    if (_appliedCoupon?.success == true) {
      if (_appliedCoupon?.paymentRequired == false) return false;
      if (_appliedCoupon?.application?.type == 'subscription_duration') return false;
    }
    return true;
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void resetPaymentState() {
    _paymentStatus = PaymentStatus.initial;
    _paymentConfirm = null;
    _isPaymentButtonDisabled = false;
    notifyListeners();
  }

  void resetCoupon() {
    _appliedCoupon = null;
    _appliedCouponCode = '';
    notifyListeners();
  }

  String _cleanError(dynamic e) {
    final str = e.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring('Exception: '.length).trim();
    }
    return str.trim();
  }

  Future<void> fetchSubscription(String userId) async {
    _status = SubscriptionStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.getSubscriptionDetails(userId);
      _subscription = SubscriptionModel.fromJson(response);
      _status = SubscriptionStatus.loaded;
    } catch (e) {
      _errorMessage = _cleanError(e);
      _status = SubscriptionStatus.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> applyCoupon(String userId, String code) async {
    if (code.trim().isEmpty) {
      _errorMessage = 'Please enter a coupon code';
      notifyListeners();
      return;
    }

    _status = SubscriptionStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.applyCoupon(userId, code.trim());
      _appliedCoupon = CouponModel.fromJson(response);

      if (_appliedCoupon!.success) {
        _appliedCouponCode = code.trim();
        _successMessage = _appliedCoupon!.message ?? 'Coupon applied!';
        // If a subscription duration coupon was applied, refresh subscription status
        if (_appliedCoupon?.application?.type == 'subscription_duration' ||
            _appliedCoupon?.application?.applied == true) {
          await fetchSubscription(userId);
        }
      } else {
        _errorMessage = _appliedCoupon!.message ?? 'Failed to apply coupon';
        resetCoupon();
      }

      _status = SubscriptionStatus.loaded;
    } catch (e) {
      _errorMessage = _cleanError(e);
      _status = SubscriptionStatus.loaded;
    } finally {
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> createPaymentOrder(String userId) async {
    _paymentStatus = PaymentStatus.processing;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.createPaymentOrder(
        userId,
        couponCode: _appliedCouponCode.isNotEmpty ? _appliedCouponCode : null,
      );
      return response;
    } catch (e) {
      _errorMessage = _cleanError(e);
      _paymentStatus = PaymentStatus.failed;
      notifyListeners();
      return null;
    }
  }

  Future<bool> confirmPayment(String userId, Map<String, dynamic> paymentData) async {
    _paymentStatus = PaymentStatus.processing;
    _isPaymentButtonDisabled = true;
    notifyListeners();

    try {
      final response = await _api.confirmPayment(userId, paymentData);
      _paymentConfirm = PaymentConfirmModel.fromJson(response);

      if (_paymentConfirm!.success) {
        _paymentStatus = PaymentStatus.success;
        _successMessage = _paymentConfirm!.message ?? 'Payment successful!';
        await fetchSubscription(userId); // Refresh subscription
        resetCoupon();
        return true;
      } else {
        _errorMessage = _paymentConfirm!.message ?? 'Failed to confirm payment';
        _paymentStatus = PaymentStatus.failed;
        _isPaymentButtonDisabled = false;
        return false;
      }
    } catch (e) {
      _errorMessage = _cleanError(e);
      _paymentStatus = PaymentStatus.failed;
      _isPaymentButtonDisabled = false;
      notifyListeners();
      return false;
    }
  }
}