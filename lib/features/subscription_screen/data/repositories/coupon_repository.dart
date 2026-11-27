import 'package:smartcard_flutter/core/repositories/base_repository.dart';

/// Repository for managing coupons.
/// NOTE: The API endpoint for coupons is not documented in the provided API integration
/// document. This repository provides placeholder methods that can be wired to the
/// actual endpoint once it becomes available.
class CouponRepository extends BaseRepository {
  // Using a dedicated service class if it exists; otherwise fallback to Dio directly.
  // final CouponApiService? _service = CouponApiService.instance;

  /// Fetch list of available coupons.
  /// Returns an empty list if the service is not defined.
  Future<List<dynamic>> getCoupons() async {
    /*
    if (_service != null) {
      final response = await _service!.listCoupons();
      return response is List ? response : [];
    }
    */
    // Placeholder – no API defined.
    return [];
  }

  /// Redeem a coupon by its code.
  /// Returns true on success, false otherwise.
  Future<bool> redeemCoupon(String code) async {
    /*
    if (_service != null) {
      final response = await _service!.redeemCoupon(code);
      return response == true;
    }
    */
    // Placeholder – no API defined.
    return false;
  }
}
