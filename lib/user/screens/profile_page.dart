import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'address_picker.dart';
import 'login_page.dart';

// ============================================================================
// 🎨 ENTERPRISE DESIGN SYSTEM & THEME
// ============================================================================
class ArrozTheme {
  static const Color bgGrey = Color(0xFFF8FAFC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color emerald = Color(0xFF0F5132);
  static const Color emeraldLight = Color(0xFF198754);
  static const Color mintAccent = Color(0xFFE8F5E9);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textSub = Color(0xFF64748B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color warningOrange = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color borderLight = Color(0xFFE2E8F0);
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;
  bool _hasTriggeredNameWarning = false;

  Future<void> _sendNameWarningNotification() async {
    if (_currentUser == null) return;
    try {
      final userNotifsRef = FirebaseFirestore.instance
          .collection("users")
          .doc(_currentUser!.uid)
          .collection("notifications");

      final existingWarning = await userNotifsRef
          .where('type', isEqualTo: 'PROFILE_NAME_WARNING')
          .where('isRead', isEqualTo: false)
          .get();

      if (existingWarning.docs.isEmpty) {
        await userNotifsRef.add({
          'title': '⚠️ Kailangan ng Pangalan',
          'body': 'Kailangan mong maglagay ng iyong pangalan sa Profile para sa mas mabilis na pag-process ng iyong mga order.',
          'type': 'PROFILE_NAME_WARNING',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error sending notification warning: $e");
    }
  }

  void _showEditNameDialog(String currentFName, String currentMI, String currentLName) {
    final fNameController = TextEditingController(text: currentFName);
    final miController = TextEditingController(text: currentMI);
    final lNameController = TextEditingController(text: currentLName);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenWidth = MediaQuery.of(context).size.width;
          return Dialog(
            backgroundColor: ArrozTheme.cardWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: BoxConstraints(maxWidth: screenWidth > 600 ? 480 : screenWidth * 0.9),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: ArrozTheme.mintAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_note_rounded, color: ArrozTheme.emerald, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "I-set ang Pangalan",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ArrozTheme.textDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Pakilagay ang iyong buong pangalan para makilala ka ng aming riders at shop sellers.",
                          style: TextStyle(fontSize: 12, color: ArrozTheme.textSub, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: fNameController,
                          decoration: InputDecoration(
                            labelText: "First Name",
                            prefixIcon: const Icon(Icons.person_outline, color: ArrozTheme.emerald),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: ArrozTheme.emerald, width: 2),
                            ),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? "Kailangan ang First Name" : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: miController,
                                maxLength: 2,
                                decoration: InputDecoration(
                                  labelText: "M.I.",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: ArrozTheme.emerald, width: 2),
                                  ),
                                  counterText: "",
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                controller: lNameController,
                                decoration: InputDecoration(
                                  labelText: "Last Name",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: ArrozTheme.emerald, width: 2),
                                  ),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? "Kailangan ang Last Name" : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        child: const Text("Kanselahin", style: TextStyle(color: ArrozTheme.textSub, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ArrozTheme.emerald,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSaving = true);
                            try {
                              final String newFName = fNameController.text.trim();
                              final String newMI = miController.text.trim();
                              final String newLName = lNameController.text.trim();
                              final String full = "$newFName ${newMI.isNotEmpty ? '$newMI. ' : ''}$newLName".trim();

                              await FirebaseFirestore.instance.collection("users").doc(_currentUser!.uid).update({
                                'firstName': newFName,
                                'middleInitial': newMI,
                                'lastName': newLName,
                                'name': full,
                              });

                              await _currentUser!.updateDisplayName(full);

                              if (!context.mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Matagumpay na na-update ang pangalan!"), backgroundColor: ArrozTheme.emerald),
                              );
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Pumalya sa pag-save: $e"), backgroundColor: ArrozTheme.dangerRed),
                              );
                            }
                          }
                        },
                        child: isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("I-save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditPhoneDialog(String currentPhone) {
    final phoneController = TextEditingController(text: currentPhone == 'Walang Phone Number' ? '' : currentPhone);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenWidth = MediaQuery.of(context).size.width;
          return Dialog(
            backgroundColor: ArrozTheme.cardWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: BoxConstraints(maxWidth: screenWidth > 600 ? 450 : screenWidth * 0.9),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: ArrozTheme.mintAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_android_rounded, color: ArrozTheme.emerald, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text("Phone Number", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ArrozTheme.textDark)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Pakilagay ang iyong updated na mobile number para makontak ka ng aming riders.",
                          style: TextStyle(fontSize: 12, color: ArrozTheme.textSub, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "Mobile / Phone Number",
                            hintText: "e.g. 09123456789",
                            prefixIcon: const Icon(Icons.phone_outlined, color: ArrozTheme.emerald),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: ArrozTheme.emerald, width: 2),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return "Kailangan ang Phone Number";
                            if (v.trim().length < 11) return "Ilagay ang tamang mobile number";
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSaving ? null : () => Navigator.pop(context),
                        child: const Text("Kanselahin", style: TextStyle(color: ArrozTheme.textSub, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ArrozTheme.emerald,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSaving = true);
                            try {
                              final String newPhone = phoneController.text.trim();

                              await FirebaseFirestore.instance.collection("users").doc(_currentUser!.uid).update({
                                'phone': newPhone,
                              });

                              if (!context.mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Matagumpay na na-update ang phone number!"), backgroundColor: ArrozTheme.emerald),
                              );
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Pumalya sa pag-save: $e"), backgroundColor: ArrozTheme.dangerRed),
                              );
                            }
                          }
                        },
                        child: isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("I-save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(
        backgroundColor: ArrozTheme.bgGrey,
        body: Center(child: Text("Walang naka-login na user.")),
      );
    }

    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("users").doc(_currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: ArrozTheme.emerald));
          }

