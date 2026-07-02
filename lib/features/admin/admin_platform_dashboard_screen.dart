import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/constants.dart';
import '../../core/utils/currency.dart';
import '../../models/wallet_transaction.dart';
import '../../routes/route_names.dart';
import '../../services/app_settings_controller.dart';
import '../../services/admin_service.dart';
import '../../services/service_providers.dart';
import '../../services/wallet_service.dart';

class AdminPlatformDashboardScreen extends ConsumerStatefulWidget {
  const AdminPlatformDashboardScreen({super.key});

  @override
  ConsumerState<AdminPlatformDashboardScreen> createState() =>
      _AdminPlatformDashboardScreenState();
}

class _AdminPlatformDashboardScreenState
    extends ConsumerState<AdminPlatformDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final sections = [
      const _AdminOverview(),
      const _ReportsPanel(),
      const _AccountsPanel(),
      const _AdminWalletPanel(),
      const _TenantsPanel(),
      const _ModulesPanel(),
    ];
    final destinations = [
      NavigationDestination(
        icon: const Icon(Icons.monitor_heart_outlined),
        label: settings.t('Overview'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.report_gmailerrorred_outlined),
        label: settings.t('Reports'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.people_alt_outlined),
        label: settings.t('Accounts'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        label: settings.t('Wallet'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.business_outlined),
        label: settings.t('Tenants'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.extension_outlined),
        label: settings.t('Modules'),
      ),
    ];
    final useBottomNav = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: AppBar(
        title: Text(settings.t('Admin Dashboard')),
        actions: [
          IconButton(
            tooltip: settings.t('Logout'),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go(RouteNames.auth);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: useBottomNav
          ? sections[_selectedIndex]
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() => _selectedIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: destination.icon,
                          label: Text(destination.label),
                        ),
                      )
                      .toList(growable: false),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: sections[_selectedIndex]),
              ],
            ),
      bottomNavigationBar: useBottomNav
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              destinations: destinations,
            )
          : null,
    );
  }
}

class _AdminOverview extends ConsumerWidget {
  const _AdminOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return FutureBuilder<PlatformModuleCounts>(
      future: ref.watch(adminServiceProvider).fetchModuleCounts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
            message: settings.t(
              'Could not load platform modules. Please try again.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final counts = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              settings.t('Platform control'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              settings.t(
                'Use this area to inspect account roles, tenants, marketplace modules, jobs, bids, chats, and support notifications.',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricCard(
                    label: settings.t('Accounts'), value: counts.accounts),
                _MetricCard(
                    label: settings.t('Tenants'), value: counts.tenants),
                _MetricCard(
                    label: settings.t('Listings'), value: counts.listings),
                _MetricCard(label: settings.t('Jobs'), value: counts.jobs),
                _MetricCard(label: settings.t('Bids'), value: counts.bids),
                _MetricCard(label: settings.t('Chats'), value: counts.threads),
                _MetricCard(
                    label: settings.t('Messages'), value: counts.messages),
                _MetricCard(
                    label: settings.t('Reports'), value: counts.reports),
                _MetricCard(
                    label: settings.t('Alerts'), value: counts.notifications),
                _MetricCard(
                  label: settings.t('Wallet transactions'),
                  value: counts.walletTransactions,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _JobProgressHealth(counts: counts),
            const SizedBox(height: 16),
            const _WalletFlowPreview(),
            const SizedBox(height: 16),
            const _RecentReportsPreview(),
          ],
        );
      },
    );
  }
}

class _WalletFlowPreview extends ConsumerWidget {
  const _WalletFlowPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    return FutureBuilder<List<WalletTransaction>>(
      future: user == null
          ? Future.value(const <WalletTransaction>[])
          : shouldUseSupabase()
              ? WalletService(ref.watch(supabaseClientProvider))
                  .loadTransactions(
                  userId: user.id,
                  role: user.role,
                )
              : Future.value(const <WalletTransaction>[]),
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <WalletTransaction>[];
        final total = rows.fold<double>(
          0,
          (sum, row) => sum + row.amount,
        );
        return Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(settings.t('Wallet flow')),
            subtitle: Text(
              snapshot.hasError
                  ? settings.t('Could not load wallet.')
                  : !snapshot.hasData
                      ? settings.t('Loading wallet...')
                      : rows.isEmpty
                          ? settings.t('No wallet activity yet')
                          : settings.t('Latest accepted bid money flow.'),
            ),
            trailing: snapshot.hasData
                ? Text(
                    formatMoney(total, settings.currencyCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  )
                : const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
            onTap: () => context.push(RouteNames.wallet),
          ),
        );
      },
    );
  }
}

class _JobProgressHealth extends ConsumerWidget {
  const _JobProgressHealth({required this.counts});

