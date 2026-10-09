import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'order_details_page.dart';
import '../../providers/language_provider.dart';
import '../../services/app_localizations.dart';
import '../../services/notification/notification_service.dart';
import 'profile_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  bool isCancelling = false;
  late TabController _tabController;
  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  final Map<String, String> _lastStatuses = {};
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _listenToOrderStatusChanges();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// Nanonood ng pagbabago ng status sa Firestore para mag-trigger ng notification agad
  void _listenToOrderStatusChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _ordersSubscription = FirebaseFirestore.instance
        .collection("orders")
        .where("userId", isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      if (_isInitialLoad) {
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['orderStatus'] ?? data['status'] ?? 'Pending').toString();
          _lastStatuses[doc.id] = status;
        }
        _isInitialLoad = false;
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final newStatus = (data['orderStatus'] ?? data['status'] ?? 'Pending').toString();
          final oldStatus = _lastStatuses[change.doc.id];

          if (oldStatus != null && oldStatus != newStatus) {
            _lastStatuses[change.doc.id] = newStatus;

            NotificationService.showNotification(
              title: "Update sa Order #${change.doc.id.substring(0, change.doc.id.length > 8 ? 8 : change.doc.id.length).toUpperCase()}",
              body: "Ang status ng iyong order ay: $newStatus",
              channelId: NotificationService.channelOrders,
            );
          }
        }
      }
    });
  }

  /// Inayos: Function para mag-cancel ng order at ibalik ang stock sa Inventory
  Future<void> _cancelOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kumpirmahin ang Pag-cancel"),
        content: const Text("Sigurado ka bang nais mong i-cancel ang order na ito?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hindi"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Oo, I-cancel", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      isCancelling = true;
    });

    try {
      final orderDocSnap = await FirebaseFirestore.instance.collection("orders").doc(orderId).get();
      if (!orderDocSnap.exists) {
        throw Exception("Hindi nahanap ang order.");
      }

      final orderData = orderDocSnap.data() ?? {};
      final List<dynamic> rawItems = orderData['items'] ?? [];

      // 1. I-resolve muna ang Product References bago mag-transaction
      final Map<String, DocumentReference> resolvedRefs = {};
      final productsQuery = await FirebaseFirestore.instance
          .collection("products")
          .where("isDeleted", isEqualTo: false)
          .get();

      for (var item in rawItems) {
        final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
        final String productId = (itemMap['productId'] ?? itemMap['id'] ?? '').toString();
        final String productName = (itemMap['name'] ?? itemMap['productName'] ?? itemMap['title'] ?? '').toString();

        DocumentReference? pRef;

        if (productId.isNotEmpty) {
          final pDoc = await FirebaseFirestore.instance.collection("products").doc(productId).get();
          if (pDoc.exists) {
            pRef = pDoc.reference;
          }
        }

        if (pRef == null) {
          for (var doc in productsQuery.docs) {
            final pData = doc.data();
            final name = (pData['name'] ?? '').toString().toLowerCase().trim();
            final target = productName.toLowerCase().trim();
            if (name.contains(target) || target.contains(name)) {
              pRef = doc.reference;
              break;
            }
          }
        }

        if (pRef == null && productsQuery.docs.isNotEmpty) {
          pRef = productsQuery.docs.first.reference;
        }

        if (pRef != null) {
          final key = productId.isNotEmpty ? productId : productName;
          resolvedRefs[key] = pRef;
        }
      }

      // 2. Patakbuhin ang Firestore Transaction para maibalik sa Inventory ang Stock
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final orderRef = FirebaseFirestore.instance.collection("orders").doc(orderId);

        for (var item in rawItems) {
          final Map<String, dynamic> itemMap = Map<String, dynamic>.from(item);
          final String productId = (itemMap['productId'] ?? itemMap['id'] ?? '').toString();
          final String productName = (itemMap['name'] ?? itemMap['productName'] ?? itemMap['title'] ?? '').toString();
          final int quantity = int.tryParse(itemMap['quantity']?.toString() ?? '1') ?? 1;
          final String unit = (itemMap['unit'] ?? itemMap['unitType'] ?? itemMap['type'] ?? '').toString().toLowerCase().trim();

          final key = productId.isNotEmpty ? productId : productName;
          final productRef = resolvedRefs[key];

          if (productRef != null) {
            final pSnap = await transaction.get(productRef);
            if (pSnap.exists) {
              final pData = pSnap.data() as Map<String, dynamic>? ?? {};

              final double currentRemainingKg = ((pData['remainingKg'] ?? pData['stock'] ?? pData['initialKg'] ?? 0.0) as num).toDouble();
              final int currentTotalSold = (pData['totalSold'] ?? pData['sold'] ?? 0) as int;

              int restorationKg = quantity;
              if (unit.contains('sako') || unit.contains('sack') || productName.toLowerCase().contains('sako')) {
                restorationKg = quantity * 50;
              }

              final double newRemainingKg = currentRemainingKg + restorationKg;
              final int newTotalSold = (currentTotalSold - quantity).clamp(0, 999999);

              transaction.update(productRef, {
                'remainingKg': newRemainingKg,
                'stock': newRemainingKg,
                'totalSold': newTotalSold,
                'sold': newTotalSold,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }

        // I-update ang Order Status sa Cancelled
        transaction.update(orderRef, {
          'orderStatus': 'Cancelled',
          'status': 'Cancelled',
          'inventoryDeducted': false,
          'cancelledAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Na-cancel nang matagumpay ang order at naibalik ang stock sa Inventory!"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Nagka-error sa pag-cancel: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isCancelling = false;
        });
      }
    }
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

  bool _isRatingExpired(Map<String, dynamic> orderData) {
    dynamic completedValue = orderData['completedAt'] ?? orderData['updatedAt'] ?? orderData['createdAt'];
    if (completedValue == null) return false;

    DateTime? completedDate;
    if (completedValue is Timestamp) {
      completedDate = completedValue.toDate();
    } else if (completedValue is DateTime) {
      completedDate = completedValue;
    }

    if (completedDate == null) return false;

    final difference = DateTime.now().difference(completedDate);
    return difference.inDays >= 7;
  }

  void _showRatingDialog(BuildContext context, String orderId) {
    double selectedRating = 5.0;
    final TextEditingController commentController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                "I-rate ang Order",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Ibahagi ang iyong karanasan sa natanggap na produkto:"),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () {
                            setState(() {
                              selectedRating = index + 1.0;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Isulat ang iyong review/komento...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: ArrozTheme.emerald),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text("I-cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ArrozTheme.emerald,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setState(() {
                            isSubmitting = true;
                          });

                          try {
                            final currentUser = FirebaseAuth.instance.currentUser;

                            final orderDoc = await FirebaseFirestore.instance
                                .collection("orders")
                                .doc(orderId)
                                .get();

                            final orderData = orderDoc.data() ?? {};
                            final List<dynamic> items = orderData['items'] ?? [];
                            final String userName =
                                orderData['userName'] ?? currentUser?.displayName ?? 'Buyer';

                            final WriteBatch batch = FirebaseFirestore.instance.batch();

                            for (var item in items) {
                              final Map<String, dynamic> itemMap =
                                  Map<String, dynamic>.from(item);
                              final String? productId = itemMap['productId'];

                              if (productId != null && productId.isNotEmpty) {
                                final reviewRef =
                                    FirebaseFirestore.instance.collection("reviews").doc();
                                batch.set(reviewRef, {
                                  "productId": productId,
                                  "orderId": orderId,
                                  "userId": currentUser?.uid,
                                  "userName": userName,
                                  "rating": selectedRating,
                                  "comment": commentController.text.trim(),
                                  "createdAt": FieldValue.serverTimestamp(),
                                });
                              }
                            }

                            final orderRef =
                                FirebaseFirestore.instance.collection("orders").doc(orderId);
                            batch.update(orderRef, {
                              "isRated": true,
                              "rating": selectedRating,
                              "reviewComment": commentController.text.trim(),
                              "ratedAt": FieldValue.serverTimestamp(),
                            });

                            await batch.commit();

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Maraming salamat sa iyong rating at review!"),
                                  backgroundColor: ArrozTheme.emerald,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Nagka-error sa pag-submit: $e")),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() {
                                isSubmitting = false;
                              });
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("I-submit", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(
    String rawStatus,
    bool isPaid,
    String paymentMethod,
    bool prepareToShip,
  ) {
    final status = rawStatus.trim().toLowerCase();
    final String label;
    final Color color;

    if (status == 'cancelled' || status == 'canceled') {
      label = 'Cancelled';
      color = Colors.red;
    } else if (status == 'completed' || status == 'delivered' || status == 'done') {
      label = 'Completed';
      color = ArrozTheme.emerald;
    } else if (status == 'to deliver' ||
        status == 'to receive' ||
        status == 'out for delivery' ||
        status == 'outfordelivery' ||
        status == 'todeliver' ||
        status == 'shipped' ||
        status == 'shipping') {
      label = 'Out for Delivery';
      color = Colors.deepPurple;
    } else if (status == 'to ship' || status == 'toship' || status == 'processing' || prepareToShip || isPaid) {
      label = 'To Ship';
      color = Colors.blue;
    } else if (status == 'pending' || status == 'topay' || status == 'to pay' || status == 'unpaid') {
      label = paymentMethod.trim().toLowerCase() == 'cod' ? 'Pending' : 'To Pay';
      color = Colors.orange;
    } else {
      label = rawStatus.trim().isEmpty ? 'Pending' : rawStatus.trim();
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDeliveryDelayBanner(Map<String, dynamic> data) {
    final title = (data['title'] ?? 'Delivery Delay Notice').toString();
    final message = (data['message'] ?? 'Maaaring magkaroon ng delay sa delivery dahil sa masamang panahon.').toString();
    final delay = (data['estimatedDelay'] ?? '').toString();
    final reason = (data['reason'] ?? '').toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                ),
                if (delay.isNotEmpty || reason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (delay.isNotEmpty) _noticeChip(Icons.schedule, 'Expected delay: $delay'),
                      if (reason.isNotEmpty) _noticeChip(Icons.info_outline, reason),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noticeChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.orange.shade900),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
          return Scaffold(
            appBar: _buildAppBar(local),
            body: const Center(
              child: CircularProgressIndicator(color: ArrozTheme.emerald),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Scaffold(
            appBar: _buildAppBar(local),
            body: Column(
              children: [
                _buildAdminNoticeStream(),
                Expanded(child: _noOrders("Wala ka pang nalalagay na order.")),
              ],
            ),
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
              Column(
                children: [
                  _buildAdminNoticeStream(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildListView(allOrders, local: local),
                        _buildToPayTab(allOrders, local),
                        _buildToShipTab(allOrders, local),
                        _buildToDeliverTab(allOrders, local),
                        _buildCompletedTab(allOrders, local),
                        _buildCancelledTab(allOrders, local),
                      ],
                    ),
                  ),
                ],
              ),
              if (isCancelling)
                Container(
                  color: Colors.black38,
                  child: const Center(
                    child: CircularProgressIndicator(color: ArrozTheme.emerald),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminNoticeStream() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("app_settings")
          .doc("delivery_notice")
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data == null || data['enabled'] != true) return const SizedBox.shrink();
        return _buildDeliveryDelayBanner(data);
      },
    );
  }

  Widget _noOrders(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ArrozTheme.textSub, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildToPayTab(List<QueryDocumentSnapshot> orders, AppLocalizations local) {
    final toPay = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = (data['orderStatus'] ?? data['status'] ?? 'Pending')
          .toString()
          .trim()
          .toLowerCase();
      final bool isPaid = data['isPaid'] ?? false;
      final bool prepareToShip = data['prepareToShip'] ?? false;
      return (status == "pending" || status == "unpaid" || status == "topay" || status == "to pay") &&
          !isPaid &&
          !prepareToShip;
    }).toList();

    if (toPay.isEmpty) return _noOrders("Walang orders na naghihintay ng bayad.");
    return _buildListView(toPay, canCancel: true, local: local);
  }

  Widget _buildToShipTab(List<QueryDocumentSnapshot> orders, AppLocalizations local) {
    final toShip = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = (data['orderStatus'] ?? data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      return status == "to ship" || status == "toship" || status == "paid" || status == "processing";
    }).toList();

    if (toShip.isEmpty) return _noOrders("Walang orders na para i-ship.");
    return _buildListView(toShip, local: local);
  }

  Widget _buildToDeliverTab(List<QueryDocumentSnapshot> orders, AppLocalizations local) {
    final toDeliver = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = (data['orderStatus'] ?? data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      return status == "to deliver" ||
          status == "to receive" ||
          status == "out for delivery" ||
          status == "outfordelivery" ||
          status == "todeliver" ||
          status == "shipped" ||
          status == "shipping";
    }).toList();

    if (toDeliver.isEmpty) return _noOrders("Walang ipinapadalang order sa ngayon.");
    return _buildListView(toDeliver, local: local);
  }

  Widget _buildCompletedTab(List<QueryDocumentSnapshot> orders, AppLocalizations local) {
    final completed = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = (data['orderStatus'] ?? data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return status == "completed" || status == "delivered" || status == "done";
    }).toList();

    if (completed.isEmpty) return _noOrders("Walang nakukumpletong order.");
    return _buildListView(completed, isCompletedTab: true, local: local);
  }

  Widget _buildCancelledTab(List<QueryDocumentSnapshot> orders, AppLocalizations local) {
    final cancelled = orders.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String status = (data['orderStatus'] ?? data['status'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return status == "cancelled" || status == "canceled";
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
        final orderDoc = orders[index];
        final orderData = orderDoc.data() as Map<String, dynamic>;

        final num totalAmount = orderData['totalAmount'] ?? 0;
        final String paymentMethod = orderData['paymentMethod'] ?? 'COD';
        final String rawStatus = (orderData['orderStatus'] ?? orderData['status'] ?? 'Pending').toString();
        final bool isPaid = orderData['isPaid'] ?? false;
        final bool prepareToShip = orderData['prepareToShip'] ?? false;
        final List<dynamic> itemsList = orderData['items'] ?? [];

        final bool isRated = orderData['isRated'] ?? false;
        final num? rating = orderData['rating'];
        final String? reviewComment = orderData['reviewComment'];
        final bool ratingExpired = _isRatingExpired(orderData);

        final String cleanStatus = rawStatus.trim().toLowerCase();

        final bool canCancelThisOrder = (cleanStatus == "pending" ||
                cleanStatus == "unpaid" ||
                cleanStatus == "topay" ||
                cleanStatus == "to pay") &&
            !isPaid &&
            !prepareToShip;

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailsPage(
                  orderId: orderDoc.id,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildStatusBadge(
                        rawStatus,
                        isPaid,
                        paymentMethod,
                        prepareToShip,
                      ),
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

                  ...itemsList.map((item) {
                    final Map<String, dynamic> itemData = Map<String, dynamic>.from(item);
                    final String itemName = itemData['name']?.toString() ?? 'Item';
                    final num quantity = itemData['quantity'] ?? 1;
                    final num price = itemData['price'] ?? 0;
                    final num subtotal = itemData['subtotal'] ?? (price * quantity);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
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

                  if (canCancelThisOrder) ...[
                    const Divider(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelOrder(orderDoc.id),
                        icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                        label: const Text(
                          "I-cancel ang Order",
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (cleanStatus == "completed" || cleanStatus == "delivered" || cleanStatus == "done") ...[
                    const Divider(height: 20),
                    if (isRated) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  "Your Rating: ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                                Row(
                                  children: List.generate(5, (starIndex) {
                                    return Icon(
                                      starIndex < (rating ?? 0)
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    );
                                  }),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "${rating?.toStringAsFixed(1) ?? '0.0'}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            if (reviewComment != null && reviewComment.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '"$reviewComment"',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ] else if (ratingExpired) ...[
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "Rating period expired (7 days passed)",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ] else ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () => _showRatingDialog(context, orderDoc.id),
                          icon: const Icon(Icons.star_outline, size: 16, color: Colors.white),
                          label: const Text(
                            "Rate Item",
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ArrozTheme.emerald,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 8),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
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
}