import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
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

  // Backend-provided order amounts (set after createPaymentOrder)
  double? _backendOrderAmount;

  // Getters
  SubscriptionStatus get status => _status;
  PaymentStatus get paymentStatus => _paymentStatus;
  SubscriptionModel? get subscription => _subscription;
  bool get isPremium {
    if (_subscription == null) return false;
    final mem = _subscription!.membership.trim().toUpperCase();
    if (mem == 'PREMIUM' || mem == 'PRO' || mem.contains('PREMIUM') || mem.contains('PAID')) {
      return true;
    }
    if (_subscription!.isActive) return true;
    if (_subscription!.daysRemaining > 0 && mem != 'FREE') return true;
    return false;
  }
  CouponModel? get appliedCoupon => _appliedCoupon;
  PaymentConfirmModel? get paymentConfirm => _paymentConfirm;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String get appliedCouponCode => _appliedCouponCode;
  bool get isPaymentButtonDisabled => _isPaymentButtonDisabled;

  // Display pricing (used for UI display on plan cards)
  static const double displayBaseAmount = 365.0;
  static const double displayGstPercent = 18.0;
  double get displayGstAmount => (displayBaseAmount * displayGstPercent) / 100;
  double get displayTotalAmount => displayBaseAmount + displayGstAmount;

  // Actual pricing — prefer backend amount from order response
  // Fallback to display amounts for the checkout UI before order is created
  static const double baseAmount = 365.0;
  static const double gstPercent = 18.0;

  double get discountedAmount {
    if (_appliedCoupon?.success == true) {
      if (_appliedCoupon?.coupon?.type == 'discount') {
        final coupon = _appliedCoupon!.coupon!;
        if (coupon.discountAmount != null && coupon.discountAmount! > 0) {
          return coupon.discountAmount!.clamp(0, baseAmount);
        } else if (coupon.discountPercentage != null && coupon.discountPercentage! > 0) {
          return ((baseAmount * coupon.discountPercentage!) / 100).clamp(0, baseAmount);
        }
      }
    }
    return 0.0;
  }

  double get netBaseAmount => (baseAmount - discountedAmount).clamp(0, double.infinity);
  double get gstAmount => (netBaseAmount * gstPercent) / 100;
  double get totalAmount => netBaseAmount + gstAmount;

  double get payableAmount {
    if (!isPaymentRequired) return 0.0;
    // Prefer explicit backend payable amount if available
    if (_appliedCoupon?.payableAmount != null && _appliedCoupon!.payableAmount! >= 0) {
      return _appliedCoupon!.payableAmount!;
    }
    if (_backendOrderAmount != null) {
      return _backendOrderAmount!;
    }
    return totalAmount;
  }

  bool get isPaymentRequired {
    if (_appliedCoupon?.success == true) {
      if (_appliedCoupon?.paymentRequired == false) return false;
      if (_appliedCoupon?.application?.type == 'subscription_duration') return false;
    }
    return true;
  }

  /// Whether the applied coupon is a subscription_duration type (free premium days)
  bool get isSubscriptionDurationCoupon {
    return _appliedCoupon?.success == true &&
        _appliedCoupon?.application?.type == 'subscription_duration';
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
    _backendOrderAmount = null;
    notifyListeners();
  }

  void resetCoupon() {
    _appliedCoupon = null;
    _appliedCouponCode = '';
    _backendOrderAmount = null;
    notifyListeners();
  }

  String _cleanError(dynamic e) {
    final str = e.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring('Exception: '.length).trim();
    }
    return str.trim();
  }

  void _safeNotifyListeners() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  Future<void> fetchSubscription(String userId) async {
    _status = SubscriptionStatus.loading;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final response = await _api.getSubscriptionDetails(userId);
      _subscription = SubscriptionModel.fromJson(response);
      _status = SubscriptionStatus.loaded;
    } catch (e) {
      _errorMessage = _cleanError(e);
      _status = SubscriptionStatus.error;
    } finally {
      _safeNotifyListeners();
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
    _successMessage = null;
    notifyListeners();

    try {
      final response = await _api.applyCoupon(userId, code.trim());
      _appliedCoupon = CouponModel.fromJson(response);

      if (_appliedCoupon!.success) {
        _appliedCouponCode = code.trim();
        _successMessage = _appliedCoupon!.message ?? 'Coupon applied!';
        // Clear any backend order amount so it recalculates
        _backendOrderAmount = null;
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

      // Extract backend-calculated amount from order response
      final orderData = response['data']?['order'] as Map<String, dynamic>?;
      if (orderData != null) {
        final amountPaise = orderData['amount'] as int?;
        if (amountPaise != null && amountPaise > 0) {
          _backendOrderAmount = amountPaise / 100.0;
          notifyListeners();
        }
      }

      _paymentStatus = PaymentStatus.initial;
      notifyListeners();
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

  /// Report payment failure to backend (for email notification)
  Future<void> reportPaymentFailure(String userId, {String? reason, double? amount}) async {
    try {
      await _api.reportPaymentFailure(userId, reason: reason, amount: amount);
    } catch (_) {
      // Silently fail — this is best-effort
    }
  }
}