  final PlatformModuleCounts counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final activeJobs = counts.acceptedJobs +
        counts.startPendingJobs +
        counts.inProgressJobs +
        counts.completionPendingJobs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    settings.t('Job progress health'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(
                    '${settings.t('Active')}: $activeJobs',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _ProgressMetric(
                  label: settings.t('Open'),
                  value: counts.openJobs,
                  icon: Icons.radio_button_checked,
                ),
                _ProgressMetric(
                  label: settings.t('Accepted'),
                  value: counts.acceptedJobs,
                  icon: Icons.handshake_outlined,
                ),
                _ProgressMetric(
                  label: settings.t('Start pending'),
                  value: counts.startPendingJobs,
                  icon: Icons.pending_actions_outlined,
                ),
                _ProgressMetric(
                  label: settings.t('In progress'),
                  value: counts.inProgressJobs,
                  icon: Icons.handyman_outlined,
                ),
                _ProgressMetric(
                  label: settings.t('Completion pending'),
                  value: counts.completionPendingJobs,
                  icon: Icons.fact_check_outlined,
                ),
                _ProgressMetric(
                  label: settings.t('Completed'),
                  value: counts.completedJobs,
                  icon: Icons.task_alt,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 170,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.toString(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminWalletPanel extends ConsumerStatefulWidget {
  const _AdminWalletPanel();

  @override
  ConsumerState<_AdminWalletPanel> createState() => _AdminWalletPanelState();
}

class _AdminWalletPanelState extends ConsumerState<_AdminWalletPanel> {
  Future<List<WalletTransaction>>? _future;
  String? _loadKey;

  void _refresh(String userId, UserRole role) {
    setState(() {
      _future = WalletService(ref.read(supabaseClientProvider))
          .loadTransactions(userId: userId, role: role);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsControllerProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) {
      return Center(child: Text(settings.t('Sign in to continue')));
    }
    final key = '${user.id}:${user.role.name}';
    if (_loadKey != key) {
      _loadKey = key;
      _future = WalletService(ref.read(supabaseClientProvider))
          .loadTransactions(userId: user.id, role: user.role);
    }

    return FutureBuilder<List<WalletTransaction>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
            message: settings.t('Could not load wallet. Please try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        final total = rows.fold<double>(0, (sum, row) => sum + row.amount);
        final completed =
            rows.where((row) => row.workStatus == 'completed').length;
        final customers = rows
            .map((row) => row.customerId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .length;
        final artisans = rows
            .map((row) => row.artisanId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    settings.t('Wallet tracking'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => _refresh(user.id, user.role),
                  icon: const Icon(Icons.refresh),
                  tooltip: settings.t('Refresh'),
                ),
                FilledButton.icon(
                  onPressed: () => context.push(RouteNames.wallet),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: Text(settings.t('Reports and invoices')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _WalletMetric(
                  label: settings.t('Tracked amount'),
                  value: formatMoney(total, settings.currencyCode),
                ),
                _WalletMetric(
                  label: settings.t('Transactions'),
                  value: rows.length.toString(),
                ),
                _WalletMetric(
                  label: settings.t('Completed work'),
                  value: completed.toString(),
                ),
                _WalletMetric(
                  label: settings.t('Customers'),
                  value: customers.toString(),
                ),
                _WalletMetric(
                  label: settings.t('Artisans'),
                  value: artisans.toString(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(settings.t('No wallet activity yet')),
                ),
              )
            else
              ...rows.map(
                (row) => Card(
                  child: ListTile(
                    leading: Icon(
                      row.workStatus == 'completed'
                          ? Icons.task_alt
                          : Icons.handshake_outlined,
                    ),
                    title: Text(
                      row.jobTitle.isEmpty
                          ? settings.t('Accepted work')
                          : row.jobTitle,
                    ),
                    subtitle: Text(
                      '${row.customerName} - ${row.artisanName}\n${row.invoiceNumber} - ${settings.t(row.workStatus)}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      formatMoney(row.amount, settings.currencyCode),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () => context.push(
                      RouteNames.invoice,
                      extra: row,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WalletMetric extends StatelessWidget {
  const _WalletMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentReportsPreview extends ConsumerWidget {
  const _RecentReportsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return StreamBuilder<List<PlatformReport>>(
      stream: ref.watch(adminServiceProvider).watchReports(),
      builder: (context, snapshot) {
        final reports = (snapshot.data ?? const <PlatformReport>[])
            .where((report) => report.status == 'open')
            .take(3)
            .toList(growable: false);
        if (reports.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(settings.t('No open reports')),
              subtitle: Text(
                settings.t('Chat and support reports will appear here.'),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(settings.t('Needs review'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...reports.map((report) => _ReportTile(report: report)),
          ],
        );
      },
    );
  }
}

class _ReportsPanel extends ConsumerWidget {
  const _ReportsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return StreamBuilder<List<PlatformReport>>(
      stream: ref.watch(adminServiceProvider).watchReports(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
            message: settings.t('Could not load reports. Please try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return Center(child: Text(settings.t('No reports yet.')));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _ReportTile(report: reports[index]),
        );
      },
    );
  }
}

class _ReportTile extends ConsumerWidget {
  const _ReportTile({required this.report});

  final PlatformReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final statusColor = switch (report.status) {
      'open' => Colors.orange,
      'resolved' => Colors.green,
      'dismissed' => Colors.grey,
      _ => Theme.of(context).colorScheme.primary,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.report_gmailerrorred_outlined, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.title.isEmpty ? report.type : report.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(settings.t(report.status))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report.body.isEmpty
                  ? settings.t('No details provided.')
                  : report.body,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(report.type)),
                if (report.category.isNotEmpty)
                  Chip(label: Text(report.category)),
                if (report.relatedTable.isNotEmpty)
                  Chip(
                      label:
                          Text('${report.relatedTable}: ${report.relatedId}')),
                if (report.reportedUserId.isNotEmpty)
                  Chip(
                    label: Text(
                      '${settings.t('reported')}: ${report.reportedUserId}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: report.status == 'dismissed'
                      ? null
                      : () => ref.read(adminServiceProvider).updateReportStatus(
                            reportId: report.id,
                            status: 'dismissed',
                          ),
                  icon: const Icon(Icons.close),
                  label: Text(settings.t('Dismiss')),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: report.status == 'resolved'
                      ? null
                      : () => ref.read(adminServiceProvider).updateReportStatus(
                            reportId: report.id,
                            status: 'resolved',
                          ),
                  icon: const Icon(Icons.check),
                  label: Text(settings.t('Resolve')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsPanel extends ConsumerWidget {
  const _AccountsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return StreamBuilder<List<PlatformAccount>>(
      stream: ref.watch(adminServiceProvider).watchAccounts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
            message: settings.t('Could not load accounts. Please try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final accounts = snapshot.data!;
        if (accounts.isEmpty) {
          return Center(child: Text(settings.t('No accounts found.')));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: accounts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return _AccountTile(account: accounts[index]);
          },
        );
      },
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});

  final PlatformAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(_initial(account.name))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(account.email.isEmpty ? account.id : account.email),
                    ],
                  ),
                ),
                Chip(label: Text(account.role.name)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                    label:
                        Text('${settings.t('tenant')}: ${account.tenantId}')),
                Chip(
                    label: Text(
                        '${settings.t('verification')}: ${account.verificationStatus.name}')),
                if (account.phone.isNotEmpty) Chip(label: Text(account.phone)),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [UserRole.customer, UserRole.artisan].map((role) {
                  final selected = account.role == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton(
                      onPressed: selected
                          ? null
                          : () async {
                              await ref
                                  .read(adminServiceProvider)
                                  .updateAccountRole(
                                    userId: account.id,
                                    role: role,
                                  );
                            },
                      child: Text(selected
                          ? '${role.name} ${settings.t('active')}'
                          : '${settings.t('Set')} ${role.name}'),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }
}

class _TenantsPanel extends ConsumerWidget {
  const _TenantsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return StreamBuilder<List<PlatformAccount>>(
      stream: ref.watch(adminServiceProvider).watchAccounts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
            message: settings.t('Could not load tenants. Please try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final grouped = <String, List<PlatformAccount>>{};
        for (final account in snapshot.data!) {
          grouped
              .putIfAbsent(account.tenantId, () => <PlatformAccount>[])
              .add(account);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: grouped.entries.map((entry) {
            final artisans = entry.value
                .where((account) => account.role == UserRole.artisan)
                .length;
            final users = entry.value
                .where((account) => account.role == UserRole.customer)
                .length;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.business_outlined),
                title: Text(entry.key),
                subtitle: Text(
                  '${entry.value.length} ${settings.t('accounts')} - $users ${settings.t('users')} - $artisans ${settings.t('artisans')}',
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _ModulesPanel extends ConsumerWidget {
  const _ModulesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return FutureBuilder<PlatformModuleCounts>(
      future: ref.watch(adminServiceProvider).fetchModuleCounts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
            message: settings.t('Could not load modules. Please try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final counts = snapshot.data!;
        final modules = [
          ('Profiles', counts.accounts, 'Account and role records'),
          ('Listings', counts.listings, 'Artisan service listings'),
          ('Jobs', counts.jobs, 'Customer service requests'),
          ('Bids', counts.bids, 'Negotiation offers from artisans'),
          ('Threads', counts.threads, 'Chat rooms'),
          ('Messages', counts.messages, 'Chat messages and offers'),
          ('Reports', counts.reports, 'Chat, support, and safety reports'),
          ('Notifications', counts.notifications, 'Support tasks'),
          (
            'Wallet transactions',
            counts.walletTransactions,
            'Accepted and completed bid money flow'
          ),
        ];
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: modules.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final module = modules[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.extension_outlined),
                title: Text(settings.t(module.$1)),
                subtitle: Text(settings.t(module.$3)),
                trailing: Text(module.$2.toString()),
              ),
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.toString(),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
