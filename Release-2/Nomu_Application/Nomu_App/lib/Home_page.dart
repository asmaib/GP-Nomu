import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_profile.dart';
import 'portfolio_page.dart';
import 'stock_market_page.dart';
import 'Learning page.dart';

import 'daily_questions.dart';
import 'combined_chat_screen.dart';
import 'simulation_utils.dart';

// --- Import Notification Service & Page ---
import 'notification_service.dart';
import 'notifications_page.dart';
// -----------------------------------------

/// Helper class for FIFO logic
class _OpenLot {
  final String symbol;
  final double qty;
  final double price;
  final DateTime buyDate;
  _OpenLot(this.symbol, this.qty, this.price, this.buyDate);
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 4;
  bool _challengeAnswered = false;
  Question? _todaysQuestion;
  String? _selectedAnswer;
  int _coinCount = 0;

  @override
  void initState() {
    super.initState();
    _loadChallengeStatus();
    _initializeDailyQuestion();
    _loadCoinCount();

    // ✨ THIS IS THE FIX: Check if we should show the custom dialog
    _initNotificationsOnHomeLoad();
  }

  // --- 🚀 NEW: CUSTOM PERMISSION LOGIC ---
  Future<void> _initNotificationsOnHomeLoad() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Check if we have asked the user before
    bool hasAskedBefore = prefs.getBool('has_asked_notification_permission') ?? false;

