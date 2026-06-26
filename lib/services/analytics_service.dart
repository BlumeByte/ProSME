import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'service_providers.dart';

class AnalyticsService {
  const AnalyticsService._();

  static Future<void> trackAppOpen() async {
    if (!shouldUseSupabase()) return;
    try {
      final client = Supabase.instance.client;
      await client.from('analytics_events').insert({
        'source': 'app',
        'event_name': 'app_open',
        'path': defaultTargetPlatform.name,
        'user_id': client.auth.currentUser?.id,
        'metadata': {
          'platform': defaultTargetPlatform.name,
          'kIsWeb': kIsWeb,
        },
      });
    } catch (_) {
      // Analytics must never block app startup.
    }
  }
}
