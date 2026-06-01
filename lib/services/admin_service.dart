import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import '../models/artisan_profile.dart';
import '../models/discount_offer.dart';

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
                categories:
                    _listFromAny(row['categories']).whereType<String>().toList(),
                bio: (row['bio'] ?? '').toString(),
                ratingSummary:
                    ((row['rating_summary'] ?? row['ratingSummary']) as num?)
                            ?.toDouble() ??
                        0,
              ))
          .where((profile) => profile.verifiedStatus == VerificationStatus.pending)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
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
      'body': 'An artisan uploaded front and back ID documents for verification. Review them in the admin dashboard.',
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

  Future<List<DiscountOffer>> fetchDiscounts() async {
    if (_supabase == null) return const [];
    try {
      final rows = await _supabase
          .from('discount_offers')
          .select('id,title,description,percent,active,start,end');
      return (rows as List<dynamic>)
          .map((row) => DiscountOffer.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
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
