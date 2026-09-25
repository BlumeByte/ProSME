import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/constants.dart';
import '../../core/utils/currency.dart';
import '../../core/widgets/loading_state.dart';
import '../../core/widgets/safe_back_button.dart';
import '../../models/app_user.dart';
import '../../models/wallet_transaction.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/invoice_pdf_service.dart';
import '../../services/service_providers.dart';
import '../../services/wallet_service.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  static const _pdfService = InvoicePdfService();
  List<WalletTransaction> _items = const [];
  String? _attemptedLoadKey;
  Object? _error;
  bool _loading = false;
  bool _exporting = false;

  Future<void> _load(AppUser user) async {
    if (_loading) return;
    final loadKey = '${user.id}:${user.role.name}';
    setState(() {
      _loading = true;
      _error = null;
      _attemptedLoadKey = loadKey;
    });
    try {
      final items = shouldUseSupabase()
          ? await WalletService(ref.read(supabaseClientProvider))
              .loadTransactions(userId: user.id, role: user.role)
          : const <WalletTransaction>[];
      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runExport(Future<void> Function() action) async {
    if (_exporting) return;
    final settings = ref.read(appSettingsControllerProvider);
    setState(() => _exporting = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              settings.t('Could not create report. Please try again.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          leading: const SafeBackButton(),
          title: Text(settings.t('Wallet')),
        ),
        body: Center(child: Text(settings.t('Sign in to continue'))),
      );
    }
    final loadKey = '${user.id}:${user.role.name}';
    if (_attemptedLoadKey != loadKey && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(user));
    }

    final isPlatformRole = user.role == UserRole.admin;
    final completedItems =
        _items.where((item) => item.workStatus == 'completed');
    final pendingItems =
        _items.where((item) => item.workStatus != 'completed');
    final completedTotal =
        completedItems.fold<double>(0, (sum, item) => sum + item.amount);
    final pendingTotal =
        pendingItems.fold<double>(0, (sum, item) => sum + item.amount);
    final currencyCode = settings.currencyCode;
    final reportOwner = user.fullName.trim().isNotEmpty
        ? user.fullName.trim()
        : user.name.trim().isEmpty
            ? user.email
            : user.name;

    return Scaffold(
      appBar: AppBar(
        leading: const SafeBackButton(),
        title: Text(
          settings.t(isPlatformRole ? 'Platform wallet' : 'Wallet'),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(user),
            icon: const Icon(Icons.refresh),
            tooltip: settings.t('Refresh'),
          ),
          if (_items.isNotEmpty)
            PopupMenuButton<String>(
              enabled: !_exporting,
              tooltip: settings.t('Wallet report'),
              onSelected: (value) {
                if (value == 'print') {
                  _runExport(
                    () => _pdfService.printWalletReport(
                      _items,
                      reportOwner: reportOwner,
                      translate: settings.t,
                    ),
                  );
                } else if (value == 'share') {
                  _runExport(
                    () => _pdfService.shareWalletReport(
                      _items,
                      reportOwner: reportOwner,
                      translate: settings.t,
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'print',
                  child: ListTile(
                    leading: const Icon(Icons.print_outlined),
                    title: Text(settings.t('Print report')),
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: const Icon(Icons.share_outlined),
                    title: Text(settings.t('Share report')),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading && _items.isEmpty
          ? LoadingState(label: settings.t('Loading wallet...'))
          : RefreshIndicator(
              onRefresh: () => _load(user),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _WalletSummary(
                    title: settings.t(
                      isPlatformRole
                          ? 'Total wallet amount'
                          : user.role == UserRole.artisan
                              ? 'Money received'
                              : 'Money spent',
                    ),
                    subtitle: settings.t(
                      isPlatformRole
                          ? 'Paid out once a job is marked complete.'
                          : user.role == UserRole.artisan
                              ? 'Credited to your wallet once a customer confirms the job is complete.'
                              : 'Charged once you confirm a job is complete.',
                    ),
                    amount: formatMoney(completedTotal, currencyCode),
                    count: completedItems.length,
                    countLabel: settings.t('completed jobs'),
                  ),
                  const SizedBox(height: 8),
                  _WalletSummary(
                    title: settings.t('Pending (not yet completed)'),
                    subtitle: settings.t(
                      'Agreed on an accepted bid, but the job hasn\'t been marked complete yet.',
                    ),
                    amount: formatMoney(pendingTotal, currencyCode),
                    count: pendingItems.length,
                    countLabel: settings.t('accepted jobs'),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                        leading: const Icon(Icons.error_outline),
                        title: Text(settings.t('Could not load wallet.')),
                        subtitle: Text(
                          _walletErrorText(settings, _error!),
                        ),
                        trailing: IconButton(
                          onPressed: () => _load(user),
                          icon: const Icon(Icons.refresh),
                          tooltip: settings.t('Retry'),
                        ),
                      ),
                    )
                  else if (_items.isEmpty)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(settings.t('No wallet activity yet')),
                        subtitle: Text(settings.t(
                          'Accepted bids will appear here automatically.',
                        )),
                      ),
                    )
                  else ...[
                    Text(
                      settings.t('Transactions'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ..._items.map(
                      (item) => _WalletTransactionCard(
                        item: item,
                        currencyCode: currencyCode,
                        settings: settings,
                        onOpen: () => context.push(
                          RouteNames.invoice,
                          extra: item,
                        ),
                        onPrint: () => _runExport(
                          () => _pdfService.printInvoice(
                            item,
                            currencyCode: currencyCode,
                            translate: settings.t,
                          ),
                        ),
                        onShare: () => _runExport(
                          () => _pdfService.shareInvoice(
                            item,
                            currencyCode: currencyCode,
                            translate: settings.t,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

String _walletErrorText(AppSettings settings, Object error) {
  final guidance = settings.t(
    'Make sure the wallet migration has been deployed, then refresh.',
  );
  if (error is PostgrestException) {
    final code = error.code?.trim();
    final suffix = code == null || code.isEmpty ? '' : ' ($code)';
    return '$guidance\n${error.message}$suffix';
  }
  return '$guidance\n$error';
}

class _WalletSummary extends StatelessWidget {
  const _WalletSummary({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.count,
    required this.countLabel,
  });

  final String title;
  final String subtitle;
  final String amount;
  final int count;
  final String countLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                  const SizedBox(height: 8),
                  Text('$count $countLabel'),
                ],
              ),
            ),
            Text(
              amount,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletTransactionCard extends StatelessWidget {
  const _WalletTransactionCard({
    required this.item,
    required this.currencyCode,
    required this.settings,
    required this.onOpen,
    required this.onPrint,
    required this.onShare,
  });

  final WalletTransaction item;
  final String currencyCode;
  final AppSettings settings;
  final VoidCallback onOpen;
  final VoidCallback onPrint;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final parties = '${item.customerName} - ${item.artisanName}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.jobTitle.isEmpty
                        ? settings.t('Accepted work')
                        : item.jobTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMoney(item.amount, currencyCode),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(settings.t('Accepted bid amount')),
            Text(item.invoiceNumber),
            if (item.jobLocation.isNotEmpty) Text(item.jobLocation),
            if (parties.replaceAll(' - ', '').trim().isNotEmpty) Text(parties),
            Text(settings.t(item.workStatus)),
            Text(DateFormat('MMM d, y h:mm a').format(item.createdAt)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(settings.t('View invoice')),
                  ),
                ),
                IconButton(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print_outlined),
                  tooltip: settings.t('Print invoice'),
                ),
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_outlined),
                  tooltip: settings.t('Share invoice'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
