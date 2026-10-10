import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';
import 'account_completion.dart';

/// Account fields the status card needs. Read from the signed-in user's own
/// profile row, which the profiles policies already allow.
final accountStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || !shouldUseSupabase()) return null;
  // The caller's own full row comes from the get_my_profile function; direct
  // reads cannot include contact columns.
  final raw = await ref.read(supabaseClientProvider).rpc('get_my_profile');
  return raw is Map ? Map<String, dynamic>.from(raw) : null;
});

/// The still-incomplete items from [accountStatusProvider], for the
/// notifications panel's priority section. Empty once everything is done, or
/// for admins (who never see the status card either).
final accountCompletionItemsProvider =
    Provider.autoDispose<List<AccountCompletionItem>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final row = ref.watch(accountStatusProvider).valueOrNull;
  if (user == null || row == null || user.role == UserRole.admin) {
    return const [];
  }
  return accountCompletionItems(row, user.role)
      .where((item) => !item.done)
      .toList(growable: false);
});

/// "Your account" summary for customers and artisans: where the account came
/// from, whether the person has set their own password, and how complete the
/// profile is.
class AccountStatusCard extends ConsumerWidget {
  const AccountStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    final statusAsync = ref.watch(accountStatusProvider);
    final theme = Theme.of(context);

    return statusAsync.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (row) {
        if (row == null) return const SizedBox.shrink();
        final imported = row['account_source'] == 'imported';
        final redeemed = row['redeemed_at'] != null;
        final items = accountCompletionItems(row, user.role);
        final done = items.where((item) => item.done).length;
        final fraction = items.isEmpty ? 0.0 : done / items.length;
        // Nothing left to do: stop taking up space on the home screen. The
        // notifications panel only ever shows the items that are still
        // missing, so there is nothing to lose by removing this card too.
        if (items.isNotEmpty && done == items.length) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      imported ? Icons.mark_email_read_outlined : Icons.badge_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.t('Your account'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text('$done/${items.length}'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  imported
                      ? settings.t('ProSME created this account for you.')
                      : settings.t('You created this account yourself.'),
                  style: theme.textTheme.bodySmall,
                ),
                if (imported && !redeemed) ...[
                  const SizedBox(height: 8),
                  Text(
                    settings.t(
                      'Set your password: open the email from ProSME and follow the link. You can also use Forgot password on the sign-in screen.',
                    ),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 10),
                LinearProgressIndicator(value: fraction),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final item in items)
                      Chip(
                        avatar: Icon(
                          item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 18,
                          color: item.done ? Colors.green : null,
                        ),
                        label: Text(settings.t(item.label)),
                      ),
                  ],
                ),
                if (user.role == UserRole.artisan) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${settings.t('Verification')}: ${settings.t(_verificationLabel(row['verification_status']))}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  settings.t('Finish the missing items from the Profile tab.'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _verificationLabel(Object? status) {
    switch (status) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }
}
