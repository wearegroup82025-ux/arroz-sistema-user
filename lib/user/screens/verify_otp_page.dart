import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth/auth.service.dart';
import 'homeuser_page.dart';

class ArrozTheme {
  static const Color primary = Color(0xFF0F5132);
  static const Color primaryLight = Color(0xFF2D8A56);
  static const Color accent = Color(0xFFD1E7DD);
  static const Color bg = Color(0xFFFBFBF9);
  static const Color cardBg = Colors.white;
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color error = Color(0xFFDC2626);
}

class VerifyOtpPage extends StatefulWidget {
  final String email;

  final String lastName;
  final String firstName;
  final String middleInitial;

  final String? passwordForEmail;

  const VerifyOtpPage({
    super.key,
    required this.email,
    required this.lastName,
    required this.firstName,
    required this.middleInitial,
    this.passwordForEmail,
  });

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final TextEditingController _otpController =
  TextEditingController();

  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Timer? _timer;

  bool _loading = false;
  bool _resending = false;

  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  // ============================================================
  // TIMER
  // ============================================================

  void _startTimer() {
    _timer?.cancel();

    setState(() {
      _secondsRemaining = 60;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_secondsRemaining <= 1) {
          timer.cancel();

          setState(() {
            _secondsRemaining = 0;
          });
        } else {
          setState(() {
            _secondsRemaining--;
          });
        }
      },
    );
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> _verifyOtp() async {
    if (_loading) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    await _verifyEmailOtp();
  }

  // ============================================================
  // VERIFY EMAIL OTP
  // ============================================================

  Future<void> _verifyEmailOtp() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      final email = widget.email.trim().toLowerCase();
      final typedOtp = _otpController.text.trim();

      debugPrint('================================');
      debugPrint('VERIFYING EMAIL OTP');
      debugPrint('Email: $email');
      debugPrint('OTP: $typedOtp');
      debugPrint('================================');

      // --------------------------------------------------------
      // 1. VERIFY OTP
      // --------------------------------------------------------

      final bool valid =
      await AuthService.instance.verifyEmailOTP(
        email: email,
        typedOtp: typedOtp,
      );

      if (!valid) {
        _showNotification(
          'Maling OTP o nag-expire na ang verification code.',
          ArrozTheme.error,
        );

        return;
      }

      debugPrint('Email OTP verified successfully.');

      // --------------------------------------------------------
      // 2. GET PASSWORD
      // --------------------------------------------------------

      final password = widget.passwordForEmail;

      if (password == null || password.isEmpty) {
        throw Exception(
          'Walang password para sa email registration.',
        );
      }

      // --------------------------------------------------------
      // 3. CREATE FIREBASE AUTH ACCOUNT
      // --------------------------------------------------------

      debugPrint('Creating Firebase email account...');

