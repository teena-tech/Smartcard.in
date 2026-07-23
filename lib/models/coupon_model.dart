class CouponModel {
  final bool success;
  final CouponData? coupon;
  final CouponApplication? application;
  final double? payableAmount;
  final bool? paymentRequired;
  final String? message;

  CouponModel({
    required this.success,
    this.coupon,
    this.application,
    this.payableAmount,
    this.paymentRequired,
    this.message,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'] as Map<String, dynamic>?;
    final couponJson = dataJson?['coupon'] as Map<String, dynamic>?;
    final applicationJson = dataJson?['application'] as Map<String, dynamic>?;
    
    return CouponModel(
      success: json['success'] as bool? ?? false,
      coupon: couponJson != null ? CouponData.fromJson(couponJson) : null,
      application: applicationJson != null ? CouponApplication.fromJson(applicationJson) : null,
      payableAmount: (json['payable_amount'] as num?)?.toDouble(),
      paymentRequired: applicationJson?['applied'] as bool? ?? !(applicationJson?['type'] == 'subscription_duration'),
      message: json['message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': {
        'coupon': coupon?.toJson(),
        'application': application?.toJson(),
      },
      'payable_amount': payableAmount,
      'payment_required': paymentRequired,
      'message': message,
    };
  }
}

class CouponApplication {
  final bool applied;
  final String type;
  final String? note;
  final String? membership;
  final int? daysAdded;
  final String? startDate;
  final String? endDate;
  final int? daysRemaining;

  CouponApplication({
    required this.applied,
    required this.type,
    this.note,
    this.membership,
    this.daysAdded,
    this.startDate,
    this.endDate,
    this.daysRemaining,
  });

  factory CouponApplication.fromJson(Map<String, dynamic> json) {
    return CouponApplication(
      applied: json['applied'] as bool? ?? false,
      type: json['type']?.toString() ?? '',
      note: json['note']?.toString(),
      membership: json['membership']?.toString(),
      daysAdded: json['days_added'] as int?,
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      daysRemaining: json['days_remaining'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'applied': applied,
      'type': type,
      'note': note,
      'membership': membership,
      'days_added': daysAdded,
      'start_date': startDate,
      'end_date': endDate,
      'days_remaining': daysRemaining,
    };
  }
}

class CouponData {
  final String type;
  final double? discountAmount;
  final int? discountPercentage;
  final int? extraDays;
  final String? code;
  final String? status;
  final String? description;
  final String? expiryDate;
  final int? subscriptionDays;

  CouponData({
    required this.type,
    this.discountAmount,
    this.discountPercentage,
    this.extraDays,
    this.code,
    this.status,
    this.description,
    this.expiryDate,
    this.subscriptionDays,
  });

  factory CouponData.fromJson(Map<String, dynamic> json) {
    return CouponData(
      type: json['type']?.toString() ?? '',
      discountAmount: (json['discount_amount'] as num?)?.toDouble(),
      discountPercentage: json['discount_percentage'] as int?,
      extraDays: json['subscription_days'] as int?,
      code: json['code']?.toString(),
      status: json['status']?.toString(),
      description: json['description']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      subscriptionDays: json['subscription_days'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'discount_amount': discountAmount,
      'discount_percentage': discountPercentage,
      'extra_days': extraDays,
      'code': code,
      'status': status,
      'description': description,
      'expiry_date': expiryDate,
      'subscription_days': subscriptionDays,
    };
  }
}
