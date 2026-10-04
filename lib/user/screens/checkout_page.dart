import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'homeuser_page.dart';
import 'payment_webview.dart';
import 'address_picker.dart'; 
import 'package:arroz_app/services/notification/notification_service.dart';

class CheckoutPage extends StatefulWidget {
  final Map<String, dynamic>? initialAddress;
  final List<Map<String, dynamic>> orderItems;
  final double totalAmount;

  const CheckoutPage({
    super.key,
    this.initialAddress,
    required this.orderItems,
    required this.totalAmount,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Map<String, dynamic>? selectedAddress;
  String paymentMethod = "Cash on Delivery (COD)";
  bool isPlacingOrder = false;

  double distanceInKm = 0.0;
  double shippingFee = 0.0;
  bool isCalculatingShipping = false;

  // Main Store Coordinates (San Jose del Monte)
  final Map<String, dynamic> storeLocation = {
    'storeName': 'Main Warehouse',
    'latitude': 14.8138, 
    'longitude': 121.0453,
  };

  int completedOrderCount = 0;
  double loyaltyDiscount = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialAddress != null) {
      selectedAddress = widget.initialAddress;
      _updateDistanceAndShippingFee();
    } else {
      _loadDefaultAddress();
    }
    _checkCustomerLoyalty();
  }

  @override
  void dispose() {
    super.dispose();
  }

  double get totalPalayKg {
    double total = 0.0;
    for (var item in widget.orderItems) {
      final qty = (item['quantity'] as num? ?? 1).toDouble();
      total += qty;
    }
    return total;
  }

