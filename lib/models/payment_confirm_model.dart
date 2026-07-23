class PaymentConfirmModel {
  final bool success;
  final String? message;
  final ConfirmSubscription? subscription;

  PaymentConfirmModel({
    required this.success,
    this.message,
    this.subscription,
  });

  factory PaymentConfirmModel.fromJson(Map<String, dynamic> json) {
    final subscriptionJson = json['subscription'] as Map<String, dynamic>?;
    
    return PaymentConfirmModel(
      success: json['success'] as bool? ?? false,
      message: json['message']?.toString(),
      subscription: subscriptionJson != null ? ConfirmSubscription.fromJson(subscriptionJson) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'subscription': subscription?.toJson(),
    };
  }
}

class ConfirmSubscription {
  final String membership;
  final String subscriptionEnd;

  ConfirmSubscription({
    required this.membership,
    required this.subscriptionEnd,
  });

  factory ConfirmSubscription.fromJson(Map<String, dynamic> json) {
    return ConfirmSubscription(
      membership: json['membership']?.toString() ?? '',
      subscriptionEnd: json['subscription_end']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'membership': membership,
      'subscription_end': subscriptionEnd,
    };
  }
}
