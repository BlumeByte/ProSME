import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../services/admin_service.dart';
import '../../services/service_providers.dart';

class DeveloperDashboardScreen extends ConsumerStatefulWidget {
  const DeveloperDashboardScreen({super.key});

  @override
  ConsumerState<DeveloperDashboardScreen> createState() =>
      _DeveloperDashboardScreenState();
}

class _DeveloperDashboardScreenState
    extends ConsumerState<DeveloperDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final sections = [
      const _DeveloperOverview(),
      const _ReportsPanel(),
      const _AccountsPanel(),
      const _TenantsPanel(),
      const _ModulesPanel(),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Support Dashboard')),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.monitor_heart_outlined),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.report_gmailerrorred_outlined),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_alt_outlined),
                label: Text('Accounts'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.business_outlined),
                label: Text('Tenants'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.extension_outlined),
                label: Text('Modules'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: sections[_selectedIndex]),
        ],
      ),
    );
  }
}

class _DeveloperOverview extends ConsumerWidget {
  const _DeveloperOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PlatformModuleCounts>(
      future: ref.watch(adminServiceProvider).fetchModuleCounts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
              message: 'Could not load platform modules: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final counts = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Platform control',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use this area to inspect account roles, tenants, marketplace modules, jobs, bids, chats, and support notifications.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricCard(label: 'Accounts', value: counts.accounts),
                _MetricCard(label: 'Tenants', value: counts.tenants),
                _MetricCard(label: 'Listings', value: counts.listings),
                _MetricCard(label: 'Jobs', value: counts.jobs),
                _MetricCard(label: 'Bids', value: counts.bids),
                _MetricCard(label: 'Chats', value: counts.threads),
                _MetricCard(label: 'Messages', value: counts.messages),
                _MetricCard(label: 'Reports', value: counts.reports),
                _MetricCard(label: 'Alerts', value: counts.notifications),
              ],
            ),
            const SizedBox(height: 16),
            const _RecentReportsPreview(),
          ],
        );
      },
    );
  }
}

class _RecentReportsPreview extends ConsumerWidget {
  const _RecentReportsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<PlatformReport>>(
      stream: ref.watch(adminServiceProvider).watchReports(),
      builder: (context, snapshot) {
        final reports = (snapshot.data ?? const <PlatformReport>[])
            .where((report) => report.status == 'open')
            .take(3)
            .toList(growable: false);
        if (reports.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('No open reports'),
              subtitle: Text('Chat and support reports will appear here.'),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Needs review',
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
    return StreamBuilder<List<PlatformReport>>(
      stream: ref.watch(adminServiceProvider).watchReports(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
              message: 'Could not load reports: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reports = snapshot.data!;
        if (reports.isEmpty) {
          return const Center(child: Text('No reports yet.'));
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
                Chip(label: Text(report.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(report.body.isEmpty ? 'No details provided.' : report.body),
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
                  Chip(label: Text('reported: ${report.reportedUserId}')),
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
                  label: const Text('Dismiss'),
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
                  label: const Text('Resolve'),
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
    return StreamBuilder<List<PlatformAccount>>(
      stream: ref.watch(adminServiceProvider).watchAccounts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
              message: 'Could not load accounts: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final accounts = snapshot.data!;
        if (accounts.isEmpty) {
          return const Center(child: Text('No accounts found.'));
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
                Chip(label: Text('tenant: ${account.tenantId}')),
                Chip(
                    label: Text(
                        'verification: ${account.verificationStatus.name}')),
                if (account.phone.isNotEmpty) Chip(label: Text(account.phone)),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: UserRole.values.map((role) {
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
                          ? '${role.name} active'
                          : 'Set ${role.name}'),
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
    return StreamBuilder<List<PlatformAccount>>(
      stream: ref.watch(adminServiceProvider).watchAccounts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
              message: 'Could not load tenants: ${snapshot.error}');
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
                    '${entry.value.length} accounts • $users users • $artisans artisans'),
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
    return FutureBuilder<PlatformModuleCounts>(
      future: ref.watch(adminServiceProvider).fetchModuleCounts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(
              message: 'Could not load modules: ${snapshot.error}');
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
                title: Text(module.$1),
                subtitle: Text(module.$3),
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
