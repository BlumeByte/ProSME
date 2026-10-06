import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/app_settings_controller.dart';
import '../../services/service_providers.dart';

/// The other party's contact details for an accepted job. The server decides
/// whether the caller may see them, so this only ever returns data for the two
/// parties on an accepted, unfinished job.
class AcceptedContact {
  const AcceptedContact({
    required this.name,
    required this.phone,
    required this.country,
  });

  final String name;
  final String phone;
  final String country;

  factory AcceptedContact.fromJson(Map<String, dynamic> json) {
    return AcceptedContact(
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
    );
  }
}

final acceptedContactProvider =
    FutureProvider.autoDispose.family<AcceptedContact?, String>((ref, jobId) async {
  final raw = await ref
      .read(supabaseClientProvider)
      .rpc('get_accepted_contact', params: {'p_job_id': jobId});
  if (raw is! Map) return null;
  return AcceptedContact.fromJson(Map<String, dynamic>.from(raw));
});

class AcceptedContactCard extends ConsumerWidget {
  const AcceptedContactCard({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    final contactAsync = ref.watch(acceptedContactProvider(jobId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: contactAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Text(
            settings.t('Could not load contact details. Please try again.'),
          ),
          data: (contact) {
            if (contact == null) {
              return Text(
                settings.t('Contact details are available while the work is open.'),
              );
            }
            final hasPhone = contact.phone.trim().isNotEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.contact_phone_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        settings.t('Contact'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  hasPhone
                      ? formatPhoneForDisplay(contact.phone)
                      : settings.t('No phone number on file.'),
                ),
                if (hasPhone) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _call(context, contact.phone, settings),
                      icon: const Icon(Icons.call),
                      label: Text(settings.t('Call')),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _call(
    BuildContext context,
    String phone,
    AppSettings settings,
  ) async {
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.t('Could not open the phone app.'))),
      );
    }
  }
}

/// Human-friendly form of an E.164 number, e.g. `+233 25 612 2555`.
String formatPhoneForDisplay(String e164) {
  final check = RegExp(r'^\+(\d{1,3})(\d+)$').firstMatch(e164);
  if (check == null) return e164;
  final national = check.group(2)!;
  final spaced = <String>[];
  for (var i = 0; i < national.length; i += 3) {
    spaced.add(national.substring(i, (i + 3).clamp(0, national.length)));
  }
  return '+${check.group(1)} ${spaced.join(' ')}';
}
