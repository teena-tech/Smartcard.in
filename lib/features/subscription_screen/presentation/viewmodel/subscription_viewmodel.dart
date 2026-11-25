import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/services/subscription_api_service.dart';
import 'package:smartcard_flutter/features/subscription_screen/data/models/subscription_model.dart';
import 'package:smartcard_flutter/features/subscription_screen/data/models/coupon_model.dart';
import 'package:smartcard_flutter/features/subscription_screen/data/models/payment_confirm_model.dart';

enum SubscriptionStatus { initial, loading, loaded, error }
enum PaymentStatus { initial, processing, success, failed, cancelled }

@immutable
class SubscriptionState {
  final SubscriptionStatus status;
  final PaymentStatus paymentStatus;
  final SubscriptionModel? subscription;
  final CouponModel? appliedCoupon;
  final PaymentConfirmModel? paymentConfirm;
  final String? errorMessage;
  final String? successMessage;
  final String appliedCouponCode;
  final bool isPaymentButtonDisabled;
  final double? backendOrderAmount;

  const SubscriptionState({
    this.status = SubscriptionStatus.initial,
    this.paymentStatus = PaymentStatus.initial,
    this.subscription,
    this.appliedCoupon,
    this.paymentConfirm,
    this.errorMessage,
    this.successMessage,
    this.appliedCouponCode = '',
    this.isPaymentButtonDisabled = false,
    this.backendOrderAmount,
  });

  bool get isPremium {
    if (subscription == null) return false;
    final mem = subscription!.membership.trim().toUpperCase();
    if (mem == 'PREMIUM' || mem == 'PRO' || mem.contains('PREMIUM') || mem.contains('PAID')) {
      return true;
    }
    if (subscription!.isActive) return true;
    if (subscription!.daysRemaining > 0 && mem != 'FREE') return true;
    return false;
  }

  static const double baseAmount = 365.0;
  static const double gstPercent = 18.0;

  double get discountedAmount {
    if (appliedCoupon?.success == true) {
      if (appliedCoupon?.coupon?.type == 'discount') {
        final coupon = appliedCoupon!.coupon!;
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
    if (appliedCoupon?.payableAmount != null && appliedCoupon!.payableAmount! >= 0) {
      return appliedCoupon!.payableAmount!;
    }
    if (backendOrderAmount != null) {
      return backendOrderAmount!;
    }
    return totalAmount;
  }

  bool get isPaymentRequired {
    if (appliedCoupon?.success == true) {
      if (appliedCoupon?.paymentRequired == false) return false;
      if (appliedCoupon?.application?.type == 'subscription_duration') return false;
    }
    return true;
  }

  bool get isSubscriptionDurationCoupon {
    return appliedCoupon?.success == true &&
        appliedCoupon?.application?.type == 'subscription_duration';
  }

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    PaymentStatus? paymentStatus,
    SubscriptionModel? subscription,
    CouponModel? appliedCoupon,
    PaymentConfirmModel? paymentConfirm,
    String? errorMessage,
    String? successMessage,
    String? appliedCouponCode,
    bool? isPaymentButtonDisabled,
    double? backendOrderAmount,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearCoupon = false,
    bool clearOrderAmount = false,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      subscription: subscription ?? this.subscription,
      appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
      paymentConfirm: paymentConfirm ?? this.paymentConfirm,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      appliedCouponCode: clearCoupon ? '' : (appliedCouponCode ?? this.appliedCouponCode),
      isPaymentButtonDisabled: isPaymentButtonDisabled ?? this.isPaymentButtonDisabled,
      backendOrderAmount: clearOrderAmount ? null : (backendOrderAmount ?? this.backendOrderAmount),
    );
  }
}

class SubscriptionViewModel extends Notifier<SubscriptionState> {
  static const double baseAmount = SubscriptionState.baseAmount;
  static const double gstPercent = SubscriptionState.gstPercent;
  final SubscriptionApiService _api = SubscriptionApiService.instance;

  @override
  SubscriptionState build() {
    return const SubscriptionState();
  }

