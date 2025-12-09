import 'package:flutter/material.dart';
import 'home_page.dart';
import 'stock_market_page.dart';
import 'user_profile.dart';
import 'Learning page.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'simulation_utils.dart';

// ====== LINE CHART ======
import 'package:fl_chart/fl_chart.dart';

// ========= إعدادات التسعير =========
const bool kWaitForClose = false; // false => يعرض سعر اليوم فورًا لو يوم عمل
const int kCloseHour = 15;

// baseline قبل أول عملية
const double kInitialPortfolio = 10000.0;

class _OpenLot {
  final String symbol;
  final double qty;
  final double price;
  final DateTime buyDate;
  const _OpenLot(this.symbol, this.qty, this.price, this.buyDate);
}

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({Key? key}) : super(key: key);
  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  int _selectedIndex = 3;

  // ====== حالة الشارت ======
  String _range = '1D'; // 1D / 1W / 1M / 3M
  bool _chartLoading = false;
  bool _noOrders = false;
  List<double> _chartTotals = [];   // y-values
  List<DateTime> _chartDays = [];   // x axis (للمدى > 1D)

  // مؤشر النقطة المختارة على الشارت (لإظهار أداء المحفظة عند اللمس/التحويم)
  int? _hoverIndex;

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

  String _fmtPct(double p) => '${p.toStringAsFixed(2)}%';

  // ---------- Safe parsers ----------
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

  bool _sameYMD(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ---------- Streams ----------
  Stream<double> _watchCash() async* {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { yield 0.0; return; }
    final base = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('wallet');

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

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _watchRawOrders() async* {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { yield const []; return; }
    final ref = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('orders');
    await for (final qs in ref.snapshots()) {
      yield qs.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
    }
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _watchPositions() async* {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { yield const []; return; }
    final ref = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('positions');
    await for (final qs in ref.snapshots()) {
      yield qs.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
    }
  }

  // غلاف بنفس الشكل اللي يحتاجه الكود الجديد
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _watchRawPositions() async* {
    yield* _watchPositions();
  }

  // ---------- Companies / Prices ----------
  Future<DocumentSnapshot<Map<String, dynamic>>?> _findCompanyBySymbol(String symbol) async {
    final asInt = _toInt(symbol);
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
        .where('symbol', isEqualTo: symbol)
        .limit(1)
        .get();
    if (q2.docs.isNotEmpty) return q2.docs.first;

    final d = await FirebaseFirestore.instance
        .collection('companies')
        .doc(symbol)
        .get();
    if (d.exists) return d;

    return null;
  }

  Future<double?> _latestCloseUntil(String symbol, DateTime onOrBefore) async {
    final compDoc = await _findCompanyBySymbol(symbol);
    if (compDoc == null) return null;
    final pricesRef = compDoc.reference.collection('PriceRecords_full');

    String ymd(DateTime dt) =>
        '${dt.year.toString().padLeft(4, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')}';

    Future<double?> _tryDoc(DateTime d) async {
      try {
        final doc = await pricesRef.doc(ymd(d)).get();
        if (doc.exists) {
          final c = doc.data()?['close'];
          if (c is num) return c.toDouble();
          if (c is String) return double.tryParse(c);
        }
      } catch (_) {}
      return null;
    }

    try {
      final q = await pricesRef
          .where('date', isLessThanOrEqualTo: ymd(onOrBefore))
          .orderBy('date', descending: true)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final c = q.docs.first.data()['close'];
        if (c is num) return c.toDouble();
        if (c is String) return double.tryParse(c);
      }
    } catch (_) {}

    final same = await _tryDoc(onOrBefore);
    if (same != null) return same;

    int steps = 0;
    DateTime cur = onOrBefore;
    while (steps < 15) {
      cur = cur.subtract(const Duration(days: 1));
      if (cur.weekday == DateTime.friday || cur.weekday == DateTime.saturday) continue;
      final v = await _tryDoc(cur);
      if (v != null) return v;
      steps++;
    }
    return null;
  }

  // ---------- Mapping (real day → dataset day) ----------
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
    final realTradingDay = kWaitForClose
        ? SimulationUtils.lastCompletedTradingDayConsideringClose(closeHour: kCloseHour)
        : SimulationUtils.chartEndUserDay();
    return _mapRealToDatasetDay(realTradingDay);
  }

  Future<DateTime> _effectivePricingDayForBuy(DateTime buyDate) async {
    return _mapRealToDatasetDay(buyDate);
  }

  // ---------- Parse orders ----------
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

      final queue = buys.map((b) => {
        'qty': (b['qty'] as double),
        'price': (b['price'] as double),
        'date': (b['date'] as DateTime),
      }).toList();

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

  // ========= أدوات مساعدة للشارت =========

  // اجمالي المحفظة الآن (نفس ما تحت الكروت) = cash + currentValue مع تجاهل لوتات اليوم
  Future<double> _resolveTotalPortfolioNow(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> orderDocs,
      double cash,
      ) async {
    final res = await _calcPnLFromOrders(orderDocs, ignoreSameDay: false);
    return cash + res.currentValue;
  }

  // يبني قيمة إجمالي المحفظة ليوم معين (يُطبّق نفس "تجاهل لوتات اليوم")
  Future<double> _portfolioAtDay(
      DateTime realDay,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> allOrders,
      double cash,
      DateTime firstOrderReal,
      ) async {
    if (_sameYMD(realDay, firstOrderReal) ||
        realDay.isBefore(DateTime(firstOrderReal.year, firstOrderReal.month, firstOrderReal.day))) {
      return kInitialPortfolio;
    }

    final dsDay = await _mapRealToDatasetDay(realDay);
    // أوامر حتى هذا اليوم
    final orders = allOrders.where((d) {
      final dt = _extractDate(d.data());
      return !dt.isAfter(realDay);
    }).toList();

    // بُني اللوتات
    final openLots = _buildOpenLotsFromOrders(orders);

    // تجاهل لوتات نفس اليوم (مطابقة لمنطق الكارد)
    final filteredLots = <_OpenLot>[];
    for (final lot in openLots) {
      final lotDsDay = await _effectivePricingDayForBuy(lot.buyDate);
      if (!_sameYMD(lotDsDay, dsDay)) {
        filteredLots.add(lot);
      }
    }

    // قيمة المراكز
    double positionsValue = 0.0;
    final Map<String, double> closeCache = {};
    for (final lot in filteredLots) {
      double? close = closeCache[lot.symbol];
      close ??= await _latestCloseUntil(lot.symbol, dsDay) ?? 0.0;
      closeCache[lot.symbol] = close;
      positionsValue += close * lot.qty;
    }

    // ملاحظة: نستخدم cash الحالي كما هو (مثل الكارد)
    return cash + positionsValue;
  }

  // ---------- P&L from orders only ----------
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
        if (_sameYMD(lotDatasetDay, simDatasetDay)) {
          continue; // لا P&L لوتات اليوم
        }
      }

      final symbol = lot.symbol;
      final close = closeCache.containsKey(symbol)
          ? closeCache[symbol]!
          : (await _latestCloseUntil(symbol, simDatasetDay) ?? 0.0);
      closeCache[symbol] = close;

      final nowVal = close * lot.qty;
      final cost   = lot.price * lot.qty;
      final diff   = nowVal - cost;

      totalCost     += cost;
      currentValue  += nowVal;

      if (diff > 0) totalProfit += diff;
      else if (diff < 0) totalLoss += -diff;
    }
    return (totalProfit: totalProfit, totalLoss: totalLoss, totalCost: totalCost, currentValue: currentValue);
  }

  // ====== تحميل بيانات الشارت ======
  Future<void> _loadChart() async {
    setState(() {
      _chartLoading = true;
      _hoverIndex = null; // إعادة ضبط المؤشر عند تغيير المدى
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _chartLoading = false;
      _noOrders = true;
      setState(() {});
      return;
    }

    final ordersSnap = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('orders').get();
    final orders = ordersSnap.docs;

    // cash الآن (نفس ما تستخدمه الكروت)
    final walletMain = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('wallet').doc('main').get();
    final walletAlt = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('wallet').doc('Main').get();
    final cash = walletMain.exists
        ? _toDouble(walletMain.data()?['cash'])
        : (walletAlt.exists ? _toDouble(walletAlt.data()?['cash']) : 0.0);

    if (orders.isEmpty) {
      _noOrders = true;
      _chartTotals = [];
      _chartDays = [];
      _chartLoading = false;
      setState(() {});
      return;
    }
    _noOrders = false;

    // أول عملية
    DateTime firstOrderReal = orders
        .map((d) => _extractDate(d.data()))
        .where((d) => d.year > 1970)
        .fold<DateTime?>(null, (prev, cur) => (prev == null || cur.isBefore(prev)) ? cur : prev)
        ?? SimulationUtils.chartEndUserDay();

    final todayReal = SimulationUtils.chartEndUserDay();

    if (_range == '1D') {
      // ======== 1D: أداء اليوم (baseline + realized from today's sells) ========

      // افصل أوامر اليوم وما قبل اليوم
      final todayOrders = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final beforeTodayOrders = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final d in orders) {
        final dt = _extractDate(d.data());
        if (_sameYMD(dt, todayReal)) {
          todayOrders.add(d);
        } else if (dt.isBefore(DateTime(todayReal.year, todayReal.month, todayReal.day).add(const Duration(days: 1)))) {
          beforeTodayOrders.add(d);
        }
      }
      todayOrders.sort((a, b) => _extractDate(a.data()).compareTo(_extractDate(b.data())));

      // قيمة المراكز بداية اليوم (بدون لوتات اليوم)
      final startRes = await _calcPnLFromOrders(beforeTodayOrders, ignoreSameDay: true);
      final currentValueStart = startRes.currentValue;

      // كاش بداية اليوم = الكاش الحالي − صافي كاش اليوم
      double netCashChangeToday = 0.0;
      for (final d in todayOrders) {
        final m = d.data();
        final side = _extractSide(m);
        final qty  = _toDouble(m['qty'] ?? m['quantity'] ?? m['Quantity'] ?? 0);
        final price= _toDouble(m['price'] ?? m['Price'] ?? 0);
        if (side == 'buy')  netCashChangeToday -= qty * price;
        if (side == 'sell') netCashChangeToday += qty * price;
      }
      final cashAtStart = cash - netCashChangeToday;

      // تجهيز FIFO من ما قبل اليوم
      final fifoBySymbol = <String, List<Map<String, double>>>{};
      for (final lot in _buildOpenLotsFromOrders(beforeTodayOrders)) {
        fifoBySymbol.putIfAbsent(lot.symbol, () => []);
        fifoBySymbol[lot.symbol]!.add({'qty': lot.qty, 'cost': lot.price});
      }

      final baselineTotal = cashAtStart + currentValueStart;

      final totals = <double>[baselineTotal];
      final days   = <DateTime>[DateTime(todayReal.year, todayReal.month, todayReal.day, 9, 30)];

      double realizedToday = 0.0;

      for (final d in todayOrders) {
        final m = d.data();
        final side = _extractSide(m);
        final symbol = _extractSymbol(m, d.id);
        final qty  = _toDouble(m['qty'] ?? m['quantity'] ?? m['Quantity'] ?? 0);
        final price= _toDouble(m['price'] ?? m['Price'] ?? 0);
        final ts   = _extractDate(m);

        fifoBySymbol.putIfAbsent(symbol, () => []);

        if (side == 'buy') {
          fifoBySymbol[symbol]!.add({'qty': qty, 'cost': price});
        } else if (side == 'sell') {
          double remaining = qty;
          final lots = fifoBySymbol[symbol]!;
          int i = 0;
          while (remaining > 1e-9 && i < lots.length) {
            final take = remaining <= lots[i]['qty']! ? remaining : lots[i]['qty']!;
            realizedToday += (price - lots[i]['cost']!) * take;
            lots[i]['qty'] = lots[i]['qty']! - take;
            if (lots[i]['qty']! <= 1e-9) { lots.removeAt(i); } else { i++; }
            remaining -= take;
          }
        }

  final updatedTotal = await _resolveTotalPortfolioNow(beforeTodayOrders + todayOrders.take(todayOrders.indexOf(d) + 1).toList(), cash);
  totals.add(updatedTotal);
  days.add(ts);
      }

      // ---- تأكيد أن آخر نقطة == إجمالي المحفظة الحالي (مثل الكروت) ----
      final totalNow = await _resolveTotalPortfolioNow(orders, cash);
      if (totals.isEmpty) {
        totals.add(totalNow);
        days.add(DateTime(todayReal.year, todayReal.month, todayReal.day, 23, 59));
      } else {
        totals[totals.length - 1] = totalNow;
        days[days.length - 1] = DateTime(todayReal.year, todayReal.month, todayReal.day, 23, 59);
      }

      _chartTotals = totals;
      _chartDays = days;
    } else {
      // 1W/1M/3M
      final count = _range == '1W' ? 7 : (_range == '1M' ? 30 : 90);

      // اجمع أيام العمل فقط
      final days = <DateTime>[];
      DateTime cur = todayReal;
      while (days.length < count) {
        if (SimulationUtils.isWorkday(cur)) days.add(cur);
        cur = cur.subtract(const Duration(days: 1));
      }
      days.sort();

      // ابن القيم
      final totals = <double>[];
      for (final d in days) {
        final v = await _portfolioAtDay(d, orders, cash, firstOrderReal);
        totals.add(v);
      }
      _chartDays = days;
      _chartTotals = totals;

      // ---- تأكيد أن آخر نقطة == إجمالي المحفظة الحالي (مثل الكروت) ----
      if (_chartTotals.isNotEmpty) {
        _chartTotals[_chartTotals.length - 1] = await _resolveTotalPortfolioNow(orders, cash);
      }
    }

    _chartLoading = false;
    setState(() {});
  }

  // === حساب أداء المحفظة عند نقطة معينة بالنسبة لأول نقطة في المدى الحالي ===
  ({double amt, double pct}) _perfAt(int idx) {
    if (_chartTotals.isEmpty) return (amt: 0.0, pct: 0.0);
    final i = idx.clamp(0, _chartTotals.length - 1);
    final base = _chartTotals.first;
    final v = _chartTotals[i];
    final diff = v - base;
    final pct = (base > 0) ? (diff / base * 100.0) : 0.0;
    return (amt: diff, pct: pct);
  }

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  // ---------- Navigation ----------
  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);

    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LearningPage()));
    } else if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MarketSimulationPage()));
    } else if (index == 3) {
      // Portfolio
    } else if (index == 4) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserProfilePage()));
    }
  }
