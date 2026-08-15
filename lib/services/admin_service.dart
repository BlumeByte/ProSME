import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import '../models/artisan_profile.dart';
import '../models/discount_offer.dart';

class PlatformAccount {
  const PlatformAccount({
    required this.id,
    required this.name,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.country,
    required this.countryCode,
    required this.description,
    required this.gender,
    required this.dateOfBirth,
    required this.isBusy,
    required this.emailVerified,
    required this.phoneVerified,
    required this.emailNotifications,
    required this.phoneNotifications,
    required this.blockedEmailNotificationTypes,
    required this.blockedPhoneNotificationTypes,
    required this.appLanguage,
    required this.currencyCode,
    required this.role,
    required this.verificationStatus,
    required this.tenantId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final String photoUrl;
  final String country;
  final String countryCode;
  final String description;
  final String gender;
  final DateTime? dateOfBirth;
  final bool isBusy;
  final bool emailVerified;
  final bool phoneVerified;
  final bool emailNotifications;
  final bool phoneNotifications;
  final Set<String> blockedEmailNotificationTypes;
  final Set<String> blockedPhoneNotificationTypes;
  final String appLanguage;
  final String currencyCode;
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
    required this.publicJobs,
    required this.directJobs,
    required this.openJobs,
    required this.acceptedJobs,
    required this.startPendingJobs,
    required this.inProgressJobs,
    required this.completionPendingJobs,
    required this.completedJobs,
    required this.bids,
    required this.pendingBids,
    required this.editedBids,
    required this.counteredBids,
    required this.acceptedBids,
    required this.rejectedBids,
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
  final int publicJobs;
  final int directJobs;
  final int openJobs;
  final int acceptedJobs;
  final int startPendingJobs;
  final int inProgressJobs;
  final int completionPendingJobs;
  final int completedJobs;
  final int bids;
  final int pendingBids;
  final int editedBids;
  final int counteredBids;
  final int acceptedBids;
  final int rejectedBids;
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
    var lastGood = const <ArtisanProfile>[];
    while (true) {
      try {
        lastGood = await fetchVerificationQueue();
      } catch (_) {}
      yield lastGood;
      await Future<void>.delayed(const Duration(seconds: 15));
    }
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
    var lastGood = const <PlatformAccount>[];
    while (true) {
      try {
        lastGood = await fetchAccounts();
      } catch (_) {}
      yield lastGood;
      await Future<void>.delayed(const Duration(seconds: 15));
    }
  }

  Future<List<PlatformAccount>> fetchAccounts() async {
    if (_supabase == null) return const [];
    final rows = await _supabase
        .from('profiles')
        .select(
          'id,username,full_name,email,phone,avatar_url,country,country_code,description,gender,date_of_birth,is_busy,email_verified,phone_verified,email_notifications,phone_notifications,blocked_email_notification_types,blocked_phone_notification_types,app_language,currency_code,role,verification_status,tenant_id,created_at',
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
        publicJobs: 0,
        directJobs: 0,
        openJobs: 0,
        acceptedJobs: 0,
        startPendingJobs: 0,
        inProgressJobs: 0,
        completionPendingJobs: 0,
        completedJobs: 0,
        bids: 0,
        pendingBids: 0,
        editedBids: 0,
        counteredBids: 0,
        acceptedBids: 0,
        rejectedBids: 0,
        threads: 0,
        messages: 0,
        notifications: 0,
        reports: 0,
        walletTransactions: 0,
      );
    }

    final accounts = await fetchAccounts();
    final listingRows = await _supabase.from('listings').select('id');
    final jobRows =
        await _supabase.from('jobs').select('id,work_status,request_type');
    final bidRows = await _supabase.from('job_bids').select('id,status');
    final threadRows = await _supabase.from('threads').select('id');
    final messageRows = await _supabase.from('messages').select('id');
    final notificationRows =
        await _supabase.from('admin_notifications').select('id');
    final reportRows = await _supabase.from('reports').select('id');
    final walletRows = await _supabase.from('wallet_transactions').select('id');
    final jobs = (jobRows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    int countJobs(String status) => jobs
        .where((job) => (job['work_status'] ?? 'open').toString() == status)
        .length;
    int countRequestType(String type) => jobs
        .where((job) => (job['request_type'] ?? 'public').toString() == type)
        .length;
    final bids = (bidRows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    int countBids(String status) => bids
        .where((bid) => (bid['status'] ?? 'pending').toString() == status)
        .length;
    return PlatformModuleCounts(
      accounts: accounts.length,
      tenants: accounts.map((account) => account.tenantId).toSet().length,
      listings: (listingRows as List<dynamic>).length,
      jobs: jobs.length,
      publicJobs: countRequestType('public'),
      directJobs: countRequestType('direct'),
      openJobs: countJobs('open'),
      acceptedJobs: countJobs('accepted'),
      startPendingJobs: countJobs('start_pending'),
      inProgressJobs: countJobs('in_progress'),
      completionPendingJobs: countJobs('completion_pending'),
      completedJobs: countJobs('completed'),
      bids: bids.length,
      pendingBids: countBids('pending'),
      editedBids: countBids('edited'),
      counteredBids: countBids('countered'),
      acceptedBids: countBids('accepted'),
      rejectedBids: countBids('rejected'),
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
    if (role == UserRole.admin) {
      throw ArgumentError('Admin role updates are not allowed here.');
    }
    final client = _supabase;
    if (client == null) return;
    await client.from('profiles').update({'role': role.name}).eq('id', userId);
  }

  Future<void> updateAccountProfile({
    required String userId,
    required String username,
    required String fullName,
    required String email,
    required String phone,
    required String country,
    required String countryCode,
    required String description,
    required String gender,
    required DateTime? dateOfBirth,
    required bool isBusy,
    required bool emailVerified,
    required bool phoneVerified,
    required bool emailNotifications,
    required bool phoneNotifications,
    required String appLanguage,
    required String currencyCode,
    required VerificationStatus verificationStatus,
  }) async {
    final client = _supabase;
    if (client == null) return;
    await client.from('profiles').update({
      'username': username.trim(),
      'full_name': fullName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'country': country.trim().isEmpty ? 'Ghana' : country.trim(),
      'country_code': countryCode.trim().isEmpty ? '+233' : countryCode.trim(),
      'description': description.trim(),
      'gender': gender.trim().isEmpty ? null : gender.trim(),
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'is_busy': isBusy,
      'email_verified': emailVerified,
      'phone_verified': phoneVerified,
      'email_notifications': emailNotifications,
      'phone_notifications': phoneNotifications,
      'app_language':
          appLanguage.trim().isEmpty ? 'English' : appLanguage.trim(),
      'currency_code': currencyCode.trim().isEmpty
          ? 'GHS'
          : currencyCode.trim().toUpperCase(),
      'verification_status': verificationStatus.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> resetAccountData({required String userId}) async {
    final client = _supabase;
    if (client == null) return;
    final response = await client.functions.invoke(
      'admin-dashboard',
      body: {
        'action': 'resetUserData',
        'userId': userId,
      },
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    if (response.status < 200 || response.status >= 300 || data['ok'] != true) {
      throw StateError(
        (data['error'] ?? 'Could not reset account data.').toString(),
      );
    }
  }

  Future<int> resetWallet({String? userId}) async {
    final client = _supabase;
    if (client == null) return 0;
    final response = await client.rpc(
      'admin_reset_wallet',
      params: {
        'p_user_id': userId,
        'p_confirmation':
            userId == null ? 'RESET ALL WALLETS' : 'RESET USER WALLET',
      },
    );
    return (response as num?)?.toInt() ?? 0;
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
            ? 'Your documents were uploaded. Pay the \$3 artisan verification fee so Support can review them.'
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

  Future<void> submitJobReport({
    required String jobId,
    required String artisanId,
    required String title,
    required String message,
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
          if (artisanId.isNotEmpty) 'reported_user_id': artisanId,
          'type': 'job_completion_report',
          'category': 'work_not_completed',
          'title': title.trim().isEmpty
              ? 'Customer disputes completed work'
              : title.trim(),
          'body': body,
          'message': body,
          'status': 'open',
          'related_table': 'jobs',
          if (_uuidOrNull(jobId) != null) 'related_id': jobId,
        })
        .select('id')
        .maybeSingle();

    final reportId = (inserted?['id'] ?? '').toString();
    await client.from('admin_notifications').insert({
      'type': 'job_completion_report',
      'title': 'Customer disputes completed work',
      'body': body,
      'actor_id': userId,
      if (artisanId.isNotEmpty) 'related_user_id': artisanId,
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
    var lastGood = const <PlatformReport>[];
    while (true) {
      try {
        lastGood = await fetchReports();
      } catch (_) {}
      yield lastGood;
      await Future<void>.delayed(const Duration(seconds: 15));
    }
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
  final username = (row['username'] ?? '').toString();
  final fullName = (row['full_name'] ?? '').toString();
  final displayName = username.trim().isNotEmpty
      ? username
      : fullName.trim().isNotEmpty
          ? fullName
          : 'Unnamed';
  return PlatformAccount(
    id: (row['id'] ?? '').toString(),
    name: displayName,
    username: username,
    fullName: fullName,
    email: (row['email'] ?? '').toString(),
    phone: (row['phone'] ?? '').toString(),
    photoUrl: (row['avatar_url'] ?? '').toString(),
    country: (row['country'] ?? 'Ghana').toString(),
    countryCode: (row['country_code'] ?? '+233').toString(),
    description: (row['description'] ?? '').toString(),
    gender: (row['gender'] ?? '').toString(),
    dateOfBirth: DateTime.tryParse((row['date_of_birth'] ?? '').toString()),
    isBusy: _boolFromAny(row['is_busy']),
    emailVerified: _boolFromAny(row['email_verified']),
    phoneVerified: _boolFromAny(row['phone_verified']),
    emailNotifications:
        _boolFromAny(row['email_notifications'], fallback: true),
    phoneNotifications:
        _boolFromAny(row['phone_notifications'], fallback: true),
    blockedEmailNotificationTypes:
        _stringSetFromAny(row['blocked_email_notification_types']),
    blockedPhoneNotificationTypes:
        _stringSetFromAny(row['blocked_phone_notification_types']),
    appLanguage: (row['app_language'] ?? 'English').toString(),
    currencyCode: (row['currency_code'] ?? 'GHS').toString(),
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

Set<String> _stringSetFromAny(dynamic value) {
  return _listFromAny(value)
      .map((item) => item.toString())
      .where((item) => item.trim().isNotEmpty)
      .toSet();
}

bool _boolFromAny(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  final normalized = value?.toString().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return fallback;
}
