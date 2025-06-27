import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'create_reel_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅  Connected to Firebase: ${app.name}');
  } catch (e, st) {
    debugPrint('❌  Firebase NOT connected: $e');
    debugPrintStack(stackTrace: st);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Reels',
      theme: ThemeData.dark(useMaterial3: true),
      home: const CreateReelPage(),
    );
  }
}