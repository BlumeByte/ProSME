import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../config/constants.dart';
import '../../models/listing.dart';
import '../../services/service_providers.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({super.key, required this.listing});

  final Listing? listing;

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  PaymentMethod _selected = PaymentMethod.cash;

  Future<void> _handlePayment() async {
    if (_selected == PaymentMethod.cash) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Cash payment selected. Confirm payment with the artisan.'),
        ),
      );
      return;
    }

    if (kPaystackCheckoutUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paystack checkout URL is not configured yet.'),
        ),
      );
      return;
    }

    try {
      await ref.read(paymentServiceProvider).launchPaystackCheckout(
            kPaystackCheckoutUrl,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Paystack checkout.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    if (listing == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(),
          title: const Text('Invoice'),
        ),
        body: const Center(
          child: Text('No listing selected. Open invoice from a listing.'),
        ),
      );
    }
    final user = ref.watch(authStateProvider).valueOrNull;
    final unitAmount = (listing.priceMin + listing.priceMax) / 2;
    final subtotal = unitAmount;
    final fee = subtotal * 0.05;
    final total = subtotal + fee;
    final invoiceId = '${listing.id}-${user?.id ?? 'guest'}';

    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: const Text('Invoice'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Invoice #$invoiceId',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...[
            _InvoiceLineItem(
              label: listing.title,
              quantity: 1,
              amount: unitAmount,
            ),
          ].map(
            (line) => ListTile(
              title: Text(line.label),
              trailing: Text(formatCurrency(line.amount * line.quantity)),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Subtotal'),
            trailing: Text(formatCurrency(subtotal)),
          ),
          ListTile(
            title: const Text('Service Fee'),
            trailing: Text(formatCurrency(fee)),
          ),
          ListTile(
            title: const Text('Total'),
            trailing: Text(formatCurrency(total)),
          ),
          const SizedBox(height: 16),
          Text('Payment method',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<PaymentMethod>(
            segments: const [
              ButtonSegment(
                value: PaymentMethod.cash,
                icon: Icon(Icons.payments_outlined),
                label: Text('Cash'),
              ),
              ButtonSegment(
                value: PaymentMethod.paystack,
                icon: Icon(Icons.phone_android_outlined),
                label: Text('MoMo'),
              ),
            ],
            selected: {_selected},
            onSelectionChanged: (selection) {
              setState(() => _selected = selection.first);
            },
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: _selected == PaymentMethod.cash
                ? 'Confirm cash payment'
                : 'Pay with Paystack',
            icon: Icons.payment,
            onPressed: _handlePayment,
          ),
        ],
      ),
    );
  }
}

class _InvoiceLineItem {
  const _InvoiceLineItem({
    required this.label,
    required this.quantity,
    required this.amount,
  });

  final String label;
  final int quantity;
  final double amount;
}
