import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth/auth.service.dart';

class ForgotPasswordSheet extends StatefulWidget {
  final String currentLanguage;
  final Map<String, Map<String, String>> txt;
  final Function({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String buttonText,
    VoidCallback? onPressed,
  }) showCustomWarningDialog;
  final Function(String message, Color color) showSnackBar;

  const ForgotPasswordSheet({
    super.key,
    required this.currentLanguage,
    required this.txt,
    required this.showCustomWarningDialog,
    required this.showSnackBar,
  });

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final _emailController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localized = widget.txt[widget.currentLanguage]!;
    final isTagalog = widget.currentLanguage == 'Tagalog';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: ArrozTheme.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                localized['forgotTitle'] ?? 'Nakalimutan ang Password?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ArrozTheme.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                localized['forgotSub'] ?? 'I-type ang iyong email upang makatanggap ng password reset link.',
                style: const TextStyle(color: ArrozTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // 💡 PAALALA / HINT BOX PARA SA SPAM FOLDER
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mark_email_unread_outlined, color: Colors.amber.shade900, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isTagalog
                            ? 'Paalala: Kung hindi makita ang email sa Inbox, paki-check din ang iyong Spam o Junk folder.'
                            : 'Note: If you don\'t see the email in your Inbox, please check your Spam or Junk folder.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: localized['searchHintEmail'] ?? 'Ilagay ang iyong email',
                  prefixIcon: const Icon(Icons.email_outlined, color: ArrozTheme.primary),
                  filled: true,
                  fillColor: ArrozTheme.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ArrozTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          final rawEmail = _emailController.text.trim();
                          if (rawEmail.isEmpty) {
                            widget.showCustomWarningDialog(
                              context: context,
                              title: isTagalog ? 'May Kulang' : 'Missing Information',
                              description: localized['emptySearchWarn'] ?? 'Pakilagay ang iyong email address.',
                              icon: Icons.error_outline_rounded,
                              color: ArrozTheme.warning,
                              buttonText: localized['btnUnderstand'] ?? 'Naintindihan',
                            );
                            return;
                          }

                          setState(() => _isProcessing = true);

                          try {
                            // 1. Suriin muna kung umiiral sa Firestore Database
                            final result = await FirebaseFirestore.instance
                                .collection('users')
                                .where('email', isEqualTo: rawEmail.toLowerCase())
                                .limit(1)
                                .get();

                            if (result.docs.isEmpty) {
                              if (context.mounted) {
                                widget.showCustomWarningDialog(
                                  context: context,
                                  title: localized['accNotFoundTitle'] ?? 'Account Not Found',
                                  description: localized['accNotFoundSub'] ?? 'Walang account na nakakonekta sa email na ito.',
                                  icon: Icons.person_off_rounded,
                                  color: ArrozTheme.error,
                                  buttonText: localized['btnTryAgain'] ?? 'Subukan Ulit',
                                );
                              }
                              return;
                            }

                            // 2. Ipadala ang Libreng Password Reset Link ng Firebase
                            await AuthService.instance.sendPasswordResetEmail(rawEmail);

                            if (context.mounted) {
                              Navigator.pop(context); // Isara ang bottom sheet
                              
                              // Ipakita ang Custom Dialog na may kasamang malinaw na paalala sa Spam/Junk folder
                              widget.showCustomWarningDialog(
                                context: context,
                                title: isTagalog ? 'Naipadala na!' : 'Email Sent!',
                                description: isTagalog
                                    ? 'Naipadala na ang reset link sa $rawEmail. Pakisuri ang iyong Inbox pati na rin ang Spam o Junk folder kung sakaling wala sa inbox.'
                                    : 'A reset link has been sent to $rawEmail. Please check your Inbox as well as your Spam or Junk folder.',
                                icon: Icons.mark_email_read_rounded,
                                color: ArrozTheme.primary,
                                buttonText: localized['btnUnderstand'] ?? 'Naintindihan',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              widget.showSnackBar(
                                e.toString().replaceFirst('Exception: ', ''),
                                ArrozTheme.error,
                              );
                            }
                          } finally {
                            if (context.mounted) setState(() => _isProcessing = false);
                          }
                        },
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          localized['forgotSearch'] ?? 'Ipadala ang Reset Link',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArrozTheme {
  static const Color primary = Color(0xFF0F5132);
  static const Color bg = Color(0xFFF4F6F8);
  static const Color cardBg = Colors.white;
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
}