import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_page.dart';
import 'orders_page.dart';
import 'product_page.dart';
import 'profile_page.dart';
import 'messages_page.dart';
import 'login_page.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/app_localizations.dart';

class HomeUserPage extends StatefulWidget {
  final int initialIndex;

  const HomeUserPage({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<HomeUserPage> createState() => _HomeUserPageState();
}

class _HomeUserPageState extends State<HomeUserPage> {
  int _currentIndex = 0;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _listenToAccountStatus();
  }

  // 🔥 UPDATED REAL-TIME LISTENER NA MAY GRACE PERIOD PARA SA BAGONG ACCOUNTS
  void _listenToAccountStatus() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen((snapshot) async {
      // 1. Kung wala pang nababasang user document sa Firestore
      if (!snapshot.exists) {
        // Maghintay ng 2.5 seconds para bigyan ng oras ang registration flow na matapos ang pag-set sa Firestore
        await Future.delayed(const Duration(milliseconds: 2500));

        // Mag-recheck gamit ang direct get() call
        final reCheck = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        // Kung talagang wala pa ring document pagkatapos ng delay, saka lamang mag-force logout
        if (!reCheck.exists) {
          await _forceLogout(
            title: 'Account Deleted',
            message: 'Ang iyong account ay nabura na ng admin.',
          );
        }
        return;
      }

      final data = snapshot.data();
      if (data != null) {
        final bool isBlocked = data['isBlocked'] ?? false;
        final bool isScheduledForDeletion = data['isScheduledForDeletion'] ?? false;

        // 2. Kung naka-block o naka-schedule for deletion ang account
        if (isBlocked || isScheduledForDeletion) {
          await _forceLogout(
            title: isBlocked ? 'Account Blocked' : 'Account Deleted',
            message: isBlocked
                ? 'Ang iyong account ay hinarang ng admin.'
                : 'Ang iyong account ay naka-schedule na para sa deletion.',
          );
        }
      }
    });
  }

