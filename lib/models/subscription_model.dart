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
    // Handle both top-level and nested { data: { ... } } responses from backend API
    final root = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
    final subscription = root['subscription'] as Map<String, dynamic>? ?? {};
    final paymentJson = root['payment'] as Map<String, dynamic>? ?? root['last_payment'] as Map<String, dynamic>?;
    final cardsJson = root['cards'] as Map<String, dynamic>?;

    final rawMembership = (root['membership'] ?? subscription['membership'] ?? 'FREE').toString().toUpperCase();
    final subStatus = (subscription['status'] ?? '').toString().toLowerCase();

    final daysRemaining = (subscription['days_remaining'] as num?)?.toInt() ?? 0;
    final isPremiumRole = rawMembership == 'PREMIUM';
    final hasActiveSubDays = daysRemaining > 0;
    final isSubActiveStatus = subStatus == 'active';

    return SubscriptionModel(
      membership: (isPremiumRole && hasActiveSubDays) ? 'PREMIUM' : (isPremiumRole ? 'PREMIUM' : 'FREE'),
      subscriptionStart: subscription['start_date']?.toString() ?? subscription['subscription_start']?.toString() ?? '',
      subscriptionEnd: subscription['end_date']?.toString() ?? subscription['subscription_end']?.toString() ?? '',
      daysRemaining: daysRemaining,
      linkedCards: (cardsJson?['total'] as num?)?.toInt() ?? (subscription['linked_cards'] as num?)?.toInt() ?? 0,
      isActive: isSubActiveStatus && hasActiveSubDays,
      lastPayment: paymentJson != null ? LastPayment.fromJson(paymentJson) : null,
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
      paymentDate: (json['paid_at'] ?? json['payment_date'])?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'payment_date': paymentDate,
    };
  }
}
