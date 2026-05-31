import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/constants.dart';
import '../models/artisan_profile.dart';
import '../models/discount_offer.dart';

class AdminService {
  const AdminService([this._supabase]);

  final SupabaseClient? _supabase;

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
