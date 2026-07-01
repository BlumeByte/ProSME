import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing.dart';

class SyncService {
  SyncService(this._supabase);

  final SupabaseClient _supabase;

  Stream<List<Listing>> listenListings() async* {
    var lastGood = const <Listing>[];
    while (true) {
      try {
        final rows = await _supabase
            .from('listings')
            .select()
            .order('created_at', ascending: false);
        lastGood = rows
            .map((row) => Listing.fromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false);
      } catch (_) {}
      yield lastGood;
      await Future<void>.delayed(const Duration(seconds: 20));
    }
  }
}
