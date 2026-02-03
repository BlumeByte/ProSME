import 'package:flutter/material.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/utils/mock_data.dart';
import '../../config/constants.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  PaymentMethod _selected = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    final invoice = demoInvoice;
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Invoice #${invoice.id}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...invoice.lines.map(
            (line) => ListTile(
              title: Text(line.label),
              trailing: Text(formatCurrency(line.amount * line.quantity)),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Subtotal'),
            trailing: Text(formatCurrency(invoice.subtotal)),
          ),
          ListTile(
            title: const Text('Service Fee'),
            trailing: Text(formatCurrency(invoice.fee)),
          ),
          ListTile(
            title: const Text('Total'),
            trailing: Text(formatCurrency(invoice.total)),
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
