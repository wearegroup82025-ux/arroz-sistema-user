import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'homeuser_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF0F5132))),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginUserPage();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator(color: Color(0xFF0F5132))),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const LoginUserPage();
            }

            final data = userSnapshot.data!.data() as Map<String, dynamic>;
            final bool isBlocked = data['isBlocked'] ?? false;
            final bool isPendingDeletion = data['isPendingDeletion'] ?? data['isScheduledForDeletion'] ?? false;

            // 1. Pag Blocked: Sign out & Stay in Login
            if (isBlocked) {
              FirebaseAuth.instance.signOut();
              return const LoginUserPage();
            }

            // 2. Pag Pending Deletion:
            // Manatili sa LoginUserPage para lumabas/makita ang Deletion Restore Dialog
            if (isPendingDeletion) {
              return const LoginUserPage();
            }

            // 3. Pag Active Account:
            return const HomeUserPage();
          },
        );
      },
    );
  }
}