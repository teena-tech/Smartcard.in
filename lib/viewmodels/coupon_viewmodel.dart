import 'package:flutter/foundation.dart';
import '../repositories/coupon_repository.dart';

class CouponViewModel extends ChangeNotifier {
  final CouponRepository _repo = CouponRepository();
  List<dynamic> _coupons = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get coupons => _coupons;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCoupons() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _coupons = await _repo.getCoupons();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> redeem(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final success = await _repo.redeemCoupon(code);
      return success;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
