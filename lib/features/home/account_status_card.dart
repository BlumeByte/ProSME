import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';

/// Account fields the status card needs. Read from the signed-in user's own
/// profile row, which the profiles policies already allow.
final accountStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || !shouldUseSupabase()) return null;
  final row = await ref
      .read(supabaseClientProvider)
      .from('profiles')
      .select(
        'account_source,redeemed_at,phone,date_of_birth,country,avatar_url,'
        'email_verified,phone_verified,verification_status',
      )
      .eq('id', user.id)
      .maybeSingle();
  return row == null ? null : Map<String, dynamic>.from(row);
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
        final items = _completeness(row, user.role);
        final done = items.where((item) => item.$2).length;
        final fraction = items.isEmpty ? 0.0 : done / items.length;

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
                          item.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 18,
                          color: item.$2 ? Colors.green : null,
                        ),
                        label: Text(settings.t(item.$1)),
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

  /// Label and whether it is done, for each profile field that matters.
  List<(String, bool)> _completeness(Map<String, dynamic> row, UserRole role) {
    bool filled(String key) => (row[key] ?? '').toString().trim().isNotEmpty;
    return [
      ('Phone number', filled('phone')),
      ('Date of birth', filled('date_of_birth')),
      ('Country', filled('country')),
      ('Profile photo', filled('avatar_url')),
      ('Email verified', row['email_verified'] == true),
      ('Phone verified', row['phone_verified'] == true),
      if (role == UserRole.artisan)
        ('Verified badge', row['verification_status'] == 'verified'),
    ];
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
