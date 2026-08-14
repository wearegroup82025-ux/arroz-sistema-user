import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/app_localizations.dart';
import 'profile_page.dart';

class OrderDetailsPage extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailsPage({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return 'N/A';

    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Completed':
        return ArrozTheme.emerald;

      case 'Cancelled':
        return ArrozTheme.dangerRed;

      case 'To Deliver':
        return Colors.blue.shade700;

      case 'Paid':
      case 'To Ship':
        return Colors.orange.shade700;

      case 'Pending':
      case 'Unpaid':
      default:
        return Colors.orange;
    }
  }

  String _displayStatus(
      String status,
      bool isPaid,
      ) {
    if (status == 'Completed') {
      return 'Completed';
    }

    if (status == 'Cancelled') {
      return 'Cancelled';
    }

    if (status == 'To Deliver') {
      return 'To Deliver';
    }

    if (status == 'To Ship' || status == 'Paid') {
      return 'To Ship';
    }

    if (isPaid) {
      return 'To Ship';
    }

    return 'To Pay';
  }

  Widget _infoRow(
      String label,
      String value, {
        IconData? icon,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 19,
              color: ArrozTheme.emerald,
            ),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: ArrozTheme.textSub,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
      String title,
      IconData icon,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 21,
          color: ArrozTheme.emerald,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String customerName =
        orderData['customerName']?.toString() ?? 'N/A';

    final String deliveryAddress =
        orderData['deliveryAddress']?.toString() ?? 'N/A';

    final String emailAddress =
        orderData['emailAddress']?.toString() ?? 'N/A';

    final String phoneNumber =
        orderData['phoneNumber']?.toString() ?? 'N/A';

    final String paymentMethod =
        orderData['paymentMethod']?.toString() ?? 'N/A';

    final String status =
        orderData['orderStatus']?.toString() ??
            orderData['status']?.toString() ??
            'Pending';

    final bool isPaid =
        orderData['isPaid'] == true;

    final num totalAmount =
        orderData['totalAmount'] ?? 0;

    final List<dynamic> items =
    orderData['items'] is List
        ? orderData['items']
        : [];

    final String displayStatus =
    _displayStatus(status, isPaid);

    final Color statusColor =
    _statusColor(displayStatus);

    return Scaffold(
      backgroundColor: ArrozTheme.bgGrey,
      appBar: AppBar(
        title: const Text(
          'Order Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: ArrozTheme.emerald,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [

            // ============================================================
            // ORDER SUMMARY
            // ============================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [

                      // STATUS - LEFT
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius:
                          BorderRadius.circular(6),
                        ),
                        child: Text(
                          displayStatus,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // DATE - RIGHT
                      Text(
                        _formatDate(
                          orderData['createdAt'],
                        ),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ArrozTheme.textSub,
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 25),

                  Text(
                    'Order ID',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ArrozTheme.textSub,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    orderId,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ============================================================
            // CUSTOMER / CONTACT DETAILS
            // ============================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [

                  _sectionTitle(
                    'Customer Information',
                    Icons.person_outline,
                  ),

                  const SizedBox(height: 12),

                  _infoRow(
                    'Name',
                    customerName,
                    icon: Icons.person,
                  ),

                  _infoRow(
                    'Email',
                    emailAddress,
                    icon: Icons.email_outlined,
                  ),

                  _infoRow(
                    'Phone',
                    phoneNumber,
                    icon: Icons.phone_outlined,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ============================================================
            // DELIVERY ADDRESS
            // ============================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [

                  _sectionTitle(
                    'Delivery Address',
                    Icons.location_on_outlined,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    deliveryAddress,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ============================================================
            // PAYMENT INFORMATION
            // ============================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [

                  _sectionTitle(
                    'Payment Information',
                    Icons.payment_outlined,
                  ),

                  const SizedBox(height: 12),

                  _infoRow(
                    'Payment Method',
                    paymentMethod,
                    icon: Icons.account_balance_wallet_outlined,
                  ),

                  _infoRow(
                    'Payment Status',
                    isPaid ? 'Paid' : 'Unpaid',
                    icon: isPaid
                        ? Icons.check_circle_outline
                        : Icons.pending_outlined,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ============================================================
            // ORDER ITEMS
            // ============================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [

                  _sectionTitle(
                    'Order Items',
                    Icons.shopping_bag_outlined,
                  ),

                  const SizedBox(height: 12),

                  if (items.isEmpty)
                    const Text(
                      'No items found.',
                      style: TextStyle(
                        color: ArrozTheme.textSub,
                      ),
                    ),

                  ...items.map((item) {
                    final Map<String, dynamic> itemData =
                    Map<String, dynamic>.from(item);

                    final String name =
                        itemData['name']?.toString() ??
                            'Item';

                    final num price =
                        itemData['price'] ?? 0;

                    final num quantity =
                        itemData['quantity'] ?? 1;

                    final num subtotal =
                        itemData['subtotal'] ??
                            (price * quantity);

                    return Container(
                      margin: const EdgeInsets.only(
                        bottom: 10,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: ArrozTheme.bgGrey,
                        borderRadius:
                        BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [

                          Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons
                                  .inventory_2_outlined,
                              color:
                              ArrozTheme.emerald,
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [

                                Text(
                                  name,
                                  style:
                                  const TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                Text(
                                  '₱${price.toStringAsFixed(2)} × $quantity',
                                  style:
                                  const TextStyle(
                                    fontSize: 12,
                                    color:
                                    ArrozTheme.textSub,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Text(
                            '₱${subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight:
                              FontWeight.bold,
                              color:
                              ArrozTheme.emerald,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const Divider(height: 20),

                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [

                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        '₱${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ArrozTheme.emerald,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}