          Map<String, dynamic> userData = {};
          if (snapshot.hasData && snapshot.data!.data() != null) {
            userData = snapshot.data!.data() as Map<String, dynamic>;
          }

          final String firstName = userData['firstName'] ?? '';
          final String middleInitial = userData['middleInitial'] ?? '';
          final String lastName = userData['lastName'] ?? '';

          String formattedFullName = "$firstName ${middleInitial.isNotEmpty ? '$middleInitial ' : ''}$lastName".trim();
          bool isNameMissing = false;

          if (formattedFullName.isEmpty) {
            final String rawName = userData['name'] ?? _currentUser!.displayName ?? '';
            if (rawName.isEmpty || rawName == 'Arroz User') {
              formattedFullName = 'Walang Pangalan';
              isNameMissing = true;
            } else {
              formattedFullName = rawName;
            }
          }

          if (isNameMissing && !_hasTriggeredNameWarning) {
            _hasTriggeredNameWarning = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _sendNameWarningNotification();
            });
          }

          final String userEmail = userData['email'] ?? _currentUser!.email ?? 'Walang Email';
          final String userPhone = userData['phone'] ?? 'Walang Phone Number';
          final String? photoUrl = userData['photoUrl'] ?? _currentUser!.photoURL;

          return LayoutBuilder(
            builder: (context, constraints) {
              final double screenWidth = constraints.maxWidth;
              final bool isTabletOrDesktop = screenWidth >= 600;

              return Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 850),
                  width: double.infinity,
                  color: ArrozTheme.bgGrey,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // 1. TOP PROFILE HEADER & AVATAR
                      SliverToBoxAdapter(
                        child: Container(
                          width: double.infinity,
                          color: ArrozTheme.cardWhite,
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    height: isTabletOrDesktop ? 180 : 130,
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [ArrozTheme.emerald, ArrozTheme.emeraldLight],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -48,
                                    child: Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 4),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.08),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: isTabletOrDesktop ? 56 : 48,
                                            backgroundColor: ArrozTheme.mintAccent,
                                            backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                                            child: _isUploadingImage
                                                ? const CircularProgressIndicator(color: ArrozTheme.emerald)
                                                : (photoUrl == null || photoUrl.isEmpty)
                                                ? Text(
                                              formattedFullName.isNotEmpty ? formattedFullName[0].toUpperCase() : "A",
                                              style: TextStyle(
                                                fontSize: isTabletOrDesktop ? 40 : 34,
                                                fontWeight: FontWeight.bold,
                                                color: ArrozTheme.emerald,
                                              ),
                                            )
                                                : null,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _showImageSourcePicker(context),
                                          child: Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.12),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: ArrozTheme.emerald),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 56),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      formattedFullName,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: isTabletOrDesktop ? 22 : 19,
                                        fontWeight: FontWeight.bold,
                                        color: isNameMissing ? ArrozTheme.dangerRed : ArrozTheme.textDark,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: ArrozTheme.emerald),
                                    onPressed: () => _showEditNameDialog(firstName, middleInitial, lastName),
                                    splashRadius: 20,
                                  )
                                ],
                              ),
                              Text(
                                userEmail,
                                style: const TextStyle(fontSize: 13, color: ArrozTheme.textSub),
                              ),
                              const SizedBox(height: 16),

                              if (isNameMissing) ...[
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: ArrozTheme.warningBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: ArrozTheme.warningOrange.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded, color: ArrozTheme.warningOrange, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Kailangan ng Pangalan",
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ArrozTheme.warningOrange),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Mangyaring i-set ang iyong pangalan upang mapabilis ang pagproseso ng iyong order.",
                                              style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900, height: 1.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: ArrozTheme.warningOrange,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () => _showEditNameDialog(firstName, middleInitial, lastName),
                                        child: const Text("I-set Now", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],

                              const Divider(height: 1, color: ArrozTheme.borderLight),
                            ],
                          ),
                        ),
                      ),

                      // 2. MAIN MENU SETTINGS
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTabletOrDesktop ? 24 : 16,
                          vertical: 20,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 12),
                                child: Text("Account Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ArrozTheme.textSub)),
                              ),

                              LayoutBuilder(
                                builder: (context, gridConstraints) {
                                  final double itemWidth = isTabletOrDesktop
                                      ? (gridConstraints.maxWidth - 16) / 2
                                      : gridConstraints.maxWidth;

                                  return Wrap(
                                    spacing: 16,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: itemWidth,
                                        child: _buildMenuTile(
                                          icon: Icons.person_outline_rounded,
                                          title: "Personal Details",
                                          subtitle: isNameMissing ? "⚠️ Walang pangalan na nakalagay" : "Pangalan, email, at phone number",
                                          isWarning: isNameMissing,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => PersonalDetailsPage(
                                                  fullName: formattedFullName,
                                                  email: userEmail,
                                                  phone: userPhone,
                                                  isNameMissing: isNameMissing,
                                                  onEditNameTap: () => _showEditNameDialog(firstName, middleInitial, lastName),
                                                  onEditPhoneTap: () => _showEditPhoneDialog(userPhone),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _buildMenuTile(
                                          icon: Icons.location_on_outlined,
                                          title: "Addresses",
                                          subtitle: "I-manage ang iyong delivery addresses",
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => SecurityAndAddressPage(
                                                  email: userEmail,
                                                  fullName: formattedFullName,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _buildMenuTile(
                                          icon: Icons.tune_rounded,
                                          title: "Preferences",
                                          subtitle: "Notifications at Wika ng application",
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const PreferencesPage(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: _buildMenuTile(
                                          icon: Icons.help_outline_rounded,
                                          title: "Help & Support Guide",
                                          subtitle: "Gabay sa paggamit ng ArrozApp at FAQs",
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const HelpGuidePage(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 28),

                              // LOGOUT BUTTON
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    foregroundColor: ArrozTheme.dangerRed,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.red.shade200),
                                    ),
                                  ),
                                  icon: const Icon(Icons.logout_rounded, size: 20),
                                  label: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  onPressed: () => _showLogoutDialog(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isWarning = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isWarning ? ArrozTheme.warningBg : ArrozTheme.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWarning ? ArrozTheme.warningOrange.withOpacity(0.4) : ArrozTheme.borderLight,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: isWarning ? ArrozTheme.warningOrange.withOpacity(0.15) : ArrozTheme.mintAccent,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isWarning ? ArrozTheme.warningOrange : ArrozTheme.emerald, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ArrozTheme.textDark)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
            color: isWarning ? ArrozTheme.warningOrange : ArrozTheme.textSub,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: ArrozTheme.textSub),
        onTap: onTap,
      ),
    );
  }

  void _showImageSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: ArrozTheme.emerald),
              title: const Text('Mula sa Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: ArrozTheme.emerald),
              title: const Text('Kumuha ng Litrato', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 75, maxWidth: 600);
      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      final File imageFile = File(pickedFile.path);
      final String refPath = 'profile_pictures/${_currentUser!.uid}.jpg';

      final storageRef = FirebaseStorage.instance.ref().child(refPath);
      await storageRef.putFile(imageFile);

      final String downloadUrl = await storageRef.getDownloadURL();

      await _currentUser!.updatePhotoURL(downloadUrl);
      await FirebaseFirestore.instance.collection("users").doc(_currentUser!.uid).update({'photoUrl': downloadUrl});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Na-upload na ang Profile Picture!"), backgroundColor: ArrozTheme.emerald),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: ArrozTheme.dangerRed));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: ArrozTheme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: ArrozTheme.textDark)),
              const SizedBox(height: 12),
              const Text("Sigurado ka bang nais mong lumabas sa ArrozApp?", style: TextStyle(color: ArrozTheme.textSub)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: ArrozTheme.textSub, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArrozTheme.dangerRed,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                    child: const Text("Log Out", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 📱 1. PERSONAL DETAILS PAGE
// ============================================================================

class PersonalDetailsPage extends StatelessWidget {
  final String fullName;
  final String email;
  final String phone;
  final bool isNameMissing;
  final VoidCallback onEditNameTap;
  final VoidCallback onEditPhoneTap;

  const PersonalDetailsPage({
    super.key,
    required this.fullName,
    required this.email,
    required this.phone,
    this.isNameMissing = false,
    required this.onEditNameTap,
    required this.onEditPhoneTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: const Text("Personal Details", style: TextStyle(color: ArrozTheme.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: ArrozTheme.textDark),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          width: double.infinity,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text("Contact & Identity", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ArrozTheme.textSub)),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ArrozTheme.borderLight),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.person_outline_rounded,
                          color: isNameMissing ? ArrozTheme.warningOrange : ArrozTheme.emerald,
                        ),
                        title: const Text("Buong Pangalan", style: TextStyle(fontSize: 12, color: ArrozTheme.textSub)),
                        subtitle: Text(
                          fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isNameMissing ? ArrozTheme.warningOrange : ArrozTheme.textDark,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: onEditNameTap,
                          child: Text(
                            isNameMissing ? "I-set" : "I-edit",
                            style: TextStyle(
                              color: isNameMissing ? ArrozTheme.warningOrange : ArrozTheme.emerald,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: ArrozTheme.borderLight),
                      ListTile(
                        leading: const Icon(Icons.email_outlined, color: ArrozTheme.emerald),
                        title: const Text("Email Address", style: TextStyle(fontSize: 12, color: ArrozTheme.textSub)),
                        subtitle: Text(email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: ArrozTheme.textDark)),
                      ),
                      const Divider(height: 1, color: ArrozTheme.borderLight),
                      ListTile(
                        leading: const Icon(Icons.phone_outlined, color: ArrozTheme.emerald),
                        title: const Text("Mobile / Phone Number", style: TextStyle(fontSize: 12, color: ArrozTheme.textSub)),
                        subtitle: Text(
                          phone,
                          style: TextStyle(
                            fontWeight: phone == 'Walang Phone Number' ? FontWeight.normal : FontWeight.bold,
                            fontSize: 14,
                            color: phone == 'Walang Phone Number' ? ArrozTheme.textSub : ArrozTheme.textDark,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: onEditPhoneTap,
                          child: Text(
                            phone == 'Walang Phone Number' ? "I-set" : "I-edit",
                            style: const TextStyle(
                              color: ArrozTheme.emerald,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text("Account Management", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ArrozTheme.textSub)),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ArrozTheme.borderLight),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.delete_outline_rounded, color: ArrozTheme.dangerRed, size: 20),
                    ),
                    title: const Text("Delete Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ArrozTheme.dangerRed)),
                    subtitle: const Text("Mag-request ng pagbura ng iyong account", style: TextStyle(fontSize: 12, color: ArrozTheme.textSub)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: ArrozTheme.textSub),
                    onTap: () {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AccountDeletionPage(userId: uid, userEmail: email),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🔴 2. DELETE ACCOUNT PAGE
// ============================================================================

class AccountDeletionPage extends StatefulWidget {
  final String userId;
  final String userEmail;
  const AccountDeletionPage({super.key, required this.userId, required this.userEmail});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  bool _isProcessing = false;

  Future<void> _startDeletionFlow() async {
    setState(() => _isProcessing = true);

    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: widget.userId)
          .get();

      List<DocumentSnapshot> activeOrders = [];

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String status = (data['orderStatus'] ?? data['status'] ?? 'Pending').toString();

        if (status != "Completed" && status != "Cancelled") {
          activeOrders.add(doc);
        }
      }

      setState(() => _isProcessing = false);

      if (activeOrders.isNotEmpty) {
        if (!mounted) return;
        _showActiveOrdersBlockerDialog(activeOrders.length);
        return;
      }

      if (!mounted) return;
      _showPasswordVerificationDialog();
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: ArrozTheme.dangerRed),
      );
    }
  }

  void _showActiveOrdersBlockerDialog(int orderCount) {
    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: BoxConstraints(maxWidth: screenWidth > 600 ? 420 : screenWidth * 0.9),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gavel_rounded, color: ArrozTheme.dangerRed, size: 24),
                    SizedBox(width: 8),
                    Expanded(child: Text("Hindi Maiproseso", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Mayroon ka pang $orderCount (na) aktibo o nakabinbing order.\n\nHindi maaaring i-delete ang account habang may hindi pa nakukumpletong transaksyon.",
                  style: const TextStyle(fontSize: 13, color: ArrozTheme.textDark, height: 1.4),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArrozTheme.emerald,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Naintindihan Ko", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPasswordVerificationDialog() {
    final passwordController = TextEditingController();
    String passwordError = "";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final screenWidth = MediaQuery.of(context).size.width;
            return Dialog(
              backgroundColor: ArrozTheme.cardWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: BoxConstraints(maxWidth: screenWidth > 600 ? 450 : screenWidth * 0.9),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Kumpirmahin ang Deletion Request", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text(
                      "⏳ 30-DAY GRACE PERIOD:\n"
                      "Ang iyong account ay ilalagay sa pending deletion status sa loob ng 30 araw bago tuluyang mabura.",
                      style: TextStyle(fontSize: 12, color: ArrozTheme.textSub, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Password",
                        errorText: passwordError.isNotEmpty ? passwordError : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel", style: TextStyle(color: ArrozTheme.textSub)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ArrozTheme.dangerRed,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            FocusScope.of(context).unfocus();
                            final pass = passwordController.text.trim();
                            if (pass.isEmpty) {
                              setDialogState(() => passwordError = "Required ang password!");
                              return;
                            }

                            try {
                              final currentUser = FirebaseAuth.instance.currentUser;
                              AuthCredential cred = EmailAuthProvider.credential(email: widget.userEmail, password: pass);
                              await currentUser!.reauthenticateWithCredential(cred);

                              if (!context.mounted) return;
                              Navigator.pop(context);

                              _executeGracePeriodDeletion();
                            } catch (e) {
                              setDialogState(() => passwordError = "Maling password!");
                            }
                          },
                          child: const Text("I-confirm ang Deletion", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeGracePeriodDeletion() async {
    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      final scheduledDeletionDate = now.add(const Duration(days: 30));

      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'isPendingDeletion': true,
        'deletionRequestedAt': FieldValue.serverTimestamp(),
        'scheduledDeletionDate': Timestamp.fromDate(scheduledDeletionDate),
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Naitala na ang iyong deletion request."),
          backgroundColor: ArrozTheme.warningOrange,
          duration: Duration(seconds: 4),
        ),
      );

      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginUserPage()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Pumalya sa pag-process: $e"), backgroundColor: ArrozTheme.dangerRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: const Text("Delete Account", style: TextStyle(color: ArrozTheme.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: ArrozTheme.textDark),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: ArrozTheme.dangerRed, size: 22),
                          SizedBox(width: 8),
                          Text("Paalala bago magbura", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ArrozTheme.dangerRed)),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Kapag inihiling mo ang pagbura ng iyong account:\n\n"
                        "• Siguraduhing WALANG nakabinbing (pending) o aktibong order sa iyong account.\n"
                        "• Magkakaroon ng 30-day Grace Period bago tuluyang mabura ang account.\n"
                        "• Pagkalipas ng 30 araw, awtomatikong mabubura nang tuluyan ang iyong profile, saved address, at history.",
                        style: TextStyle(fontSize: 13, height: 1.5, color: ArrozTheme.textDark),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArrozTheme.dangerRed,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isProcessing ? null : _startDeletionFlow,
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      "I-request Ang Pag-delete ng Account",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 📱 OTHER SUPPORTING PAGES
// ============================================================================

class SecurityAndAddressPage extends StatelessWidget {
  final String email;
  final String fullName;

  const SecurityAndAddressPage({
    super.key,
    required this.email,
    required this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: const Text("Addresses", style: TextStyle(color: ArrozTheme.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: ArrozTheme.textDark),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          width: double.infinity,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ArrozTheme.borderLight),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: const BoxDecoration(
                        color: ArrozTheme.mintAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on_outlined, color: ArrozTheme.emerald, size: 22),
                    ),
                    title: const Text("Delivery Address Manager", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ArrozTheme.textDark)),
                    subtitle: const Text("Pumili, magdagdag, o mag-manage ng iyong delivery address.", style: TextStyle(fontSize: 12, color: ArrozTheme.textSub, height: 1.3)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: ArrozTheme.textSub),
                    onTap: () {
                      GlobalAddressSelectionService.showAddressPicker(
                        context: context,
                        onAddressSelected: (addr) {
                          if (!context.mounted) return;

                          final String barangay = (addr['barangay'] ?? '').toString();
                          final String municipality = (addr['municipality'] ?? '').toString();

                          String selectedAddress = barangay;
                          if (municipality.isNotEmpty) {
                            selectedAddress = "$barangay, $municipality";
                          }
                          if (selectedAddress.trim().isEmpty) {
                            selectedAddress = "Delivery address";
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Napiling address: $selectedAddress"),
                              backgroundColor: ArrozTheme.emerald,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  void _showLanguageDialog(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          backgroundColor: ArrozTheme.cardWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: BoxConstraints(maxWidth: screenWidth > 600 ? 400 : screenWidth * 0.9),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Pumili ng Wika / Select Language", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: ArrozTheme.textDark)),
                const SizedBox(height: 16),
                RadioListTile<AppLanguage>(
                  activeColor: ArrozTheme.emerald,
                  title: const Text("English", style: TextStyle(fontWeight: FontWeight.w600, color: ArrozTheme.textDark)),
                  value: AppLanguage.english,
                  groupValue: languageProvider.language,
                  onChanged: (value) {
                    if (value == null) return;
                    languageProvider.setLanguage(value);
                    Navigator.pop(dialogContext);
                  },
                ),
                RadioListTile<AppLanguage>(
                  activeColor: ArrozTheme.emerald,
                  title: const Text("Tagalog", style: TextStyle(fontWeight: FontWeight.w600, color: ArrozTheme.textDark)),
                  value: AppLanguage.tagalog,
                  groupValue: languageProvider.language,
                  onChanged: (value) {
                    if (value == null) return;
                    languageProvider.setLanguage(value);
                    Navigator.pop(dialogContext);
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      languageProvider.isEnglish ? "Cancel" : "Kanselahin",
                      style: const TextStyle(color: ArrozTheme.textSub, fontWeight: FontWeight.w600),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final bool isEnglish = languageProvider.isEnglish;

        return Scaffold(
          backgroundColor: ArrozTheme.bgGrey,
          appBar: AppBar(
            title: const Text("Preferences", style: TextStyle(color: ArrozTheme.textDark, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            elevation: 0.5,
            iconTheme: const IconThemeData(color: ArrozTheme.textDark),
            centerTitle: true,
          ),
          body: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ArrozTheme.borderLight),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      activeColor: ArrozTheme.emerald,
                      title: const Text("Push Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        isEnglish ? "Receive updates about your order status" : "Makatanggap ng update tungkol sa order status",
                        style: const TextStyle(fontSize: 12, color: ArrozTheme.textSub),
                      ),
                      value: true,
                      onChanged: (value) {},
                    ),
                    const Divider(height: 1, color: ArrozTheme.borderLight),
                    ListTile(
                      leading: const Icon(Icons.language_rounded, color: ArrozTheme.emerald),
                      title: Text(isEnglish ? "Language" : "Wika", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(languageProvider.languageName, style: const TextStyle(fontSize: 12, color: ArrozTheme.textSub)),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: ArrozTheme.textSub),
                      onTap: () => _showLanguageDialog(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class HelpGuidePage extends StatelessWidget {
  const HelpGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: const Text("Help & Support Guide", style: TextStyle(color: ArrozTheme.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: ArrozTheme.textDark),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          width: double.infinity,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHelpCard("🛒 Paano Mag-order sa ArrozApp?", "Pumunta sa Home Tab, piliin ang gustong uri ng palay o bigas, at ilagay ang kilos/sacks bago mag-checkout."),
              _buildHelpCard("📍 Paano magdagdag ng Delivery Address?", "Pumunta sa 'Addresses' menu at piliin ang 'Delivery Address Manager'."),
              _buildHelpCard("🔒 Safe ba ang aking account?", "Opo, protektado ng Google Firebase authentication ang iyong datos."),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpCard(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ArrozTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ArrozTheme.textDark)),
          const SizedBox(height: 6),
          Text(a, style: const TextStyle(color: ArrozTheme.textSub, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}