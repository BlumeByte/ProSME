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
    required this.reports,
    required this.walletTransactions,
  });

  final int accounts;
  final int tenants;
  final int listings;
  final int jobs;
  final int bids;
  final int threads;
  final int messages;
  final int notifications;
  final int reports;
  final int walletTransactions;
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

class PlatformReport {
  const PlatformReport({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.type,
    required this.category,
    required this.title,
    required this.body,
    required this.status,
    required this.relatedTable,
    required this.relatedId,
    required this.createdAt,
  });

  final String id;
  final String reporterId;
  final String reportedUserId;
  final String type;
  final String category;
  final String title;
  final String body;
  final String status;
  final String relatedTable;
  final String relatedId;
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
        .stream(primaryKey: ['id']).asyncMap((_) => fetchVerificationQueue());
  }

  Future<List<ArtisanProfile>> fetchVerificationQueue() async {
    if (_supabase == null) return const [];
    try {
      final rows = await _supabase.from('profiles').select(
            'id,phone,role,verification_status,national_id_url,national_id_front_url,national_id_back_url,momo_number,location,categories,bio,rating_summary',
          );
      return (rows as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((row) => ArtisanProfile(
                userId: (row['id'] ?? '').toString(),
                role: UserRole.values.firstWhere(
                  (role) => role.name == (row['role'] ?? '').toString(),
                  orElse: () => UserRole.artisan,
                ),
                phone: (row['phone'] ?? '').toString(),
                verifiedStatus: _verificationFrom(
                  (row['verification_status'] ?? row['verifiedStatus'])
                      ?.toString(),
                ),
                nationalIdUrl: (row['national_id_front_url'] ??
                        row['national_id_url'] ??
                        row['nationalIdUrl'] ??
                        '')
                    .toString(),
                nationalIdBackUrl:
                    (row['national_id_back_url'] ?? '').toString(),
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
          .where((profile) =>
              profile.verifiedStatus == VerificationStatus.pending &&
              profile.nationalIdUrl.isNotEmpty)
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
        reports: 0,
        walletTransactions: 0,
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
    final reportRows = await _supabase.from('reports').select('id');
    final walletRows = await _supabase.from('wallet_transactions').select('id');
    return PlatformModuleCounts(
      accounts: accounts.length,
      tenants: accounts.map((account) => account.tenantId).toSet().length,
      listings: (listingRows as List<dynamic>).length,
      jobs: (jobRows as List<dynamic>).length,
      bids: (bidRows as List<dynamic>).length,
      threads: (threadRows as List<dynamic>).length,
      messages: (messageRows as List<dynamic>).length,
      notifications: (notificationRows as List<dynamic>).length,
      reports: (reportRows as List<dynamic>).length,
      walletTransactions: (walletRows as List<dynamic>).length,
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
    required String phone,
    required String nationalIdFrontUrl,
    required String nationalIdBackUrl,
    List<String> businessCertificateUrls = const [],
  }) async {
    final client = _supabase;
    if (client == null) return;
    await client.from('profiles').update({
      'verification_status': VerificationStatus.pending.name,
      'phone': phone,
      'national_id_url': nationalIdFrontUrl,
      'national_id_front_url': nationalIdFrontUrl,
      'national_id_back_url': nationalIdBackUrl,
      'business_certificate_urls': businessCertificateUrls,
      'verification_submitted_at': DateTime.now().toUtc().toIso8601String(),
      'verification_notes': null,
      'verification_retry_after': null,
    }).eq('id', userId);

    final profile = await client
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    final role = (profile?['role'] ?? UserRole.customer.name).toString() ==
            UserRole.artisan.name
        ? UserRole.artisan.name
        : UserRole.customer.name;
    await client.from('verification_subscriptions').upsert({
      'user_id': userId,
      'role': role,
      'plan_interval': 'monthly',
      'status': 'payment_required',
      'amount_usd': role == UserRole.artisan.name ? 5 : 2,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');

    try {
      await client.from('admin_notifications').insert({
        'type': 'verification_payment_required',
        'title': 'Verification documents uploaded',
        'body':
            'Documents were uploaded. Payment is required before admin review. Phone: $phone',
        'actor_id': userId,
        'related_user_id': userId,
      });
      await client.from('email_outbox').insert({
        'to_email': null,
        'subject': 'Pay for your ProSME verification',
        'body': role == UserRole.artisan.name
            ? 'Your documents were uploaded. Pay the \$5 artisan verification fee so Support can review them.'
            : 'Your documents were uploaded. Pay the \$2 account verification fee so Support can review them.',
        'related_user_id': userId,
      });
    } catch (_) {
      // The uploaded documents are saved; background alerts can be retried.
    }
    await _flushEmailOutbox(relatedUserId: userId);
  }

  Future<void> restartArtisanVerification({
    required String userId,
    required List<String> documentUrls,
  }) async {
    final client = _supabase;
    if (client == null) return;
    final paths = documentUrls
        .map(_artisanVerificationPathFromUrl)
        .whereType<String>()
        .toList(growable: false);
    if (paths.isNotEmpty) {
      await client.storage.from('artisan-verification').remove(paths);
    }
    await client.from('profiles').update({
      'national_id_url': null,
      'national_id_front_url': null,
      'national_id_back_url': null,
      'business_certificate_urls': <String>[],
      'verification_status': VerificationStatus.pending.name,
      'verification_notes': null,
      'verification_submitted_at': null,
      'verification_reviewed_at': null,
      'verification_retry_after': null,
    }).eq('id', userId);
    await client
        .from('verification_subscriptions')
        .delete()
        .eq('user_id', userId);
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
    final now = DateTime.now().toUtc().toIso8601String();
    if (approved) {
      final subscription = await client
          .from('verification_subscriptions')
          .select('id,status,plan_interval,current_period_end')
          .eq('user_id', userId)
          .maybeSingle();
      if ((subscription?['status'] ?? '').toString() != 'paid_pending_review') {
        throw StateError('Payment must be confirmed before approval.');
      }
      await client.from('verification_subscriptions').update({
        'status': 'active',
        'admin_approved_at': now,
        'updated_at': now,
      }).eq('user_id', userId);
    }
    await client.from('profiles').update({
      'verification_status': status.name,
      'verification_notes': notes,
      'verification_reviewed_at': now,
      'verification_retry_after': approved
          ? null
          : DateTime.now()
              .toUtc()
              .add(const Duration(days: 30))
              .toIso8601String(),
    }).eq('id', userId);
    await client.from('admin_notifications').insert({
      'type': approved ? 'verification_approved' : 'verification_rejected',
      'title': approved ? 'Verification approved' : 'Verification rejected',
      'body': approved
          ? 'Admin approved a paid verification submission.'
          : 'Verification was rejected. Notes: $notes',
      'related_user_id': userId,
    });
    await client.from('email_outbox').insert({
      'to_email': null,
      'subject': approved
          ? 'Your ProSME verification was approved'
          : 'Your ProSME verification needs attention',
      'body': approved
          ? 'Your verification is approved and your public checkmark is active.'
          : 'Your verification was rejected. Notes: $notes',
      'related_user_id': userId,
    });
    await _flushEmailOutbox(relatedUserId: userId);
  }

  Future<void> _flushEmailOutbox({String? relatedUserId}) async {
    final client = _supabase;
    if (client == null) return;
    try {
      await client.functions.invoke(
        'send-email-outbox',
        body: {
          if (relatedUserId != null) 'relatedUserId': relatedUserId,
          'limit': 10,
        },
      );
    } catch (_) {
      // Email delivery is retried from the outbox; never block the user action.
    }
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

  Future<void> submitChatReport({
    required String threadId,
    required String reportedUserId,
    required String reason,
    String category = 'chat',
  }) async {
    final client = _supabase;
    if (client == null) return;
    final userId = client.auth.currentUser?.id;
    final body = reason.trim();
    if (userId == null || body.isEmpty) return;

    final inserted = await client
        .from('reports')
        .insert({
          'reporter_id': userId,
          if (reportedUserId.isNotEmpty) 'reported_user_id': reportedUserId,
          'type': 'chat_report',
          'category': category,
          'title': category == 'block' ? 'Blocked chat user' : 'Chat report',
          'body': body,
          'message': body,
          'status': 'open',
          'related_table': 'threads',
          if (_uuidOrNull(threadId) != null) 'related_id': threadId,
        })
        .select('id')
        .maybeSingle();

    final reportId = (inserted?['id'] ?? '').toString();
    await client.from('admin_notifications').insert({
      'type': category == 'block' ? 'chat_block' : 'chat_report',
      'title': category == 'block' ? 'User blocked a chat' : 'New chat report',
      'body': body,
      'actor_id': userId,
      if (reportedUserId.isNotEmpty) 'related_user_id': reportedUserId,
      'related_table': 'reports',
      'related_id': reportId.isEmpty ? null : reportId,
    });
  }

  Future<void> blockChatUser({
    required String threadId,
    required String blockedUserId,
    required String reason,
  }) async {
    final client = _supabase;
    if (client == null) return;
    final userId = client.auth.currentUser?.id;
    if (userId == null || blockedUserId.isEmpty) return;
    await client.from('chat_blocks').upsert({
      'blocker_id': userId,
      'blocked_user_id': blockedUserId,
      if (_uuidOrNull(threadId) != null) 'thread_id': threadId,
      'reason': reason.trim().isEmpty ? 'Blocked from chat menu' : reason,
    }, onConflict: 'blocker_id,blocked_user_id');
    await submitChatReport(
      threadId: threadId,
      reportedUserId: blockedUserId,
      reason: reason.trim().isEmpty ? 'User blocked this chat.' : reason,
      category: 'block',
    );
  }

  Future<bool> isChatBlocked({
    required String threadId,
    required String currentUserId,
  }) async {
    final client = _supabase;
    if (client == null) return false;
    try {
      final rows = await client
          .from('chat_blocks')
          .select('id')
          .eq('thread_id', threadId)
          .or('blocker_id.eq.$currentUserId,blocked_user_id.eq.$currentUserId')
          .limit(1);
      return (rows as List<dynamic>).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<List<PlatformReport>> watchReports() async* {
    yield await fetchReports();
    final client = _supabase;
    if (client == null) return;
    yield* client
        .from('reports')
        .stream(primaryKey: ['id']).asyncMap((_) => fetchReports());
  }

  Future<List<PlatformReport>> fetchReports() async {
    final client = _supabase;
    if (client == null) return const [];
    final rows = await client
        .from('reports')
        .select(
          'id,reporter_id,reported_user_id,type,category,title,body,message,status,related_table,related_id,created_at',
        )
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List<dynamic>)
        .map((row) => _reportFromRow(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<void> updateReportStatus({
    required String reportId,
    required String status,
  }) async {
    final client = _supabase;
    if (client == null) return;
    await client.from('reports').update({
      'status': status,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reportId);
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
        .eq('type', 'admin_response')
        .order('created_at', ascending: false)
        .limit(10);
    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .map(
          (row) => SupportNotice(
            id: (row['id'] ?? '').toString(),
            title: (row['title'] ?? 'Support update').toString(),
            body: (row['body'] ?? '').toString(),
            createdAt:
                DateTime.tryParse((row['created_at'] ?? '').toString()) ??
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

String? _artisanVerificationPathFromUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  const marker = '/storage/v1/object/public/artisan-verification/';
  final markerIndex = trimmed.indexOf(marker);
  if (markerIndex >= 0) {
    return Uri.decodeFull(trimmed.substring(markerIndex + marker.length));
  }
  const bucketMarker = 'artisan-verification/';
  final bucketIndex = trimmed.indexOf(bucketMarker);
  if (bucketIndex >= 0) {
    return Uri.decodeFull(trimmed.substring(bucketIndex + bucketMarker.length));
  }
  return trimmed.contains('/') ? trimmed : null;
}

String? _uuidOrNull(String value) {
  final normalized = value.trim();
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(normalized)
      ? normalized
      : null;
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

PlatformReport _reportFromRow(Map<String, dynamic> row) {
  final body = (row['body'] ?? row['message'] ?? '').toString();
  return PlatformReport(
    id: (row['id'] ?? '').toString(),
    reporterId: (row['reporter_id'] ?? '').toString(),
    reportedUserId: (row['reported_user_id'] ?? '').toString(),
    type: (row['type'] ?? 'support_ticket').toString(),
    category: (row['category'] ?? '').toString(),
    title: (row['title'] ?? 'Report').toString(),
    body: body,
    status: (row['status'] ?? 'open').toString(),
    relatedTable: (row['related_table'] ?? '').toString(),
    relatedId: (row['related_id'] ?? '').toString(),
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
