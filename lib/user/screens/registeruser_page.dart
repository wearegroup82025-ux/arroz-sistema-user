import 'package:flutter/material.dart';

import '../../services/auth/auth.service.dart';
import 'verify_otp_page.dart';

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

class RegisterUserPage extends StatefulWidget {
  final String initialLanguage;

  const RegisterUserPage({
    super.key,
    this.initialLanguage = 'Tagalog',
  });

  @override
  State<RegisterUserPage> createState() =>
      _RegisterUserPageState();
}

class _RegisterUserPageState
    extends State<RegisterUserPage> {
  final _formKey = GlobalKey<FormState>();

  late String _currentLanguage;

  final _lastNameController =
  TextEditingController();

  final _firstNameController =
  TextEditingController();

  final _middleInitialController =
  TextEditingController();

  final _emailController =
  TextEditingController();

  final _passwordController =
  TextEditingController();

  final _confirmPasswordController =
  TextEditingController();

  bool _loading = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _acceptedTerms = false;

  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  final Map<String, Map<String, String>>
  _localizedText = {
    'English': {
      'title': 'Create Account',
      'subtitle':
      'Enter your information to create your Arroz account.',
      'lastName': 'Last Name',
      'lastNameHint': 'Enter your last name',
      'firstName': 'First Name',
      'firstNameHint': 'Enter your first name',
      'middleInitial': 'Middle Initial (Optional)',
      'middleInitialHint': 'Example: A.',
      'email': 'Email Address',
      'emailHint': 'Example: juan@gmail.com',
      'password': 'Password',
      'confirmPassword': 'Repeat Password',
      'rule1': 'At least 8 characters',
      'rule2': 'At least one number (0-9)',
      'rule3': 'At least one symbol (e.g., @, #, \$)',
      'btnRegister': 'CREATE ACCOUNT',
      'termsText': 'I agree to the ',
      'termsLink': 'Terms & Privacy Policy',
      'termsModalTitle':
      'Terms of Service & Privacy Policy',
      'termsModalBody': '''
WELCOME TO ARROZ AGRICULTURAL MANAGEMENT SYSTEM

1. DATA COLLECTION & PRIVACY

By registering, you consent to the collection and processing of your information in compliance with applicable Data Privacy laws. Your information is used for account verification and system updates.

2. ACCOUNT SECURITY & RESPONSIBILITY

You are responsible for maintaining the confidentiality of your credentials. Any activity performed under your registered account shall be deemed your responsibility.

3. ACCEPTABLE USE

You agree not to submit false identification details, disrupt platform security, or attempt unauthorized access to Arroz system resources.
''',
      'termsAgreeBtn': 'I AGREE & CONTINUE',
      'termsDeclineBtn': 'CANCEL',
      'valLastName': 'Enter your last name',
      'valFirstName': 'Enter your first name',
      'valMiddleInitial':
      'Enter a valid middle initial',
      'valEmail': 'Enter a valid email address',
      'valPassword': 'Do not leave password blank',
      'valConfirm': 'Passwords do not match',
      'valTerms':
      'You must accept the Terms & Privacy Policy to proceed.',
      'pwdAlert':
      'Please follow all password security requirements.',
      'successEmail':
      'Verification code sent to your email.',
      'errorConn':
      'Unable to send OTP. Please check your email address.',
    },
    'Tagalog': {
      'title': 'Gumawa ng Account',
      'subtitle':
      'Ilagay ang iyong impormasyon upang gumawa ng Arroz account.',
      'lastName': 'Apelyido',
      'lastNameHint': 'Ilagay ang iyong apelyido',
      'firstName': 'Pangalan',
      'firstNameHint': 'Ilagay ang iyong pangalan',
      'middleInitial': 'Middle Initial (Opsyonal)',
      'middleInitialHint': 'Halimbawa: A.',
      'email': 'Email Address',
      'emailHint': 'Halimbawa: juan@gmail.com',
      'password': 'Password',
      'confirmPassword': 'Ulitin ang Password',
      'rule1': 'Hindi bababa sa 8 characters',
      'rule2': 'May kahit isang numero (0-9)',
      'rule3': 'May special symbol (hal. @, #, \$)',
      'btnRegister': 'MAG-REGISTER NGAYON',
      'termsText': 'Sumasang-ayon ako sa ',
      'termsLink': 'Terms & Privacy Policy',
      'termsModalTitle':
      'Mga Tuntunin at Privacy Policy',
      'termsModalBody': '''
MALIGAYANG DATANG SA ARROZ AGRICULTURAL MANAGEMENT SYSTEM

1. PANGONGOLEKTA NG DATOS AT PRIVACY

Sa pagrehistro, nagbibigay ka ng pahintulot sa pagproseso ng iyong impormasyon ayon sa umiiral na Data Privacy laws. Ang iyong impormasyon ay gagamitin para sa account verification at mga mahalagang abiso.

2. SEGURIDAD NG ACCOUNT

Tungkulin mong ingatan ang pagiging kumpidensyal ng iyong password at credentials. Ang anumang aktibidad sa iyong account ay ituturing na iyong responsibilidad.

3. MGA HINDI PINAHIHINTULUTAN

Bawal ang paglalagay ng pekeng impormasyon, pagsubok na sirain ang seguridad ng system, o paggamit ng Arroz sa anumang ilegal na paraan.
''',
      'termsAgreeBtn': 'SUMASANG-AYON AKO',
      'termsDeclineBtn': 'KANSELAHIN',
      'valLastName': 'Ilagay ang iyong apelyido',
      'valFirstName': 'Ilagay ang iyong pangalan',
      'valMiddleInitial':
      'Maglagay ng tamang middle initial',
      'valEmail': 'Gumamit ng tamang email format',
      'valPassword':
      'Huwag iwanang blangko ang password',
      'valConfirm':
      'Hindi magkatugma ang password',
      'valTerms':
      'Kailangan mong sumang-ayon sa Terms & Privacy Policy.',
      'pwdAlert':
      'Mangyaring sundin ang password rules para sa iyong seguridad.',
      'successEmail':
      'Napadala na ang verification code sa iyong email.',
      'errorConn':
      'Hindi maipadala ang OTP. Pakisuri ang email address.',
    },
  };

  @override
  void initState() {
    super.initState();

    _currentLanguage =
        widget.initialLanguage;

    _passwordController.addListener(
      _checkPasswordRules,
    );
  }

  void _checkPasswordRules() {
    final pass =
        _passwordController.text;

    if (!mounted) return;

    setState(() {
      _hasMinLength =
          pass.length >= 8;

      _hasNumber =
          pass.contains(
            RegExp(r'[0-9]'),
          );

      _hasSpecialChar =
          pass.contains(
            RegExp(
              r'[!@#$%^&*(),.?":{}|<>]',
            ),
          );
    });
  }

  String _cleanInput(String input) {
    return input
        .replaceAll(
      RegExp(r"[<>'{}\[\]\\;]"),
      "",
    )
        .trim();
  }

  String _normalizeMiddleInitial(
      String input) {
    String value =
    _cleanInput(input);

    if (value.isEmpty) {
      return '';
    }

    if (value.endsWith('.')) {
      value =
          value.substring(
            0,
            value.length - 1,
          );
    }

    if (value.isEmpty) {
      return '';
    }

    return '${value[0].toUpperCase()}.';
  }

  void _showTermsDialog() {
    final txt =
    _localizedText[_currentLanguage]!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (context) =>
          Container(
            height:
            MediaQuery.of(context)
                .size
                .height *
                0.80,
            padding:
            const EdgeInsets.all(24),
            decoration:
            const BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration:
                    BoxDecoration(
                      color:
                      Colors.grey.shade300,
                      borderRadius:
                      BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  txt['termsModalTitle']!,
                  style:
                  const TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.bold,
                    color:
                    ArrozTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                Expanded(
                  child:
                  SingleChildScrollView(
                    physics:
                    const BouncingScrollPhysics(),
                    child: Text(
                      txt['termsModalBody']!,
                      style:
                      const TextStyle(
                        fontSize: 13,
                        color:
                        ArrozTheme.textMain,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () =>
                            Navigator.pop(
                              context,
                            ),
                        child: Text(
                          txt['termsDeclineBtn']!,
                          style:
                          const TextStyle(
                            color:
                            ArrozTheme
                                .textMuted,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child:
                      ElevatedButton(
                        style:
                        ElevatedButton.styleFrom(
                          backgroundColor:
                          ArrozTheme
                              .primary,
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              14,
                            ),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() {
                            _acceptedTerms =
                            true;
                          });

                          Navigator.pop(
                            context,
                          );
                        },
                        child: Text(
                          txt['termsAgreeBtn']!,
                          style:
                          const TextStyle(
                            color: Colors.white,
                            fontWeight:
                            FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  // ============================================================
  // REGISTRATION
  // ============================================================

  Future<void> _handleRegistration() async {
    final txt =
    _localizedText[_currentLanguage]!;

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (!_acceptedTerms) {
      _showNotification(
        txt['valTerms']!,
        Colors.orange.shade800,
      );
      return;
    }

    if (!_hasMinLength ||
        !_hasNumber ||
        !_hasSpecialChar) {
      _showNotification(
        txt['pwdAlert']!,
        Colors.orange.shade800,
      );
      return;
    }

    if (_loading) return;

    setState(() {
      _loading = true;
    });

    final lastName =
    _cleanInput(
      _lastNameController.text,
    );

    final firstName =
    _cleanInput(
      _firstNameController.text,
    );

    final middleInitial =
    _normalizeMiddleInitial(
      _middleInitialController.text,
    );

    final email =
    _cleanInput(
      _emailController.text,
    ).toLowerCase();

    final password =
        _passwordController.text;

    final fullName =
    '$firstName $middleInitial $lastName'
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .trim();

    try {
      debugPrint(
        'Starting EMAIL registration...',
      );

      debugPrint(
        'Last Name: $lastName',
      );

      debugPrint(
        'First Name: $firstName',
      );

      debugPrint(
        'Middle Initial: $middleInitial',
      );

      debugPrint(
        'Email: $email',
      );

      await AuthService.instance
          .generateAndSaveEmailOTP(
        email: email,
        name: fullName,
        reason: 'Registration',
      )
          .timeout(
        const Duration(seconds: 20),
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showNotification(
        txt['successEmail']!,
        Colors.green.shade700,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              VerifyOtpPage(
                email: email,
                lastName: lastName,
                firstName: firstName,
                middleInitial:
                middleInitial,
                passwordForEmail:
                password,
              ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Registration Error: $e',
      );

      if (!mounted) return;

      String errorMsg =
      e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      if (errorMsg.trim().isEmpty) {
        errorMsg =
        txt['errorConn']!;
      }

      setState(() {
        _loading = false;
      });

      _showNotification(
        errorMsg,
        ArrozTheme.error,
      );
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
          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
            color: Colors.white,
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

  @override
  void dispose() {
    _passwordController
        .removeListener(
      _checkPasswordRules,
    );

    _lastNameController.dispose();
    _firstNameController.dispose();
    _middleInitialController
        .dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController
        .dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txt =
    _localizedText[_currentLanguage]!;

    return Scaffold(
      backgroundColor:
      ArrozTheme.bg,
      appBar: AppBar(
        backgroundColor:
        Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons
                .arrow_back_ios_new_rounded,
            color:
            ArrozTheme.textMain,
            size: 20,
          ),
          onPressed: _loading
              ? null
              : () =>
              Navigator.pop(
                context,
              ),
        ),
        actions: [
          Container(
            margin:
            const EdgeInsets.only(
              right: 16,
              top: 8,
              bottom: 8,
            ),
            padding:
            const EdgeInsets
                .symmetric(
              horizontal: 10,
            ),
            decoration:
            BoxDecoration(
              color:
              ArrozTheme.cardBg,
              borderRadius:
              BorderRadius.circular(
                12,
              ),
              border: Border.all(
                color:
                Colors.grey.shade200,
              ),
            ),
            child:
            DropdownButtonHideUnderline(
              child:
              DropdownButton<String>(
                value:
                _currentLanguage,
                style:
                const TextStyle(
                  color:
                  ArrozTheme.textMain,
                  fontWeight:
                  FontWeight.bold,
                  fontSize: 12,
                ),
                onChanged: (v) {
                  if (v == null)
                    return;

                  setState(() {
                    _currentLanguage =
                        v;
                  });
                },
                items: [
                  'Tagalog',
                  'English',
                ]
                    .map(
                      (e) =>
                      DropdownMenuItem(
                        value: e,
                        child:
                        Text(e),
                      ),
                )
                    .toList(),
              ),
            ),
          ),
        ],
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
                vertical: 12,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      txt['title']!,
                      style:
                      const TextStyle(
                        fontSize: 26,
                        fontWeight:
                        FontWeight.bold,
                        color:
                        ArrozTheme
                            .primary,
                      ),
                    ),
                    const SizedBox(
                        height: 4),
                    Text(
                      txt['subtitle']!,
                      style:
                      const TextStyle(
                        fontSize: 13,
                        color:
                        ArrozTheme
                            .textMuted,
                      ),
                    ),
                    const SizedBox(
                        height: 24),

                    // LAST NAME
                    _buildInputField(
                      controller:
                      _lastNameController,
                      label:
                      txt['lastName']!,
                      icon: Icons
                          .badge_outlined,
                      placeholder:
                      txt['lastNameHint']!,
                      keyboardType:
                      TextInputType
                          .name,
                      validator: (v) {
                        if (v == null ||
                            v.trim()
                                .isEmpty) {
                          return txt[
                          'valLastName'];
                        }

                        if (v.trim()
                            .length <
                            2) {
                          return txt[
                          'valLastName'];
                        }

                        return null;
                      },
                    ),

                    // FIRST NAME
                    _buildInputField(
                      controller:
                      _firstNameController,
                      label:
                      txt['firstName']!,
                      icon: Icons
                          .person_outline_rounded,
                      placeholder:
                      txt['firstNameHint']!,
                      keyboardType:
                      TextInputType
                          .name,
                      validator: (v) {
                        if (v == null ||
                            v.trim()
                                .isEmpty) {
                          return txt[
                          'valFirstName'];
                        }

                        if (v.trim()
                            .length <
                            2) {
                          return txt[
                          'valFirstName'];
                        }

                        return null;
                      },
                    ),

                    // MIDDLE INITIAL (OPSYONAL)
                    _buildInputField(
                      controller:
                      _middleInitialController,
                      label: txt[
                      'middleInitial']!,
                      icon: Icons
                          .person_outline_rounded,
                      placeholder: txt[
                      'middleInitialHint']!,
                      keyboardType:
                      TextInputType
                          .text,
                      maxLength: 2,
                      validator: (v) {
                        if (v == null ||
                            v.trim()
                                .isEmpty) {
                          return null;
                        }

                        final value =
                        v.trim();

                        if (!RegExp(
                          r'^[A-Za-z]\.?$',
                        ).hasMatch(
                            value)) {
                          return txt[
                          'valMiddleInitial'];
                        }

                        return null;
                      },
                    ),

                    // EMAIL
                    _buildInputField(
                      controller:
                      _emailController,
                      label:
                      txt['email']!,
                      icon: Icons
                          .mail_outline_rounded,
                      placeholder:
                      txt['emailHint']!,
                      keyboardType:
                      TextInputType
                          .emailAddress,
                      validator: (v) {
                        if (v == null ||
                            v.trim()
                                .isEmpty) {
                          return txt[
                          'valEmail'];
                        }

                        final emailRegExp =
                        RegExp(
                          r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$',
                        );

                        if (!emailRegExp
                            .hasMatch(
                          v.trim(),
                        )) {
                          return txt[
                          'valEmail'];
                        }

                        return null;
                      },
                    ),

                    // PASSWORD
                    _buildInputField(
                      controller:
                      _passwordController,
                      label:
                      txt['password']!,
                      icon: Icons
                          .lock_open_rounded,
                      obscure:
                      _obscurePassword,
                      toggle: () {
                        setState(() {
                          _obscurePassword =
                          !_obscurePassword;
                        });
                      },
                      validator: (v) {
                        if (v == null ||
                            v.isEmpty) {
                          return txt[
                          'valPassword'];
                        }

                        return null;
                      },
                    ),

                    Padding(
                      padding:
                      const EdgeInsets
                          .only(
                        bottom: 16,
                        left: 4,
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          _buildSecurityIndicator(
                            txt['rule1']!,
                            _hasMinLength,
                          ),
                          _buildSecurityIndicator(
                            txt['rule2']!,
                            _hasNumber,
                          ),
                          _buildSecurityIndicator(
                            txt['rule3']!,
                            _hasSpecialChar,
                          ),
                        ],
                      ),
                    ),

                    // CONFIRM PASSWORD
                    _buildInputField(
                      controller:
                      _confirmPasswordController,
                      label:
                      txt[
                      'confirmPassword']!,
                      icon: Icons
                          .lock_outline_rounded,
                      obscure:
                      _obscureConfirmPassword,
                      toggle: () {
                        setState(() {
                          _obscureConfirmPassword =
                          !_obscureConfirmPassword;
                        });
                      },
                      validator: (v) {
                        if (v !=
                            _passwordController
                                .text) {
                          return txt[
                          'valConfirm'];
                        }

                        return null;
                      },
                    ),

                    const SizedBox(
                        height: 4),

                    // TERMS
                    Row(
                      children: [
                        Checkbox(
                          value:
                          _acceptedTerms,
                          activeColor:
                          ArrozTheme
                              .primary,
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              4,
                            ),
                          ),
                          onChanged: (v) {
                            setState(() {
                              _acceptedTerms =
                                  v ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child:
                          GestureDetector(
                            onTap:
                            _showTermsDialog,
                            child:
                            RichText(
                              text:
                              TextSpan(
                                text: txt[
                                'termsText'],
                                style:
                                const TextStyle(
                                  color:
                                  ArrozTheme
                                      .textMuted,
                                  fontSize:
                                  12,
                                ),
                                children: [
                                  TextSpan(
                                    text: txt[
                                    'termsLink'],
                                    style:
                                    const TextStyle(
                                      color:
                                      ArrozTheme
                                          .primary,
                                      fontWeight:
                                      FontWeight
                                          .bold,
                                      decoration:
                                      TextDecoration
                                          .underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                        height: 16),

                    // REGISTER BUTTON
                    SizedBox(
                      width:
                      double.infinity,
                      height: 52,
                      child:
                      ElevatedButton(
                        onPressed:
                        _loading
                            ? null
                            : _handleRegistration,
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
                            0.6,
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
                            : Text(
                          txt[
                          'btnRegister']!,
                          style:
                          const TextStyle(
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
                        height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityIndicator(
      String message,
      bool isValid,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 2,
      ),
      child: Row(
        children: [
          Icon(
            isValid
                ? Icons
                .check_circle_rounded
                : Icons
                .radio_button_unchecked_rounded,
            color: isValid
                ? ArrozTheme.primary
                : Colors.grey,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: isValid
                    ? ArrozTheme
                    .textMain
                    : ArrozTheme
                    .textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController
    controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggle,
    int? maxLength,
    String? placeholder,
    TextInputType keyboardType =
        TextInputType.text,
    String? Function(String?)?
    validator,
  }) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 14,
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        maxLength: maxLength,
        validator: validator,
        textCapitalization:
        TextCapitalization.words,
        style: const TextStyle(
          color:
          ArrozTheme.textMain,
          fontWeight:
          FontWeight.w500,
          fontSize: 14,
        ),
        decoration:
        InputDecoration(
          labelText: label,
          hintText: placeholder,
          counterText: '',
          labelStyle:
          const TextStyle(
            color:
            ArrozTheme.textMuted,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            icon,
            color:
            ArrozTheme.primary,
            size: 20,
          ),
          suffixIcon:
          toggle != null
              ? IconButton(
            icon: Icon(
              obscure
                  ? Icons
                  .visibility_outlined
                  : Icons
                  .visibility_off_outlined,
              color:
              ArrozTheme
                  .textMuted,
              size: 20,
            ),
            onPressed:
            toggle,
          )
              : null,
          filled: true,
          fillColor:
          ArrozTheme.cardBg,
          contentPadding:
          const EdgeInsets
              .symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          focusedBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius
                .circular(16),
            borderSide:
            const BorderSide(
              color:
              ArrozTheme.primary,
              width: 1.5,
            ),
          ),
          enabledBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius
                .circular(16),
            borderSide: BorderSide(
              color:
              Colors.grey.shade300,
            ),
          ),
          errorBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius
                .circular(16),
            borderSide:
            const BorderSide(
              color:
              ArrozTheme.error,
            ),
          ),
          focusedErrorBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius
                .circular(16),
            borderSide:
            const BorderSide(
              color:
              ArrozTheme.error,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}