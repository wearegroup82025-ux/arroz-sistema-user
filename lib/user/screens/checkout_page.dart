import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'homeuser_page.dart';
import 'address_picker.dart';
import 'payment_webview.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'orders_page.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDefaultAddress();
  }

  Future<void> _loadDefaultAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
    }
  }

  Future<void> _deductProductStock() async {
    final batch = FirebaseFirestore.instance.batch();

    for (final item in widget.orderItems) {
      final productId = item['productId'];
      final quantityOrdered = item['quantity'] as int? ?? 1;

      if (productId != null && productId.toString().isNotEmpty) {
        final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
        batch.update(productRef, {
          'stock': FieldValue.increment(-quantityOrdered)
        });
      }
    }

    await batch.commit();
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
          "amount": widget.totalAmount,
          "paymentMethod": methodKey,
          "customerName": customerName,
          "customerEmail": customerEmail,
          "customerPhone": customerPhone,
        }),
      );

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
              content: Text("Online payment session failed (${response.statusCode})."),
              backgroundColor: errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment Gateway Error: $e"), backgroundColor: errorColor),
        );
      }
    }
  }

  Future<void> _removePurchasedItemsFromCart() async {
    final batch = FirebaseFirestore.instance.batch();

    for (final item in widget.orderItems) {
      if (item['cartDocId'] != null) {
        final docRef = FirebaseFirestore.instance.collection('cart').doc(item['cartDocId']);
        batch.delete(docRef);
      }
    }

    await batch.commit();
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
      if (user == null) return;

      final bool isOnlinePayment = paymentMethod == "GCash / E-Wallet";
      final String contactNum = selectedAddress!['phoneNumber'] ?? selectedAddress!['mobileNumber'] ?? "N/A";
      final String customerName = selectedAddress!['fullName'] ?? 'Customer';

      // 1. Create Order Document sa Firestore
      final orderRef = await FirebaseFirestore.instance.collection("orders").add({
        "userId": user.uid,
        "customerName": customerName,
        "emailAddress": selectedAddress!['emailAddress'],
        "phoneNumber": contactNum,
        "deliveryAddress": "${selectedAddress!['streetBuildingHouseNo']}, ${selectedAddress!['barangay']}, ${selectedAddress!['cityMunicipality']}, ${selectedAddress!['province']} (${selectedAddress!['postalCode'] ?? ''})",
        "items": widget.orderItems,
        "totalAmount": widget.totalAmount,
        "paymentMethod": paymentMethod,
        "isPaid": false,
        "orderStatus": isOnlinePayment ? "Unpaid" : "Pending",
        "createdAt": FieldValue.serverTimestamp(),
      });

      final shortOrderId = orderRef.id.substring(0, 6);
      final formattedAmount = "₱${widget.totalAmount.toStringAsFixed(2)}";

      // 2. NOTIFICATION PARA SA CUSTOMER (Buyer App)
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

      // 3. NOTIFICATION PARA SA ADMIN / SELLER (Admin App)
      await FirebaseFirestore.instance.collection("notifications").add({
        "recipientType": "admin",
        "title": "New Order Alert! (#$shortOrderId)",
        "body": "New order received from $customerName worth $formattedAmount via $paymentMethod. Please process for fulfillment.",
        "type": "order",
        "orderId": orderRef.id,
        "isRead": false,
        "timestamp": FieldValue.serverTimestamp(),
      });

      // 4. System Push Banner
      await NotificationService.showNotification(
        title: "New Order Alert! (#$shortOrderId)",
        body: "New order received from $customerName worth $formattedAmount.",
        channelId: NotificationService.channelOrders,
      );

      // 5. Payment Routing
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
        await _deductProductStock();
        await _removePurchasedItemsFromCart();

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("Order Placed Successfully!"),
              content: const Text("Thank you! We have received your order and are preparing it for delivery."),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const OrdersPage()),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error placing order: $e"), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => isPlacingOrder = false);
    }
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
                                setState(() => selectedAddress = newAddress);
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
                      Text("Name: ${selectedAddress!['fullName']}", style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text("Email: ${selectedAddress!['emailAddress'] ?? 'N/A'}"),
                      Text(
                        "Contact No: ${selectedAddress!['phoneNumber'] ?? selectedAddress!['mobileNumber'] ?? 'N/A'}",
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "${selectedAddress!['streetBuildingHouseNo']}, ${selectedAddress!['barangay']}, ${selectedAddress!['cityMunicipality']}, ${selectedAddress!['province']} (${selectedAddress!['postalCode'] ?? ''})",
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                          Text("${item['quantity']}x ${item['name']}"),
                          Text("₱${item['price'] * item['quantity']}"),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Amount:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text("₱${widget.totalAmount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)),
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
            onPressed: isPlacingOrder ? null : _placeOrder,
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