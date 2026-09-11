import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'cart_page.dart';
import 'checkout_page.dart';
import 'payment_webview.dart';
import 'orders_page.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/app_localizations.dart';
import 'profile_page.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>().language;
    final local = AppLocalizations(language);

    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: Text(
          local.products,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: ArrozTheme.emerald,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 🔍 SEARCH BAR SECTION
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: ArrozTheme.emerald,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 14, color: ArrozTheme.textDark),
                decoration: InputDecoration(
                  hintText: language == AppLanguage.english ? "Search product..." : "Maghanap ng produkto...",
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(Icons.search, color: Colors.grey.shade600, size: 24),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = "";
                      });
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ),

          // 🌾 PRODUCT GRID (INVENTORIY-BASED)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection("products").snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: ArrozTheme.emerald));
                }

                final allDocs = snapshot.data?.docs ?? [];

                final docs = allDocs.where((doc) {
                  final product = doc.data() as Map<String, dynamic>? ?? {};
                  final isDeleted = product['isDeleted'] == true;
                  final name = (product['name'] ?? '').toString().toLowerCase();

                  return !isDeleted && name.contains(_searchQuery);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? "Walang produktong tumutugma sa \"$_searchQuery\""
                          : "Walang available na produkto sa ngayon.",
                      style: const TextStyle(color: ArrozTheme.textSub),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final product = doc.data() as Map<String, dynamic>;
                    final String imageUrl = product['imageUrl'] ?? '';
                    final int deliveryDays = product['deliveryDays'] ?? 3;

                    final double totalKgStock = ((product['totalKg'] ?? 0.0) as num).toDouble();
                    final double srp = ((product['srpPerKg'] ?? 0.0) as num).toDouble();

                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailPage(product: product, productId: doc.id),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    decoration: const BoxDecoration(
                                      color: ArrozTheme.bgGrey,
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                    ),
                                    child: imageUrl.isNotEmpty
                                        ? ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: Image.network(imageUrl, fit: BoxFit.cover),
                                    )
                                        : const Icon(Icons.agriculture_rounded, size: 48, color: Colors.grey),
                                  ),
                                  if (totalKgStock <= 0)
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text("Out of Stock", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['name'] ?? 'Palay Item',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ArrozTheme.textDark),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "₱${srp.toStringAsFixed(2)} /kg",
                                    style: const TextStyle(color: ArrozTheme.emerald, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Stock: ${totalKgStock.toStringAsFixed(0)} kg",
                                        style: const TextStyle(color: ArrozTheme.textSub, fontSize: 10),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.orange.shade200),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.local_shipping, size: 10, color: ArrozTheme.warningOrange),
                                            const SizedBox(width: 2),
                                            Text("$deliveryDays d", style: const TextStyle(color: ArrozTheme.warningOrange, fontSize: 9, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }
}

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final String productId;

  const ProductDetailPage({super.key, required this.product, required this.productId});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final currentUser = FirebaseAuth.instance.currentUser;

  void _showAddToCartSheet(BuildContext pageContext) {
    int selectedQuantityKg = 1;
    double totalKgStock = ((widget.product['totalKg'] ?? 0.0) as num).toDouble();
    double srp = ((widget.product['srpPerKg'] ?? 0.0) as num).toDouble();

    showModalBottomSheet(
      context: pageContext,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double totalAmount = srp * selectedQuantityKg;

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Pumili ng Dami (Kilo)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ArrozTheme.textDark)),
                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Kabuuan: ₱${totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, color: ArrozTheme.emerald, fontWeight: FontWeight.bold)),
                          Text("Presyo: ₱${srp.toStringAsFixed(2)} / kg", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () { if (selectedQuantityKg > 1) setSheetState(() => selectedQuantityKg--); },
                              icon: const Icon(Icons.remove, color: ArrozTheme.emerald, size: 18),
                            ),
                            Text("$selectedQuantityKg kg", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            IconButton(
                              onPressed: () {
                                if ((selectedQuantityKg + 1) <= totalKgStock) {
                                  setSheetState(() => selectedQuantityKg++);
                                }
                              },
                              icon: const Icon(Icons.add, color: ArrozTheme.emerald, size: 18),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ArrozTheme.warningOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: totalKgStock <= 0 ? null : () async {
                        if (currentUser == null) return;
                        Navigator.pop(sheetContext);

                        await FirebaseFirestore.instance
                            .collection("cart")
                            .doc("${currentUser!.uid}_${widget.productId}")
                            .set({
                          "userId": currentUser!.uid,
                          "productId": widget.productId,
                          "name": widget.product["name"],
                          "price": srp,
                          "imageUrl": widget.product["imageUrl"] ?? "",
                          "quantity": selectedQuantityKg,
                          "addedAt": FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                        if (pageContext.mounted) {
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            const SnackBar(content: Text("Naidagdag na sa Cart!"), backgroundColor: ArrozTheme.warningOrange),
                          );
                          Navigator.of(pageContext).push(MaterialPageRoute(builder: (_) => const CartPage()));
                        }
                      },
                      child: Text(totalKgStock <= 0 ? "Out of Stock" : "Add to Cart", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPaymentSheet(BuildContext pageContext, int initialQty) {
    int selectedQuantityKg = initialQty;
    double totalKgStock = ((widget.product['totalKg'] ?? 0.0) as num).toDouble();
    double srp = ((widget.product['srpPerKg'] ?? 0.0) as num).toDouble();

    showModalBottomSheet(
      context: pageContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double totalAmount = srp * selectedQuantityKg;

            return Padding(
              padding: EdgeInsets.only(
                top: 20, left: 20, right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Buy Now Options", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ArrozTheme.textDark)),
                  const Divider(),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Dami sa Kilo (kg):", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () { if (selectedQuantityKg > 1) setSheetState(() => selectedQuantityKg--); },
                            icon: const Icon(Icons.remove_circle_outline, color: ArrozTheme.emerald),
                          ),
                          Text("$selectedQuantityKg kg", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: () {
                              if ((selectedQuantityKg + 1) <= totalKgStock) {
                                setSheetState(() => selectedQuantityKg++);
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline, color: ArrozTheme.emerald),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text("Kabuuan: ₱${totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, color: ArrozTheme.emerald, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ArrozTheme.emerald,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: totalKgStock <= 0 ? null : () {
                        if (currentUser == null) return;
                        Navigator.pop(sheetContext);

                        Navigator.of(pageContext).push(
                          MaterialPageRoute(
                            builder: (_) => CheckoutPage(
                              initialAddress: null,
                              orderItems: [
                                {
                                  "productId": widget.productId,
                                  "name": widget.product['name'],
                                  "price": srp,
                                  "quantity": selectedQuantityKg,
                                  "subtotal": totalAmount,
                                  "imageUrl": widget.product["imageUrl"] ?? "",
                                }
                              ],
                              totalAmount: totalAmount,
                            ),
                          ),
                        );
                      },
                      child: Text(totalKgStock <= 0 ? "Out of Stock" : "Proceed to Checkout", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
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
    final String imageUrl = widget.product['imageUrl'] ?? '';
    final int deliveryDays = widget.product['deliveryDays'] ?? 3;
    final double totalKgStock = ((widget.product['totalKg'] ?? 0.0) as num).toDouble();
    final double srp = ((widget.product['srpPerKg'] ?? 0.0) as num).toDouble();

    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: Text(widget.product['name'] ?? 'Product Details'),
        backgroundColor: ArrozTheme.emerald,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 280,
              width: double.infinity,
              color: Colors.white,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover)
                  : const Icon(Icons.agriculture_rounded, size: 80, color: Colors.grey),
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "₱${srp.toStringAsFixed(2)}",
                        style: const TextStyle(color: ArrozTheme.emerald, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        " / kg",
                        style: TextStyle(color: ArrozTheme.emerald, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(widget.product['name'] ?? 'Palay Item', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ArrozTheme.textDark)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping, size: 14, color: ArrozTheme.warningOrange),
                            const SizedBox(width: 4),
                            Text("Ships in $deliveryDays days", style: const TextStyle(fontSize: 12, color: ArrozTheme.warningOrange, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: ArrozTheme.bgGrey, borderRadius: BorderRadius.circular(6)),
                        child: Text("Stock: ${totalKgStock.toStringAsFixed(0)} kg", style: const TextStyle(fontSize: 12, color: ArrozTheme.textSub)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Detalye ng Palay", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ArrozTheme.textDark)),
                  const SizedBox(height: 8),
                  Text("Uri: ${widget.product['type'] ?? 'N/A'}", style: const TextStyle(fontSize: 13, color: ArrozTheme.textDark)),
                  const SizedBox(height: 4),
                  Text("Kondisyon: ${widget.product['condition'] ?? 'N/A'}", style: const TextStyle(fontSize: 13, color: ArrozTheme.textDark)),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ArrozTheme.warningOrange, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showAddToCartSheet(context),
                  child: const Text("Add to Cart", style: TextStyle(color: ArrozTheme.warningOrange, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ArrozTheme.emerald,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showPaymentSheet(context, 1),
                  child: const Text("Buy Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}