  Future<void> _forceLogout({required String title, required String message}) async {
    // I-cancel ang listener para hindi paulit-ulit na tumakbo
    await _userSubscription?.cancel();

    // Sign out sa Firebase Auth
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    // Ipakita ang prompt dialog sa user
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginUserPage()),
                    (route) => false,
              );
            },
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  List<Widget> _buildPages() {
    return [
      _DashboardView(
        language: context.watch<LanguageProvider>().language,
        onLanguageToggle: () {
          context.read<LanguageProvider>().toggleLanguage();
        },
        onNavigateToProducts: () => setState(() => _currentIndex = 1),
        onNavigateToCart: () => setState(() => _currentIndex = 2),
        onNavigateToOrders: () => setState(() => _currentIndex = 3),
      ),
      const ProductPage(),
      const CartPage(),
      const OrdersPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>().language;
    final local = AppLocalizations(language);
    final currentPages = _buildPages();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: IndexedStack(
        index: _currentIndex,
        children: currentPages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        elevation: 3,
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: theme.colorScheme.primary),
              label: local.home
          ),
          NavigationDestination(
              icon: const Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront, color: theme.colorScheme.primary),
              label: local.products
          ),
          NavigationDestination(
              icon: const Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart, color: theme.colorScheme.primary),
              label: local.cart
          ),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: theme.colorScheme.primary),
              label: local.orders
          ),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: theme.colorScheme.primary),
              label: local.profile
          ),
        ],
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  final AppLanguage language;
  final VoidCallback onLanguageToggle;
  final VoidCallback onNavigateToProducts;
  final VoidCallback onNavigateToCart;
  final VoidCallback onNavigateToOrders;

  const _DashboardView({
    required this.language,
    required this.onLanguageToggle,
    required this.onNavigateToProducts,
    required this.onNavigateToCart,
    required this.onNavigateToOrders,
  });

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return language == AppLanguage.english ? "Good Morning! 🌾" : "Magandang Umaga! 🌾";
    if (hour < 18) return language == AppLanguage.english ? "Good Afternoon! ☀️" : "Magandang Hapon! ☀️";
    return language == AppLanguage.english ? "Good Evening! 🌙" : "Magandang Gabi! 🌙";
  }

  void _showNotificationPanel(BuildContext context, AppLocalizations local, String userId) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          local.notifTitle,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)
                      ),
                      IconButton(
                        icon: Icon(Icons.done_all, color: theme.colorScheme.primary, size: 20),
                        tooltip: "I-mark lahat bilang nabasa",
                        onPressed: () async {
                          final batch = FirebaseFirestore.instance.batch();
                          final unread = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .collection('notifications')
                              .where('isRead', isEqualTo: false)
                              .get();
                          for (var doc in unread.docs) {
                            batch.update(doc.reference, {'isRead': true});
                          }
                          await batch.commit();
                        },
                      )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('notifications')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Text(local.noNotif, style: TextStyle(color: theme.colorScheme.outline, fontSize: 14)),
                          );
                        }

                        return ListView.builder(
                          controller: scrollController,
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final notif = docs[index].data() as Map<String, dynamic>;
                            final bool isRead = notif['isRead'] ?? false;
                            final String type = notif['type'] ?? 'GENERAL';

                            IconData notifIcon = Icons.notifications;
                            Color iconColor = theme.colorScheme.primary;

                            if (type == 'ORDER_UPDATE') {
                              notifIcon = Icons.local_shipping;
                              iconColor = Colors.blue;
                            } else if (type == 'RESTOCK_ALERT') {
                              notifIcon = Icons.storefront;
                              iconColor = Colors.orange;
                            } else if (type == 'CART_NUDGE') {
                              notifIcon = Icons.shopping_cart;
                              iconColor = theme.colorScheme.error;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.transparent : theme.colorScheme.primaryContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: iconColor.withOpacity(0.15),
                                  child: Icon(notifIcon, color: iconColor, size: 20),
                                ),
                                title: Text(
                                  notif['title'] ?? 'Notification',
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                subtitle: Text(
                                  notif['body'] ?? '',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                                onTap: () {
                                  docs[index].reference.update({'isRead': true});
                                  if (type == 'ORDER_UPDATE') {
                                    Navigator.pop(context);
                                    onNavigateToOrders();
                                  } else if (type == 'CART_NUDGE') {
                                    Navigator.pop(context);
                                    onNavigateToCart();
                                  } else if (type == 'RESTOCK_ALERT') {
                                    Navigator.pop(context);
                                    onNavigateToProducts();
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations(language);
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 125.0,
          floating: false,
          pinned: true,
          elevation: 0,
          scrolledUnderElevation: 2,
          backgroundColor: theme.colorScheme.primary,
          iconTheme: IconThemeData(color: theme.colorScheme.onPrimary),
          actions: [
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: onLanguageToggle,
              icon: const Icon(Icons.translate, size: 16),
              label: Text(
                language == AppLanguage.tagalog ? "EN" : "TAG",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),

            if (currentUser != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("chats")
                    .doc(currentUser.uid)
                    .collection("messages")
                    .snapshots(),
                builder: (context, snapshot) {
                  return IconButton(
                    icon: Icon(
                      Icons.mail_outline,
                      color: theme.colorScheme.onPrimary,
                    ),
                    tooltip: "Messages",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MessagesPage(),
                        ),
                      );
                    },
                  );
                },
              ),

            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: currentUser == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .collection('notifications')
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return IconButton(
                    icon: Badge(
                      label: Text(
                        "$unreadCount",
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.onError),
                      ),
                      backgroundColor: theme.colorScheme.error,
                      isLabelVisible: unreadCount > 0,
                      child: Icon(Icons.notifications_none_outlined, color: theme.colorScheme.onPrimary),
                    ),
                    onPressed: () => _showNotificationPanel(context, local, currentUser.uid),
                  );
                },
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.85),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 40,
                    bottom: -30,
                    child: Text(
                      "🌾",
                      style: TextStyle(
                        fontSize: 100,
                        color: theme.colorScheme.onPrimary.withOpacity(0.12),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _getTimeGreeting(),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        StreamBuilder<DocumentSnapshot>(
                          stream: currentUser != null
                              ? FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots()
                              : const Stream.empty(),
                          builder: (context, snapshot) {
                            String name = language == AppLanguage.english ? "Buyer" : "Mamimili";
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>;
                              name = data['firstName'] ?? data['name'] ?? name;
                            }
                            return Text(
                              "${local.welcome}, ${name.trim()}!",
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: currentUser == null
                ? const SizedBox.shrink()
                : _DashboardCardGrid(
              userId: currentUser.uid,
              local: local,
              onOrdersTap: onNavigateToOrders,
              onCartTap: onNavigateToCart,
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gavel_outlined, color: theme.colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(local.specsTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(local.specsDesc, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            local.actionDesc,
                            style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant, height: 1.4),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: onNavigateToProducts,
                            icon: const Icon(Icons.shopping_basket_outlined, size: 16),
                            label: Text(local.orderNow, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.eco_outlined, size: 54, color: theme.colorScheme.primary.withOpacity(0.5)),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 🔥 PINAKAMABENTA & 👍 REKOMENDADO SECTIONS
        SliverToBoxAdapter(
          child: _HorizontalProductSection(
            local: local,
            title: local.bestSeller,
            categoryFilter: 'best_seller',
            onSeeAll: onNavigateToProducts,
          ),
        ),
        SliverToBoxAdapter(
          child: _HorizontalProductSection(
            local: local,
            title: local.recommended,
            categoryFilter: 'recommended',
            onSeeAll: onNavigateToProducts,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _DashboardCardGrid extends StatelessWidget {
  final String userId;
  final AppLocalizations local;
  final VoidCallback onOrdersTap;
  final VoidCallback onCartTap;

  const _DashboardCardGrid({
    required this.userId,
    required this.local,
    required this.onOrdersTap,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.1,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricCard(
          context: context,
          stream: FirebaseFirestore.instance.collection('orders').where('userId', isEqualTo: userId).snapshots(),
          label: local.activeOrders,
          icon: Icons.local_shipping_outlined,
          color: Colors.blue,
          onTap: onOrdersTap,
        ),
        _buildMetricCard(
          context: context,
          stream: FirebaseFirestore.instance.collection('cart').where('userId', isEqualTo: userId).snapshots(),
          label: local.myCart,
          icon: Icons.shopping_bag_outlined,
          color: Colors.orange,
          onTap: onCartTap,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required Stream<QuerySnapshot> stream,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 18, child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: stream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text("!", style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold));
                      }
                      final count = snapshot.hasData ? snapshot.data!.docs.length.toString() : "...";
                      return Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: theme.colorScheme.onSurface));
                    },
                  ),
                  Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// 🌾 UPDATED & DYNAMIC PRODUCT SECTION
class _HorizontalProductSection extends StatelessWidget {
  final AppLocalizations local;
  final String title;
  final String categoryFilter;
  final VoidCallback onSeeAll;

  const _HorizontalProductSection({
    required this.local,
    required this.title,
    required this.categoryFilter,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: -0.3, color: theme.colorScheme.onSurface)),
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(local.viewAll, style: TextStyle(color: theme.colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)),
                );
              }

              final allDocs = snapshot.data?.docs ?? [];

              List<QueryDocumentSnapshot> docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data[categoryFilter] == true;
              }).toList();

              if (docs.isEmpty) {
                docs = allDocs.take(5).toList();
              } else if (docs.length > 5) {
                docs = docs.sublist(0, 5);
              }

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(local.noItems, style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final prod = docs[index].data() as Map<String, dynamic>;
                  final String? imageUrl = prod['imageUrl'] ?? prod['photoUrl'] ?? prod['image'];

                  return GestureDetector(
                    onTap: onSeeAll,
                    child: Container(
                      width: 130,
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 60,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Icon(Icons.grain, color: theme.colorScheme.secondary, size: 28),
                                ),
                              )
                                  : Icon(Icons.grain, color: theme.colorScheme.secondary, size: 28),
                            ),
                            const Spacer(),
                            Text(
                              prod['name'] ?? prod['title'] ?? 'Palay Bag',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "₱${prod['price'] ?? 0}",
                              style: TextStyle(color: theme.colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}