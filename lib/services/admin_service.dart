import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import '../models/artisan_profile.dart';
import '../models/discount_offer.dart';

class PlatformAccount {
  const PlatformAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.verificationStatus,
    required this.tenantId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final VerificationStatus verificationStatus;
  final String tenantId;
  final DateTime createdAt;
}

class PlatformModuleCounts {
  const PlatformModuleCounts({
    required this.accounts,
    required this.tenants,
    required this.listings,
    required this.jobs,
    required this.bids,
    required this.threads,
    required this.messages,
    required this.notifications,
  });

  final int accounts;
  final int tenants;
  final int listings;
  final int jobs;
  final int bids;
  final int threads;
  final int messages;
  final int notifications;
}

class SupportNotice {
  const SupportNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
}

class AdminService {
  const AdminService([this._supabase]);

  final SupabaseClient? _supabase;

  Stream<List<ArtisanProfile>> watchVerificationQueue() async* {
    yield await fetchVerificationQueue();
    final client = _supabase;
    if (client == null) return;
    yield* client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('role', 'artisan')
        .asyncMap((_) => fetchVerificationQueue());
  }

  Future<List<ArtisanProfile>> fetchVerificationQueue() async {
    if (_supabase == null) return const [];
    try {
      final rows = await _supabase
          .from('profiles')
          .select(
            'id,verification_status,national_id_url,momo_number,location,categories,bio,rating_summary,role',
          )
          .eq('role', 'artisan');
      return (rows as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((row) => ArtisanProfile(
                userId: (row['id'] ?? '').toString(),
                verifiedStatus: _verificationFrom(
                  (row['verification_status'] ?? row['verifiedStatus'])
                      ?.toString(),
                ),
                nationalIdUrl:
                    (row['national_id_url'] ?? row['nationalIdUrl'] ?? '')
                        .toString(),
                momoNumber:
                    (row['momo_number'] ?? row['momoNumber'] ?? '').toString(),
                location: (row['location'] ?? '').toString(),
                categories: _listFromAny(row['categories'])
                    .whereType<String>()
                    .toList(),
                bio: (row['bio'] ?? '').toString(),
                ratingSummary:
                    ((row['rating_summary'] ?? row['ratingSummary']) as num?)
                            ?.toDouble() ??
                        0,
              ))
          .where(
              (profile) => profile.verifiedStatus == VerificationStatus.pending)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Stream<List<PlatformAccount>> watchAccounts() async* {
    yield await fetchAccounts();
    final client = _supabase;
    if (client == null) return;
    yield* client
        .from('profiles')
        .stream(primaryKey: ['id']).asyncMap((_) => fetchAccounts());
  }

  Future<List<PlatformAccount>> fetchAccounts() async {
    if (_supabase == null) return const [];
    final rows = await _supabase
        .from('profiles')
        .select(
          'id,username,full_name,email,phone,role,verification_status,tenant_id,created_at',
        )
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((row) => _accountFromRow(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<PlatformModuleCounts> fetchModuleCounts() async {
    if (_supabase == null) {
      return const PlatformModuleCounts(
        accounts: 0,
        tenants: 0,
        listings: 0,
        jobs: 0,
        bids: 0,
        threads: 0,
        messages: 0,
        notifications: 0,
      );
    }

    final accounts = await fetchAccounts();
    final listingRows = await _supabase.from('listings').select('id');
    final jobRows = await _supabase.from('jobs').select('id');
    final bidRows = await _supabase.from('job_bids').select('id');
    final threadRows = await _supabase.from('threads').select('id');
    final messageRows = await _supabase.from('messages').select('id');
    final notificationRows =
        await _supabase.from('admin_notifications').select('id');
    return PlatformModuleCounts(
      accounts: accounts.length,
      tenants: accounts.map((account) => account.tenantId).toSet().length,
      listings: (listingRows as List<dynamic>).length,
      jobs: (jobRows as List<dynamic>).length,
      bids: (bidRows as List<dynamic>).length,
      threads: (threadRows as List<dynamic>).length,
      messages: (messageRows as List<dynamic>).length,
      notifications: (notificationRows as List<dynamic>).length,
    );
  }

  Future<void> updateAccountRole({
    required String userId,
    required UserRole role,
  }) async {
    final client = _supabase;
    if (client == null) return;
    await client.from('profiles').update({'role': role.name}).eq('id', userId);
  }

  Future<void> submitArtisanVerification({
    required String userId,
    required String nationalIdFrontUrl,
    required String nationalIdBackUrl,
    List<String> businessCertificateUrls = const [],
  }) async {
    final client = _supabase;
    if (client == null) return;
    await client.from('profiles').update({
      'verification_status': VerificationStatus.pending.name,
      'national_id_url': nationalIdFrontUrl,
      'national_id_front_url': nationalIdFrontUrl,
      'national_id_back_url': nationalIdBackUrl,
      'business_certificate_urls': businessCertificateUrls,
      'verification_submitted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
    await client.from('admin_notifications').insert({
      'type': 'artisan_verification',
      'title': 'New artisan verification',
      'body': 'An artisan uploaded national ID documents for review.',
      'actor_id': userId,
    });
    await client.from('email_outbox').insert({
      'to_email': 'blumebyte@gmail.com',
      'subject': 'New ProSME artisan verification',
      'body':
          'An artisan uploaded front and back ID documents for verification. Review them in the Support dashboard.',
      'related_user_id': userId,
    });
  }

  Future<void> reviewArtisan({
    required String userId,
    required bool approved,
    String notes = '',
  }) async {
    final client = _supabase;
    if (client == null) return;
    final status =
        approved ? VerificationStatus.verified : VerificationStatus.rejected;
    await client.from('profiles').update({
      'verification_status': status.name,
      'verification_notes': notes,
      'verification_reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'verification_retry_after': approved
          ? null
          : DateTime.now()
              .toUtc()
              .add(const Duration(days: 30))
              .toIso8601String(),
    }).eq('id', userId);
    await client.from('email_outbox').insert({
      'to_email': null,
      'subject': approved
          ? 'Your ProSME artisan account is verified'
          : 'Your ProSME artisan verification needs attention',
      'body': approved
          ? 'Your artisan account has been verified and can now publish services.'
          : 'Your artisan verification was rejected. Notes: $notes',
      'related_user_id': userId,
    });
  }

  Future<void> submitSupportReport({
    required String title,
    required String message,
    String category = 'support',
  }) async {
    final client = _supabase;
    if (client == null) return;
    final userId = client.auth.currentUser?.id;
    final body = message.trim();
    if (userId == null || body.isEmpty) return;

    final inserted = await client
        .from('reports')
        .insert({
          'reporter_id': userId,
          'type': 'support_ticket',
          'category': category,
          'title': title.trim().isEmpty ? 'Support request' : title.trim(),
          'body': body,
          'message': body,
          'status': 'open',
        })
        .select('id')
        .maybeSingle();

    final ticketId = (inserted?['id'] ?? '').toString();
    await client.from('admin_notifications').insert({
      'type': 'support_ticket',
      'title': 'New support ticket',
      'body': body,
      'actor_id': userId,
      'related_user_id': userId,
      'related_table': 'reports',
      'related_id': ticketId.isEmpty ? null : ticketId,
    });
  }

  Future<List<SupportNotice>> fetchSupportNotices() async {
    final client = _supabase;
    if (client == null) return const [];
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await client
        .from('admin_notifications')
        .select('id,title,body,created_at')
        .eq('related_user_id', userId)
        .eq('type', 'developer_response')
        .order('created_at', ascending: false)
        .limit(10);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .map(
          (row) => SupportNotice(
            id: (row['id'] ?? '').toString(),
            title: (row['title'] ?? 'Support update').toString(),
            body: (row['body'] ?? '').toString(),
            createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ??
                DateTime.now(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<DiscountOffer>> fetchDiscounts() async {
    if (_supabase == null) return const [];
    try {
      final rows = await _supabase
          .from('discount_offers')
          .select('id,title,description,percent,active,start,end');
      return (rows as List<dynamic>)
          .map((row) =>
              DiscountOffer.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}

PlatformAccount _accountFromRow(Map<String, dynamic> row) {
  final roleName = (row['role'] ?? '').toString();
  final statusName = (row['verification_status'] ?? '').toString();
  return PlatformAccount(
    id: (row['id'] ?? '').toString(),
    name: (row['username'] ?? row['full_name'] ?? 'Unnamed').toString(),
    email: (row['email'] ?? '').toString(),
    phone: (row['phone'] ?? '').toString(),
    role: UserRole.values.firstWhere(
      (role) => role.name == roleName,
      orElse: () => UserRole.customer,
    ),
    verificationStatus: VerificationStatus.values.firstWhere(
      (status) => status.name == statusName,
      orElse: () => VerificationStatus.pending,
    ),
    tenantId: (row['tenant_id'] ?? 'default').toString(),
    createdAt: DateTime.tryParse((row['created_at'] ?? '').toString()) ??
        DateTime.now(),
  );
}

VerificationStatus _verificationFrom(String? raw) {
  return VerificationStatus.values.firstWhere(
    (status) => status.name == raw,
    orElse: () => VerificationStatus.pending,
  );
}

List<dynamic> _listFromAny(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }
  return const [];
}
