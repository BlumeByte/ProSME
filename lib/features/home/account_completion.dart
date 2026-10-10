import '../../config/constants.dart';

/// What tapping an incomplete item should open, once the Profile tab is
/// showing. Shared between the "Your account" home card and the
/// notifications panel's priority items so both agree on where each field
/// is fixed.
enum AccountCompletionAction {
  /// Phone, country, date of birth: all live in the Account settings sheet.
  accountSettings,
  photo,
  verifyEmail,
  verifyPhone,
  artisanVerification,
}

class AccountCompletionItem {
  const AccountCompletionItem({
    required this.id,
    required this.label,
    required this.done,
    required this.action,
  });

  final String id;
  final String label;
  final bool done;
  final AccountCompletionAction action;
}

/// Profile fields that matter for "Your account" completeness, derived from
/// the `get_my_profile()` row. Shared by [AccountStatusCard] and the
/// notifications panel so a field can never show done in one place and
/// missing in the other.
List<AccountCompletionItem> accountCompletionItems(
  Map<String, dynamic> row,
  UserRole role,
) {
  bool filled(String key) => (row[key] ?? '').toString().trim().isNotEmpty;
  return [
    AccountCompletionItem(
      id: 'phone',
      label: 'Phone number',
      done: filled('phone'),
      action: AccountCompletionAction.accountSettings,
    ),
    AccountCompletionItem(
      id: 'date_of_birth',
      label: 'Date of birth',
      done: filled('date_of_birth'),
      action: AccountCompletionAction.accountSettings,
    ),
    AccountCompletionItem(
      id: 'country',
      label: 'Country',
      done: filled('country'),
      action: AccountCompletionAction.accountSettings,
    ),
    AccountCompletionItem(
      id: 'avatar',
      label: 'Profile photo',
      done: filled('avatar_url'),
      action: AccountCompletionAction.photo,
    ),
    AccountCompletionItem(
      id: 'email_verified',
      label: 'Email verified',
      done: row['email_verified'] == true,
      action: AccountCompletionAction.verifyEmail,
    ),
    AccountCompletionItem(
      id: 'phone_verified',
      label: 'Phone verified',
      done: row['phone_verified'] == true,
      action: AccountCompletionAction.verifyPhone,
    ),
    if (role == UserRole.artisan)
      AccountCompletionItem(
        id: 'verification_badge',
        label: 'Verified badge',
        done: row['verification_status'] == 'verified',
        action: AccountCompletionAction.artisanVerification,
      ),
  ];
}
