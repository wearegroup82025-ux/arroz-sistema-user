import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'homeuser_page.dart';
import 'registeruser_page.dart';
import 'forgot_password_sheet.dart'; // IMPORT ANG BAGONG WIDGET DITO

class ArrozTheme {
  static const Color primary = Color(0xFF0F5132);
  static const Color primaryLight = Color(0xFF2D8A56);
  static const Color accent = Color(0xFFD1E7DD);
  static const Color bg = Color(0xFFFBFBF9);
  static const Color cardBg = Colors.white;
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
}

class LoginUserPage extends StatefulWidget {
  const LoginUserPage({super.key});

  @override
  State<LoginUserPage> createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  String _currentLanguage = 'Tagalog';

  int _failedAttempts = 0;
  DateTime? _lockoutTime;

  final Map<String, Map<String, String>> _txt = {
    'English': {
      'subtitle': 'Modern Agriculture Platform',
      'email': 'Email Address',
      'password': 'Password',
      'forgotPwd': 'Forgot Password?',
      'btnLogin': 'Sign In',
      'noAccount': 'New to Arroz? ',
      'joinHere': 'Create Account',

      'valEmail': 'Please enter your email address',
      'valPassword': 'Password is required',

      'forgotTitle': 'Reset Password',
      'forgotSub':
          'Enter your registered email address to receive an OTP verification code.',
      'forgotSearch': 'SEND OTP CODE',

      'searchHintEmail': 'Enter registered Email Address',

      'emptySearchWarn': 'Please enter your registered email address.',

      'accNotFoundTitle': 'Account Not Found',
      'accNotFoundSub':
          'We couldn\'t find any Arroz account linked to that email address.',

      'chooseOtpTitle': 'Email Verification',
      'enterOtpTitle': 'Enter 6-Digit OTP',
      'enterOtpSub': 'Enter the verification code sent to ',

      'verifyOtpBtn': 'VERIFY OTP',

      'invalidOtpTitle': 'Invalid Verification Code',
      'invalidOtpSub':
          'The OTP code you entered is incorrect or expired. Please check and try again.',

      'newPassTitle': 'Set New Password',
      'newPassSub': 'Create a strong new password for your account.',

      'newPassHint': 'New Password',
      'confirmPassHint': 'Confirm Password',

      'savePassBtn': 'UPDATE PASSWORD',

      'passNotMatchTitle': 'Passwords Do Not Match',
      'passNotMatchSub': 'Please ensure both password fields are identical.',

      'passSuccessTitle': 'Password Reset Successful!',
      'passSuccessSub':
          'Your password has been updated. You can now login using your new credentials.',

      'ruleLength': 'At least 8 characters long',
      'ruleNumber': 'Contains at least 1 number (0-9)',
      'ruleSpecial': 'Contains at least 1 special character (!@#\$%^&*)',

      'lockoutMsg': 'Too many failed attempts. Try again in 2 minutes.',

      'errorAuth': 'Invalid email or password. Please check and try again.',

      'connErr': 'Unable to connect. Please check your internet.',

      'btnUnderstand': 'I Understand',
      'btnTryAgain': 'Try Again',
      'btnOk': 'OK',

      'resendOtp': 'Resend OTP Code',
      'resendIn': 'Resend available in',
      'otpSent': 'OTP code sent successfully!',
      'passwordUpdated': 'Your password has been updated successfully.',

      'accBlockedTitle': 'Account Blocked',
      'accBlockedSub':
          'Your account has been restricted by the admin. Please contact support.',

      'accDeletedTitle': 'Account Deleted',
      'accDeletedSub':
          'This account has been deleted or scheduled for permanent deletion.',
    },
    'Tagalog': {
      'subtitle': 'Sistema para sa Modernong Magsasaka',
      'email': 'Email Address',
      'password': 'Password',
      'forgotPwd': 'Nakalimutan ang Password?',
      'btnLogin': 'Mag-login',
      'noAccount': 'Bago ka ba sa Arroz? ',
      'joinHere': 'Gumawa ng Account',

      'valEmail': 'Ilagay ang iyong email address',
      'valPassword': 'Kailangan ang password',

      'forgotTitle': 'I-reset ang Password',
      'forgotSub':
          'Ilagay ang iyong registered email address para makatanggap ng OTP verification code.',
      'forgotSearch': 'IPADALA ANG OTP',

      'searchHintEmail': 'Ilagay ang registered Email Address',

      'emptySearchWarn': 'Mangyaring maglagay ng registered email address.',

      'accNotFoundTitle': 'Walang Nahanap na Account',
      'accNotFoundSub':
          'Walang Arroz account na nakarehistro gamit ang email address na ito.',

      'chooseOtpTitle': 'Email Verification',
      'enterOtpTitle': 'Ilagay ang 6-Digit OTP',
      'enterOtpSub': 'Ilagay ang code na ipinadala sa ',

      'verifyOtpBtn': 'I-VERIFY ANG OTP',

      'invalidOtpTitle': 'Maling OTP Code',
      'invalidOtpSub':
          'Ang OTP code na inilagay mo ay mali o expired na. Pakisuri at subukang muli.',

      'newPassTitle': 'Gumawa ng Bagong Password',
      'newPassSub':
          'Maglagay ng matatag na bagong password para sa iyong account.',

      'newPassHint': 'Bagong Password',
      'confirmPassHint': 'Kumpirmahin ang Password',

      'savePassBtn': 'I-UPDATE ANG PASSWORD',

      'passNotMatchTitle': 'Hindi Magkatugma ang Password',
      'passNotMatchSub':
          'Siguraduhing pareho ang inilagay na password sa dalawang field.',

      'passSuccessTitle': 'Tagumpay ang Pag-reset!',
      'passSuccessSub':
          'Na-update na ang iyong password. Maaari ka nang mag-login gamit ang bagong password.',

      'ruleLength': 'Hindi bababa sa 8 characters',
      'ruleNumber': 'Mayroong kahit 1 numero (0-9)',
      'ruleSpecial': 'Mayroong kahit 1 special character (!@#\$%^&*)',

      'lockoutMsg': 'Masyadong maraming subok. Maghintay muna ng 2 minuto.',

      'errorAuth': 'Maling email o password. Pakisuri at subukan ulit.',

      'connErr': 'Hindi makakonekta sa internet sa kasalukuyan.',

      'btnUnderstand': 'Naintindihan Ko',
      'btnTryAgain': 'Subukang Muli',
      'btnOk': 'Sige',

      'resendOtp': 'Ipadala Muli ang OTP',
      'resendIn': 'Maaaring mag-resend sa',
      'otpSent': 'Matagumpay na naipadala ang OTP!',
      'passwordUpdated': 'Matagumpay na na-update ang iyong password.',

      'accBlockedTitle': 'Naka-block ang Account',
      'accBlockedSub':
          'Ang iyong account ay na-restrict ng Admin. Makipag-ugnayan sa support.',

      'accDeletedTitle': 'Account Dinelete Na',
      'accDeletedSub':
          'Ang account na ito ay nabura na o naka-schedule para sa permanent deletion.',
    },
  };

