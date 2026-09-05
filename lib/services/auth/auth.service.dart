import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class AuthService {
  AuthService._privateConstructor();

  static final AuthService instance =
      AuthService._privateConstructor();

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  User? get currentUser =>
      _auth.currentUser;

  // ============================================================
  // TEXTBEE CONFIGURATION
  // ============================================================

  static const String _textBeeApiKey =
      '3976128d-92db-428f-8e94-8ac21cb5b1b4';

  static const String _textBeeDeviceId =
      '6a6c26d3cd8a35b23c02a931';

  static const String _textBeeBaseUrl =
      'https://api.textbee.dev/api/v1/gateway/devices';

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  Future<bool> _isEmailDomainValid(
    String email,
  ) async {
    try {
      final parts = email.split('@');

      if (parts.length != 2) {
        return false;
      }

      final domain = parts[1].trim();

      final result = await InternetAddress.lookup(
        domain,
      );

      return result.isNotEmpty &&
          result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // FIREBASE PASSWORD RESET LINK (100% LIBRE)
  // ============================================================

  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    final emailRegex = RegExp(
      r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$',
    );

    if (!emailRegex.hasMatch(cleanEmail)) {
      throw Exception('Maling format ng email address.');
    }

    try {
      await _auth.sendPasswordResetEmail(email: cleanEmail);
      debugPrint('SUCCESS: Password reset email sent to $cleanEmail');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Walang account na nakarehistro sa email na ito.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Hindi valid ang format ng email.');
      } else {
        throw Exception(e.message ?? 'Bigo sa pagpapadala ng password reset email.');
      }
    } catch (e) {
      debugPrint('PASSWORD RESET ERROR: $e');
      throw Exception('May naganap na error habang nagpapadala ng reset link.');
    }
  }

  // ============================================================
  // GENERATE EMAIL OTP
  // ============================================================

  Future<String> generateAndSaveEmailOTP({
    required String email,
    required String name,
    String reason = 'Registration',
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // ----------------------------------------------------------
    // EMAIL FORMAT
    // ----------------------------------------------------------

    final emailRegex = RegExp(
      r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$',
    );

    if (!emailRegex.hasMatch(cleanEmail)) {
      throw Exception(
        'Maling format ng email address.',
      );
    }

    // ----------------------------------------------------------
    // EMAIL DOMAIN CHECK
    // ----------------------------------------------------------

    final domainExists = await _isEmailDomainValid(cleanEmail);

    if (!domainExists) {
      throw Exception(
        'Hindi umiiral ang email domain na ito.',
      );
    }

    // ----------------------------------------------------------
    // CHECK EXISTING USER
    // ----------------------------------------------------------

    if (reason == 'Registration') {
      try {
        final existingEmailDoc = await _firestore
            .collection('users')
            .where(
              'email',
              isEqualTo: cleanEmail,
            )
            .limit(1)
            .get();

        if (existingEmailDoc.docs.isNotEmpty) {
          throw Exception(
            'May nakarehistro nang account gamit ang email na ito.',
          );
        }
      } catch (e) {
        if (e is Exception) {
          rethrow;
        }

        debugPrint(
          'Firestore email check error: $e',
        );
      }

      try {
        final methods = await _auth.fetchSignInMethodsForEmail(
          cleanEmail,
        );

        if (methods.isNotEmpty) {
          throw Exception(
            'May existing account na gamit ang email na ito.',
          );
        }
      } on FirebaseAuthException catch (e) {
        debugPrint(
          'Firebase email existence check: ${e.code}',
        );
      }
    }

    // ----------------------------------------------------------
    // GENERATE OTP
    // ----------------------------------------------------------

    final random = Random();

    final otp = List.generate(
      6,
      (_) => random.nextInt(10).toString(),
    ).join();

    debugPrint(
      'Generated OTP for $cleanEmail: $otp',
    );

    // ==========================================================
    // GMAIL SMTP
    // ==========================================================

    const senderEmail = 'wearegroup82025@gmail.com';

    const appPassword = 'ygyziuokfrdxqrfd';

    final smtpServer = gmail(
      senderEmail,
      appPassword,
    );

    // ----------------------------------------------------------
    // EMAIL CONTENT
    // ----------------------------------------------------------

    final message = Message()
      ..from = Address(
        senderEmail,
        'Arroz Platform Support',
      )
      ..recipients.add(cleanEmail)
      ..subject = '[Arroz] Your Verification Code'
      ..text = '''
Magandang araw $name,

Ang iyong Arroz verification code ay:

$otp

Ang code na ito ay valid lamang sa loob ng 1 minuto.

Huwag ibahagi ang OTP sa ibang tao.

Salamat,
Arroz Platform Support
'''
      ..html = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
</head>

<body style="
  margin:0;
  padding:20px;
  background:#f4f6f8;
  font-family:Arial,sans-serif;
">

<div style="
  max-width:500px;
  margin:auto;
  background:white;
  padding:30px;
  border-radius:16px;
">

<h2 style="
  color:#0F5132;
  margin-top:0;
">
🌱 ARROZ
</h2>

<p>
Magandang araw <strong>$name</strong>,
</p>

<p>
Gamitin ang verification code sa ibaba upang
makumpleto ang iyong registration.
</p>

<div style="
  margin:25px 0;
  padding:20px;
  background:#E8F5E9;
  border-radius:12px;
  text-align:center;
">

<div style="
  font-size:13px;
  color:#64748B;
  margin-bottom:10px;
">
YOUR VERIFICATION CODE
</div>

<div style="
  font-size:34px;
  font-weight:bold;
  letter-spacing:8px;
  color:#0F5132;
">
$otp
</div>

</div>

<p style="
  color:#64748B;
  font-size:13px;
">
This verification code expires in 1 minute.
</p>

<p style="
  color:#64748B;
  font-size:13px;
">
Huwag ibahagi ang code na ito sa ibang tao.
</p>

<hr style="
  border:none;
  border-top:1px solid #eee;
  margin:25px 0;
">

<p style="
  color:#64748B;
  font-size:12px;
">
Arroz Platform Support
</p>

</div>

</body>
</html>
''';

    // ==========================================================
    // SEND EMAIL
    // ==========================================================

    try {
      debugPrint(
        'Attempting to send OTP email to $cleanEmail...',
      );

      final sendReport = await send(
        message,
        smtpServer,
      );

      debugPrint(
        'OTP EMAIL SENT SUCCESSFULLY: $sendReport',
      );
    } on MailerException catch (e) {
      debugPrint(
        '================ MAILER ERROR ================',
      );

      debugPrint(
        e.toString(),
      );

      for (final problem in e.problems) {
        debugPrint(
          'Mailer problem: ${problem.code}',
        );

        debugPrint(
          'Mailer detail: ${problem.msg}',
        );
      }

      debugPrint(
        '===============================================',
      );

      throw Exception(
        'Hindi maipadala ang OTP email. '
        'Pakisuri ang Gmail App Password at SMTP configuration.',
      );
    } catch (e) {
      debugPrint(
        'EMAIL SEND ERROR: $e',
      );

      throw Exception(
        'Nagkaroon ng problema sa pagpapadala ng OTP email.',
      );
    }

    // ==========================================================
    // SAVE OTP TO FIRESTORE
    // ==========================================================

    final expirationTime = DateTime.now().add(
      const Duration(minutes: 1),
    );

    await _firestore
        .collection('email_otps')
        .doc(cleanEmail)
        .set({
      'otp': otp,
      'email': cleanEmail,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        expirationTime,
      ),
    });

    debugPrint(
      'OTP saved to Firestore: email_otps/$cleanEmail',
    );

    return otp;
  }

  // ============================================================
  // VERIFY EMAIL OTP
  // ============================================================

  Future<bool> verifyEmailOTP({
    required String email,
    required String typedOtp,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();

      final doc = await _firestore
          .collection('email_otps')
          .doc(cleanEmail)
          .get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data();

      if (data == null) {
        return false;
      }

      final savedOtp = data['otp']?.toString() ?? '';

      final expiresAt = data['expiresAt'] as Timestamp?;

      if (expiresAt == null) {
        return false;
      }

      // --------------------------------------------------------
      // EXPIRED
      // --------------------------------------------------------

      if (DateTime.now().isAfter(
        expiresAt.toDate(),
      )) {
        await _firestore
            .collection(
              'email_otps',
            )
            .doc(cleanEmail)
            .delete();

        return false;
      }

      // --------------------------------------------------------
      // WRONG OTP
      // --------------------------------------------------------

      if (savedOtp != typedOtp.trim()) {
        return false;
      }

      // --------------------------------------------------------
      // DELETE OTP AFTER SUCCESS
      // --------------------------------------------------------

      await _firestore
          .collection('email_otps')
          .doc(cleanEmail)
          .delete();

      return true;
    } catch (e) {
      debugPrint(
        'verifyEmailOTP error: $e',
      );

      return false;
    }
  }

  // ============================================================
  // CREATE FIREBASE EMAIL ACCOUNT
  // ============================================================

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  // ============================================================
  // LOGIN WITH EMAIL
  // ============================================================

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  // ============================================================
  // UPDATE PASSWORD VIA OTP (CLOUD FUNCTION BACKEND)
  // ============================================================

  Future<void> updatePasswordWithOTP({
    required String email,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      // 1. Siguraduhing umiiral ang account sa Firestore
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('Hindi mahanap ang account sa database.');
      }

      // 2. TAMA AT UP-TO-DATE URL GAMIT ANG IYONG PROJECT ID (arroz-sys)
      final url = Uri.parse('https://us-central1-arroz-sys.cloudfunctions.net/adminResetPassword');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Bigo sa pagpapalit ng password.');
      }

      // 3. I-update ang timestamp record sa Firestore
      final userDoc = userQuery.docs.first;
      await userDoc.reference.update({
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('SUCCESS: Password updated successfully for $cleanEmail');
    } catch (e) {
      debugPrint('UPDATE PASSWORD ERROR: $e');
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // TEXTBEE - NORMALIZE PHILIPPINE PHONE NUMBER
  // ============================================================

  String normalizePhilippinePhone(String phone) {
    String cleaned = phone.trim().replaceAll(RegExp(r'[\s\-()]'), '');

    if (cleaned.startsWith('09') && cleaned.length == 11) {
      return '+63${cleaned.substring(1)}';
    }

    if (cleaned.startsWith('63') && cleaned.length == 12) {
      return '+$cleaned';
    }

    if (cleaned.startsWith('+63') && cleaned.length == 13) {
      return cleaned;
    }

    throw Exception(
      'Invalid Philippine mobile number. Gamitin ang format na 09XXXXXXXXX.',
    );
  }

  // ============================================================
  // TEXTBEE - SEND SMS
  // ============================================================

  Future<void> sendTextBeeSMS({
    required String phoneNumber,
    required String message,
  }) async {
    final phone = normalizePhilippinePhone(
      phoneNumber,
    );

    if (_textBeeApiKey == 'YOUR_TEXTBEE_API_KEY' ||
        _textBeeDeviceId == 'YOUR_TEXTBEE_DEVICE_ID') {
      throw Exception(
        'Hindi pa naka-configure ang TextBee API Key at Device ID.',
      );
    }

    final url = '$_textBeeBaseUrl/$_textBeeDeviceId/send-sms';

    try {
      debugPrint(
        'TEXTBEE: Sending SMS to $phone',
      );

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': _textBeeApiKey,
            },
            body: jsonEncode({
              'recipients': [phone],
              'message': message,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
          );

      debugPrint(
        'TEXTBEE STATUS: ${response.statusCode}',
      );

      debugPrint(
        'TEXTBEE RESPONSE: ${response.body}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'TextBee failed (${response.statusCode}): ${response.body}',
        );
      }

      debugPrint(
        'TEXTBEE: SMS accepted successfully.',
      );
    } catch (e) {
      debugPrint(
        'TEXTBEE SEND ERROR: $e',
      );

      rethrow;
    }
  }

  // ============================================================
  // TEXTBEE - GENERATE PHONE OTP
  // ============================================================

  Future<String> generatePhoneOTP({
    required String phoneNumber,
  }) async {
    final phone = normalizePhilippinePhone(phoneNumber);

    final random = Random();

    final otp = List.generate(
      6,
      (_) => random.nextInt(10).toString(),
    ).join();

    final expiresAt = DateTime.now().add(
      const Duration(minutes: 5),
    );

    await _firestore
        .collection('phone_otps')
        .doc(phone)
        .set({
      'phoneNumber': phone,
      'otp': otp,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    try {
      await sendTextBeeSMS(
        phoneNumber: phone,
        message: 'Arroz verification code: $otp\n\n'
            'Valid for 5 minutes. Huwag ibahagi ang code na ito.',
      );

      debugPrint(
        'PHONE OTP SENT: $phone',
      );

      return otp;
    } catch (e) {
      await _firestore
          .collection('phone_otps')
          .doc(phone)
          .delete();

      rethrow;
    }
  }

  // ============================================================
  // TEXTBEE - VERIFY PHONE OTP
  // ============================================================

  Future<bool> verifyPhoneOTP({
    required String phoneNumber,
    required String typedOtp,
  }) async {
    try {
      final phone = normalizePhilippinePhone(phoneNumber);

      final otp = typedOtp.trim();

      if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
        return false;
      }

      final doc = await _firestore
          .collection('phone_otps')
          .doc(phone)
          .get();

      if (!doc.exists) {
        debugPrint(
          'PHONE OTP: No OTP found.',
        );

        return false;
      }

      final data = doc.data();

      if (data == null) {
        return false;
      }

      final savedOtp = data['otp']?.toString() ?? '';

      final expiresAt = data['expiresAt'] as Timestamp?;

      if (expiresAt == null) {
        return false;
      }

      if (DateTime.now().isAfter(
        expiresAt.toDate(),
      )) {
        await _firestore
            .collection('phone_otps')
            .doc(phone)
            .delete();

        debugPrint(
          'PHONE OTP: OTP expired.',
        );

        return false;
      }

      if (savedOtp != otp) {
        debugPrint(
          'PHONE OTP: Wrong OTP.',
        );

        return false;
      }

      await _firestore
          .collection('phone_otps')
          .doc(phone)
          .delete();

      debugPrint(
        'PHONE OTP: Successfully verified.',
      );

      return true;
    } catch (e) {
      debugPrint(
        'VERIFY PHONE OTP ERROR: $e',
      );

      return false;
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    await _auth.signOut();
  }
}