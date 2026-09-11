import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'homeuser_page.dart';
import 'registeruser_page.dart';
import 'forgot_password_sheet.dart';

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
      'lockoutMsg': 'Too many failed attempts. Try again in 2 minutes.',
      'errorAuth': 'Invalid email or password. Please check and try again.',
      'connErr': 'Unable to connect. Please check your internet.',
      'btnUnderstand': 'I Understand',
      'btnTryAgain': 'Try Again',
      'btnOk': 'OK',
      'accBlockedTitle': 'Account Blocked',
      'accBlockedSub': 'Your account has been restricted by the admin.',
      'accDeletedTitle': 'Account Permanently Deleted',
      'accDeletedSub': 'This account has exceeded the grace period and is permanently deleted.',
      'confirmDeleteTitle': 'Confirm Deletion Grace Period',
      'confirmDeleteSub': 'Are you sure you want to schedule account deletion? You will have a 30-day grace period to restore your account before it is permanently removed.',
      'btnConfirm': 'Confirm Deletion',
      'btnCancel': 'Cancel',
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
      'lockoutMsg': 'Masyadong maraming subok. Maghintay muna ng 2 minuto.',
      'errorAuth': 'Maling email o password. Pakisuri at subukan ulit.',
      'connErr': 'Hindi makakonekta sa internet sa kasalukuyan.',
      'btnUnderstand': 'Naintindihan Ko',
      'btnTryAgain': 'Subukang Muli',
      'btnOk': 'Sige',
      'accBlockedTitle': 'Naka-block ang Account',
      'accBlockedSub': 'Ang iyong account ay na-restrict ng Admin.',
      'accDeletedTitle': 'Account Dinelete Na',
      'accDeletedSub': 'Lumagpas na sa grace period ang account na ito at tuluyan nang nabura sa platform.',
      'confirmDeleteTitle': 'Kumpirmahin ang 30-Araw na Palugit',
      'confirmDeleteSub': 'Sigurado ka bang gusto mong i-schedule ang pagbura ng account? Magkakaroon ka ng 30 araw na palugit (grace period) para bawiin ito bago tuluyang mabura.',
      'btnConfirm': 'Ituloy ang Pagbura',
      'btnCancel': 'Kanselahin',
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
        final screenWidth = MediaQuery.of(ctx).size.width;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.all(screenWidth < 360 ? 16 : 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: screenWidth < 360 ? 28 : 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth < 360 ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: ArrozTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth < 360 ? 12 : 13,
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: onPressed ?? () => Navigator.pop(ctx),
                      child: Text(
                        buttonText,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Responsive Restore Dialog para sa Deletion Grace Period
  void _showFacebookStyleRestoreDialog({
    required BuildContext context,
    required String userId,
    required Timestamp? scheduledTimestamp,
  }) {
    String remainingTimeText = "30 araw";

    if (scheduledTimestamp != null) {
      final scheduledDate = scheduledTimestamp.toDate();
      final difference = scheduledDate.difference(DateTime.now());

      final days = difference.inDays;
      final hours = difference.inHours % 24;

      remainingTimeText = _currentLanguage == 'Tagalog'
          ? "$days araw at $hours oras"
          : "$days days and $hours hours";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: EdgeInsets.all(screenWidth < 360 ? 16 : 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ArrozTheme.warning.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: ArrozTheme.warning,
                      size: screenWidth < 360 ? 28 : 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentLanguage == 'Tagalog'
                        ? 'Gusto mo bang itigil ang pagbura ng account?'
                        : 'Cancel Deletion Request?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth < 360 ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: ArrozTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _currentLanguage == 'Tagalog'
                        ? 'Naka-schedule na mabura ang iyong account sa loob ng $remainingTimeText.\n\n'
                          'Kapag ipinagpatuloy mo ang pagbawi ngayon, maa-cancel ang deletion at magagamit mo ulit ang iyong account.'
                        : 'Your account is scheduled for deletion in $remainingTimeText.\n\n'
                          'If you cancel deletion now, your account will be fully restored.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth < 360 ? 12 : 13,
                      color: ArrozTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Button 1: Restore Account
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ArrozTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        try {
                          await FirebaseFirestore.instance.collection('users').doc(userId).update({
                            'isPendingDeletion': false,
                            'deletionRequestedAt': FieldValue.delete(),
                            'scheduledDeletionDate': FieldValue.delete(),
                          });

                          if (ctx.mounted) Navigator.pop(ctx);

                          _showSnackBar(
                            _currentLanguage == 'Tagalog'
                                ? 'Na-cancel ang pagbura! Maligayang pagbabalik.'
                                : 'Deletion request canceled! Welcome back.',
                            ArrozTheme.primary,
                          );
                        } catch (e) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          await FirebaseAuth.instance.signOut();
                          _showSnackBar("Restore Error: $e", ArrozTheme.error);
                        }
                      },
                      child: Text(
                        _currentLanguage == 'Tagalog' ? 'Oo, Bawiin ang Account' : 'Yes, Restore Account',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Button 2: Keep Scheduled & Sign Out
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await FirebaseAuth.instance.signOut();
                      },
                      child: Text(
                        _currentLanguage == 'Tagalog' ? 'Hayaan Lang (Mag-logout)' : 'Keep Scheduled & Sign Out',
                        style: const TextStyle(color: ArrozTheme.textMuted, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

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

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      UserCredential credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;

      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

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
        
        // Match Field Names with ProfilePage
        final bool isPendingDeletion = data['isPendingDeletion'] ?? data['isScheduledForDeletion'] ?? false;
        final Timestamp? scheduledTimestamp = data['scheduledDeletionDate'] ?? data['deletionScheduledAt'];

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

        if (isPendingDeletion) {
          bool isGracePeriodExpired = false;

          if (scheduledTimestamp != null) {
            final expiryDate = scheduledTimestamp.toDate();
            if (DateTime.now().isAfter(expiryDate)) {
              isGracePeriodExpired = true;
            }
          }

          if (isGracePeriodExpired) {
            await FirebaseFirestore.instance.collection('users').doc(uid).delete();
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            _showCustomWarningDialog(
              context: context,
              title: localized['accDeletedTitle']!,
              description: localized['accDeletedSub']!,
              icon: Icons.delete_forever_rounded,
              color: ArrozTheme.error,
              buttonText: localized['btnUnderstand']!,
            );
            return;
          } else {
            if (!mounted) return;
            _showFacebookStyleRestoreDialog(
              context: context,
              userId: uid,
              scheduledTimestamp: scheduledTimestamp,
            );
            return;
          }
        }
      }

      _failedAttempts = 0;
    } on FirebaseAuthException catch (_) {
      _failedAttempts++;
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
        _showCustomWarningDialog(
          context: context,
          title: _currentLanguage == 'Tagalog' ? 'Maling Credentials' : 'Invalid Credentials',
          description: localized['errorAuth']!,
          icon: Icons.no_accounts_rounded,
          color: ArrozTheme.error,
          buttonText: localized['btnTryAgain']!,
        );
      }
    } catch (e) {
      _showSnackBar(localized['connErr']!, ArrozTheme.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            decoration: BoxDecoration(
                              color: ArrozTheme.cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
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
                                  setState(() => _currentLanguage = value);
                                },
                                items: const [
                                  DropdownMenuItem(value: 'Tagalog', child: Text('Tagalog')),
                                  DropdownMenuItem(value: 'English', child: Text('English')),
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
                            child: const Icon(Icons.eco_rounded, size: 38, color: ArrozTheme.accent),
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
                          style: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: ArrozTheme.cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.grey.shade200),
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
                                decoration: _inputDecoration(localized['email']!, Icons.mail_outline_rounded),
                                validator: (value) => (value == null || value.trim().isEmpty) ? localized['valEmail'] : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  color: ArrozTheme.textMain,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _inputDecoration(localized['password']!, Icons.lock_outline_rounded).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: ArrozTheme.textMuted,
                                    ),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (value) => (value == null || value.isEmpty) ? localized['valPassword'] : null,
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
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
                            Text(localized['noAccount']!, style: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13)),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RegisterUserPage(initialLanguage: _currentLanguage),
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
              );
            },
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: ArrozTheme.primary, size: 20),
      filled: true,
      fillColor: ArrozTheme.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ArrozTheme.primary, width: 1.5),
      ),
    );
  }
}