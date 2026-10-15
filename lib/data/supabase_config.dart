import 'package:flutter/foundation.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  static const authRedirectUrl = 'com.just2alim.musico://login-callback';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static void validate() {
    if (!isConfigured && kReleaseMode) {
      throw StateError(
        'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY with --dart-define before release.',
      );
    }
  }
}
