import 'package:url_launcher/url_launcher.dart';

class PaymentService {
  Future<void> launchPaystackCheckout(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch Paystack checkout');
    }
  }
}
