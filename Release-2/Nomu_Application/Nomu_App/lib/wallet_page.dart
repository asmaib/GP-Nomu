import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'simulation_utils.dart';

/// نفس فكرة HomePage: نحتاج كلاس لوت مفتوح لحساب إجمالي المحفظة
class _OpenLot {
  final String symbol;
  final double qty;
  final double price;
  final DateTime buyDate;
  _OpenLot(this.symbol, this.qty, this.price, this.buyDate);
}

class WalletPage extends StatefulWidget {
  const WalletPage({Key? key}) : super(key: key);

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  // ألوان عامة للواجهة
  static const Color _green   = Color(0xFF609966); // لون الهوية العامة للتطبيق
  // ألوان محايدة لحركات البيع/الشراء (بدون دلالة ربح/خسارة)
  static const Color _neutral = Color(0xFF6B7280); // رمادي مزرق
  static const Color _chipBg  = Color(0xFFE5E7EB); // خلفية فاتحة محايدة

  static const double _seed = 10000.0; // رأس المال التدريبي الثابت

  // ---------- Formatting ----------
  String _fmtMoney(num v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
    return '$intPart.${parts[1]}';
  }

  String _sar(num v) => 'ر.س ${_fmtMoney(v)}';
  String _fmtQty(double q) => (q % 1 == 0) ? q.toInt().toString() : q.toStringAsFixed(2);
  String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------- Safe parsers ----------
  double _toDouble(dynamic v, [double fallback = 0.0]) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? fallback;
    return fallback;
  }

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  // ---------- Extractors (متوافقة مع منطق البورتفوليو) ----------
  String _extractSide(Map<String, dynamic> m) {
    final raw = (m['side'] ?? m['Side'] ?? '').toString().trim();
    final low = raw.toLowerCase();
    if (low == 'buy'  || low == 'شراء' || low == 'buyorder'  || raw.toUpperCase() == 'BUY')  return 'buy';
    if (low == 'sell' || low == 'بيع'  || low == 'sellorder' || raw.toUpperCase() == 'SELL') return 'sell';
    return low;
  }

  String _extractSymbol(Map<String, dynamic> m, String docId) {
    final v = (m['symbol'] ?? m['companyId'] ?? m['id'] ?? docId);
    return v.toString();
  }

  String _extractName(Map<String, dynamic> m) {
    final n = (m['name'] ?? m['companyName'] ?? '').toString();
    return n.isEmpty ? 'سهم' : n;
  }

  DateTime _extractDate(Map<String, dynamic> m) {
    return _toDateTime(m['createdAt'] ?? m['timestamp'] ?? m['date'] ?? m['time']) ?? DateTime(1970);
  }

  // ---------- Streams ----------
  /// رصيد الكاش من Firestore
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
        final alt = await base.doc('Main').get(); // fallback
        if (alt.exists && (alt.data()?['cash'] != null)) {
          yield _toDouble(alt.data()!['cash']);
        } else {
          yield 0.0;
        }
      }
    }
  }

  /// مراقبة عدد العملات (Coins) للمستخدم
  Stream<int> _watchCoins() async* {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      yield 0;
      return;
    }
    await for (final s in FirebaseFirestore.instance.collection('users').doc(uid).snapshots()) {
      if (s.exists && s.data()?['coins'] != null) {
        yield (s.data()!['coins'] as num).toInt();
      } else {
        yield 0;
      }
    }
  }

  /// كل حركات البطاقة المتعلقة بالأوامر
  /// شراء = خصم ، بيع = إضافة
  Stream<List<_WalletMovement>> _watchWalletMovements() async* {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      yield const [];
      return;
    }
    final ref = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('orders');

    await for (final qs in ref.orderBy('createdAt', descending: true).snapshots()) {
      final list = <_WalletMovement>[];
      for (final d in qs.docs) {
        final m = d.data();
        final side = _extractSide(m);
        if (side != 'buy' && side != 'sell') continue;

        final symbol = _extractSymbol(m, d.id);
        final name = _extractName(m);
        final qty = _toDouble(m['qty'] ?? m['quantity'] ?? m['Quantity'] ?? 0);
        final price = _toDouble(m['price'] ?? m['Price'] ?? 0);
        final dt = _extractDate(m);
        if (qty <= 0 || price <= 0) continue;

        list.add(_WalletMovement(
          side: side, symbol: symbol, name: name, qty: qty, price: price, date: dt,
        ));
      }
      list.sort((a, b) => b.date.compareTo(a.date)); // الأحدث أولاً
      yield list;
    }
  }

  /// نفس منطق الهوم بيج: نحتاج الـ orders الخام لحساب إجمالي المحفظة
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _watchOrders() async* {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      yield const [];
      return;
    }
    final ref = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('orders');
    await for (final qs in ref.snapshots()) {
      yield qs.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
    }
  }

  // ---------- منطق الشركات والأسعار (مطابق للهوم بيج) ----------
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findCompanyBySymbolOrId(String symbolOrId) async {
    final asInt = int.tryParse(symbolOrId);
    if (asInt != null) {
      final q1 = await FirebaseFirestore.instance
          .collection('companies')
          .where('id', isEqualTo: asInt)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) return q1.docs.first;
    }

    final q2 = await FirebaseFirestore.instance
        .collection('companies')
        .where('id', isEqualTo: symbolOrId)
        .limit(1)
        .get();
    if (q2.docs.isNotEmpty) return q2.docs.first;

    final q3 = await FirebaseFirestore.instance
        .collection('companies')
        .where('symbol', isEqualTo: symbolOrId)
        .limit(1)
        .get();
    if (q3.docs.isNotEmpty) return q3.docs.first;

    final d = await FirebaseFirestore.instance
        .collection('companies')
        .doc(symbolOrId)
        .get();
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
      final sq = await pricesRef
          .where('date', isLessThanOrEqualTo: dateStr)
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      if (sq.docs.isNotEmpty) return _toDouble(sq.docs.first.data()['close']);
    } catch (_) {}

    try {
      final tq = await pricesRef
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(onOrBefore))
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      if (tq.docs.isNotEmpty) return _toDouble(tq.docs.first.data()['close']);
    } catch (_) {}

    final byId = await pricesRef.doc(dateStr).get();
    if (byId.exists) return _toDouble(byId.data()?['close']);

    return null;
  }

  Future<DateTime> _mapRealToDatasetDay(DateTime realDay) async {
    final createdAt = await SimulationUtils.resolveCreatedAt();
    int workdays = 0;
    final start = DateTime(createdAt.year, createdAt.month, createdAt.day)
        .add(const Duration(days: 1));
    final end = DateTime(realDay.year, realDay.month, realDay.day);

    if (!end.isBefore(start)) {
      for (DateTime cur = start;
      !cur.isAfter(end);
      cur = cur.add(const Duration(days: 1))) {
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

  List<_OpenLot> _buildOpenLotsFromOrders(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orderDocs) {
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
          open.add(
            _OpenLot(symbol, qQty, q['price'] as double, q['date'] as DateTime),
          );
        }
      }
    }
    return open;
  }

  Future<
      ({
      double totalProfit,
      double totalLoss,
      double totalCost,
      double currentValue
      })> _calcPnLFromOrders(
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
          continue; // تجاهل لوتات اليوم
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

  // ---------- حذف ساب-كلكشن (للأوامر والبوْزشن) ----------
  Future<void> _deleteUserSubcollection(String uid, String sub) async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(sub);
    final qs = await ref.get();
    for (final d in qs.docs) {
      await d.reference.delete();
    }
  }

  // ---------- Reset Wallet ----------
  Future<void> _resetWallet() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFE5E5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text('تأكيد إعادة الضبط', textAlign: TextAlign.right),
            SizedBox(width: 8),
            Icon(Icons.refresh, color: Colors.red),
          ],
        ),
        content: const Text(
          'تنبيه: الضغط على إعادة الضبط سيؤدي إلى حذف جميع اسهمك الحاليه، وسيتم إعادة رصيد المحفظة إلى 10,000 ر.س',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFE5E7EB),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final walletCol = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('wallet');

      // إعادة ضبط الكاش إلى 10000 في كل من main/Main
      await walletCol.doc('main').set({'cash': _seed}, SetOptions(merge: true));
      await walletCol.doc('Main').set({'cash': _seed}, SetOptions(merge: true));

      // حذف جميع الأوامر والبوْزشن عشان الهوم/البورتفوليو/السيميوليشن ترجع 10,000
      await _deleteUserSubcollection(uid, 'orders');
      await _deleteUserSubcollection(uid, 'positions');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إعادة ضبط رصيد المحفظة إلى 10,000 ر.س')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إعادة الضبط: $e')),
      );
    }
  }

  // ---------- Coin Exchange Logic ----------

  // Helper function to show success/failure dialogs
  Future<void> _showResultDialog(String title, String message, {bool isSuccess = true}) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(title, style: TextStyle(color: isSuccess ? _green : Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline, color: isSuccess ? _green : Colors.red),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message, textAlign: TextAlign.right),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('موافق', style: TextStyle(color: isSuccess ? _green : Colors.red, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _processExchange(int coinsToDeduct, double cashToAdd) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 1. Show Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF1F8E9), // Light green tint
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Text('تأكيد الاستبدال'),
            SizedBox(width: 8),
            Icon(Icons.currency_exchange, color: _green),
          ],
        ),
        content: Text(
          'هل أنت متأكد أنك تريد استبدال $coinsToDeduct عملة مقابل ${_fmtMoney(cashToAdd)} ريال؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Close the exchange dialog first
    Navigator.pop(context);

    // 2. Execute Transaction
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final walletRef = userRef.collection('wallet').doc('main'); // Prefer 'main'

        final userSnap = await transaction.get(userRef);
        final walletSnap = await transaction.get(walletRef);

        final currentCoins = (userSnap.data()?['coins'] as num?)?.toInt() ?? 0;
        final currentCash = (walletSnap.data()?['cash'] as num?)?.toDouble() ?? 0.0;

        if (currentCoins < coinsToDeduct) {
          throw Exception('لا تملك عملات كافية!');
        }

        transaction.update(userRef, {'coins': currentCoins - coinsToDeduct});

        if (walletSnap.exists) {
          transaction.update(walletRef, {'cash': currentCash + cashToAdd});
        } else {
          transaction.set(walletRef, {'cash': cashToAdd});
        }
      });

      if (!mounted) return;
      // Show success dialog
      await _showResultDialog('تمت العملية بنجاح', 'تم استبدال $coinsToDeduct عملة مقابل ${_fmtMoney(cashToAdd)} ريال وإضافتها إلى محفظتك.');

    } catch (e) {
      if (!mounted) return;
      // Show failure dialog
      await _showResultDialog('خطأ في العملية', 'حدث خطأ أثناء الاستبدال: ${e.toString().replaceAll('Exception: ', '')}', isSuccess: false);
    }
  }

  void _showExchangeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<int>(
          stream: _watchCoins(),
          builder: (context, snapshot) {
            final coins = snapshot.data ?? 0;
            // Calculate cash for all coins (1 coin = 10 SAR)
            final cashForAll = (coins * 10).toDouble();
            final coinsToExchangeAll = coins;

            return AlertDialog(
              backgroundColor: const Color(0xFFFDFDFD),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              contentPadding: const EdgeInsets.all(20),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'استبدال العملات',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'رصيدك الحالي: $coins عملة',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  if (coins == 0) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'لا يوجد لديك عملات كافية. شاهد المحتوى التعليمي للحصول على عملات',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Option 1
                  _buildExchangeRow(
                    label: 'استبدل عملة واحدة واحصل على عشرة ريال',
                    cost: 1,
                    reward: 10.0,
                    userCoins: coins,
                  ),
                  const SizedBox(height: 12),
                  // Option 2
                  _buildExchangeRow(
                    label: 'استبدل خمس عملات واحصل على خمسين ريال',
                    cost: 5,
                    reward: 50.0,
                    userCoins: coins,
                  ),
                  const SizedBox(height: 12),
                  // Option 3
                  _buildExchangeRow(
                    label: 'استبدل عشر عملات واحصل على مئة ريال',
                    cost: 10,
                    reward: 100.0,
                    userCoins: coins,
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),

                  // --- New "Exchange All" Option ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'استبدال الكل (${coinsToExchangeAll} عملة مقابل ${_fmtMoney(cashForAll)} ريال)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: _green),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: coinsToExchangeAll > 0 ? () => _processExchange(coinsToExchangeAll, cashForAll) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            disabledBackgroundColor: Colors.grey.shade300,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            minimumSize: const Size(double.infinity, 40),
                          ),
                          child: const Text('استبدال جميع العملات'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'ملاحظة: كل عملة واحدة تساوي عشرة ريال.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.grey.shade200,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('إلغاء'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildExchangeRow({
    required String label,
    required int cost,
    required double reward,
    required int userCoins,
  }) {
    final canAfford = userCoins >= cost;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Button on the left (in RTL)
          ElevatedButton(
            onPressed: canAfford ? () => _processExchange(cost, reward) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              disabledBackgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(80, 36),
            ),
            child: const Text('استبدل'),
          ),
          // Text on the right (in RTL)
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF609966),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48),

              const Expanded(
                child: Text(
                  'المحفظة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),


        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ====== الكروت العلوية: صافي الأصول + إعادة الضبط ======
              StreamBuilder<double>(
                stream: _watchCash(),
                builder: (context, cashSnap) {
                  final cash = cashSnap.data ?? 0.0;

                  return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                    stream: _watchOrders(),
                    builder: (context, ordSnap) {
                      final orders = ordSnap.data ?? const [];
                      return FutureBuilder<({
                      double totalProfit,
                      double totalLoss,
                      double totalCost,
                      double currentValue
                      })>(
                        // هنا نحسب قيمة المراكز كاملة (بدون تجاهل لوتات اليوم)
                        future: _calcPnLFromOrders(orders, ignoreSameDay: false),
                        builder: (context, pnlSnap) {
                          final currentValue = pnlSnap.data?.currentValue ?? 0.0;
                          final totalPortfolio = cash + currentValue; // صافي الأصول = كاش + قيمة المراكز

                          return Row(
                            children: [
                              Expanded(
                                child: _TopInteractiveCard(
                                  icon: Icons.account_balance_wallet,
                                  title: 'صافي الأصول',
                                  value: _fmtMoney(totalPortfolio),
                                  subtitle: 'هذا الرصيد وهمي',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TopInteractiveCard(
                                  icon: Icons.refresh,
                                  title: 'إعادة الضبط',
                                  value: '',
                                  subtitle: 'سيتم حذف جميع أسهمك الحاليه',
                                  onTap: _resetWallet,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),


              const SizedBox(height: 24),

              // 2) طريقة الدفع (عرض فقط – محايدة) مع الأيقونات بجانب العنوان
              _paymentSectionCard(),

              const SizedBox(height: 16),

              // 3) الحركات: شراء = خصم ، بيع = إضافة (محايد في العرض)
              _sectionCard(
                title: 'حركات البطاقة (آخر العمليات: شراء = خصم • بيع = إضافة)',
                child: StreamBuilder<List<_WalletMovement>>(
                  stream: _watchWalletMovements(),
                  builder: (context, snap) {
                    final moves = snap.data ?? const <_WalletMovement>[];

                    if (moves.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'لا توجد عمليات حتى الآن.\nالمبالغ هنا تمثل الخصم عند الشراء والإضافة عند البيع — هذه ليست أسعار الأسهم الحالية.',
                          textAlign: TextAlign.right,
                        ),
                      );
                    }

                    // إجماليات
                    double totalDebited  = 0.0; // شراء (خصم)
                    double totalCredited = 0.0; // بيع (إضافة)
                    for (final m in moves) {
                      final amt = m.qty * m.price;
                      if (m.side == 'buy')  totalDebited  += amt;
                      if (m.side == 'sell') totalCredited += amt;
                    }
                    final net = totalCredited - totalDebited; // موجب = صافي إضافة

                    // الرصيد المتوقع من العمليات فقط (seed + net) — للمقارنة
                    final expectedCash = (_seed + net).clamp(0.0, double.infinity);

                    return Column(
                      children: [
                        ...moves.map(_movementTile).toList(),
                        const Divider(height: 1),

                        // ملخصات بدون تلوين دلالي
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: const Text('إجمالي الخصم (شراء)', style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Text(_sar(totalDebited), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: const Text('إجمالي الإضافة (بيع)', style: TextStyle(fontWeight: FontWeight.w600)),
                          trailing: Text(_sar(totalCredited), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: const Text('الصافي (بيع − شراء)', style: TextStyle(fontWeight: FontWeight.w700)),
                          trailing: Text(
                            (net >= 0 ? '+' : '-') + _sar(net.abs()).replaceFirst('ر.س ', ''),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),

                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Widgets ----------

  Widget _walletBalanceCard({required double amount}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: _green),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('الرصيد المتاح', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Row(
            children: [
              Image.asset('assets/saudi_riyal.png', width: 18, height: 18),
              const SizedBox(width: 6),
              Text(_sar(amount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentSectionCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.credit_card, color: _green),
                const SizedBox(width: 8),
                const Text(
                  'طريقة الدفع',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Tooltip(
                  message: 'هذه طريقة دفع افتراضية للتدريب فقط',
                  triggerMode: TooltipTriggerMode.tap,   // show on tap, not long-press
                  showDuration: Duration(seconds: 3),    // how long it stays visible
                  preferBelow: false,                    // show above the icon if possible
                  child: Icon(Icons.info_outline, size: 18),
                ),

              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('بطاقة ائتمانية (محاكاة تدريبية)'),
                ),
                const SizedBox(height: 12),
// هنا نعرض "القوة الشرائية" فقط داخل بطاقة نمو
                StreamBuilder<double>(
                  stream: _watchCash(),
                  builder: (context, cashSnap) {
                    final cash = cashSnap.data ?? 0.0;
                    return _virtualNomuCard(cash);
                  },
                ),

                // --- NEW BUTTON ADDED HERE (Styled as requested) ---
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _showExchangeDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _green,
                        elevation: 0, // Shadow is handled by Container
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: _green, width: 1),
                        ),
                      ),
                      icon: const Icon(Icons.currency_exchange, size: 24),
                      label: const Text(
                        'محتاج رصيد اضافي؟ استبدل عملاتك',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _virtualNomuCard(double totalPortfolio) {
    return Container(
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF2E7D4E), // أخضر غامق يسار
            Color(0xFF6FBF73), // أخضر أفتح يمين
          ],
        ),
      ),
      child: Stack(
        children: [
          // دوائر زخرفية يسار الكرت
          Positioned(
            left: -60,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(180),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 2,
                ),
              ),
            ),
          ),
          Positioned(
            left: -20,
            top: 40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(140),
                border: Border.all(
                  color: Colors.white.withOpacity(0.20),
                  width: 1.5,
                ),
              ),
            ),
          ),

          // "اللوجو" أسفل اليسار (صغرنا المربع شوية)
          Positioned(
            left: 24,
            bottom: 24,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.credit_card,
                color: _green,
                size: 26,
              ),
            ),
          ),

          // النصوص يمين الكرت
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'بطاقة نمو الافتراضية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "القوة الشرائية",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmtMoney(totalPortfolio).split('.').first, // بدون كسور
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'هذا الرصيد وهمي',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  // عنصر حركة محايد (شراء/بيع) بلا تلوين يدل على ربح/خسارة
  Widget _movementTile(_WalletMovement m) {
    final amt   = m.qty * m.price;
    final isAdd = m.side == 'sell'; // بيع = إضافة كاش
    final sign  = isAdd ? '+' : '-';
    final icon  = isAdd ? Icons.call_received : Icons.call_made; // استقبال/إرسال كاش (محايد)
    final label = isAdd ? 'بيع' : 'شراء';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(
        backgroundColor: _chipBg,
        child: Icon(icon, color: _neutral),
      ),
      title: Text('${m.name} (${m.symbol})', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${_fmtQty(m.qty)} × ${_sar(m.price)}  •  ${_dateStr(m.date)}  •  $label',
        style: const TextStyle(color: Colors.black54),
      ),
      trailing: Text(
        '$sign${_sar(amt).replaceFirst("ر.س ", "")}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ---------- Models ----------

class _WalletMovement {
  final String side;    // 'buy' | 'sell'
  final String symbol;
  final String name;
  final double qty;
  final double price;
  final DateTime date;

  const _WalletMovement({
    required this.side,
    required this.symbol,
    required this.name,
    required this.qty,
    required this.price,
    required this.date,
  });
}

// ---------- Payment method row (const-safe) ----------

class _PaymentMethodRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PaymentMethodRow({Key? key, required this.icon, required this.label}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _WalletPageState._green),
      title: Text(label),
      trailing: const Icon(Icons.info_outline, size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذه طريقة دفع افتراضية للتدريب فقط')),
        );
      },
    );
  }
}

// ---------- الكرت التفاعلي العلوي (الرصيد / إعادة الضبط) ----------

class _TopInteractiveCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String value;     // يمكن أن يكون فارغًا
  final String subtitle;  // يمكن أن يكون فارغًا
  final VoidCallback? onTap;

  const _TopInteractiveCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    this.onTap,
  }) : super(key: key);

  @override
  State<_TopInteractiveCard> createState() => _TopInteractiveCardState();
}

class _TopInteractiveCardState extends State<_TopInteractiveCard> {
  bool _hovered = false; // بقيت لكن لا نستخدمها فعليًا
  bool _pressed = false;

  void _setHovered(bool v) {
    setState(() => _hovered = v);
  }

  void _setPressed(bool v) {
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    // خلفية ثابتة أخضر فاتح
    const Color bgColor = Color(0xFFEFF7F0); // أخضر فاتح جدًا
    // ظل خفييف
    final List<BoxShadow> shadow = [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) {
          _setPressed(false);
          widget.onTap?.call();
        },
        onTapCancel: () => _setPressed(false),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          height: 190, // ارتفاع أكبر لتفادي الـ overflow مع نفس الحجم للكرتين
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _WalletPageState._green, // بوردر أخضر غامق
              width: 1.3,
            ),
            boxShadow: shadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                // دائرة ثابتة: أخضر غامق والأيقونة بيضاء
                backgroundColor: _WalletPageState._green,
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              if (widget.value.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
              if (widget.subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}