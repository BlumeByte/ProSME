import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import '../core/utils/currency.dart';
import '../models/verification_subscription.dart';

class PaymentService {
  const PaymentService([this._supabase]);

  final SupabaseClient? _supabase;

  Future<void> launchPaystackCheckout(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch Paystack checkout');
    }
  }

  Stream<VerificationSubscription?> watchVerificationSubscription(
    String userId,
  ) async* {
    yield await fetchVerificationSubscription(userId);
    final client = _supabase;
    if (client == null) return;
    yield* client
        .from('verification_subscriptions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((_) => fetchVerificationSubscription(userId));
  }

  Future<VerificationSubscription?> fetchVerificationSubscription(
    String userId,
  ) async {
    final client = _supabase;
    if (client == null) return null;
    final row = await client
        .from('verification_subscriptions')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null
        ? null
        : VerificationSubscription.fromJson(
            Map<String, dynamic>.from(row),
          );
  }

  Future<VerificationCheckout> startVerificationCheckout({
    required String interval,
    String channel = '',
    String currencyCode = 'GHS',
  }) async {
    final client = _supabase;
    if (client == null) {
      throw StateError('Account service is not connected.');
    }
    final response = await client.functions.invoke(
      'verification-billing',
      body: {
        'action': 'initialize',
        'interval': interval,
        'displayCurrency': currencyCode,
        if (channel.trim().isNotEmpty) 'channel': channel.trim(),
      },
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    if (response.status < 200 || response.status >= 300 || data['ok'] != true) {
      throw StateError(
        (data['error'] ?? 'Could not start verification payment.').toString(),
      );
    }
    final checkout = VerificationCheckout.fromJson(data);
    await launchPaystackCheckout(checkout.authorizationUrl);
    return checkout;
  }

  Future<void> verifyVerificationPayment(String reference) async {
    final client = _supabase;
    if (client == null || reference.trim().isEmpty) return;
    final response = await client.functions.invoke(
      'verification-billing',
      body: {
        'action': 'verify',
        'reference': reference.trim(),
      },
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    if (response.status < 200 || response.status >= 300 || data['ok'] != true) {
      throw StateError(
        (data['error'] ?? 'Could not verify payment.').toString(),
      );
    }
  }

  Future<void> refreshVerificationBilling() async {
    final client = _supabase;
    if (client == null) return;
    final response = await client.functions.invoke(
      'verification-billing',
      body: {'action': 'syncExpirations'},
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    if (response.status < 200 || response.status >= 300 || data['ok'] != true) {
      throw StateError(
        (data['error'] ?? 'Could not refresh verification status.').toString(),
      );
    }
  }

  String verificationPriceLabel({
    required String role,
    required String interval,
    required String currencyCode,
  }) {
    final monthlyUsd = role == UserRole.artisan.name
        ? kVerificationArtisanMonthlyUsd
        : kVerificationCustomerMonthlyUsd;
    final amountUsd = interval == 'yearly' ? monthlyUsd * 12 : monthlyUsd;
    final amountGhs = amountUsd * kUsdToGhsEstimate;
    return '${formatMoney(amountGhs, currencyCode)} / ${interval == 'yearly' ? 'year' : 'month'}';
  }
}

class VerificationCheckout {
  const VerificationCheckout({
    required this.reference,
    required this.authorizationUrl,
    required this.amountUsd,
    required this.chargeCurrency,
    required this.chargeAmount,
  });

  final String reference;
  final String authorizationUrl;
  final double amountUsd;
  final String chargeCurrency;
  final int chargeAmount;

  factory VerificationCheckout.fromJson(Map<String, dynamic> json) {
    return VerificationCheckout(
      reference: (json['reference'] ?? '').toString(),
      authorizationUrl: (json['authorizationUrl'] ?? '').toString(),
      amountUsd: ((json['amountUsd'] ?? 0) as num).toDouble(),
      chargeCurrency: (json['chargeCurrency'] ?? 'GHS').toString(),
      chargeAmount: ((json['chargeAmount'] ?? 0) as num).toInt(),
    );
  }
}