  // Getters for convenience
  SubscriptionStatus get status => state.status;
  PaymentStatus get paymentStatus => state.paymentStatus;
  SubscriptionModel? get subscription => state.subscription;
  bool get isPremium => state.isPremium;
  CouponModel? get appliedCoupon => state.appliedCoupon;
  PaymentConfirmModel? get paymentConfirm => state.paymentConfirm;
  String? get errorMessage => state.errorMessage;
  String? get successMessage => state.successMessage;
  String get appliedCouponCode => state.appliedCouponCode;
  bool get isPaymentButtonDisabled => state.isPaymentButtonDisabled;
  double get displayGstAmount => (SubscriptionState.baseAmount * SubscriptionState.gstPercent) / 100;
  double get displayTotalAmount => SubscriptionState.baseAmount + displayGstAmount;
  double get discountedAmount => state.discountedAmount;
  double get netBaseAmount => state.netBaseAmount;
  double get gstAmount => state.gstAmount;
  double get totalAmount => state.totalAmount;
  double get payableAmount => state.payableAmount;
  bool get isPaymentRequired => state.isPaymentRequired;
  bool get isSubscriptionDurationCoupon => state.isSubscriptionDurationCoupon;

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }

  void resetPaymentState() {
    state = state.copyWith(
      paymentStatus: PaymentStatus.initial,
      isPaymentButtonDisabled: false,
      clearOrderAmount: true,
    );
  }

  void resetCoupon() {
    state = state.copyWith(
      clearCoupon: true,
      clearOrderAmount: true,
    );
  }

  String _cleanError(dynamic e) {
    final str = e.toString();
    if (str.startsWith('Exception: ')) {
      return str.substring('Exception: '.length).trim();
    }
    return str.trim();
  }

  Future<void> fetchSubscription(String userId) async {
    state = state.copyWith(status: SubscriptionStatus.loading, clearError: true);
    try {
      final response = await _api.getSubscriptionDetails(userId);
      final sub = SubscriptionModel.fromJson(response);
      state = state.copyWith(
        subscription: sub,
        status: SubscriptionStatus.loaded,
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: _cleanError(e),
        status: SubscriptionStatus.error,
      );
    }
  }

  Future<void> applyCoupon(String userId, String code) async {
    if (code.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Please enter a coupon code');
      return;
    }

    state = state.copyWith(
      status: SubscriptionStatus.loading,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final response = await _api.applyCoupon(userId, code.trim());
      final coupon = CouponModel.fromJson(response);

      if (coupon.success) {
        state = state.copyWith(
          appliedCoupon: coupon,
          appliedCouponCode: code.trim(),
          successMessage: coupon.message ?? 'Coupon applied!',
          clearOrderAmount: true,
          status: SubscriptionStatus.loaded,
        );

        if (coupon.application?.type == 'subscription_duration' ||
            coupon.application?.applied == true) {
          await fetchSubscription(userId);
        }
      } else {
        state = state.copyWith(
          errorMessage: coupon.message ?? 'Failed to apply coupon',
          clearCoupon: true,
          clearOrderAmount: true,
          status: SubscriptionStatus.loaded,
        );
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: _cleanError(e),
        status: SubscriptionStatus.loaded,
      );
    }
  }

  Future<Map<String, dynamic>?> createPaymentOrder(String userId) async {
    state = state.copyWith(paymentStatus: PaymentStatus.processing, clearError: true);

    try {
      final response = await _api.createPaymentOrder(
        userId,
        couponCode: state.appliedCouponCode.isNotEmpty ? state.appliedCouponCode : null,
      );

      double? orderAmt;
      final orderData = response['data']?['order'] as Map<String, dynamic>?;
      if (orderData != null) {
        final amountPaise = orderData['amount'] as int?;
        if (amountPaise != null && amountPaise > 0) {
          orderAmt = amountPaise / 100.0;
        }
      }

      state = state.copyWith(
        backendOrderAmount: orderAmt ?? state.backendOrderAmount,
        paymentStatus: PaymentStatus.initial,
      );
      return response;
    } catch (e) {
      state = state.copyWith(
        errorMessage: _cleanError(e),
        paymentStatus: PaymentStatus.failed,
      );
      return null;
    }
  }

  Future<bool> confirmPayment(String userId, Map<String, dynamic> paymentData) async {
    state = state.copyWith(
      paymentStatus: PaymentStatus.processing,
      isPaymentButtonDisabled: true,
    );

    try {
      final response = await _api.confirmPayment(userId, paymentData);
      final confirm = PaymentConfirmModel.fromJson(response);

      if (confirm.success) {
        state = state.copyWith(
          paymentConfirm: confirm,
          paymentStatus: PaymentStatus.success,
          successMessage: confirm.message ?? 'Payment successful!',
          clearCoupon: true,
        );
        await fetchSubscription(userId);
        return true;
      } else {
        state = state.copyWith(
          paymentConfirm: confirm,
          errorMessage: confirm.message ?? 'Failed to confirm payment',
          paymentStatus: PaymentStatus.failed,
          isPaymentButtonDisabled: false,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: _cleanError(e),
        paymentStatus: PaymentStatus.failed,
        isPaymentButtonDisabled: false,
      );
      return false;
    }
  }

  Future<void> reportPaymentFailure(String userId, {String? reason, double? amount}) async {
    try {
      await _api.reportPaymentFailure(userId, reason: reason, amount: amount);
    } catch (_) {}
  }
}

final subscriptionViewModelProvider =
    NotifierProvider<SubscriptionViewModel, SubscriptionState>(SubscriptionViewModel.new);
