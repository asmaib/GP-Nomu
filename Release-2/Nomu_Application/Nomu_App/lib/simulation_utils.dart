// simulation_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SimulationUtils {
  // مرساة الجدول الزمني الثابتة (مطابقة لكودك)
  static final DateTime baseAnchor = DateTime(2019, 3, 31);

  // ====== أدوات عامة ======
  static DateTime d(DateTime t) => DateTime(t.year, t.month, t.day);
  static bool isWorkday(DateTime x) =>
      x.weekday != DateTime.friday && x.weekday != DateTime.saturday;

  static Future<DateTime> resolveCreatedAt() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final v = doc.data()?['createdAt'];
        if (v is Timestamp) return d(v.toDate());
        if (v is String) return d(DateTime.parse(v));
      }
    } catch (_) {}
    final meta = FirebaseAuth.instance.currentUser?.metadata.creationTime;
    if (meta != null) return d(meta);
    return d(DateTime.now());
  }

  static DateTime alignStartToWeekday(DateTime createdAt) {
    final weekday = createdAt.weekday;
    int diff = weekday - baseAnchor.weekday;
    if (diff < 0) diff += 7;
    return baseAnchor.add(Duration(days: diff));
  }

  static int businessDaysSince(DateTime from, DateTime to) {
    if (to.isBefore(from)) return 0;
    int n = 0;
    for (DateTime cur = d(from); !cur.isAfter(d(to)); cur = cur.add(const Duration(days: 1))) {
      if (isWorkday(cur)) n++;
    }
    return n;
  }

  static DateTime shiftWorkdays(DateTime start, int delta) {
    int remaining = delta.abs();
    DateTime cur = d(start);
    final step = delta >= 0 ? 1 : -1;
    while (remaining > 0) {
      cur = cur.add(Duration(days: step));
      if (isWorkday(cur)) remaining--;
    }
    return cur;
  }

  // ====== نهايات مختلفة بحسب السيناريو ======

  /// للـ Charts فقط (نظرة عامة + شركة): اليوم الحالي إذا كان يوم عمل، وإلا آخر خميس.
  static DateTime chartEndUserDay() {
    DateTime today = d(DateTime.now());
    if (isWorkday(today)) return today;
    while (today.weekday != DateTime.thursday) {
      today = today.subtract(const Duration(days: 1));
    }
    return today;
  }

  /// للتوب 5 فقط: قبل 3م = أقرب يوم عمل سابق؛ بعد 3م = اليوم (Sun–Thu)، والجمعة/السبت = الخميس.
  static DateTime lastCompletedTradingDayConsideringClose({int closeHour = 15}) {
    final now = DateTime.now();
    DateTime today = d(now);

    // جمعة/سبت → الخميس
    if (!isWorkday(today)) {
      while (today.weekday != DateTime.thursday) {
        today = today.subtract(const Duration(days: 1));
      }
      return today;
    }

    // Sun..Thu
    final afterClose = now.hour > closeHour || (now.hour == closeHour && now.minute >= 0);
    if (afterClose) return today;
    // قبل الإغلاق → أقرب يوم عمل سابق
    do {
      today = today.subtract(const Duration(days: 1));
    } while (!isWorkday(today));
    return today;
  }

  // ====== توحيد النصوص/التواريخ ======
  static String ymd(DateTime dte) =>
      '${dte.year}-${dte.month.toString().padLeft(2, '0')}-${dte.day.toString().padLeft(2, '0')}';
}
