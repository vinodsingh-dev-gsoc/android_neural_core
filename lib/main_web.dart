/// Main entry point for the Flutter web dashboard.
/// This is used when building for web: `flutter build web`
import 'package:flutter/material.dart';
import 'package:android_neural_core/config/supabase_config.dart';
import 'package:android_neural_core/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with the correct base URL (no /rest/v1/ suffix)
  await SupabaseConfig.init();

  runApp(const DashboardApp());
}

class DashboardApp extends StatelessWidget {
  const DashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Location Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
