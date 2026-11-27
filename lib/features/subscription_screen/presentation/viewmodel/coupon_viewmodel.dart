import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/features/subscription_screen/data/repositories/coupon_repository.dart';

@immutable
class CouponState {
  final List<dynamic> coupons;
  final bool isLoading;
  final String? error;

  const CouponState({
    this.coupons = const [],
    this.isLoading = false,
    this.error,
  });

  CouponState copyWith({
    List<dynamic>? coupons,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CouponState(
      coupons: coupons ?? this.coupons,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CouponViewModel extends Notifier<CouponState> {
  final CouponRepository _repo = CouponRepository();

  @override
  CouponState build() {
    return const CouponState();
  }

  List<dynamic> get coupons => state.coupons;
  bool get isLoading => state.isLoading;
  String? get error => state.error;

  Future<void> loadCoupons() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repo.getCoupons();
      state = state.copyWith(coupons: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<bool> redeem(String code) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final success = await _repo.redeemCoupon(code);
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }
}

final couponViewModelProvider =
    NotifierProvider<CouponViewModel, CouponState>(CouponViewModel.new);
