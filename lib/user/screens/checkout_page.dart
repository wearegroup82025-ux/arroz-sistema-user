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

  double distanceInKm = 0.0;
  double shippingFee = 0.0;
  bool isCalculatingShipping = false;

  // Main Store Coordinates (Default: San Jose del Monte)
  final Map<String, dynamic> storeLocation = {
    'storeName': 'Main Warehouse',
    'latitude': 14.8138, 
    'longitude': 121.0453,
  };

  final TextEditingController _voucherController = TextEditingController();
  double voucherDiscount = 0.0;
  String? appliedVoucherCode;
  bool isApplyingVoucher = false;

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

  double get totalPalayKg {
    double total = 0.0;
    for (var item in widget.orderItems) {
      final qty = (item['quantity'] as num? ?? 1).toDouble();
      total += qty;
    }
    return total;
  }

  /// Dynamic Shipping Calculation
  Future<void> _updateDistanceAndShippingFee() async {
    if (selectedAddress == null) return;

    setState(() => isCalculatingShipping = true);

    try {
      final summary = await DistanceService.computeDeliverySummary(
        storeData: storeLocation,
        userAddress: selectedAddress!,
      );

      double calculatedKm = (summary['distanceKm'] as num).toDouble();
      
      // Affordable Shipping Rates:
      double baseFare = 40.0;      // ₱40 base fee
      double ratePerKm = 5.0;      // ₱5/km
      double ratePerKg = 0.50;     // ₱0.50 kada kilo ng palay

      double calculatedShipping = baseFare + (calculatedKm * ratePerKm) + (totalPalayKg * ratePerKg);

      // MAXIMUM SHIPPING FEE CAP: Limitado sa maximum na ₱300 para abot-kaya
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

    final snapshot = await FirebaseFirestore.instance
        .collection("orders")
        .where("userId", isEqualTo: user.uid)
        .where("orderStatus", isEqualTo: "Completed")
        .get();

    if (mounted) {
      setState(() {
        completedOrderCount = snapshot.docs.length;
        if (completedOrderCount >= 3) {
          loyaltyDiscount = widget.totalAmount * 0.05;
        } else {
          loyaltyDiscount = 0.0;
        }
      });
    }
  }

  Future<void> _applyVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) return;

    setState(() => isApplyingVoucher = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('vouchers')
          .where('code', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Hindi valid o expired na ang voucher code.")),
          );
        }
        return;
      }

      final voucherData = snapshot.docs.first.data();
      final double discountVal = (voucherData['discountValue'] ?? 0).toDouble();
      final String discountType = voucherData['discountType'] ?? 'fixed';
      final double minSpend = (voucherData['minSpend'] ?? 0).toDouble();

      if (widget.totalAmount < minSpend) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Kailangan ng minimum spend na ₱$minSpend para sa voucher na ito.")),
          );
        }
        return;
      }

      double calculated = 0.0;
      if (discountType == 'percentage') {
        calculated = widget.totalAmount * (discountVal / 100);
      } else {
        calculated = discountVal;
      }

      setState(() {
        voucherDiscount = calculated;
        appliedVoucherCode = code;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Voucher applied! Nakatipid ka ng ₱${calculated.toStringAsFixed(2)}"),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sa voucher: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isApplyingVoucher = false);
    }
  }

  double get totalDiscount => loyaltyDiscount + voucherDiscount;

  double get finalTotal {
    double itemTotalAfterDiscount = widget.totalAmount - totalDiscount;
    if (itemTotalAfterDiscount < 0) itemTotalAfterDiscount = 0.0;
    return itemTotalAfterDiscount + shippingFee;
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
      _updateDistanceAndShippingFee();
    }
  }

  Future<void> _deductProductStock() async {
    final batch = FirebaseFirestore.instance.batch();

    for (final item in widget.orderItems) {
      final productId = item['productId'];
      final quantityOrdered = item['quantity'] as num? ?? 1;

      if (productId != null && productId.toString().isNotEmpty) {
        final productRef = FirebaseFirestore.instance.collection('products').doc(productId);
        batch.update(productRef, {
          'totalKg': FieldValue.increment(-quantityOrdered)
        });
      }
    }

    await batch.commit();
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

      final orderRef = await FirebaseFirestore.instance.collection("orders").add({
        "userId": user.uid,
        "customerName": customerName,
        "emailAddress": selectedAddress!['emailAddress'],
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
        "voucherDiscount": voucherDiscount,
        "voucherCode": appliedVoucherCode ?? "",
        "totalAmount": finalTotal,
        "totalPalayKg": totalPalayKg,
        "paymentMethod": paymentMethod,
        "isPaid": false,
        "orderStatus": isOnlinePayment ? "Unpaid" : "Pending",
        "createdAt": FieldValue.serverTimestamp(),
      });

      await _deductProductStock();
      await _removePurchasedItemsFromCart();

      final shortOrderId = orderRef.id.substring(0, 6);
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
                    Row(
                      children: [
                        Icon(Icons.confirmation_number_outlined, color: primaryColor),
                        const SizedBox(width: 8),
                        const Text("Vouchers & Diskwento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const Divider(),

                    if (completedOrderCount >= 3) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Suki Customer Perk: May 5% Loyalty Discount ka dahil sa iyong $completedOrderCount completed orders!",
                                style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _voucherController,
                            decoration: const InputDecoration(
                              hintText: "Enter Voucher Code (e.g. PALAY100)",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                          onPressed: isApplyingVoucher ? null : _applyVoucher,
                          child: isApplyingVoucher
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Apply", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    if (appliedVoucherCode != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          const SizedBox(width: 4),
                          Text("Voucher '$appliedVoucherCode' applied!", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                appliedVoucherCode = null;
                                voucherDiscount = 0.0;
                                _voucherController.clear();
                              });
                            },
                            child: const Text("Remove", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
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
                          Text("${item['quantity']} kg x ${item['name']}"),
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
                    if (voucherDiscount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Voucher Discount:", style: TextStyle(color: Colors.green)),
                          Text("-₱${voucherDiscount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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