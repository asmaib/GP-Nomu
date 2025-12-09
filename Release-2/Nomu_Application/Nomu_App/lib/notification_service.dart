import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Note: Background handling usually doesn't need manual saving here
  // if the app is in background, as the OS handles the tray.
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✨ FIX: Flag to prevent double initialization
  bool _isInitialized = false;

  // --- INITIALIZE ---
  Future<void> initialize() async {
    // ✨ FIX: If already running, stop here.
    if (_isInitialized) return;

    tz.initializeTimeZones();

    // 1. Check User Preference
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (!isEnabled) {
      print("🛑 Notifications are disabled by user. Service stopped.");
      return;
    }

    // 2. Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('User permission status: ${settings.authorizationStatus}');

    // 3. Setup Local Settings
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // 4. Create Channels
    const AndroidNotificationChannel highChannel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is for urgent alerts.',
      importance: Importance.max,
      playSound: true,
    );

    const AndroidNotificationChannel normalChannel = AndroidNotificationChannel(
      'normal_importance_channel',
      'Normal Notifications',
      description: 'This channel respects Quiet Hours/DND.',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(highChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(normalChannel);

    // 5. Setup Listeners
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // ✨ This listener was likely running multiple times before. Now it runs once.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalBanner(message);
      _saveNotificationToHistory(message.notification?.title, message.notification?.body);
    });

    scheduleInvestmentReminders();

    if (_auth.currentUser != null) {
      saveTokenToDatabase();
    }

    _fcm.onTokenRefresh.listen(saveTokenToDatabase);

    // ✨ Mark as initialized so we don't run this whole function again
    _isInitialized = true;
  }

  // --- TOGGLE LOGIC ---

Future<void> enableNotifications() async {
  String? token = await FirebaseMessaging.instance.getToken();

  await FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .update({'fcm_token': token});
}


  Future<void> disableNotifications() async {

  await FirebaseMessaging.instance.deleteToken();

  await FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .update({'fcm_token': null});

  }

  // --- DAILY MOTIVATION ---
  Future<void> checkAndSendDailyMotivation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isEnabled = prefs.getBool('notifications_enabled') ?? true;
    if (!isEnabled) return;

    String today = DateTime.now().toIso8601String().split('T')[0];
    String? lastDate = prefs.getString('last_motivation_date');

    if (lastDate != today) {
      _sendRandomMotivation();
      await prefs.setString('last_motivation_date', today);
    }
  }

  void _sendRandomMotivation() {
    List<String> motivations = [
      "أهلاً بعودتك! 🚀 جاهز لتعلم شيء جديد اليوم؟",
      "الاستثمار في المعرفة هو الأفضل دائماً. 📚",
      "خطوة صغيرة اليوم في نمو، تعني الكثير لمستقبلك. 🌱",
      "السوق لا ينتظر، ابدأ جلستك التعليمية الآن. 💪",
      "هل راجعت محفظتك اليوم؟ 💰"
    ];

    var random = Random();
    String message = motivations[random.nextInt(motivations.length)];
    String title = "رسالة من نمو 🌿";

    _localNotifications.show(
      999,
      title,
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'motivation_channel',
          'Motivation',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );

    _saveNotificationToHistory(title, message);
  }

  // --- HELPERS ---

  Future<void> saveTokenToDatabase([String? token]) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if ((prefs.getBool('notifications_enabled') ?? true) == false) return;

    User? user = _auth.currentUser;
    if (user != null) {
      String? currentToken = token ?? await _fcm.getToken();
      if (currentToken != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': currentToken,
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  Future<void> scheduleInvestmentReminders() async {
    await _scheduleDaily(9, 0, 1, "صباح الخير يا مستثمر! ☀️", "ابدأ يومك بمعلومة مالية جديدة.");
    await _scheduleDaily(21, 0, 2, "وقت المراجعة 🎯", "خصص دقيقة لمراجعة أدائك اليوم.");
  }

  Future<void> _scheduleDaily(int hour, int minute, int id, String title, String body) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'scheduled_channel',
          'Scheduled Reminders',
          importance: Importance.defaultImportance,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> _saveNotificationToHistory(String? title, String? body) async {
    User? user = _auth.currentUser;
    if (user != null && title != null) {
      await _firestore.collection('users').doc(user.uid).collection('notifications').add({
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
  }

  void _showLocalBanner(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            android.channelId ?? 'high_importance_channel',
            'Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  }
}