  void _showCustomWarningDialog({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String buttonText,
    VoidCallback? onPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ArrozTheme.textMain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ArrozTheme.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: onPressed ?? () => Navigator.pop(ctx),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _handleLogin() async {
    final localized = _txt[_currentLanguage]!;

    if (_lockoutTime != null) {
      final difference = DateTime.now().difference(_lockoutTime!);

      if (difference.inMinutes < 2) {
        _showCustomWarningDialog(
          context: context,
          title: 'Account Locked Temporarily',
          description: localized['lockoutMsg']!,
          icon: Icons.lock_clock_rounded,
          color: ArrozTheme.error,
          buttonText: localized['btnUnderstand']!,
        );
        return;
      } else {
        _failedAttempts = 0;
        _lockoutTime = null;
      }
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;

      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _showCustomWarningDialog(
            context: context,
            title: localized['accDeletedTitle']!,
            description: localized['accDeletedSub']!,
            icon: Icons.person_off_rounded,
            color: ArrozTheme.error,
            buttonText: localized['btnUnderstand']!,
          );
          return;
        }

        final data = userDoc.data() as Map<String, dynamic>;
        final bool isBlocked = data['isBlocked'] ?? false;
        final bool isScheduledForDeletion =
            data['isScheduledForDeletion'] ?? false;

        if (isBlocked) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _showCustomWarningDialog(
            context: context,
            title: localized['accBlockedTitle']!,
            description: localized['accBlockedSub']!,
            icon: Icons.block_rounded,
            color: ArrozTheme.error,
            buttonText: localized['btnUnderstand']!,
          );
          return;
        }

        if (isScheduledForDeletion) {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          _showCustomWarningDialog(
            context: context,
            title: localized['accDeletedTitle']!,
            description: localized['accDeletedSub']!,
            icon: Icons.person_off_rounded,
            color: ArrozTheme.error,
            buttonText: localized['btnUnderstand']!,
          );
          return;
        }
      }

      _failedAttempts = 0;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeUserPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _failedAttempts++;

      debugPrint('LOGIN ERROR: ${e.code} - ${e.message}');

      if (_failedAttempts >= 5) {
        _lockoutTime = DateTime.now();

        _showCustomWarningDialog(
          context: context,
          title: 'Account Locked Temporarily',
          description: localized['lockoutMsg']!,
          icon: Icons.lock_clock_rounded,
          color: ArrozTheme.error,
          buttonText: localized['btnUnderstand']!,
        );
      } else {
        String message = localized['errorAuth']!;

        if (e.code == 'user-not-found') {
          message = _currentLanguage == 'Tagalog'
              ? 'Walang account na gumagamit ng email na ito.'
              : 'No account found with this email address.';
        }

        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          message = localized['errorAuth']!;
        }

        _showCustomWarningDialog(
          context: context,
          title: _currentLanguage == 'Tagalog'
              ? 'Maling Credentials'
              : 'Invalid Credentials',
          description: message,
          icon: Icons.no_accounts_rounded,
          color: ArrozTheme.error,
          buttonText: localized['btnTryAgain']!,
        );
      }
    } catch (e) {
      debugPrint('LOGIN GENERAL ERROR: $e');

      _showSnackBar(
        localized['connErr']!,
        ArrozTheme.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // OPEN FORGOT PASSWORD SHEET (MALINIS AT MAIKLI NA)
  // ============================================================

  void _openForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ForgotPasswordSheet(
          currentLanguage: _currentLanguage,
          txt: _txt,
          showCustomWarningDialog: _showCustomWarningDialog,
          showSnackBar: _showSnackBar,
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localized = _txt[_currentLanguage]!;

    return Scaffold(
      backgroundColor: ArrozTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ArrozTheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currentLanguage,
                            style: const TextStyle(
                              color: ArrozTheme.textMain,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _currentLanguage = value;
                              });
                            },
                            items: const [
                              DropdownMenuItem(
                                value: 'Tagalog',
                                child: Text('Tagalog'),
                              ),
                              DropdownMenuItem(
                                value: 'English',
                                child: Text('English'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: ArrozTheme.primary,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: ArrozTheme.primary.withOpacity(0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          size: 38,
                          color: ArrozTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'ARROZ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: ArrozTheme.primary,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      localized['subtitle']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ArrozTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ArrozTheme.cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(
                              color: ArrozTheme.textMain,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _inputDecoration(
                              localized['email']!,
                              Icons.mail_outline_rounded,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return localized['valEmail'];
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(
                              color: ArrozTheme.textMain,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: _inputDecoration(
                              localized['password']!,
                              Icons.lock_outline_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: ArrozTheme.textMuted,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return localized['valPassword'];
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _openForgotPasswordSheet,
                              child: Text(
                                localized['forgotPwd']!,
                                style: const TextStyle(
                                  color: ArrozTheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ArrozTheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      localized['btnLogin']!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          localized['noAccount']!,
                          style: const TextStyle(
                            color: ArrozTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegisterUserPage(
                                  initialLanguage: _currentLanguage,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            localized['joinHere']!,
                            style: const TextStyle(
                              color: ArrozTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: ArrozTheme.textMuted,
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        color: ArrozTheme.primary,
        size: 20,
      ),
      filled: true,
      fillColor: ArrozTheme.bg,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: ArrozTheme.primary,
          width: 1.5,
        ),
      ),
    );
  }
}