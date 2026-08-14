import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'order_details_page.dart';
import '../../providers/language_provider.dart';
import '../../services/app_localizations.dart';
import 'profile_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  bool isCancelling = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations local) {
    return AppBar(
      title: Text(local.orders, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: ArrozTheme.emerald,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: [
          Tab(text: local.all),
          Tab(text: local.toPay),
          Tab(text: local.toShip),
          Tab(text: local.toDeliver),
          Tab(text: local.completed),
          Tab(text: local.cancelled),
        ],
      ),
    );
  }

  String _formatOrderDate(dynamic value) {
    if (value == null) return '';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '';

    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>().language;
    final local = AppLocalizations(language);
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: ArrozTheme.bgGrey,
        body: Center(child: Text("Please log in to view your orders.")),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("orders")
          .where("userId", isEqualTo: currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: _buildAppBar(local), body: const Center(child: CircularProgressIndicator(color: ArrozTheme.emerald)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Scaffold(
            appBar: _buildAppBar(local),
            body: _noOrders("Wala ka pang nalalagay na order."),
          );
        }

        final allOrders = snapshot.data!.docs;
        allOrders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final Timestamp aTime = aData['createdAt'] ?? Timestamp.now();
          final Timestamp bTime = bData['createdAt'] ?? Timestamp.now();
          return bTime.compareTo(aTime);
        });

        return Scaffold(
          backgroundColor: ArrozTheme.bgGrey,
          appBar: _buildAppBar(local),
          body: Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: [
                  _buildListView(allOrders, local: local),
                  _buildToPayTab(allOrders, local),
                  _buildToShipTab(allOrders, local),
                  _buildToReceiveTab(allOrders, local),
                  _buildCompletedTab(allOrders, local),
                  _buildCancelledTab(allOrders, local),
                ],
              ),
              if (isCancelling)
                Container(
                  color: Colors.black38,
                  child: const Center(child: CircularProgressIndicator(color: ArrozTheme.emerald)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToPayTab(List<QueryDocumentSnapshot> orders, AppLocalizations local) {
    final toPay = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = data['orderStatus'] ?? data['status'] ?? 'Pending';
      final bool isPaid = data['isPaid'] ?? false;
      final bool prepareToShip = data['prepareToShip'] ?? false;
      return (status == "Pending" || status == "Unpaid") && !isPaid && !prepareToShip;
    }).toList();

    if (toPay.isEmpty) return _noOrders("Walang orders na naghihintay ng bayad.");
    return _buildListView(toPay, canCancel: true, local: local);
  }

  Widget _buildToShipTab(List<QueryDocumentSnapshot> orders, AppLocalizations local) {
    final toShip = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = data['orderStatus'] ?? data['status'] ?? 'Pending';
      final bool isPaid = data['isPaid'] ?? false;
      final bool prepareToShip = data['prepareToShip'] ?? false;
      return (status == "Pending" || status == "Paid") && (isPaid || prepareToShip);
    }).toList();

    if (toShip.isEmpty) return _noOrders("Walang orders na para i-ship.");
    return _buildListView(toShip, local: local);
  }

  Widget _buildToReceiveTab(List<QueryDocumentSnapshot> orders, AppLocalizations local) {
    final toReceive = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = data['orderStatus'] ?? data['status'] ?? 'Pending';

      return status == "To Deliver";
    }).toList();

    if (toReceive.isEmpty) {
      return _noOrders("Walang ipinapadalang order sa ngayon.");
    }

    return _buildListView(toReceive, local: local);
  }

  Widget _buildCompletedTab(List<QueryDocumentSnapshot> orders, AppLocalizations local) {
    final completed = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['orderStatus'] ?? data['status']) == "Completed";
    }).toList();

    if (completed.isEmpty) return _noOrders("Walang nakukumpletong order.");
    return _buildListView(completed, isCompletedTab: true, local: local);
  }

  Widget _buildCancelledTab(List<QueryDocumentSnapshot> orders, AppLocalizations local) {
    final cancelled = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['orderStatus'] ?? data['status']) == "Cancelled";
    }).toList();

    if (cancelled.isEmpty) return _noOrders("Walang na-cancel na order.");
    return _buildListView(cancelled, buyAgain: true, local: local);
  }

  Widget _buildListView(
      List<QueryDocumentSnapshot> orders, {
        required AppLocalizations local,
        bool canCancel = false,
        bool buyAgain = false,
        bool isCompletedTab = false,
      }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final orderData =
        orders[index].data() as Map<String, dynamic>;

        final num totalAmount =
            orderData['totalAmount'] ?? 0;

        final String paymentMethod =
            orderData['paymentMethod'] ?? 'COD';

        final String status =
            orderData['orderStatus'] ??
                orderData['status'] ??
                'Pending';

        final bool isPaid =
            orderData['isPaid'] ?? false;

        final bool prepareToShip =
            orderData['prepareToShip'] ?? false;

        final List<dynamic> itemsList =
            orderData['items'] ?? [];

        return InkWell(
          borderRadius: BorderRadius.circular(12),

          // ============================================================
          // OPEN ORDER DETAILS
          // ============================================================
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailsPage(
                  orderId: orders[index].id,
                  orderData: orderData,
                ),
              ),
            );
          },

          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),

            child: Padding(
              padding: const EdgeInsets.all(14),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  // ======================================================
                  // STATUS LEFT + ORDER DATE RIGHT
                  // ======================================================
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    crossAxisAlignment:
                    CrossAxisAlignment.center,

                    children: [
                      // STATUS - LEFT
                      _buildStatusBadge(
                        status,
                        isPaid,
                        paymentMethod,
                        prepareToShip,
                      ),

                      // DATE - RIGHT
                      Text(
                        _formatOrderDate(
                          orderData['createdAt'],
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: ArrozTheme.textSub,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 20),

                  // ======================================================
                  // ORDER ITEMS
                  // ======================================================
                  ...itemsList.map((item) {
                    final Map<String, dynamic> itemData =
                    Map<String, dynamic>.from(item);

                    final String itemName =
                        itemData['name']?.toString() ??
                            'Item';

                    final num quantity =
                        itemData['quantity'] ?? 1;

                    final num price =
                        itemData['price'] ?? 0;

                    final num subtotal =
                        itemData['subtotal'] ??
                            (price * quantity);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                      ),

                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,

                        children: [
                          Expanded(
                            child: Text(
                              '$itemName (x$quantity)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(width: 10),

                          Text(
                            '₱${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  // ======================================================
                  // PAYMENT + TOTAL
                  // ======================================================
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,

                    crossAxisAlignment:
                    CrossAxisAlignment.center,

                    children: [
                      Expanded(
                        child: Text(
                          'Payment: $paymentMethod',
                          style: const TextStyle(
                            fontSize: 12,
                            color: ArrozTheme.textSub,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Text(
                        'Total: ₱${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: ArrozTheme.emerald,
                        ),
                      ),
                    ],
                  ),

                  // ======================================================
                  // TAP INDICATOR
                  // ======================================================
                  const SizedBox(height: 8),

                  const Row(
                    mainAxisAlignment:
                    MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.black38,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, bool isPaid, String paymentMethod, bool prepareToShip) {
    Color badgeColor = Colors.grey;
    String text = status;

    // Inuuna ang mismong explicit orderStatus bago ang payment conditions
    if (status == "Completed") {
      badgeColor = ArrozTheme.emerald;
      text = "Completed";
    } else if (status == "Cancelled") {
      badgeColor = ArrozTheme.dangerRed;
      text = "Cancelled";
    } else if (status == "To Deliver") {
      badgeColor = Colors.blue.shade700;
      text = "To Deliver";
    } else if (isPaid || prepareToShip || status == "Paid") {
      badgeColor = ArrozTheme.warningOrange;
      text = "To Ship";
    } else {
      badgeColor = Colors.orange;
      text = "To Pay";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _noOrders(String msg) => Center(child: Text(msg, style: const TextStyle(color: ArrozTheme.textSub)));
}