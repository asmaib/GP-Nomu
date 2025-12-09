import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> with WidgetsBindingObserver {
  bool _internalNotificationsEnabled = true;
  bool _systemNotificationsEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSystemPermission();
    }
  }

  Future<void> _checkSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Load the saved preference
    bool internal = prefs.getBool('notifications_enabled') ?? true;

    await _checkSystemPermission();

    if (mounted) {
      setState(() {
        _internalNotificationsEnabled = internal;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkSystemPermission() async {
    NotificationSettings settings = await FirebaseMessaging.instance.getNotificationSettings();
    bool isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized;

    if (mounted) {
      setState(() {
        _systemNotificationsEnabled = isAuthorized;
      });
    }
  }

  // ✨ FIXED FUNCTION: Saves the preference explicitly
  Future<void> _toggleInternalNotifications(bool value) async {
    setState(() => _internalNotificationsEnabled = value);

    // 1. Save the choice to Storage (Crucial Step!)
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);

    // 2. Call Service to handle Token logic
    if (value) {
      await NotificationService().enableNotifications();
    } else {
      await NotificationService().disableNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Color(0xFF609966),
          elevation: 0,
          centerTitle: true,
          leading: SizedBox(),
          actions: [
            IconButton(
              icon: Icon(Icons.arrow_forward_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],

          title: const Text(
            'إعدادات الإشعارات',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),

        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF609966)))
            : Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // 1. Internal Switch
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                ),
                child: SwitchListTile(
                  value: _internalNotificationsEnabled,
                  onChanged: _toggleInternalNotifications, // Calls the fixed function
                  activeColor: const Color(0xFF609966),
                  title: const Text("تشغيل الإشعارات داخل التطبيق", style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("تفعيل الرسائل التحفيزية والتذكيرات اليومية", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF609966).withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.notifications_active, color: Color(0xFF609966)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. System Settings
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text("إشعارات النظام (الهاتف): ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        Text(
                          _systemNotificationsEnabled ? "مفعلة" : "معطلة",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _systemNotificationsEnabled ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _systemNotificationsEnabled ? Icons.check_circle : Icons.cancel,
                          color: _systemNotificationsEnabled ? Colors.green : Colors.red,
                          size: 20,
                        )
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      _systemNotificationsEnabled
                          ? "إعدادات هاتفك تسمح لـ نمو بإرسال الإشعارات."
                          : "لقد قمت بمنع الإشعارات من إعدادات الهاتف. لن تصلك أي تنبيهات حتى لو قمت بتفعيل الزر في الأعلى.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          openAppSettings();
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text("فتح إعدادات الهاتف"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}