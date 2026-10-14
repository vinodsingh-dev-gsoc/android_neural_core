/// Supabase configuration singleton.
/// Contains the project URL and anon key — replace with YOUR values.
/// Get these from: https://supabase.com/dashboard/project/<your-project>/settings/api
library;

import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  /// Supabase project URL — base host only, NO /rest/v1/ suffix.
  /// The supabase_flutter client appends /rest/v1/ internally; a duplicate
  /// path produces 404s on every request.
  static const String projectUrl = 'https://tbxfdqpmfkywcyyhrqxm.supabase.co';

  /// Replace with your anon/public key (also in Settings > API)
  /// Using the new sb_publishable_ format (recommended by Supabase).
  static const String anonKey = 'sb_publishable_xByFmkP_tT4rhO9yOhaCLQ_4MLPaGXh';

  // Singleton initialization flag — prevents re-initialization in background isolates
  static bool _initialized = false;

  /// Initialize Supabase client — call once at app start in main().
  /// Background isolates call this too, but the flag prevents duplicate HTTP clients.
  static Future<void> init() async {
    // Return early if already initialized (e.g., in background isolate second call)
    if (_initialized) {
      debugPrint('[Supabase] Already initialized, skipping re-init');
      return;
    }
    _initialized = true;
    await Supabase.initialize(
      url: projectUrl,
      anonKey: anonKey,
    );
    debugPrint('[Supabase] Initialized: ${projectUrl}');
  }

  /// Get the initialized client instance
  static SupabaseClient get client => Supabase.instance.client;
}