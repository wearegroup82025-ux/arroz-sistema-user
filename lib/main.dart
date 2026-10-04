import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase; // 1. Idinagdag ang Supabase package

import 'firebase_options.dart';
import 'providers/language_provider.dart';
import 'services/notification/notification_service.dart';

import 'user/screens/login_page.dart';
import 'user/screens/homeuser_page.dart';

class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = DevHttpOverrides();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. In-initialize ang Supabase para sa Storage
  await supabase.Supabase.initialize(
    url: 'https://fgkxatamapalhuvwuzpw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZna3hhdGFtYXBhbGh1dnd1enB3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA5NTUwNjYsImV4cCI6MjEwNjUzMTA2Nn0.Sd4gp0V8yKFZieeZRju13y8suOP-s8-T3xYPtvGghm4', // Palitan ito ng iyong tamang Supabase Anon Key!
  );


  await NotificationService().initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Arroz",
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0F5132),
        scaffoldBackgroundColor: const Color(0xFFFBFBF9),
      ),
      home: StreamBuilder<firebase_auth.User?>(
        stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFFBFBF9),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0F5132),
                ),
              ),
            );
          }

          if (snapshot.hasData) {
            return const HomeUserPage();
          }

          return const LoginUserPage();
        },
      ),
    );
  }
}