class VerificationSubscription {
  const VerificationSubscription({
    required this.id,
    required this.userId,
    required this.role,
    required this.planInterval,
    required this.status,
    required this.amountUsd,
    required this.chargeCurrency,
    required this.chargeAmount,
    this.paystackReference = '',
    this.authorizationUrl = '',
    this.autoRenew = false,
    this.paymentMethodChannel = '',
    this.paymentMethodLabel = '',
    this.lastRenewalError = '',
    this.currentPeriodEnd,
    this.lastPaymentAt,
  });

  final String id;
  final String userId;
  final String role;
  final String planInterval;
  final String status;
  final double amountUsd;
  final String chargeCurrency;
  final int chargeAmount;
  final String paystackReference;
  final String authorizationUrl;
  final bool autoRenew;
  final String paymentMethodChannel;
  final String paymentMethodLabel;
  final String lastRenewalError;
  final DateTime? currentPeriodEnd;
  final DateTime? lastPaymentAt;

  bool get isActive =>
      status == 'active' &&
      (currentPeriodEnd == null || currentPeriodEnd!.isAfter(DateTime.now()));
  bool get needsPayment =>
      status == 'payment_required' ||
      status == 'pending_payment' ||
      status == 'expired';
  bool get isPaidPendingReview => status == 'paid_pending_review';

  factory VerificationSubscription.fromJson(Map<String, dynamic> json) {
    return VerificationSubscription(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      planInterval: (json['plan_interval'] ?? 'monthly').toString(),
      status: (json['status'] ?? 'payment_required').toString(),
      amountUsd: ((json['amount_usd'] ?? 0) as num).toDouble(),
      chargeCurrency: (json['charge_currency'] ?? 'GHS').toString(),
      chargeAmount: ((json['charge_amount'] ?? 0) as num).toInt(),
      paystackReference: (json['paystack_reference'] ?? '').toString(),
      authorizationUrl: (json['paystack_authorization_url'] ?? '').toString(),
      autoRenew: json['auto_renew'] == true,
      paymentMethodChannel: (json['payment_method_channel'] ?? '').toString(),
      paymentMethodLabel: (json['payment_method_label'] ?? '').toString(),
      lastRenewalError: (json['last_renewal_error'] ?? '').toString(),
      currentPeriodEnd: DateTime.tryParse(
        (json['current_period_end'] ?? '').toString(),
      ),
      lastPaymentAt: DateTime.tryParse(
        (json['last_payment_at'] ?? '').toString(),
      ),
    );
  }
}