      final UserCredential userCredential =
      await AuthService.instance.registerWithEmail(
        email: email,
        password: password,
      );

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception(
          'Hindi makuha ang Firebase user.',
        );
      }

      debugPrint(
        'Firebase account created successfully.',
      );

      debugPrint(
        'Firebase UID: ${firebaseUser.uid}',
      );

      // --------------------------------------------------------
      // 4. SAVE USER TO FIRESTORE
      // --------------------------------------------------------

      await _saveUserToFirestore(firebaseUser);

      debugPrint(
        'Registration completed successfully.',
      );

      if (!mounted) return;

      _showNotification(
        'Matagumpay na na-verify ang iyong email at nalikha ang account.',
        Colors.green.shade700,
      );

      await Future.delayed(
        const Duration(milliseconds: 800),
      );

      if (!mounted) return;

      // --------------------------------------------------------
      // 5. GO TO HOME
      // --------------------------------------------------------

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeUserPage(),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase Email Error: ${e.code}',
      );

      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
          'May existing account na gamit ang email na ito.';
          break;

        case 'weak-password':
          message =
          'Mahina ang password. Gumamit ng mas secure na password.';
          break;

        case 'invalid-email':
          message =
          'Invalid ang email address.';
          break;

        case 'network-request-failed':
          message =
          'Walang internet connection. Pakisuri ang iyong internet.';
          break;

        case 'too-many-requests':
          message =
          'Masyadong maraming attempts. Maghintay muna bago subukan muli.';
          break;

        case 'operation-not-allowed':
          message =
          'Email/Password Authentication ay hindi enabled sa Firebase.';
          break;

        default:
          message =
              e.message ??
                  'Hindi ma-create ang account.';
      }

      _showNotification(
        message,
        ArrozTheme.error,
      );
    } catch (e) {
      debugPrint(
        'Email OTP verification error: $e',
      );

      if (!mounted) return;

      String message = e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      if (message.trim().isEmpty) {
        message =
        'May nangyaring error habang vine-verify ang email.';
      }

      _showNotification(
        message,
        ArrozTheme.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE USER TO FIRESTORE
  // ============================================================

  Future<void> _saveUserToFirestore(
      User firebaseUser,
      ) async {
    final uid = firebaseUser.uid;

    final userRef =
    _firestore.collection('users').doc(uid);

    final existingDoc =
    await userRef.get();

    final String lastName =
    widget.lastName.trim();

    final String firstName =
    widget.firstName.trim();

    final String middleInitial =
    widget.middleInitial.trim();

    final String email =
    widget.email.trim().toLowerCase();

    // Full name for easier display/search.
    final String fullName = [
      firstName,
      middleInitial,
      lastName,
    ].where((value) => value.isNotEmpty).join(' ');

    final Map<String, dynamic> userData = {
      'uid': uid,

      'lastName': lastName,

      'firstName': firstName,

      'middleInitial': middleInitial,

      'fullName': fullName,

      'email': email,

      'role': 'user',

      'status': 'active',

      'emailVerified': true,

      'updatedAt':
      FieldValue.serverTimestamp(),
    };

    if (!existingDoc.exists) {
      userData['createdAt'] =
          FieldValue.serverTimestamp();
    }

    await userRef.set(
      userData,
      SetOptions(merge: true),
    );

    debugPrint(
      'User saved to Firestore: users/$uid',
    );

    debugPrint(
      'Full Name: $fullName',
    );
    debugPrint(
      'Email: $email',
    );
  }

  // ============================================================
  // RESEND OTP
  // ============================================================

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 ||
        _resending ||
        _loading) {
      return;
    }

    setState(() {
      _resending = true;
    });

    try {
      final String fullName = [
        widget.firstName.trim(),
        widget.middleInitial.trim(),
        widget.lastName.trim(),
      ].where((value) => value.isNotEmpty).join(' ');

      debugPrint(
        'Resending email OTP to: ${widget.email}',
      );

      await AuthService.instance.generateAndSaveEmailOTP(
        email: widget.email,
        name: fullName,
        reason: 'Registration',
      );

      if (!mounted) return;

      _otpController.clear();

      _startTimer();

      _showNotification(
        'Naipadala na ang bagong verification code sa iyong email.',
        Colors.green.shade700,
      );
    } catch (e) {
      debugPrint(
        'Resend email OTP error: $e',
      );

      if (!mounted) return;

      String message =
      e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      if (message.trim().isEmpty) {
        message =
        'Hindi maipadala ang bagong OTP.';
      }

      _showNotification(
        message,
        ArrozTheme.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _resending = false;
        });
      }
    }
  }

  // ============================================================
  // NOTIFICATION
  // ============================================================

  void _showNotification(
      String message,
      Color color,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .clearSnackBars();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: color,
        behavior:
        SnackBarBehavior.floating,
        duration:
        const Duration(seconds: 4),
        margin:
        const EdgeInsets.all(16),
        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      backgroundColor:
      ArrozTheme.bg,

      appBar: AppBar(
        backgroundColor:
        Colors.transparent,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color:
            ArrozTheme.textMain,
            size: 20,
          ),
          onPressed: _loading
              ? null
              : () {
            Navigator.pop(
              context,
            );
          },
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
            const BoxConstraints(
              maxWidth: 450,
            ),

            child:
            SingleChildScrollView(
              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 24,
                vertical: 20,
              ),

              child: Form(
                key: _formKey,

                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .center,

                  children: [
                    // ==================================================
                    // EMAIL ICON
                    // ==================================================

                    Container(
                      width: 80,
                      height: 80,

                      decoration:
                      const BoxDecoration(
                        color:
                        ArrozTheme
                            .accent,
                        shape:
                        BoxShape.circle,
                      ),

                      child: const Icon(
                        Icons
                            .mark_email_read_outlined,
                        size: 38,
                        color:
                        ArrozTheme
                            .primary,
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // ==================================================
                    // TITLE
                    // ==================================================

                    const Text(
                      'Verify Your Email',
                      textAlign:
                      TextAlign.center,

                      style:
                      TextStyle(
                        fontSize: 27,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        ArrozTheme
                            .primary,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    const Text(
                      'Ilagay ang 6-digit verification code na ipinadala sa iyong email.',
                      textAlign:
                      TextAlign.center,

                      style:
                      TextStyle(
                        fontSize: 14,
                        color:
                        ArrozTheme
                            .textMuted,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ==================================================
                    // EMAIL DISPLAY
                    // ==================================================

                    Container(
                      width:
                      double.infinity,

                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        Colors.white,
                        borderRadius:
                        BorderRadius
                            .circular(
                          14,
                        ),
                        border:
                        Border.all(
                          color: Colors
                              .grey
                              .shade200,
                        ),
                      ),

                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .email_outlined,
                            color:
                            ArrozTheme
                                .primary,
                            size: 21,
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child: Text(
                              widget.email,
                              overflow:
                              TextOverflow
                                  .ellipsis,

                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,
                                color:
                                ArrozTheme
                                    .textMain,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ==================================================
                    // NAME DISPLAY
                    // ==================================================

                    Container(
                      width:
                      double.infinity,

                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),

                      decoration:
                      BoxDecoration(
                        color: ArrozTheme
                            .accent
                            .withOpacity(
                          0.35,
                        ),
                        borderRadius:
                        BorderRadius
                            .circular(
                          14,
                        ),
                      ),

                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .person_outline_rounded,
                            color:
                            ArrozTheme
                                .primary,
                            size: 21,
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child: Text(
                              [
                                widget.firstName
                                    .trim(),
                                widget.middleInitial
                                    .trim(),
                                widget.lastName
                                    .trim(),
                              ]
                                  .where(
                                    (value) =>
                                value
                                    .isNotEmpty,
                              )
                                  .join(' '),

                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .w600,
                                color:
                                ArrozTheme
                                    .textMain,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 28,
                    ),

                    // ==================================================
                    // OTP FIELD
                    // ==================================================

                    TextFormField(
                      controller:
                      _otpController,

                      keyboardType:
                      TextInputType
                          .number,

                      textInputAction:
                      TextInputAction
                          .done,

                      textAlign:
                      TextAlign.center,

                      maxLength: 6,

                      enabled:
                      !_loading,

                      autofocus: true,

                      style:
                      const TextStyle(
                        fontSize: 28,
                        fontWeight:
                        FontWeight.bold,
                        letterSpacing: 10,
                        color:
                        ArrozTheme
                            .primary,
                      ),

                      decoration:
                      InputDecoration(
                        counterText: '',

                        hintText:
                        '000000',

                        hintStyle:
                        TextStyle(
                          fontSize: 28,
                          letterSpacing:
                          10,
                          color: Colors
                              .grey
                              .shade300,
                        ),

                        filled: true,

                        fillColor:
                        Colors.white,

                        contentPadding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),

                        enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            16,
                          ),
                          borderSide:
                          BorderSide(
                            color: Colors
                                .grey
                                .shade300,
                          ),
                        ),

                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            16,
                          ),
                          borderSide:
                          const BorderSide(
                            color:
                            ArrozTheme
                                .primary,
                            width: 1.5,
                          ),
                        ),

                        errorBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            16,
                          ),
                          borderSide:
                          const BorderSide(
                            color:
                            ArrozTheme
                                .error,
                          ),
                        ),

                        focusedErrorBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            16,
                          ),
                          borderSide:
                          const BorderSide(
                            color:
                            ArrozTheme
                                .error,
                            width: 1.5,
                          ),
                        ),
                      ),

                      validator: (value) {
                        final otp =
                            value?.trim() ??
                                '';

                        if (otp.isEmpty) {
                          return 'Ilagay ang OTP code.';
                        }

                        if (otp.length != 6) {
                          return 'Ang OTP ay dapat 6 digits.';
                        }

                        if (!RegExp(
                          r'^\d{6}$',
                        ).hasMatch(otp)) {
                          return 'Numbers lamang ang OTP.';
                        }

                        return null;
                      },

                      onChanged: (value) {
                        if (value.length == 6 &&
                            !_loading) {
                          FocusScope.of(
                            context,
                          ).unfocus();
                        }
                      },

                      onFieldSubmitted:
                          (_) {
                        if (!_loading) {
                          _verifyOtp();
                        }
                      },
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ==================================================
                    // VERIFY BUTTON
                    // ==================================================

                    SizedBox(
                      width:
                      double.infinity,
                      height: 52,

                      child:
                      ElevatedButton(
                        onPressed:
                        _loading
                            ? null
                            : _verifyOtp,

                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          ArrozTheme
                              .primary,

                          disabledBackgroundColor:
                          ArrozTheme
                              .primary
                              .withOpacity(
                            0.55,
                          ),

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              16,
                            ),
                          ),

                          elevation: 0,
                        ),

                        child: _loading
                            ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                          CircularProgressIndicator(
                            color: Colors
                                .white,
                            strokeWidth:
                            2,
                          ),
                        )
                            : const Text(
                          'VERIFY EMAIL',
                          style:
                          TextStyle(
                            color: Colors
                                .white,
                            fontSize:
                            15,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // ==================================================
                    // TIMER / RESEND
                    // ==================================================

                    if (_secondsRemaining > 0)
                      Text(
                        'Muling magpadala ng OTP sa $_secondsRemaining segundo',
                        textAlign:
                        TextAlign.center,

                        style:
                        const TextStyle(
                          color:
                          ArrozTheme
                              .textMuted,
                          fontSize: 13,
                        ),
                      )
                    else
                      TextButton(
                        onPressed:
                        _resending ||
                            _loading
                            ? null
                            : _resendOtp,

                        child: _resending
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2,
                            color:
                            ArrozTheme
                                .primary,
                          ),
                        )
                            : const Text(
                          'RESEND OTP',
                          style:
                          TextStyle(
                            color:
                            ArrozTheme
                                .primary,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ==================================================
                    // SECURITY MESSAGE
                    // ==================================================

                    Container(
                      width:
                      double.infinity,

                      padding:
                      const EdgeInsets
                          .all(16),

                      decoration:
                      BoxDecoration(
                        color: ArrozTheme
                            .accent
                            .withOpacity(
                          0.5,
                        ),

                        borderRadius:
                        BorderRadius
                            .circular(
                          14,
                        ),
                      ),

                      child: const Row(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                        children: [
                          Icon(
                            Icons
                                .security_rounded,
                            color:
                            ArrozTheme
                                .primary,
                            size: 20,
                          ),

                          SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child: Text(
                              'Huwag ibahagi ang iyong OTP sa ibang tao. Gamitin lamang ang code na ipinadala sa iyong email.',
                              style:
                              TextStyle(
                                color:
                                ArrozTheme
                                    .textMain,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 20,
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

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();

    super.dispose();
  }
}