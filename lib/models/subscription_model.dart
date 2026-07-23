class SubscriptionModel {
  final String membership;
  final String subscriptionStart;
  final String subscriptionEnd;
  final int daysRemaining;
  final int linkedCards;
  final bool isActive;
  final LastPayment? lastPayment;

  SubscriptionModel({
    required this.membership,
    required this.subscriptionStart,
    required this.subscriptionEnd,
    required this.daysRemaining,
    required this.linkedCards,
    required this.isActive,
    this.lastPayment,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    final subscription = json['subscription'] as Map<String, dynamic>? ?? {};
    final lastPaymentJson = json['last_payment'] as Map<String, dynamic>?;
    
    return SubscriptionModel(
      membership: json['membership']?.toString() ?? subscription['membership']?.toString() ?? 'FREE',
      subscriptionStart: subscription['start_date']?.toString() ?? subscription['subscription_start']?.toString() ?? '',
      subscriptionEnd: subscription['end_date']?.toString() ?? subscription['subscription_end']?.toString() ?? '',
      daysRemaining: subscription['days_remaining'] as int? ?? 0,
      linkedCards: subscription['linked_cards'] as int? ?? 0,
      isActive: subscription['status']?.toString().toLowerCase() == 'active' || subscription['is_active'] == true,
      lastPayment: lastPaymentJson != null ? LastPayment.fromJson(lastPaymentJson) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'membership': membership,
      'subscription_start': subscriptionStart,
      'subscription_end': subscriptionEnd,
      'days_remaining': daysRemaining,
      'linked_cards': linkedCards,
      'is_active': isActive,
      'last_payment': lastPayment?.toJson(),
    };
  }
}

class LastPayment {
  final double amount;
  final String paymentDate;

  LastPayment({
    required this.amount,
    required this.paymentDate,
  });

  factory LastPayment.fromJson(Map<String, dynamic> json) {
    return LastPayment(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: json['payment_date']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'payment_date': paymentDate,
    };
  }
}
