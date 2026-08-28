import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'address_picker.dart';
import 'checkout_page.dart';
import 'package:provider/provider.dart';

import '../../providers/language_provider.dart';
import '../../services/app_localizations.dart';
import 'profile_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final Set<String> _selectedItemIds = {};
  final User? currentUser = FirebaseAuth.instance.currentUser;

  void _proceedToCheckout(
      List<QueryDocumentSnapshot> selectedDocs,
      double totalAmount,
      ) {
    List<Map<String, dynamic>> orderItems = selectedDocs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String variation = data['variation'] ?? 'Kilo';
      final String productName = data['name'] ?? 'Item';

      return {
        'productId': data['productId'] ?? doc.id,
        'name': "$productName ($variation)",
        'price': (data['price'] ?? 0.0).toDouble(),
        'variation': variation,
        'quantity': data['quantity'] ?? 1,
        'imageUrl': data['imageUrl'] ?? '',
        'cartDocId': doc.id,
      };
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          orderItems: orderItems,
          totalAmount: totalAmount,
        ),
      ),
    );
  }

  void _updateQuantity(String docId, int currentQty, int change) {
    int newQty = currentQty + change;
    if (newQty > 0) {
      FirebaseFirestore.instance.collection("cart").doc(docId).update({
        'quantity': newQty,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>().language;
    final local = AppLocalizations(language);

    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: ArrozTheme.bgGrey,
        body: Center(child: Text("Mangyaring mag-log in muna.")),
      );
    }

    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: Text(local.myCart, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: ArrozTheme.emerald,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("cart")
            .where("userId", isEqualTo: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(local.emptyCart, style: const TextStyle(color: ArrozTheme.textSub, fontSize: 15)),
                ],
              ),
            );
          }

          final cartDocs = snapshot.data!.docs;
          double totalAmount = 0;
          List<QueryDocumentSnapshot> selectedDocs = [];

          for (var doc in cartDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final double price = (data['price'] ?? 0.0).toDouble();
            final int quantity = data['quantity'] ?? 1;

            if (_selectedItemIds.contains(doc.id)) {
              selectedDocs.add(doc);
              totalAmount += (price * quantity);
            }
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: cartDocs.length,
                  itemBuilder: (context, index) {
                    final doc = cartDocs[index];
                    final item = doc.data() as Map<String, dynamic>;
                    final bool isChecked = _selectedItemIds.contains(doc.id);

                    final double price = (item['price'] ?? 0.0).toDouble();
                    final int quantity = item['quantity'] ?? 1;
                    final String variation = item['variation'] ?? 'Kilo';
                    final String imageUrl = item['imageUrl'] ?? '';

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            activeColor: ArrozTheme.emerald,
                            value: isChecked,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedItemIds.add(doc.id);
                                } else {
                                  _selectedItemIds.remove(doc.id);
                                }
                              });
                            },
                          ),
                          
                          // Product Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imageUrl.isNotEmpty
                                ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                                : Container(
                                    width: 50,
                                    height: 50,
                                    color: ArrozTheme.bgGrey,
                                    child: const Icon(Icons.image, size: 24, color: Colors.grey),
                                  ),
                          ),
                          const SizedBox(width: 10),

                          // Product Info & Variation Tag
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? 'Item',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ArrozTheme.textDark),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ArrozTheme.emerald.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        variation.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: ArrozTheme.emerald,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "₱${price.toStringAsFixed(2)}",
                                      style: const TextStyle(color: ArrozTheme.textSub, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Quantity Controls
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _updateQuantity(doc.id, quantity, -1),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.remove, size: 14, color: ArrozTheme.textDark),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text("$quantity", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                    InkWell(
                                      onTap: () => _updateQuantity(doc.id, quantity, 1),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(Icons.add, size: 14, color: ArrozTheme.textDark),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Subtotal & Delete
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "₱${(price * quantity).toStringAsFixed(2)}",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: ArrozTheme.emerald, fontSize: 14),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: ArrozTheme.dangerRed, size: 18),
                                onPressed: () => FirebaseFirestore.instance.collection("cart").doc(doc.id).delete(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Checkout Panel
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(local.total, style: const TextStyle(fontSize: 12, color: ArrozTheme.textSub)),
                        Text(
                          "₱${totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ArrozTheme.emerald),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ArrozTheme.emerald,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        if (selectedDocs.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(local.selectItemFirst),
                            ),
                          );
                        } else {
                          _proceedToCheckout(
                            selectedDocs,
                            totalAmount,
                          );
                        }
                      },
                      child: Text(
                        local.checkoutCart,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}