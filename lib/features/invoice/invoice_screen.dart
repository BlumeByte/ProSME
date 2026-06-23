import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../config/constants.dart';
import '../../models/listing.dart';
import '../../models/chat_models.dart';
import '../../models/wallet_transaction.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/service_providers.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  const InvoiceScreen({
    super.key,
    this.listing,
    this.transaction,
  });

  final Listing? listing;
  final WalletTransaction? transaction;

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  static const _pdfService = InvoicePdfService();
  PaymentMethod _selected = PaymentMethod.cash;
  bool _exporting = false;

  Future<void> _export(Future<void> Function() action) async {
    if (_exporting) return;
    final settings = ref.read(appSettingsControllerProvider);
    setState(() => _exporting = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${settings.t('Could not create invoice')}: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _handlePayment() async {
    final settings = ref.read(appSettingsControllerProvider);
    if (_selected == PaymentMethod.cash) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            settings
                .t('Cash payment selected. Confirm payment with the artisan.'),
          ),
        ),
      );
      return;
    }

    if (kPaystackCheckoutUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(settings.t('Paystack checkout URL is not configured yet.')),
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
        SnackBar(
            content: Text(settings.t('Could not open Paystack checkout.'))),
      );
    }
  }

  Future<void> _sendInvoiceToChat(WalletTransaction transaction) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || user.id != transaction.artisanId) return;
    final settings = ref.read(appSettingsControllerProvider);
    await _export(() async {
      final thread = await ref.read(chatServiceProvider).createOrOpenThread(
            userId: transaction.customerId,
            artisanId: transaction.artisanId,
          );
      await ref.read(chatServiceProvider).sendMessage(
            ChatMessage(
              id: const Uuid().v4(),
              threadId: thread.id,
              senderId: user.id,
              type: MessageType.invoice,
              content: jsonEncode(transaction.toJson()),
              createdAt: DateTime.now(),
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Invoice sent to chat.'))),
      );
      context.push('${RouteNames.chatThread}/${thread.id}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final transaction = widget.transaction;
    final settings = ref.watch(appSettingsControllerProvider);
    if (transaction != null) {
      return _buildTransactionInvoice(context, settings, transaction);
    }
    if (listing == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(),
          title: Text(settings.t('Invoice')),
        ),
        body: Center(
          child: Text(
            settings.t('No listing selected. Open invoice from a listing.'),
          ),
        ),
      );
    }
    final user = ref.watch(authStateProvider).valueOrNull;
    final currencyCode = settings.currencyCode;
    final unitAmount = (listing.priceMin + listing.priceMax) / 2;
    final subtotal = unitAmount;
    final fee = subtotal * 0.05;
    final total = subtotal + fee;
    final invoiceId = '${listing.id}-${user?.id ?? 'guest'}';

    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('Invoice')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${settings.t('Invoice')} #$invoiceId',
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
              trailing: Text(
                formatCurrency(
                  line.amount * line.quantity,
                  currencyCode: currencyCode,
                ),
              ),
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(settings.t('Subtotal')),
            trailing:
                Text(formatCurrency(subtotal, currencyCode: currencyCode)),
          ),
          ListTile(
            title: Text(settings.t('Service Fee')),
            trailing: Text(formatCurrency(fee, currencyCode: currencyCode)),
          ),
          ListTile(
            title: Text(settings.t('Total')),
            trailing: Text(formatCurrency(total, currencyCode: currencyCode)),
          ),
          const SizedBox(height: 16),
          Text(settings.t('Payment method'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<PaymentMethod>(
            segments: [
              ButtonSegment(
                value: PaymentMethod.cash,
                icon: const Icon(Icons.payments_outlined),
                label: Text(settings.t('Cash')),
              ),
              ButtonSegment(
                value: PaymentMethod.paystack,
                icon: const Icon(Icons.phone_android_outlined),
                label: Text(settings.t('MoMo')),
              ),
            ],
            selected: {_selected},
            onSelectionChanged: (selection) {
              setState(() => _selected = selection.first);
            },
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: settings.t(_selected == PaymentMethod.cash
                ? 'Confirm cash payment'
                : 'Pay with Paystack'),
            icon: Icons.payment,
            onPressed: _handlePayment,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionInvoice(
    BuildContext context,
    AppSettings settings,
    WalletTransaction transaction,
  ) {
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final canSendToChat = currentUser?.id == transaction.artisanId;
    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(settings.t('Invoice')),
        actions: [
          IconButton(
            onPressed: _exporting
                ? null
                : () => _export(() => _pdfService.printInvoice(transaction)),
            icon: const Icon(Icons.print_outlined),
            tooltip: settings.t('Print invoice'),
          ),
          IconButton(
            onPressed: _exporting
                ? null
                : () => _export(() => _pdfService.shareInvoice(transaction)),
            icon: const Icon(Icons.share_outlined),
            tooltip: settings.t('Share invoice'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Image.asset(
              'assets/images/prosme_logo.png',
              width: 76,
              height: 76,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ProSME',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            settings.t('Professional services marketplace'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${settings.t('Invoice')} ${transaction.invoiceNumber}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(
                    label: settings.t('Date'),
                    value: DateFormat('MMM d, y').format(transaction.createdAt),
                  ),
                  _DetailRow(
                    label: settings.t('Status'),
                    value: settings.t(transaction.paymentStatus),
                  ),
                  _DetailRow(
                    label: settings.t('Work'),
                    value: transaction.jobTitle,
                  ),
                  if (transaction.jobLocation.isNotEmpty)
                    _DetailRow(
                      label: settings.t('Location'),
                      value: transaction.jobLocation,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PartyCard(
                  label: settings.t('Customer'),
                  name: transaction.customerName,
                  email: transaction.customerEmail,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PartyCard(
                  label: settings.t('Service provider'),
                  name: transaction.artisanName,
                  email: transaction.artisanEmail,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text(settings.t('Total')),
              trailing: Text(
                '${transaction.currency} ${transaction.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _exporting
                ? null
                : () => _export(() => _pdfService.printInvoice(transaction)),
            icon: const Icon(Icons.print_outlined),
            label: Text(settings.t('Print invoice')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _exporting
                ? null
                : () => _export(() => _pdfService.shareInvoice(transaction)),
            icon: const Icon(Icons.share_outlined),
            label: Text(settings.t('Share invoice')),
          ),
          if (canSendToChat) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  _exporting ? null : () => _sendInvoiceToChat(transaction),
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text(settings.t('Send invoice to chat')),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({
    required this.label,
    required this.name,
    required this.email,
  });

  final String label;
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(name.isEmpty ? '-' : name),
            if (email.isNotEmpty) Text(email),
          ],
        ),
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
