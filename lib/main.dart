// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:ai_reels/auth_service.dart'; // Import AuthService
import 'package:ai_reels/login_page.dart';
import 'package:ai_reels/view_reels_page.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For User type

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Connected to Firebase');
  } catch (e, st) {
    debugPrint('❌ Firebase NOT connected: $e');
    debugPrintStack(stackTrace: st);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return MaterialApp(
      title: 'AI Reels',
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: authService.user, // Listen to auth state changes
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator())); // Or a splash screen
          }
          if (snapshot.hasData && snapshot.data != null) {
            // User is logged in
            return const ViewReelsPage();
          } else {
            // User is not logged in
            return const LoginPage();
          }
        },
      ),
    );
  }
}