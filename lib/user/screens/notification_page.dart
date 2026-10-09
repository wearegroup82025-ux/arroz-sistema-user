import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cart_page.dart';
import 'orders_page.dart';
import 'product_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _notifications {
    final uid = _userId;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications');
  }

  Future<void> _markAllAsRead() async {
    final uid = _userId;
    if (uid == null) return;

    try {
      final result = await _notifications
          .where('isRead', isEqualTo: false)
          .get();

      if (result.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in result.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lahat ng notification ay minarkahang nabasa.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hindi ma-mark as read: $e')),
      );
    }
  }

  Future<void> _deleteAllNotifications() async {
    final uid = _userId;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.red),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete All Notifications',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Sigurado ka bang buburahin ang lahat ng notifications? '
          'Hindi na ito maaaring i-undo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      while (true) {
        final result = await _notifications.limit(450).get();
        if (result.docs.isEmpty) break;

        final batch = FirebaseFirestore.instance.batch();
        for (final doc in result.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();

        if (result.docs.length < 450) break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lahat ng notifications ay nabura.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hindi mabura ang notifications: $e')),
      );
    }
  }

  Future<void> _markAsRead(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      await ref.update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _openNotification(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final type = (data['type'] ?? 'GENERAL').toString();

    await _markAsRead(doc.reference);

    if (!context.mounted) return;

    switch (type) {
      case 'ORDER_UPDATE':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrdersPage()),
        );
        break;

      case 'ADMIN_MESSAGE':
        // Pwedeng mag-show ng dialog o mag-navigate sa chat/messages screen kung mayroon
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text((data['title'] ?? 'Mensahe mula sa Admin').toString()),
            content: Text((data['body'] ?? '').toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        break;

      case 'CART_NUDGE':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartPage()),
        );
        break;

      case 'RESTOCK_ALERT':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProductPage()),
        );
        break;

      default:
        break;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'ORDER_UPDATE':
        return Icons.local_shipping_rounded;
      case 'ADMIN_MESSAGE':
        return Icons.admin_panel_settings_rounded;
      case 'RESTOCK_ALERT':
        return Icons.storefront_rounded;
      case 'CART_NUDGE':
        return Icons.shopping_cart_rounded;
      case 'DELAY_WARNING':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(BuildContext context, String type) {
    final theme = Theme.of(context);

    switch (type) {
      case 'ORDER_UPDATE':
        return Colors.blue;
      case 'ADMIN_MESSAGE':
        return Colors.green;
      case 'RESTOCK_ALERT':
        return Colors.orange;
      case 'CART_NUDGE':
        return theme.colorScheme.error;
      case 'DELAY_WARNING':
        return Colors.deepOrange;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return '';

    final date = value.toDate();
    final now = DateTime.now();

    final sameDay = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (sameDay) return 'Ngayon, $hour:$minute';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$month/$day/${date.year} • $hour:$minute';
  }

  Widget _notificationTile(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final theme = Theme.of(context);
    final data = doc.data();

    final isRead = data['isRead'] == true;
    final type = (data['type'] ?? 'GENERAL').toString();
    final title = (data['title'] ?? 'Notification').toString();
    final body = (data['body'] ?? '').toString();
    final date = _formatDate(data['createdAt']);

    final iconColor = _colorFor(context, type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openNotification(context, doc),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isRead
                ? theme.colorScheme.surface
                : theme.colorScheme.primaryContainer.withValues(alpha: .35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRead
                  ? theme.colorScheme.outlineVariant.withValues(alpha: .5)
                  : theme.colorScheme.primary.withValues(alpha: .25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: iconColor.withValues(alpha: .13),
                child: Icon(
                  _iconFor(type),
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (date.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = _userId;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(
          child: Text(
            'Kailangan mong mag-login para makita ang notifications.',
          ),
        ),
      );
    }

    final stream = _notifications
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: theme.colorScheme.surface,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _notifications
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unread = snapshot.data?.docs.length ?? 0;

              return TextButton.icon(
                onPressed: unread == 0 ? null : _markAllAsRead,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text(
                  'Mark all',
                  style: TextStyle(fontSize: 12),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Delete all notifications',
            icon: const Icon(Icons.delete_sweep_rounded),
            color: Colors.red,
            onPressed: _deleteAllNotifications,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Hindi ma-load ang notifications.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 70,
                      color: theme.colorScheme.outline.withValues(alpha: .45),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Wala pang notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Dito lalabas ang status ng order mo at mga mensahe mula sa Admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              return _notificationTile(context, docs[index]);
            },
          );
        },
      ),
    );
  }
}