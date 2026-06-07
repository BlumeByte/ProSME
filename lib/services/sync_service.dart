import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/listing.dart';

class SyncService {
  SyncService(this._supabase);

  final SupabaseClient _supabase;

  Stream<List<Listing>> listenListings() {
    return _supabase.from('listings').stream(primaryKey: ['id']).map(
      (rows) => rows.map((row) => Listing.fromJson(row)).toList(),
    );
  }
}
