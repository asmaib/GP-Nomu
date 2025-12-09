import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:ui' as ui;

import 'user_profile.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoadingPreference = true;

  bool _internalEnabled = true;   // إعدادات التطبيق الداخلية
  bool _systemEnabled = true;     // إعدادات إشعارات الهاتف

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    _internalEnabled = prefs.getBool('notifications_enabled') ?? true;

    NotificationSettings settings =
        await FirebaseMessaging.instance.getNotificationSettings();
    _systemEnabled = settings.authorizationStatus == AuthorizationStatus.authorized;

    setState(() {
      _isLoadingPreference = false;
    });
  }

  // -------- Banner --------
  Widget _notificationBanner() {
    if (!_systemEnabled) {
      return _banner(
        "إشعارات الهاتف معطّلة",
        "لن تصلك أي إشعارات حتى تعيد تفعيلها من إعدادات الهاتف."
      );
    }

    if (!_internalEnabled) {
      return _banner(
        "إشعارات التطبيق متوقفة",
        "أعد تفعيلها من الإعدادات لتصلك من جديد."
      );
    }

    return const SizedBox();
  }

  // ✅ البانر الآن بعرض الصفحة
  Widget _banner(String title, String msg) {
    return Container(
      width: double.infinity, // ← يمسك العرض كامل
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.amber[100],
        borderRadius: BorderRadius.circular(0), // ← بدون زوايا مثل شريط تحذير
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(msg, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  // -------- Delete All --------
  Future<void> _deleteAllNotifications(String uid) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          title: const Text("حذف الكل؟"),
          content: const Text("هل أنت متأكد من رغبتك في حذف جميع الإشعارات؟"),
          actions: [
            TextButton(child: const Text("إلغاء"), onPressed: () => Navigator.pop(ctx, false)),
            TextButton(
              child: const Text("حذف", style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    ) ?? false;

    if (confirm) {
      var collection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications');

      var snapshots = await collection.get();
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "الإشعارات",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF609966),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (uid != null && _internalEnabled)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _deleteAllNotifications(uid),
              tooltip: "حذف الكل",
            )
        ],
      ),

      body: _isLoadingPreference
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF609966)))
          : uid == null
              ? const Center(child: Text("يرجى تسجيل الدخول"))
              : Column(
                  children: [
                    _notificationBanner(),

                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('notifications')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(color: Color(0xFF609966)));
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.notifications_none,
                                      size: 80, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    "لا توجد إشعارات حالياً",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              var doc = snapshot.data!.docs[index];
                              var data = doc.data() as Map<String, dynamic>;

                              String title = data['title'] ?? 'إشعار جديد';
                              String body = data['body'] ?? '';
                              Timestamp? timestamp = data['timestamp'];

                              String timeStr = "الآن";
                              if (timestamp != null) {
                                try {
                                  timeStr = DateFormat('h:mm a  •  d MMM', 'ar')
                                      .format(timestamp.toDate());
                                } catch (e) {
                                  timeStr = DateFormat('h:mm a  •  d MMM')
                                      .format(timestamp.toDate());
                                }
                              }

                              return Dismissible(
                                key: Key(doc.id),
                                direction: DismissDirection.startToEnd,
                                background: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[400],
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete,
                                      color: Colors.white, size: 30),
                                ),
                                onDismissed: (_) {
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(uid)
                                      .collection('notifications')
                                      .doc(doc.id)
                                      .delete();
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFE8F5E9),
                                      child: const Icon(Icons.lightbulb,
                                          color: Color(0xFF609966)),
                                    ),
                                    title: Text(title,
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          body,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700]),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ),
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
