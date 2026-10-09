import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'cart_page.dart';
import 'checkout_page.dart';
import '../../providers/language_provider.dart';
import '../../services/app_localizations.dart';
import 'package:provider/provider.dart';

/// Common Helper Widget para sa Pag-render ng Larawan ng Produkto
Widget _buildProductImage(String url, {double? size, BoxFit fit = BoxFit.cover}) {
  final cleanUrl = url.trim();

  if (cleanUrl.isEmpty) {
    return Icon(Icons.agriculture_rounded, size: size ?? 48, color: Colors.grey);
  }

  if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
    return Image.network(
      cleanUrl,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (ctx, err, stack) => Icon(Icons.agriculture_rounded, size: size ?? 48, color: Colors.grey),
      loadingBuilder: (ctx, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF16A34A), strokeWidth: 2),
        );
      },
    );
  }

  final file = File(cleanUrl);
  if (file.existsSync()) {
    return Image.file(
      file,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (ctx, err, stack) => Icon(Icons.agriculture_rounded, size: size ?? 48, color: Colors.grey),
    );
  }

  return Icon(Icons.agriculture_rounded, size: size ?? 48, color: Colors.grey);
}

double _toDouble(dynamic value, [double fallback = 0.0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int _toInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _toStringList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }
  return <String>[];
}

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

  /// FIFO Logic & Grouping (Inayos: Live remainingKg na ang ginagamit)
  List<Map<String, dynamic>> _processFifoProducts(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> allBatches = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      if (data['isDeleted'] == true) continue;

      final String docId = doc.id;
      final String type = data['type']?.toString() ?? 'N/A';
      final List breakdowns = data['breakdowns'] is List ? List.from(data['breakdowns']) : <dynamic>[];
      final Timestamp? createdAt = data['createdAt'] as Timestamp?;
      final String imageUrl = data['imageUrl']?.toString() ?? '';
      final List<String> imageUrls = _toStringList(data['imageUrls']);
      final List<String> safeImageUrls = imageUrls.isNotEmpty
          ? imageUrls
          : (imageUrl.isNotEmpty ? [imageUrl] : <String>[]);
      final String description = data['description']?.toString() ?? '';
      final double rating = ((data['rating'] ?? data['averageRating'] ?? 0.0) as num).toDouble();
      final int totalSold = _toInt(data['totalSold'] ?? data['sold']);

      // INAYOS: Kunin ang live remainingKg mula sa document level
      final double docRemainingKg = _toDouble(data['remainingKg'] ?? data['stock'] ?? data['initialKg']);

      for (int i = 0; i < breakdowns.length; i++) {
        final b = breakdowns[i];
        final double bSrp = _toDouble(b['srp']);
        final String condition = b['condition']?.toString() ?? 'N/A';

        // Kapag singular ang breakdown, gagamitin ang aktuwal na live remainingKg
        final double bKg = breakdowns.length == 1 ? docRemainingKg : _toDouble(b['kg']);

        final String displayName = "$type Palay ($condition)";
        final String groupKey = "${type}_$condition".toLowerCase().replaceAll(" ", "");

        allBatches.add({
          'docId': docId,
          'breakdownIndex': i,
          'groupKey': groupKey,
          'displayName': displayName,
          'type': type,
          'condition': condition,
          'srpPerKg': bSrp,
          'remainingKg': bKg,
          'imageUrl': imageUrl,
          'imageUrls': safeImageUrls,
          'description': description,
          'deliveryDays': data['deliveryDays'] ?? 3,
          'createdAt': createdAt?.toDate() ?? DateTime.now(),
          'rating': rating,
          'totalSold': totalSold,
        });
      }
    }

    allBatches.sort((a, b) => (a['createdAt'] as DateTime).compareTo(b['createdAt'] as DateTime));

    Map<String, Map<String, dynamic>> activeGroupedMap = {};

    for (var item in allBatches) {
      String key = item['groupKey'];

      if (!activeGroupedMap.containsKey(key)) {
        if (item['remainingKg'] > 0) {
          activeGroupedMap[key] = item;
        }
      } else {
        if (activeGroupedMap[key]!['remainingKg'] <= 0 && item['remainingKg'] > 0) {
          activeGroupedMap[key] = item;
        }
      }
    }

    for (var item in allBatches) {
      String key = item['groupKey'];
      if (!activeGroupedMap.containsKey(key)) {
        activeGroupedMap[key] = item;
      }
    }

    return activeGroupedMap.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>().language;
    final local = AppLocalizations(language);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          local.products,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
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
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection("products").snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
                }

                final rawDocs = snapshot.data?.docs ?? [];
                final processedProducts = _processFifoProducts(rawDocs);

                final filteredProducts = processedProducts.where((prod) {
                  final name = (prod['displayName'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? "Walang produktong tumutugma sa \"$_searchQuery\""
                          : "Walang available na produkto sa ngayon.",
                      style: const TextStyle(color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final String imageUrl = product['imageUrl'] ?? '';
                    final int deliveryDays = _toInt(product['deliveryDays'], 3);
                    final double totalKgStock = _toDouble(product['remainingKg']);
                    final double srp = _toDouble(product['srpPerKg']);
                    final int totalSold = _toInt(product['totalSold']);

                    return InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductDetailPage(
                              product: product,
                              productId: product['docId'],
                            ),
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
                                      color: Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: _buildProductImage(imageUrl, size: 48),
                                    ),
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
                                        child: const Text("Out of Stock",
                                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                    product['displayName'] ?? 'Palay Item',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "₱${srp.toStringAsFixed(2)} /kg",
                                    style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$totalSold sold",
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Stock: ${totalKgStock.toStringAsFixed(0)} kg",
                                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
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
                                            const Icon(Icons.local_shipping, size: 10, color: Color(0xFFD97706)),
                                            const SizedBox(width: 2),
                                            Text("$deliveryDays d",
                                                style: const TextStyle(color: Color(0xFFD97706), fontSize: 9, fontWeight: FontWeight.bold)),
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

class _ProductImageGallery extends StatefulWidget {
  final List<String> imageUrls;

  const _ProductImageGallery({required this.imageUrls});

  @override
  State<_ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<_ProductImageGallery> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;

    if (urls.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        color: Colors.white,
        child: const Center(
          child: Icon(Icons.agriculture_rounded, size: 80, color: Colors.grey),
        ),
      );
    }

    return Container(
      height: 330,
      width: double.infinity,
      color: Colors.white,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openFullScreen(context, urls, index),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildProductImage(urls[index], size: 70, fit: BoxFit.contain),
                ),
              );
            },
          ),
          if (urls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(urls.length, (index) {
                  final selected = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: selected ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF16A34A) : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }),
              ),
            ),
          if (urls.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentPage + 1}/${urls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenProductGallery(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _FullScreenProductGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenProductGallery({required this.imageUrls, required this.initialIndex});

  @override
  State<_FullScreenProductGallery> createState() => _FullScreenProductGalleryState();
}

class _FullScreenProductGalleryState extends State<_FullScreenProductGallery> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1}/${widget.imageUrls.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) => setState(() => _current = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: _buildProductImage(widget.imageUrls[index], size: 60, fit: BoxFit.contain),
            ),
          );
        },
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
    double totalKgStock = _toDouble(widget.product['remainingKg']);
    double srp = _toDouble(widget.product['srpPerKg']);

    final TextEditingController quantityController =
        TextEditingController(text: selectedQuantityKg.toString());

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
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Pumili ng Dami (Kilo)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Kabuuan: ₱${totalAmount.toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 16, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                          Text("Presyo: ₱${srp.toStringAsFixed(2)} / kg", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (selectedQuantityKg > 1) {
                                  setSheetState(() {
                                    selectedQuantityKg--;
                                    quantityController.text = selectedQuantityKg.toString();
                                  });
                                }
                              },
                              icon: const Icon(Icons.remove, color: Color(0xFF16A34A), size: 18),
                            ),
                            SizedBox(
                              width: 60,
                              child: TextField(
                                controller: quantityController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  suffixText: 'kg',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                  int? parsed = int.tryParse(val);
                                  if (parsed != null && parsed > 0) {
                                    if (parsed > totalKgStock) {
                                      parsed = totalKgStock.toInt();
                                      quantityController.text = parsed.toString();
                                      quantityController.selection = TextSelection.fromPosition(
                                        TextEditingValue(text: quantityController.text).selection.base,
                                      );
                                    }
                                    setSheetState(() {
                                      selectedQuantityKg = parsed!;
                                    });
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                if ((selectedQuantityKg + 1) <= totalKgStock) {
                                  setSheetState(() {
                                    selectedQuantityKg++;
                                    quantityController.text = selectedQuantityKg.toString();
                                  });
                                }
                              },
                              icon: const Icon(Icons.add, color: Color(0xFF16A34A), size: 18),
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
                        backgroundColor: const Color(0xFFD97706),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: totalKgStock <= 0
                          ? null
                          : () async {
                              if (currentUser == null) return;
                              Navigator.pop(sheetContext);

                              await FirebaseFirestore.instance
                                  .collection("cart")
                                  .doc("${currentUser!.uid}_${widget.productId}_${widget.product['breakdownIndex']}")
                                  .set({
                                "userId": currentUser!.uid,
                                "productId": widget.productId,
                                "breakdownIndex": widget.product['breakdownIndex'],
                                "name": widget.product["displayName"],
                                "price": srp,
                                "imageUrl": (widget.product["imageUrls"] is List && (widget.product["imageUrls"] as List).isNotEmpty)
                                    ? (widget.product["imageUrls"] as List).first.toString()
                                    : (widget.product["imageUrl"]?.toString() ?? ""),
                                "quantity": selectedQuantityKg,
                                "addedAt": FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                              if (pageContext.mounted) {
                                ScaffoldMessenger.of(pageContext).showSnackBar(
                                  const SnackBar(content: Text("Naidagdag na sa Cart!"), backgroundColor: Color(0xFFD97706)),
                                );
                                Navigator.of(pageContext).push(MaterialPageRoute(builder: (_) => const CartPage()));
                              }
                            },
                      child: Text(totalKgStock <= 0 ? "Out of Stock" : "Add to Cart",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    double totalKgStock = _toDouble(widget.product['remainingKg']);
    double srp = _toDouble(widget.product['srpPerKg']);

    final TextEditingController quantityController =
        TextEditingController(text: selectedQuantityKg.toString());

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
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Buy Now Options", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Dami sa Kilo (kg):", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (selectedQuantityKg > 1) {
                                setSheetState(() {
                                  selectedQuantityKg--;
                                  quantityController.text = selectedQuantityKg.toString();
                                });
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF16A34A)),
                          ),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                suffixText: 'kg',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                int? parsed = int.tryParse(val);
                                if (parsed != null && parsed > 0) {
                                  if (parsed > totalKgStock) {
                                    parsed = totalKgStock.toInt();
                                    quantityController.text = parsed.toString();
                                    quantityController.selection = TextSelection.fromPosition(
                                      TextEditingValue(text: quantityController.text).selection.base,
                                    );
                                  }
                                  setSheetState(() {
                                    selectedQuantityKg = parsed!;
                                  });
                                }
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if ((selectedQuantityKg + 1) <= totalKgStock) {
                                setSheetState(() {
                                  selectedQuantityKg++;
                                  quantityController.text = selectedQuantityKg.toString();
                                });
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF16A34A)),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text("Kabuuan: ₱${totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(fontSize: 16, color: Color(0xFF16A34A), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: totalKgStock <= 0
                          ? null
                          : () {
                              if (currentUser == null) return;
                              Navigator.pop(sheetContext);

                              Navigator.of(pageContext).push(
                                MaterialPageRoute(
                                  builder: (_) => CheckoutPage(
                                    initialAddress: null,
                                    orderItems: [
                                      {
                                        "productId": widget.productId,
                                        "breakdownIndex": widget.product['breakdownIndex'],
                                        "name": widget.product['displayName'],
                                        "price": srp,
                                        "quantity": selectedQuantityKg,
                                        "subtotal": totalAmount,
                                        "imageUrl": (widget.product["imageUrls"] is List && (widget.product["imageUrls"] as List).isNotEmpty)
                                    ? (widget.product["imageUrls"] as List).first.toString()
                                    : (widget.product["imageUrl"]?.toString() ?? ""),
                                      }
                                    ],
                                    totalAmount: totalAmount,
                                  ),
                                ),
                              );
                            },
                      child: Text(totalKgStock <= 0 ? "Out of Stock" : "Proceed to Checkout",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _buildReviewsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("reviews")
          .where("productId", isEqualTo: widget.productId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Color(0xFF16A34A)),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Product Ratings & Reviews", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                SizedBox(height: 8),
                Text("Wala pang mga review para sa produktong ito.", style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ],
            ),
          );
        }

        double totalRating = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalRating += (data['rating'] ?? 0.0) as num;
        }
        double avgRating = totalRating / docs.length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Product Ratings & Reviews", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),

              Row(
                children: [
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < avgRating.round() ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                      ),
                      Text(
                        "${docs.length} (na) review",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 20),
                itemBuilder: (context, index) {
                  final review = docs[index].data() as Map<String, dynamic>;
                  final String userName = review['userName'] ?? 'Buyer';
                  final double rating = ((review['rating'] ?? 5.0) as num).toDouble();
                  final String comment = review['comment'] ?? review['reviewComment'] ?? '';
                  final Timestamp? createdAt = review['createdAt'] as Timestamp?;

                  String dateStr = "";
                  if (createdAt != null) {
                    final date = createdAt.toDate();
                    dateStr = "${date.month}/${date.day}/${date.year}";
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: const Color(0xFF16A34A).withOpacity(0.2),
                                child: Text(
                                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(userName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                          Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          );
                        }),
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          comment,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("products").doc(widget.productId).snapshots(),
      builder: (context, snapshot) {
        final docData = snapshot.data?.data() as Map<String, dynamic>? ?? {};

        final String imageUrl = docData['imageUrl']?.toString() ??
            widget.product['imageUrl']?.toString() ?? '';

        List<String> breakdownImageUrls = <String>[];
        final dynamic rawBreakdowns = docData['breakdowns'];
        final int breakdownIndex = _toInt(widget.product['breakdownIndex']);
        if (rawBreakdowns is List &&
            breakdownIndex >= 0 &&
            breakdownIndex < rawBreakdowns.length &&
            rawBreakdowns[breakdownIndex] is Map) {
          final breakdown = Map<String, dynamic>.from(rawBreakdowns[breakdownIndex] as Map);
          breakdownImageUrls = _toStringList(breakdown['imageUrls']);
          if (breakdownImageUrls.isEmpty && breakdown['imageUrl'] != null) {
            final one = breakdown['imageUrl'].toString().trim();
            if (one.isNotEmpty) breakdownImageUrls = [one];
          }
        }

        final List<String> rawImageUrls = _toStringList(
          docData['imageUrls'] ?? widget.product['imageUrls'],
        );
        final List<String> imageUrls = breakdownImageUrls.isNotEmpty
            ? breakdownImageUrls
            : (rawImageUrls.isNotEmpty
                ? rawImageUrls
                : (imageUrl.isNotEmpty ? [imageUrl] : <String>[]));
        final String description = docData['description'] ?? widget.product['description'] ?? '';
        final int deliveryDays = _toInt(docData['deliveryDays'] ?? widget.product['deliveryDays'], 3);
        final double totalKgStock = _toDouble(docData['remainingKg'] ?? widget.product['remainingKg']);
        final double srp = _toDouble(docData['srpPerKg'] ?? widget.product['srpPerKg']);
        final double rating = ((docData['rating'] ?? widget.product['rating'] ?? 0.0) as num).toDouble();
        final int totalSold = _toInt(docData['totalSold'] ?? docData['sold'] ?? widget.product['totalSold']);

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(widget.product['displayName'] ?? 'Product Details'),
            backgroundColor: const Color(0xFF16A34A),
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductImageGallery(imageUrls: imageUrls),
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
                            style: const TextStyle(color: Color(0xFF16A34A), fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            " / kg",
                            style: TextStyle(color: Color(0xFF16A34A), fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(widget.product['displayName'] ?? 'Palay Item',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                rating > 0 ? rating.toStringAsFixed(1) : "Walang rating",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "$totalSold (na) kabuuang order",
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: [
                                const Icon(Icons.local_shipping, size: 14, color: Color(0xFFD97706)),
                                const SizedBox(width: 4),
                                Text("Ships in $deliveryDays days",
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
                            child: Text("Stock: ${totalKgStock.toStringAsFixed(0)} kg",
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                      const Text("Detalye ng Palay", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      Text("Uri: ${widget.product['type'] ?? 'N/A'}", style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text("Kondisyon: ${widget.product['condition'] ?? 'N/A'}", style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text("Deskripsyon:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                _buildReviewsSection(),

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
                        side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showAddToCartSheet(context),
                      child: const Text("Add to Cart", style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
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
      },
    );
  }
}