    if (!hasAskedBefore) {
      // 🛑 If NOT asked before, show our Custom Dialog
      // Delay slightly so the page loads first
      await Future.delayed(Duration(seconds: 1));
      if (mounted) {
        await _showCustomNotificationDialog();
      }
      // Mark as asked so we don't annoy them next time
      await prefs.setBool('has_asked_notification_permission', true);
    } else {
      // ✅ If already asked, just initialize silently
      await NotificationService().initialize();
      await NotificationService().saveTokenToDatabase();
      await NotificationService().checkAndSendDailyMotivation();
    }
  }

  Future<void> _showCustomNotificationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User MUST choose Yes or No
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.notifications_active, color: Color(0xFF609966)),
                SizedBox(width: 8),
                Text("تفعيل الإشعارات", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              "هل ترغب في تلقي رسائل تحفيزية وتنبيهات حول دروسك اليومية؟\nيمكنك تغيير هذا لاحقاً من الإعدادات.",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('لا شكراً', style: TextStyle(color: Colors.grey)),
                onPressed: () async {
                  // User said NO
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notifications_enabled', false);
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF609966),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('نعم، فعلها', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  Navigator.of(context).pop();

                  // User said YES
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notifications_enabled', true);

                  // Enable Service
                  await NotificationService().enableNotifications();

                  // Send welcome motivation immediately
                  await NotificationService().checkAndSendDailyMotivation();
                },
              ),
            ],
          ),
        );
      },
    );
  }
  // ------------------------------------------

  Future<void> _initializeDailyQuestion() async {
    _todaysQuestion = await _getDailyQuestion();
  }

  Future<void> _loadChallengeStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final answered = doc['challenge_answered'] ?? false;
        final ts = (doc['challenge_timestamp'] as Timestamp?)?.toDate();
        if (answered && ts != null) {
          final diff = DateTime.now().difference(ts).inHours;
          if (diff >= 24) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'challenge_answered': false});
            setState(() => _challengeAnswered = false);
          } else {
            setState(() => _challengeAnswered = true);
          }
        } else {
          setState(() => _challengeAnswered = false);
        }
      }
    }
  }

  Future<void> _markChallengeAnswered() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final now = DateTime.now();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'challenge_answered': true,
        'challenge_timestamp': Timestamp.fromDate(now),
      });
      setState(() => _challengeAnswered = true);
    }
  }

  Future<String> _getUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        return doc.get('username') ?? '';
      }
    }
    return '';
  }

  Future<void> _storeDailyQuestionForUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final q = (dailyQuestions..shuffle()).first;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'daily_question_${user.uid}',
        jsonEncode({
          'text': q.text,
          'options': q.options,
          'correctAnswer': q.correctAnswer,
        }),
      );
    }
  }

  Future<Question> _getDailyQuestion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('daily_question_${user.uid}');
      if (saved != null) {
        final m = jsonDecode(saved);
        return Question(
          text: m['text'],
          options: List<String>.from(m['options']),
          correctAnswer: m['correctAnswer'],
        );
      }
    }
    await _storeDailyQuestionForUser();
    return _getDailyQuestion();
  }

  Future<void> _loadCoinCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() => _coinCount = doc.data()?['coins'] ?? 0);
    }
  }

  void _showQuestionDialog(Question question) {
    _selectedAnswer = null;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Color(0xFF609966),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Text(
                    'تحدي اليوم',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 12),
                Text(question.text, textAlign: TextAlign.right, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 16),
                ...question.options.map((opt) {
                  return RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.trailing,
                    title: Text(opt, textAlign: TextAlign.right),
                    value: opt,
                    groupValue: _selectedAnswer,
                    onChanged: (v) => setState(() => _selectedAnswer = v),
                  );
                }).toList(),
                SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedAnswer == null
                          ? null
                          : () {
                        Navigator.pop(ctx);
                        if (_selectedAnswer == question.correctAnswer) _showCorrectDialog();
                        else _showWrongAnswerDialogWithCorrect(question);
                      },
                      child: Text('إرسال'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFF609966), width: 2),
                        foregroundColor: Color(0xFF609966),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('تخطي'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Color(0xFF609966), width: 2),
                        foregroundColor: Color(0xFF609966),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _showCorrectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Color(0xFF609966),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 64, color: Colors.white),
              SizedBox(height: 16),
              Text('يا سلام عليك! إجابة صحيحة وربحت 5 عملات إضافية',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF609966),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'coins': FieldValue.increment(5)});
                    }
                    setState(() {
                      _coinCount += 5;
                    });
                    Navigator.pop(context);
                    _markChallengeAnswered();
                  },
                  child: Text('موافق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWrongAnswerDialogWithCorrect(Question question) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.red[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, size: 64, color: Colors.black),
              SizedBox(height: 16),
              Text('إجابة خاطئة', style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('الإجابة الصحيحة:', style: TextStyle(color: Colors.black, fontSize: 18)),
              SizedBox(height: 6),
              Text(question.correctAnswer, textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w600)),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.red[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _markChallengeAnswered();
                },
                child: Text('موافق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int i) {
    setState(() => _selectedIndex = i);
    switch (i) {
      case 0:
        Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage()));
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => PortfolioPage()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => MarketSimulationPage()));
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => LearningPage()));
        break;
    }
  }

  // UPDATED HEADER WITH NOTIFICATION ICON LOGIC
  Widget _buildHeader() => FutureBuilder<String>(
    future: _getUsername(),
    builder: (ctx, snap) {
      final user = snap.data ?? '';
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- UPDATED ICON BUTTON ---
            IconButton(
                icon: Icon(Icons.notifications, color: Colors.white),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage()));
                }
            ),
            // ---------------------------
            SizedBox(width: 12),
            Expanded(
              child: Text(
                user.isNotEmpty ? 'مرحبًا بك، $user' : 'مرحبًا بك',
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _buildChatbotCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CombinedChatScreen())),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFDAF0CF), Color(0xFF609966)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  decoration: BoxDecoration(color: Color(0xFF609966), shape: BoxShape.circle),
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.smart_toy, size: 32, color: Colors.white),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text('تحدث مع نمو وتعلم عن الاستثمار',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
                Icon(Icons.arrow_back_ios, color: Colors.black54),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Color(0xFF609966),
    body: SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildBalanceCard(),
                    _buildChatbotCard(),
                    _buildChallengeCard(),
                    _buildTransactionsList(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: _buildBottomNavBar(),
  );

  // ================== Live Numbers (Matching Portfolio) ==================

  // Formatting
  String _fmtMoney(num v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
    return '$intPart.${parts[1]}';
  }

  // Converters
  double _toDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? fallback;
    return fallback;
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  // Streams
  Stream<double> _watchCash() async* {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      yield 0.0;
      return;
    }
    final base = FirebaseFirestore.instance.collection('users').doc(uid).collection('wallet');

    await for (final s in base.doc('main').snapshots()) {
      if (s.exists && (s.data()?['cash'] != null)) {
        yield _toDouble(s.data()!['cash']);
      } else {
        final m2 = await base.doc('Main').get();
        if (m2.exists && (m2.data()?['cash'] != null)) {
          yield _toDouble(m2.data()!['cash']);
        } else {
          yield 0.0;
        }
      }
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _watchOrders() async* {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      yield const [];
      return;
    }
    final ref = FirebaseFirestore.instance.collection('users').doc(uid).collection('orders');
    await for (final qs in ref.snapshots()) {
      yield qs.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
    }
  }

  // Companies / Prices
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findCompanyBySymbolOrId(String symbolOrId) async {
    final asInt = _toInt(symbolOrId);
    if (asInt != null) {
      final q1 = await FirebaseFirestore.instance.collection('companies').where('id', isEqualTo: asInt).limit(1).get();
      if (q1.docs.isNotEmpty) return q1.docs.first;
    }
    final q2 = await FirebaseFirestore.instance.collection('companies').where('id', isEqualTo: symbolOrId).limit(1).get();
    if (q2.docs.isNotEmpty) return q2.docs.first;

    final q3 = await FirebaseFirestore.instance.collection('companies').where('symbol', isEqualTo: symbolOrId).limit(1).get();
    if (q3.docs.isNotEmpty) return q3.docs.first;

    final d = await FirebaseFirestore.instance.collection('companies').doc(symbolOrId).get();
    if (d.exists) return d;

    return null;
  }

  Future<double?> _latestCloseUntil(String symbol, DateTime onOrBefore) async {
    final compDoc = await _findCompanyBySymbolOrId(symbol);
    if (compDoc == null) return null;
    final pricesRef = compDoc.reference.collection('PriceRecords_full');

    final y = onOrBefore.year.toString().padLeft(4, '0');
    final m = onOrBefore.month.toString().padLeft(2, '0');
    final d = onOrBefore.day.toString().padLeft(2, '0');
    final dateStr = '$y-$m-$d';

    try {
      final sq = await pricesRef.where('date', isLessThanOrEqualTo: dateStr).orderBy('date', descending: true).limit(1).get();
      if (sq.docs.isNotEmpty) return _toDouble(sq.docs.first.data()['close']);
    } catch (_) {}

    try {
      final tq = await pricesRef.where('date', isLessThanOrEqualTo: Timestamp.fromDate(onOrBefore)).orderBy('date', descending: true).limit(1).get();
      if (tq.docs.isNotEmpty) return _toDouble(tq.docs.first.data()['close']);
    } catch (_) {}

    final byId = await pricesRef.doc(dateStr).get();
    if (byId.exists) return _toDouble(byId.data()?['close']);

    return null;
  }

  // Mapping
  Future<DateTime> _mapRealToDatasetDay(DateTime realDay) async {
    final createdAt = await SimulationUtils.resolveCreatedAt();
    int workdays = 0;
    final start = DateTime(createdAt.year, createdAt.month, createdAt.day).add(const Duration(days: 1));
    final end = DateTime(realDay.year, realDay.month, realDay.day);

    if (!end.isBefore(start)) {
      for (DateTime cur = start; !cur.isAfter(end); cur = cur.add(const Duration(days: 1))) {
        if (SimulationUtils.isWorkday(cur)) workdays++;
      }
    }
    return SimulationUtils.shiftWorkdays(SimulationUtils.baseAnchor, workdays);
  }

  Future<DateTime> _effectivePricingDayNow() async {
    final realTradingDay = SimulationUtils.chartEndUserDay();
    return _mapRealToDatasetDay(realTradingDay);
  }

  Future<DateTime> _effectivePricingDayForBuy(DateTime buyDate) async {
    return _mapRealToDatasetDay(buyDate);
  }

  // Parse orders helpers
  String _extractSide(Map<String, dynamic> m) {
    final raw = (m['side'] ?? m['Side'] ?? '').toString().trim();
    final low = raw.toLowerCase();
    if (low == 'buy' || low == 'شراء' || low == 'buyorder' || raw.toUpperCase() == 'BUY') return 'buy';
    if (low == 'sell' || low == 'بيع' || low == 'sellorder' || raw.toUpperCase() == 'SELL') return 'sell';
    return low;
  }

  String _extractSymbol(Map<String, dynamic> m, String docId) {
    final v = (m['symbol'] ?? m['companyId'] ?? m['id'] ?? docId);
    return v.toString();
  }

  DateTime _extractDate(Map<String, dynamic> m) {
    return _toDateTime(m['createdAt'] ?? m['timestamp'] ?? m['date'] ?? m['time']) ?? DateTime(1970);
  }

  List<_OpenLot> _buildOpenLotsFromOrders(List<QueryDocumentSnapshot<Map<String, dynamic>>> orderDocs) {
    final Map<String, List<Map<String, dynamic>>> buysBy = {};
    final Map<String, List<Map<String, dynamic>>> sellsBy = {};

    for (final d in orderDocs) {
      final m = d.data();
      final side = _extractSide(m);
      final symbol = _extractSymbol(m, d.id);
      final qty = _toDouble(m['qty'] ?? m['quantity'] ?? m['Quantity'] ?? 0);
      final price = _toDouble(m['price'] ?? m['Price'] ?? 0);
      final dt = _extractDate(m);
      if (symbol.isEmpty || qty <= 0) continue;
      final row = {'qty': qty, 'price': price, 'date': dt};
      if (side == 'buy') {
        buysBy.putIfAbsent(symbol, () => []).add(row);
      } else if (side == 'sell') {
        sellsBy.putIfAbsent(symbol, () => []).add(row);
      }
    }

    for (final s in buysBy.keys) {
      buysBy[s]!.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    }
    for (final s in sellsBy.keys) {
      sellsBy[s]!.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    }

    final List<_OpenLot> open = [];
    for (final symbol in buysBy.keys) {
      final buys = buysBy[symbol]!;
      final sells = sellsBy[symbol] ?? [];

      final queue = buys
          .map((b) => {
        'qty': (b['qty'] as double),
        'price': (b['price'] as double),
        'date': (b['date'] as DateTime),
      })
          .toList();

      double remainingSell = 0.0;
      for (final s in sells) {
        remainingSell += (s['qty'] as double);
      }

      int i = 0;
      while (remainingSell > 0 && i < queue.length) {
        final lotQty = queue[i]['qty'] as double;
        if (lotQty <= remainingSell + 1e-9) {
          remainingSell -= lotQty;
          queue[i]['qty'] = 0.0;
          i++;
        } else {
          queue[i]['qty'] = lotQty - remainingSell;
          remainingSell = 0.0;
          break;
        }
      }

      for (final q in queue) {
        final qQty = q['qty'] as double;
        if (qQty > 1e-9) {
          open.add(_OpenLot(symbol, qQty, q['price'] as double, q['date'] as DateTime));
        }
      }
    }
    return open;
  }

  Future<({double totalProfit, double totalLoss, double totalCost, double currentValue})> _calcPnLFromOrders(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orderDocs, {
        bool ignoreSameDay = true,
      }) async {
    final simDatasetDay = await _effectivePricingDayNow();
    final openLots = _buildOpenLotsFromOrders(orderDocs);

    double totalProfit = 0.0;
    double totalLoss = 0.0;
    double totalCost = 0.0;
    double currentValue = 0.0;

    final Map<String, double> closeCache = {};

    for (final lot in openLots) {
      if (ignoreSameDay) {
        final lotDatasetDay = await _effectivePricingDayForBuy(lot.buyDate);
        if (lotDatasetDay.year == simDatasetDay.year &&
            lotDatasetDay.month == simDatasetDay.month &&
            lotDatasetDay.day == simDatasetDay.day) {
          continue; // Ignore today's lots
        }
      }

      final symbol = lot.symbol;
      final close = closeCache.containsKey(symbol)
          ? closeCache[symbol]!
          : (await _latestCloseUntil(symbol, simDatasetDay) ?? 0.0);
      closeCache[symbol] = close;

      final nowVal = close * lot.qty;
      final cost = lot.price * lot.qty;
      final diff = nowVal - cost;

      totalCost += cost;
      currentValue += nowVal;

      if (diff > 0) {
        totalProfit += diff;
      } else if (diff < 0) {
        totalLoss += -diff;
      }
    }
    return (totalProfit: totalProfit, totalLoss: totalLoss, totalCost: totalCost, currentValue: currentValue);
  }
  Future<({double totalProfit, double totalLoss, double totalCost, double currentValue})>
  _calcPnLFull_NoIgnore(List<QueryDocumentSnapshot<Map<String, dynamic>>> orders) async {
    return await _calcPnLFromOrders(orders, ignoreSameDay: false);
  }

  // ===== Balance Card — Dynamic =====
  Widget _buildBalanceCard() => Padding(
    padding: EdgeInsets.all(16),
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5, spreadRadius: 2)],
      ),
      child: StreamBuilder<double>(
        stream: _watchCash(),
        builder: (context, cashSnap) {
          final cash = cashSnap.data ?? 0.0;
          return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _watchOrders(),
            builder: (context, ordSnap) {
              final orders = ordSnap.data ?? const [];
              return FutureBuilder<({double totalProfit, double totalLoss, double totalCost, double currentValue})>(
                future: _calcPnLFromOrders(orders, ignoreSameDay: false),
                builder: (context, pnlSnap) {
                  final totalProfit = pnlSnap.data?.totalProfit ?? 0.0;
                  final totalLoss = pnlSnap.data?.totalLoss ?? 0.0;
                  final currentValue = pnlSnap.data?.currentValue ?? 0.0;
                  final totalPortfolio = cash + currentValue;

                  return Column(children: [
                    Text('صافي الأصول', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/saudi_riyal_black.png', height: 24),
                        SizedBox(width: 6),
                        Text(_fmtMoney(totalPortfolio), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text('هذا الرصيد وهمي', style: TextStyle(color: Colors.red, fontSize: 14)),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('الخسارة', _fmtMoney(totalLoss), Colors.red, 'assets/saudi_riyal_red.png'),
                        _buildStatItem('الربح', _fmtMoney(totalProfit), Color(0xFF609966), 'assets/saudi_riyal_green.png'),
                      ],
                    ),
                  ]);
                },
              );
            },
          );
        },
      ),
    ),
  );

  Widget _buildStatItem(String label, String value, Color color, String iconPath) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 16)),
        SizedBox(height: 5),
        Row(
          children: [
            Image.asset(iconPath, height: 18),
            SizedBox(width: 4),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildChallengeCard() {
    if (_challengeAnswered) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [Colors.white, Color(0xFFDAF0CF), Color(0xFF609966)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            padding: EdgeInsets.all(16),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.check_circle, size: 48, color: Colors.white),
                SizedBox(width: 16),
                Expanded(
                  child: Text('لقد اجبت على تحدي اليوم',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              if (_todaysQuestion == null) {
                _todaysQuestion = await _getDailyQuestion();
              }
              _showQuestionDialog(_todaysQuestion!);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(colors: [Colors.white, Color(0xFFDAF0CF), Color(0xFF609966)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              padding: EdgeInsets.all(16),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(decoration: BoxDecoration(color: Color(0xFF609966), shape: BoxShape.circle), padding: EdgeInsets.all(12), child: Icon(Icons.emoji_events, size: 32, color: Colors.white)),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text('جاهز لتحدي اليوم ؟',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  Icon(Icons.arrow_back_ios, color: Colors.black54),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  // ===== List of Transactions =====
  Widget _buildTransactionsList() => Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      textDirection: TextDirection.rtl,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'آخر العمليات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 6),
              Tooltip(
                message: 'آخر عمليات البيع والشراء التي قمت بها',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: Duration(seconds: 3),
                preferBelow: false,
                child: Icon(Icons.info_outline, size: 18),
              ),
            ],
          ),
        ),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: () {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) {
              return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
            }
            return FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('orders')
                .orderBy('createdAt', descending: true)
                .limit(3)
                .snapshots();
          }(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Center(child: Text('لا توجد عمليات بعد')),
              );
            }

            return Column(
              children: [
                ...docs.map((d) => FutureBuilder<Widget>(
                  future: _buildTransactionTile(d.data()),
                  builder: (context, tile) {
                    if (!tile.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      );
                    }
                    return tile.data!;
                  },
                )),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton(
                    onPressed: _openAllTransactionsPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF609966),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
                      child: Text('المزيد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );

  // === Transaction Tile ===
  Future<Widget> _buildTransactionTile(Map<String, dynamic> m) async {
    final symbol = (m['symbol'] ?? m['companyId'] ?? '').toString();
    final qty = _toDouble(m['qty'] ?? m['quantity'] ?? 0);
    final sideRaw = (m['side'] ?? '').toString().toUpperCase();

    final compDoc = await _findCompanyBySymbolOrId(symbol);
    final comp = compDoc?.data() ?? {};
    final companyName = (comp['name'] ?? compDoc?.id ?? symbol).toString();

    String logoAsset = (comp['logoAsset'] ?? comp['logo'] ?? '').toString().trim();
    if (logoAsset.isNotEmpty && !logoAsset.startsWith('assets/')) {
      logoAsset = 'assets/company-logos/$logoAsset';
    }

    final sideArabic = sideRaw == 'SELL' ? 'بيع' : 'شراء';

    String fmtQty(double q) {
      return (q % 1 == 0) ? q.toInt().toString() : q.toString();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, spreadRadius: 1, offset: Offset(0, 4))],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(0), // بدون أي padding
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset(
                  logoAsset.isNotEmpty ? logoAsset : 'assets/company-logos/default.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              companyName,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          Container(
            width: 92,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sideArabic,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                SizedBox(height: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    'الكمية: ${fmtQty(qty)}',
                    style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAllTransactionsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _TransactionsPage(buildTile: _buildTransactionTile)),
    );
  }

  Widget _buildBottomNavBar() => BottomNavigationBar(
    items: [
      BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
      BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: ''),
      BottomNavigationBarItem(
        icon: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF609966),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [BoxShadow(color: Color(0xFF609966).withOpacity(0.3), blurRadius: 5, spreadRadius: 2)],
          ),
          child: Image.asset('assets/saudi_riyal.png', width: 30, height: 30),
        ),
        label: '',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
      BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
    ],
    selectedItemColor: Color(0xFF609966),
    unselectedItemColor: Colors.grey,
    currentIndex: _selectedIndex,
    type: BottomNavigationBarType.fixed,
    onTap: _onItemTapped,
  );
}

// ===== All Transactions Page =====
class _TransactionsPage extends StatelessWidget {
  final Future<Widget> Function(Map<String, dynamic>) buildTile;
  const _TransactionsPage({Key? key, required this.buildTile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF609966),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    const SizedBox(width: 48),

                    const Expanded(
                      child: Text(
                        'كل العمليات',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(width: 8),

                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                    ),
                  ],

                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
                child: uid == null
                    ? const Center(child: Text('غير مسجل'))
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('orders')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text('لا توجد عمليات'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 12, bottom: 24),
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final m = docs[i].data();
                        return FutureBuilder<Widget>(
                          future: buildTile(m),
                          builder: (context, w) => w.hasData
                              ? w.data!
                              : const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}