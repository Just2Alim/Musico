import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CrashReportService {
  Future<void> report(Object error) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;
    try {
      await client.functions.invoke(
        'report-crash',
        body: {
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
          'error_type': error.runtimeType.toString().substring(
            0,
            error.runtimeType.toString().length.clamp(1, 160),
          ),
          'message': 'Unhandled application error',
        },
      );
    } catch (_) {
      // Reporting must never mask the original application error.
    }
  }
}