  /// Haversine Formula para sa eksaktong pagkalkula ng distansya (in KM)
  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R * asin... (R = 6371 km)
  }

  /// Dynamic Shipping Calculation
  Future<void> _updateDistanceAndShippingFee() async {
    if (selectedAddress == null) return;

    setState(() => isCalculatingShipping = true);

    try {
      double userLat = (selectedAddress!['latitude'] as num?)?.toDouble() ?? storeLocation['latitude'];
      double userLon = (selectedAddress!['longitude'] as num?)?.toDouble() ?? storeLocation['longitude'];

      double calculatedKm = _calculateHaversineDistance(
        storeLocation['latitude'],
        storeLocation['longitude'],
        userLat,
        userLon,
      );

      if (calculatedKm < 1.0) calculatedKm = 1.0;

      double baseFare = 40.0;      
      double ratePerKm = 5.0;      
      double ratePerKg = 0.50;     

      double calculatedShipping = baseFare + (calculatedKm * ratePerKm) + (totalPalayKg * ratePerKg);

      const double maxShippingFee = 300.0;
      if (calculatedShipping > maxShippingFee) {
        calculatedShipping = maxShippingFee;
      }

      if (mounted) {
        setState(() {
          distanceInKm = calculatedKm;
          shippingFee = calculatedShipping;
        });
      }
    } catch (e) {
      debugPrint("Error updating shipping fee: $e");
    } finally {
      if (mounted) setState(() => isCalculatingShipping = false);
    }
  }

  Future<void> _checkCustomerLoyalty() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("orders")
          .where("userId", isEqualTo: user.uid)
          .where("orderStatus", isEqualTo: "Completed")
          .get();

      if (mounted) {
        setState(() {
          completedOrderCount = snapshot.docs.length;
          if (completedOrderCount >= 3) {
            loyaltyDiscount = widget.totalAmount * 0.05; // 5% Discount
          } else {
            loyaltyDiscount = 0.0;
          }
        });
      }
    } catch (e) {
      debugPrint("Loyalty Check Error: $e");
    }
  }

  double get totalDiscount => loyaltyDiscount;

  double get finalTotal {
    double itemTotalAfterDiscount = widget.totalAmount - totalDiscount;
    if (itemTotalAfterDiscount < 0) itemTotalAfterDiscount = 0.0;
    return itemTotalAfterDiscount + shippingFee;
  }

  Future<void> _loadDefaultAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("addresses")
          .where("isDefault", isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          selectedAddress = snapshot.docs.first.data();
        });
        _updateDistanceAndShippingFee();
      }
    } catch (e) {
      debugPrint("Error loading default address: $e");
    }
  }

  /// INAYOS NA STOCK DEDUCTION METHOD PARA SA ADMIN INVENTORY
  Future<void> _deductProductStock() async {
    final db = FirebaseFirestore.instance;

    for (final item in widget.orderItems) {
      debugPrint("🔍 CHECKING ORDER ITEM: $item");

      final String? productId = item['productId']?.toString() ?? 
                                 item['id']?.toString() ?? 
                                 item['docId']?.toString();
                                 
      final double quantityOrdered = ((item['quantity'] as num?) ?? 1).toDouble();
      final String? selectedCondition = item['condition']?.toString();

      if (productId != null && productId.trim().isNotEmpty) {
        try {
          await db.runTransaction((transaction) async {
            final productRef = db.collection('products').doc(productId.trim());
            final snapshot = await transaction.get(productRef);

            if (!snapshot.exists) {
              debugPrint("❌ Product doc not found: $productId");
              return;
            }

            final data = snapshot.data() as Map<String, dynamic>;
            double currentRemaining = ((data['remainingKg'] ?? 0.0) as num).toDouble();
            List<dynamic> breakdowns = List.from(data['breakdowns'] ?? []);

            if (selectedCondition != null && selectedCondition.isNotEmpty) {
              for (int i = 0; i < breakdowns.length; i++) {
                if (breakdowns[i]['condition'] == selectedCondition) {
                  double currentKg = ((breakdowns[i]['kg'] ?? 0.0) as num).toDouble();
                  double newKg = currentKg - quantityOrdered;
                  breakdowns[i]['kg'] = newKg < 0 ? 0.0 : newKg;
                  break;
                }
              }
            } else if (breakdowns.isNotEmpty) {
              double currentKg = ((breakdowns[0]['kg'] ?? 0.0) as num).toDouble();
              double newKg = currentKg - quantityOrdered;
              breakdowns[0]['kg'] = newKg < 0 ? 0.0 : newKg;
            }

            double newRemaining = currentRemaining - quantityOrdered;
            if (newRemaining < 0) newRemaining = 0.0;

            transaction.update(productRef, {
              'remainingKg': newRemaining,
              'totalKg': newRemaining,
              'breakdowns': breakdowns,
            });

            debugPrint("✅ STOCK DEDUCTED: -$quantityOrdered kg para sa Product: $productId");
          });
        } catch (e) {
          debugPrint("❌ Transaction Error sa Stock Deduction: $e");
          rethrow;
        }
      } else {
        debugPrint("⚠️ WARNING: Walang Product ID sa item $item");
      }
    }
  }

  Future<void> _removePurchasedItemsFromCart() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      bool hasCartItems = false;

      for (final item in widget.orderItems) {
        if (item['cartDocId'] != null) {
          final docRef = FirebaseFirestore.instance.collection('cart').doc(item['cartDocId']);
          batch.delete(docRef);
          hasCartItems = true;
        }
      }

      if (hasCartItems) {
        await batch.commit();
        debugPrint("✅ Cart items successfully removed.");
      }
    } catch (e) {
      debugPrint("Error removing cart items: $e");
    }
  }

  Future<void> _processOnlinePayment(
      DocumentReference orderRef,
      String methodKey,
      String customerName,
      String customerEmail,
      String customerPhone,
      ) async {
    final primaryColor = Theme.of(context).primaryColor;
    final errorColor = Theme.of(context).colorScheme.error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          margin: const EdgeInsets.all(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryColor),
                const SizedBox(height: 15),
                const Text("Preparing secure payment gateway...", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse("https://arroz-backend.onrender.com/api/create-payment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "orderId": orderRef.id,
          "amount": finalTotal,
          "paymentMethod": methodKey,
          "customerName": customerName,
          "customerEmail": customerEmail,
          "customerPhone": customerPhone,
        }),
      ).timeout(const Duration(seconds: 60));

      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final checkoutUrl = data["checkoutUrl"];

        if (!mounted || checkoutUrl == null) return;

        if (kIsWeb) {
          final uri = Uri.parse(checkoutUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            throw Exception("Unable to open PayMongo Checkout.");
          }
          return;
        }

        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PaymentWebView(
              checkoutUrl: checkoutUrl,
              orderId: orderRef.id,
              paymentMethod: methodKey,
            ),
          ),
        );

        if (mounted && result == "SUCCESS") {
          await _deductProductStock();
          await _removePurchasedItemsFromCart();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Payment Successful! Your payment and order have been received."),
              backgroundColor: primaryColor,
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const HomeUserPage(initialIndex: 3),
            ),
                (route) => false,
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Online payment was cancelled or failed."),
              backgroundColor: errorColor,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SelectableText("Online payment session failed (${response.statusCode}): ${response.body}"),
              backgroundColor: errorColor,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText("Payment Gateway Error: $e"),
            backgroundColor: errorColor,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  void _placeOrder() async {
    final errorColor = Theme.of(context).colorScheme.error;
    final primaryColor = Theme.of(context).primaryColor;

    if (selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Please select a delivery address."), backgroundColor: errorColor),
      );
      return;
    }

    setState(() => isPlacingOrder = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User is not authenticated. Please log in again.");
      }

      final bool isOnlinePayment = paymentMethod == "GCash / E-Wallet";
      final String contactNum = selectedAddress!['phoneNumber'] ?? selectedAddress!['mobileNumber'] ?? "N/A";
      final String customerName = selectedAddress!['fullName'] ?? 'Customer';

      final noticeSnapshot = await FirebaseFirestore.instance
          .collection("app_settings")
          .doc("delivery_notice")
          .get();
      final noticeData = noticeSnapshot.data() ?? {};
      final bool deliveryDelayEnabled = noticeData['enabled'] == true;

      final orderRef = await FirebaseFirestore.instance.collection("orders").add({
        "userId": user.uid,
        "customerName": customerName,
        "emailAddress": selectedAddress!['emailAddress'] ?? user.email ?? "",
        "phoneNumber": contactNum,
        "deliveryAddress": "${selectedAddress!['streetBuildingHouseNo']}, ${selectedAddress!['barangay']}, ${selectedAddress!['cityMunicipality']}, ${selectedAddress!['province']} (${selectedAddress!['postalCode'] ?? ''})",
        "deliveryCoordinates": {
          "latitude": selectedAddress!['latitude'] ?? storeLocation['latitude'],
          "longitude": selectedAddress!['longitude'] ?? storeLocation['longitude'],
        },
        "distanceKm": distanceInKm,
        "items": widget.orderItems,
        "subtotal": widget.totalAmount,
        "shippingFee": shippingFee,
        "discountAmount": totalDiscount,
        "loyaltyDiscount": loyaltyDiscount,
        "totalAmount": finalTotal,
        "totalPalayKg": totalPalayKg,
        "paymentMethod": paymentMethod,
        "deliveryDelay": deliveryDelayEnabled,
        "deliveryDelayTitle": deliveryDelayEnabled ? (noticeData['title'] ?? 'Delivery Delay Notice') : null,
        "deliveryDelayMessage": deliveryDelayEnabled ? (noticeData['message'] ?? '') : null,
        "deliveryDelayDays": deliveryDelayEnabled ? (noticeData['estimatedDelay'] ?? '') : null,
        "deliveryDelayReason": deliveryDelayEnabled ? (noticeData['reason'] ?? '') : null,
        "isPaid": false,
        "orderStatus": isOnlinePayment ? "Unpaid" : "Pending",
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!isOnlinePayment) {
        await _deductProductStock();
        await _removePurchasedItemsFromCart();
      }

      final shortOrderId = orderRef.id.length >= 6 ? orderRef.id.substring(0, 6) : orderRef.id;
      final formattedAmount = "₱${finalTotal.toStringAsFixed(2)}";

      await FirebaseFirestore.instance.collection("notifications").add({
        "userId": user.uid,
        "recipientType": "customer",
        "title": "Order Confirmed! (#$shortOrderId)",
        "body": "Salamat sa pagbili, $customerName! Ang iyong order na $formattedAmount ay nai-place na.",
        "type": "order",
        "orderId": orderRef.id,
        "isRead": false,
        "timestamp": FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection("notifications").add({
        "recipientType": "admin",
        "title": "New Order Alert! (#$shortOrderId)",
        "body": "New order received from $customerName worth $formattedAmount via $paymentMethod.",
        "type": "order",
        "orderId": orderRef.id,
        "isRead": false,
        "timestamp": FieldValue.serverTimestamp(),
      });

      await NotificationService.showNotification(
        title: "New Order Alert! (#$shortOrderId)",
        body: "New order received from $customerName worth $formattedAmount.",
        channelId: NotificationService.channelOrders,
      );

      if (isOnlinePayment) {
        if (mounted) setState(() => isPlacingOrder = false);
        await _processOnlinePayment(
          orderRef,
          "gcash",
          customerName,
          selectedAddress!['emailAddress']?.toString() ?? user.email ?? "",
          contactNum,
        );
      } else {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("Order Placed Successfully!"),
              content: const Text("Salamat! Natanggap na namin ang iyong order para sa kargamento ng palay."),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const HomeUserPage(initialIndex: 3),
                      ),
                          (route) => false,
                    );
                  },
                  child: const Text("OK", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint("❌ DETAILED ORDER ERROR: $e");
      debugPrint("❌ STACK TRACE: $stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText("Error placing order: $e"),
            backgroundColor: errorColor,
            duration: const Duration(seconds: 15),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isPlacingOrder = false);
    }
  }

  Widget _buildDeliveryDelayBanner(Map<String, dynamic> data) {
    final title = (data['title'] ?? 'Delivery Delay Notice').toString();
    final message = (data['message'] ?? 'Maaaring magkaroon ng delay sa delivery dahil sa masamang panahon.').toString();
    final delay = (data['estimatedDelay'] ?? '').toString();
    final reason = (data['reason'] ?? '').toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 15)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: Colors.orange.shade900, fontSize: 13)),
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
      decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.orange.shade900),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: Colors.orange.shade900, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout / Order Review", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("app_settings")
                  .doc("delivery_notice")
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                if (data == null || data['enabled'] != true) return const SizedBox.shrink();
                return _buildDeliveryDelayBanner(data);
              },
            ),
            // Address Section
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: primaryColor),
                            const SizedBox(width: 8),
                            const Text("Delivery Address", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            GlobalAddressSelectionService.showAddressPicker(
                              context: context,
                              onAddressSelected: (newAddress) {
                                setState(() {
                                  selectedAddress = newAddress;
                                });
                                _updateDistanceAndShippingFee();
                              },
                            );
                          },
                          child: Text(
                            selectedAddress == null ? "+ Select / Add" : "Change",
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                    const Divider(),
                    if (selectedAddress == null)
                      Text("No address selected. Please click '+ Select / Add' above.", style: TextStyle(color: errorColor))
                    else ...[
                      Text("Name: ${selectedAddress!['fullName'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        "Contact No: ${selectedAddress!['phoneNumber'] ?? selectedAddress!['mobileNumber'] ?? 'N/A'}",
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${selectedAddress!['streetBuildingHouseNo'] ?? ''}, ${selectedAddress!['barangay'] ?? ''}, ${selectedAddress!['cityMunicipality'] ?? ''}, ${selectedAddress!['province'] ?? ''} (${selectedAddress!['postalCode'] ?? ''})",
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Option
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payment, color: primaryColor),
                        const SizedBox(width: 8),
                        const Text("Mode of Payment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const Divider(),
                    RadioListTile<String>(
                      title: const Text("Cash on Delivery (COD)"),
                      value: "Cash on Delivery (COD)",
                      groupValue: paymentMethod,
                      activeColor: primaryColor,
                      onChanged: (val) => setState(() => paymentMethod = val!),
                    ),
                    RadioListTile<String>(
                      title: const Text("GCash / E-Wallet"),
                      value: "GCash / E-Wallet",
                      groupValue: paymentMethod,
                      activeColor: primaryColor,
                      onChanged: (val) => setState(() => paymentMethod = val!),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Loyalty Discount
            if (completedOrderCount >= 3)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.stars, color: primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Suki Customer Perk: May 5% Loyalty Discount ka dahil sa iyong $completedOrderCount completed orders!",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Order Summary
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Order Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Divider(),
                    ...widget.orderItems.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text("${item['quantity']} kg x ${item['name']}")),
                          Text("₱${((item['price'] as num) * (item['quantity'] as num)).toStringAsFixed(2)}"),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Subtotal (Palay):"),
                        Text("₱${widget.totalAmount.toStringAsFixed(2)}"),
                      ],
                    ),
                    if (loyaltyDiscount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Suki Loyalty Discount (5%):", style: TextStyle(color: Colors.green)),
                          Text("-₱${loyaltyDiscount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "Shipping Fee (${totalPalayKg.toStringAsFixed(0)} kg palay • ${distanceInKm.toStringAsFixed(1)} km):",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        isCalculatingShipping
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                              )
                            : Text("₱${shippingFee.toStringAsFixed(2)}"),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Kabuuang Babayaran:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text("₱${finalTotal.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: (isPlacingOrder || isCalculatingShipping) ? null : _placeOrder,
            child: isPlacingOrder
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
              paymentMethod == "GCash / E-Wallet" ? "PAY VIA GCASH" : "PLACE ORDER NOW",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}