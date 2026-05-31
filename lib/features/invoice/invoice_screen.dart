import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/primary_button.dart';
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

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    if (listing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
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
      appBar: AppBar(title: const Text('Invoice')),
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
          RadioListTile(
            title: const Text('Cash in person'),
            value: PaymentMethod.cash,
            groupValue: _selected,
            onChanged: (value) => setState(() => _selected = value!),
          ),
          RadioListTile(
            title: const Text('Paystack MoMo'),
            value: PaymentMethod.paystack,
            groupValue: _selected,
            onChanged: (value) => setState(() => _selected = value!),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: _selected == PaymentMethod.cash
                ? 'Confirm cash payment'
                : 'Pay with Paystack',
            icon: Icons.payment,
            onPressed: () {},
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
