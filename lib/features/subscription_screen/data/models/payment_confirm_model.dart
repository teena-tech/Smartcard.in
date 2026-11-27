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
    // Backend nests subscription under data.subscription
    final dataJson = json['data'] as Map<String, dynamic>?;
    final subscriptionJson = dataJson?['subscription'] as Map<String, dynamic>?
        ?? json['subscription'] as Map<String, dynamic>?;

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
  final String? subscriptionStart;
  final int? daysAdded;
  final int? daysRemaining;

  ConfirmSubscription({
    required this.membership,
    required this.subscriptionEnd,
    this.subscriptionStart,
    this.daysAdded,
    this.daysRemaining,
  });

  factory ConfirmSubscription.fromJson(Map<String, dynamic> json) {
    return ConfirmSubscription(
      membership: json['membership']?.toString() ?? '',
      subscriptionEnd: json['end_date']?.toString() ?? json['subscription_end']?.toString() ?? '',
      subscriptionStart: json['start_date']?.toString() ?? json['subscription_start']?.toString(),
      daysAdded: json['days_added'] as int?,
      daysRemaining: json['days_remaining'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'membership': membership,
      'subscription_end': subscriptionEnd,
      'subscription_start': subscriptionStart,
      'days_added': daysAdded,
      'days_remaining': daysRemaining,
    };
  }
}
