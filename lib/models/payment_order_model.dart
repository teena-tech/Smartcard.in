class PaymentOrderModel {
  final bool success;
  final OrderData? order;
  final String? message;

  PaymentOrderModel({
    required this.success,
    this.order,
    this.message,
  });

  factory PaymentOrderModel.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'] as Map<String, dynamic>?;
    final orderJson = dataJson?['order'] as Map<String, dynamic>?;
    
    return PaymentOrderModel(
      success: json['success'] as bool? ?? false,
      order: orderJson != null ? OrderData.fromJson(orderJson) : null,
      message: json['message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': {
        'order': order?.toJson(),
      },
      'message': message,
    };
  }
}

class OrderData {
  final String razorpayOrderId;
  final int amount;
  final String currency;
  final String key;

  OrderData({
    required this.razorpayOrderId,
    required this.amount,
    required this.currency,
    required this.key,
  });

  factory OrderData.fromJson(Map<String, dynamic> json) {
    return OrderData(
      razorpayOrderId: json['razorpay_order_id']?.toString() ?? '',
      amount: json['amount'] as int? ?? 0,
      currency: json['currency']?.toString() ?? 'INR',
      key: json['razorpay_key_id']?.toString() ?? json['key']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'razorpay_order_id': razorpayOrderId,
      'amount': amount,
      'currency': currency,
      'razorpay_key_id': key,
    };
  }
}