Future<({double totalProfit, double totalLoss, double totalCost, double currentValue})> 
_calcPnL_full(List<QueryDocumentSnapshot<Map<String, dynamic>>> orderDocs) async {
  return await _calcPnLFromOrders(orderDocs, ignoreSameDay: false);
}

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            children: [
              // -------- Header --------
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF609966),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                padding: const EdgeInsets.only(top: 60, bottom: 24, left: 16, right: 16),
                child: Column(
                  children: [
                    // ====== LINE CHART (إجمالي المحفظة) ======
                    if (!_noOrders)
SizedBox(
  height: 150,
  child: _chartLoading
      ? const Center(child: CircularProgressIndicator(color: Colors.white))
      : Stack(
          clipBehavior: Clip.none, // 💡 ضروري لمنع القص
          children: [
            Positioned.fill(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  // ✅ مفعّل عناوين المحاور مع محور Y يسار
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        interval: () {
                          if (_chartTotals.isEmpty) return 1.0;
                          final yMin = _chartTotals.reduce((a, b) => a < b ? a : b);
                          final yMax = _chartTotals.reduce((a, b) => a > b ? a : b);
                          final span = (yMax - yMin).abs();
                          if (span <= 0.0001) {
                            final base = yMax == 0 ? 1.0 : (yMax.abs() / 2);
                            return base.clamp(0.01, double.infinity);
                          }
                          return (span / 4).clamp(0.01, double.infinity);
                        }(),
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: Text(
                              _fmtMoney(value),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchCallback: (event, resp) {
                      if (!event.isInterestedForInteractions ||
                          resp == null ||
                          resp.lineBarSpots == null ||
                          resp.lineBarSpots!.isEmpty) {
                        if (_hoverIndex != null) setState(() => _hoverIndex = null);
                        return;
                      }
                      final idx = resp.lineBarSpots!.first.x.toInt();
                      if (_hoverIndex != idx) setState(() => _hoverIndex = idx);
                    },
                    touchTooltipData: LineTouchTooltipData(
                      tooltipRoundedRadius: 8,
                      tooltipPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      fitInsideHorizontally: true, // 💡 مهم جدًا
                      fitInsideVertically: true,   // 💡 مهم جدًا
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((s) {
                          final i = s.x.toInt();
                          final perf = _perfAt(i);
                          final isUp = perf.amt >= 0;
                          final sign = isUp ? '+' : '-';
                          return LineTooltipItem(
                            '${_fmtMoney(s.y)}\nأداء المحفظة: $sign${_fmtMoney(perf.amt.abs())} (${_fmtPct(perf.pct.abs())})',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < _chartTotals.length; i++)
                          FlSpot(
                            i.toDouble(),
                            double.parse(_chartTotals[i].toStringAsFixed(2)),
                          ),
                      ],
                      isCurved: true,
                      color: Colors.white,
                      barWidth: 2,
                      dotData: FlDotData(show: _chartTotals.length <= 3),
                      belowBarData: BarAreaData(show: false),
                    )
                  ],
                  minX: 0,
                  maxX: (_chartTotals.length - 1).toDouble(),
                  minY: _chartTotals.isEmpty
                      ? 0
                      : _chartTotals.reduce((a, b) => a < b ? a : b),
                  maxY: _chartTotals.isEmpty
                      ? 1
                      : _chartTotals.reduce((a, b) => a > b ? a : b),
                ),
              ),
            ),
          ],
        ),
),


                    if (_noOrders)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.campaign, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            const Text('ابدأ الاستثمار لعرض أداء محفظتك', style: TextStyle(color: Colors.white)),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => MarketSimulationPage()),
                                );
                              },
                              child: const Text('استثمر الآن', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // الفلاتر
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['1D', '1W', '1M', '3M'].map((e) {
                        final isSelected = e == _range;
                        return GestureDetector(
                          onTap: () async {
                            setState(() => _range = e);
                            await _loadChart();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              e,
                              style: TextStyle(
                                  color: isSelected ? const Color(0xFF9DC08B) : Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // -------- Summary (Cash + P&L + Total) --------
              StreamBuilder<double>(
                stream: _watchCash(),
                builder: (context, cashSnap) {
                  final cash = cashSnap.data ?? 0.0;

                  return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                    stream: _watchRawOrders(),
                    builder: (context, ordSnap) {
                      final orderDocs = ordSnap.data ?? const [];

                      return FutureBuilder<({double totalProfit, double totalLoss, double totalCost, double currentValue})>(
                        future: _calcPnLFromOrders(orderDocs, ignoreSameDay: false),
                        builder: (context, pnlSnap) {
                          final totalProfit  = pnlSnap.data?.totalProfit  ?? 0.0;
                          final totalLoss    = pnlSnap.data?.totalLoss    ?? 0.0;
                          final totalCost    = pnlSnap.data?.totalCost    ?? 0.0;
                          final currentValue = pnlSnap.data?.currentValue ?? 0.0;

                          // نسب صحيحة: نسبة الربح/الخسارة مقابل إجمالي التكلفة
                          final profitPct = (totalCost > 0) ? (totalProfit / totalCost * 100.0) : 0.0;
                          final lossPct   = (totalCost > 0) ? (totalLoss   / totalCost * 100.0) : 0.0;

                          final totalPortfolio = cash + currentValue; // كاش + قيمة المراكز الحالية

                          return Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              children: [
                                Text('صافي الأصول', style: TextStyle(fontSize: 18, color: Colors.grey)),
                             Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 6),
                        Text(_fmtMoney(totalPortfolio), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      Image.asset('assets/saudi_riyal_black.png', height: 24),
                      ],
                    ),
                                Text('هذا الرصيد وهمي', style: TextStyle(color: Colors.red, fontSize: 14)),

                                const SizedBox(height: 12),

                                // صف القيم بدون كلمات "ربح/خسارة"
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // الخسارة (أحمر)
                                    Row(
                                      children: [
                                        const SizedBox(width: 4),
                                        Text(
                                          '(${_fmtPct(lossPct)})',
                                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '-${_fmtMoney(totalLoss)}',
                                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 6),
                                        Image.asset('assets/saudi_riyal_black.png', width: 18, height: 18),
                                      ],
                                    ),

                                    // الربح (أخضر)
                                    Row(
                                      children: [
                                        const SizedBox(width: 4),
                                        Text(
                                          '(${_fmtPct(profitPct)})',
                                          style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '+${_fmtMoney(totalProfit)}',
                                          style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 6),
                                        Image.asset('assets/saudi_riyal_black.png', width: 18, height: 18),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // -------- حسابي --------
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('حسابي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),

              StreamBuilder<double>(
                stream: _watchCash(),
                builder: (context, cashSnap) {
                  final cash = cashSnap.data ?? 0.0;
                  return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                    stream: _watchRawOrders(),
                    builder: (context, ordSnap) {
                      final orderDocs = ordSnap.data ?? const [];
                      return FutureBuilder<({double totalProfit, double totalLoss, double totalCost, double currentValue})>(
                        future: _calcPnLFromOrders(orderDocs, ignoreSameDay: false),
                        builder: (context, pnlSnap) {
                          final totalProfit  = pnlSnap.data?.totalProfit  ?? 0.0;
                          final totalLoss    = pnlSnap.data?.totalLoss    ?? 0.0;
                          final totalCost    = pnlSnap.data?.totalCost    ?? 0.0;
                          final currentValue = pnlSnap.data?.currentValue ?? 0.0;
                          final totalPortfolio = cash + currentValue;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatItem(
                                        'إجمالي الخسارة',
                                        '-${_fmtMoney(totalLoss)}',
                                        Icons.trending_down,
                                        Colors.orange.shade100,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatItem(
                                        "القوة الشرائية",
                                        _fmtMoney(cash),
                                        Icons.account_balance_wallet,
                                        Colors.blue.shade100,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatItem(
                                        'إجمالي الأرباح',
                                        '+${_fmtMoney(totalProfit)}',
                                        Icons.show_chart,
                                        const Color(0xFF9DC08B),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatItem(
                                        "صافي الأصول",
                                        _fmtMoney(totalPortfolio),
                                        Icons.pie_chart,
                                        Colors.red.shade100,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // -------- استثماراتي الحالية --------
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('استثماراتي الحالية',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),

              StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                stream: _watchRawPositions(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  var docs = [...snap.data!];

                  // ترتيب حسب updatedAt إن وجد
                  DateTime _toDT(dynamic v) => _toDateTime(v) ?? DateTime(1970);
                  docs.sort((a, b) {
                    final da = _toDT(a.data()['updatedAt'] ?? a.data()['createdAt'] ?? a.data()['created_at']);
                    final db = _toDT(b.data()['updatedAt'] ?? b.data()['createdAt'] ?? b.data()['created_at']);
                    return db.compareTo(da);
                  });

                  docs = docs.take(20).toList();
                    if (docs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Center(
          child: Text('لا توجد أي استثمارات حالية'),
        ),
      );
    }


                  return Column(
                    children: docs.map((d) {
                      final m = d.data();
                      final symbol = (m['symbol'] ?? d.id).toString();
                      final qty = _toDouble(m['quantity'] ?? m['qty'] ?? 0.0);
                      final avg = _toDouble(m['avgCost'] ?? 0.0);
                      final liked = (m['liked'] == true);

                      return FutureBuilder<Widget>(
                        future: _buildInvestmentCardDynamic(
                          positionDoc: d.reference,
                          symbol: symbol,
                          qty: qty,
                          avgCost: avg,
                          liked: liked,
                        ),
                        builder: (context, w) {
                          if (!w.hasData) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: Colors.white,
                                boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 6, spreadRadius: 2)],
                              ),
                              child: const LinearProgressIndicator(minHeight: 2),
                            );
                          }
                          return w.data!;
                        },
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: const Color(0xFF609966),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            const BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF609966),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [BoxShadow(color: const Color(0xFF9DC08B).withOpacity(0.3), blurRadius: 5, spreadRadius: 2)],
                ),
                child: Image.asset('assets/saudi_riyal.png', width: 30, height: 30),
              ),
              label: '',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: ''),
            const BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
          ],
        ),
      ),
    );
  }

// ---------- UI helpers ----------
OverlayEntry? _portfolioStatTooltipEntry;
Widget _buildStatItem(String title, String value, IconData icon, Color bgColor) {
  final showRiyalIcon = title != 'الطلبات المعلقة';

  void _showTitleInfoTapDown(BuildContext context, TapDownDetails details) {
    String msg;
    if (title == 'القوة الشرائية') {
      msg = 'القوة الشرائية: المبلغ المتاح لديك حاليًا لشراء الأسهم داخل المحفظة.';
    } else if (title == 'صافي الأصول') {
      msg = 'صافي الأصول: مجموع رصيدك النقدي + القيمة الحالية لجميع استثماراتك.';
    } else {
      return;
    }

    // ✅ لو التولتيب شغال أصلاً، لا تسوي شيء
    if (_portfolioStatTooltipEntry != null) return;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final size = MediaQuery.of(context).size;
    const double tooltipWidth = 230.0;
    const double padding = 12.0;

    double left = details.globalPosition.dx - tooltipWidth / 2;

    if (left < padding) {
      left = padding;
    }
    if (left + tooltipWidth + padding > size.width) {
      left = size.width - tooltipWidth - padding;
    }

    double top = details.globalPosition.dy + 10;

    const double approxHeight = 90.0;
    if (top + approxHeight + padding > size.height) {
      top = details.globalPosition.dy - approxHeight - 10;
      if (top < padding) {
        top = padding;
      }
    }

    _portfolioStatTooltipEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(10),
            width: tooltipWidth,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.88),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              msg,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ),
    );

    overlay.insert(_portfolioStatTooltipEntry!);

    Future.delayed(const Duration(seconds: 3), () {
      _portfolioStatTooltipEntry?.remove();
      _portfolioStatTooltipEntry = null; // ✅ نرجعها null عشان يسمح برسالة جديدة بعدين
    });
  }


  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      children: [
        CircleAvatar(backgroundColor: bgColor, child: Icon(icon, color: Colors.black)),
        const SizedBox(height: 8),

        // العنوان + آيكون info (للقوة الشرائية وصافي الأصول فقط)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (title == 'القوة الشرائية' || title == 'صافي الأصول') ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTapDown: (details) => _showTitleInfoTapDown(context, details),
                child: const Icon(Icons.info_outline, size: 16),
              ),
            ],
          ],
        ),

        const SizedBox(height: 4),

        // القيمة ثم أيقونة الريال
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value.trim(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (showRiyalIcon) ...[
              const SizedBox(width: 4),
              Image.asset('assets/saudi_riyal_black.png', height: 16),
            ],
          ],
        ),
      ],
    ),
  );
}

  Widget _buildCurrentInvestmentCard({required String symbol, required double? close}) {
    final priceText = (close == null) ? '—' : _fmtMoney(close);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 6, spreadRadius: 2)],
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 22, child: Icon(Icons.business)),
          const SizedBox(width: 12),
          Expanded(
            child: Text('رمز: $symbol', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Row(
            children: [
              Image.asset('assets/saudi_riyal_black.png', width: 18, height: 18),
              const SizedBox(width: 4),
              Text(priceText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ====== الكارت الديناميكي للمراكز ======
  Future<Widget> _buildInvestmentCardDynamic({
    required DocumentReference positionDoc,
    required String symbol,
    required double qty,
    required double avgCost,
    required bool liked,
  }) async {
    // --- جلب اسم الشركة والشعار والسعر الحالي والقرار ---
    String companyName = 'رمز: $symbol';
    String logoAsset = '';
    double predicted = 0.0;
    String decision = '';
    
    try {
      final compDoc = await _findCompanyBySymbol(symbol);
      final comp = compDoc?.data() ?? {};
      companyName = (comp['name'] ?? compDoc?.id ?? symbol).toString();
      // يقبل إما اسم ملف أو مسار كامل يبدأ بـ assets/
      logoAsset = (comp['logoAsset'] ?? comp['logo'] ?? '').toString().trim();
      if (logoAsset.isNotEmpty && !logoAsset.startsWith('assets/')) {
        logoAsset = 'assets/company-logos/$logoAsset';
      }
      
      // جلب السعر المتوقع والقرار إذا كان موجودًا
      predicted = _toDouble(comp['predicted'] ?? 0.0);
      decision = (comp['decision'] ?? '').toString();
    } catch (_) {}

    // --- الحسابات ---
    final simDay = await _effectivePricingDayNow();
    final close = await _latestCloseUntil(symbol, simDay) ?? 0.0;

    final currentValue = close * qty;
    final cost = avgCost * qty;
    final pnl = currentValue - cost;
    final pnlPct = (avgCost > 0) ? ((close - avgCost) / avgCost * 100.0) : 0.0;

    final isUp = pnl >= 0;
    final pnlColor = isUp ? const Color(0xFF2E7D32) : Colors.red;

   return GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MarketSimulationPage(),
        settings: RouteSettings(
          arguments: {
            'symbol': symbol,
            'selectedCompany': companyName,
          },
        ),
      ),
    );
  },
  child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.grey.shade100,
          blurRadius: 6,
          spreadRadius: 2,
        )
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: ClipOval(
            child: Image.asset(
              logoAsset.isNotEmpty
                  ? logoAsset
                  : 'assets/company-logos/default.png',
              fit: BoxFit.contain,
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(companyName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'الكمية: ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      const Text('متوسط: ',
                          style: TextStyle(color: Colors.black54)),
                      Image.asset('assets/saudi_riyal_black.png',
                          width: 14, height: 14),
                      const SizedBox(width: 2),
                      Text(
                        _fmtMoney(avgCost),
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('السعر الحالي: ',
                      style: TextStyle(color: Colors.black54)),
                  Image.asset('assets/saudi_riyal_black.png',
                      width: 14, height: 14),
                  const SizedBox(width: 2),
                  Text(
                    _fmtMoney(close),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Image.asset('assets/saudi_riyal_black.png',
                    width: 16, height: 16),
                const SizedBox(width: 4),
                Text(
                  (isUp ? '+' : '-') + _fmtMoney(pnl.abs()),
                  style: TextStyle(
                    color: pnlColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              (isUp ? '+' : '-') + _fmtPct(pnlPct.abs()),
              style: TextStyle(
                color: pnlColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),

        const SizedBox(width: 8),

        IconButton(
          onPressed: () async {
            final userId = FirebaseAuth.instance.currentUser?.uid;
            if (userId == null) return;

            try {
              await positionDoc.update({'liked': !liked});

              if (!liked) {
                await FirebaseFirestore.instance
                    .collection('Favorites')
                    .doc(userId)
                    .collection('stocks')
                    .doc(symbol)
                    .set({
                  'name': companyName,
                  'logoAsset':
                      logoAsset.replaceAll('assets/company-logos/', ''),
                  'close': close,
                  'predicted': predicted > 0 ? predicted : close,
                  'decision': decision.isNotEmpty
                      ? decision
                      : (isUp ? 'اشتري' : 'بيع'),
                  'addedAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تمت إضافة السهم إلى المفضلة'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Color(0xFF609966),
                    ),
                  );
                }
              } else {
                await FirebaseFirestore.instance
                    .collection('Favorites')
                    .doc(userId)
                    .collection('stocks')
                    .doc(symbol)
                    .delete();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تمت إزالة السهم من المفضلة'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('حدث خطأ: $e')),
                );
              }
            }
          },
          icon: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            color: liked ? const Color(0xFF609966) : Colors.grey,
          ),
        ),
      ],
    ),
  ),
);

  }
}
