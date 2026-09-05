import 'dart:io'; // 1. Idinagdag para sa HttpOverrides
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'providers/language_provider.dart';
import 'services/notification/notification_service.dart';

import 'user/screens/login_page.dart';
import 'user/screens/homeuser_page.dart';

// 2. Class para i-bypass ang SSL/Hostname mismatch sa development
class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 3. I-apply ang overrides para sa SSL bypass habang nag-e-experiment
  HttpOverrides.global = DevHttpOverrides();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
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