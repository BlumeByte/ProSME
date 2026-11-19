import 'package:flutter_test/flutter_test.dart';
import 'package:prosme/services/payment_service.dart';

void main() {
  test('rejects checkout destinations outside Paystack HTTPS', () async {
    const payment = PaymentService();
    for (final destination in [
      '',
      'http://checkout.paystack.com/fixture',
      'https://example.test/checkout',
      'https://checkout.paystack.com:8443/fixture',
    ]) {
      await expectLater(
        payment.launchPaystackCheckout(destination),
        throwsFormatException,
      );
    }
  });
}
