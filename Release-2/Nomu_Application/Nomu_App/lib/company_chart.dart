// 📦 lib/company_chart_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trading_service.dart';

class CompanyChartWidget extends StatefulWidget {
  final String companyName;

  const CompanyChartWidget({
    Key? key,
    required this.companyName,
  }) : super(key: key);

  @override
  State<CompanyChartWidget> createState() => _CompanyChartWidgetState();
}

class _CompanyChartWidgetState extends State<CompanyChartWidget> {
  static const Color _customGreen = Color(0xFF609966);
  static const Color _customRed = Color(0xFFD32F2F);

  int daysFilter = 5;

  // محاكاة
  final DateTime baseSimulationDate = DateTime(2019, 3, 31);
  DateTime? simulationStartRealDate;

  // تداول
  late final TradingService _trading;
  double? _currentSimPrice;
  DateTime? _lastComputedSimDate;

  // 🔹 كاش المراكز المباشرة لسرعة الاستجابة
  StreamSubscription<QuerySnapshot>? _posSub;
  final Map<String, int> _ownedBySymbol = {}; // symbol -> qty
  final Map<String, int> _ownedByName = {};   // docId(name) -> qty

  @override
  void initState() {
    super.initState();
    _trading = TradingService();
    _initUserStuff();
  }

  Future<void> _initUserStuff() async {
    await _loadSimulationStartDate();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _trading.ensureWallet(uid);
      _listenPositions(uid);
    }
    if (mounted) setState(() {});
  }

  void _listenPositions(String uid) {
    _posSub?.cancel();
    _posSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('positions')
        .snapshots()
        .listen((qs) {
      final bySymbol = <String, int>{};
      final byName = <String, int>{};
      for (final d in qs.docs) {
        final data = d.data() as Map<String, dynamic>;
        final sym = (data['symbol'] ?? '').toString();
        final qtyField = data['qty'] ?? data['quantity'];
        final qty = (qtyField is num) ? qtyField.toInt() : int.tryParse('$qtyField') ?? 0;
        if (sym.isNotEmpty) bySymbol[sym] = qty;
        byName[d.id] = qty;
      }
      _ownedBySymbol
        ..clear()
        ..addAll(bySymbol);
      _ownedByName
        ..clear()
        ..addAll(byName);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _loadSimulationStartDate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      setState(() {
        simulationStartRealDate =
        (data != null && data.containsKey('createdAt'))
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now();
      });
    }
  }

  // ————— منطق التواريخ —————

  DateTime _calculateSimulatedDate(List<DateTime> allTradingDays) {
    if (simulationStartRealDate == null || allTradingDays.isEmpty) {
      return baseSimulationDate;
    }

    int startIndex = allTradingDays.indexWhere((date) =>
    date.year == baseSimulationDate.year &&
        date.month == baseSimulationDate.month &&
        date.day == baseSimulationDate.day);

    if (startIndex == -1) {
      startIndex =
          allTradingDays.indexWhere((date) => date.isAfter(baseSimulationDate));
    }
    if (startIndex == -1) return baseSimulationDate;

    DateTime today = DateTime.now();
    int realTradingDays = _countRealTradingDays(simulationStartRealDate!, today);
    int targetIndex = startIndex + realTradingDays;

    if (targetIndex >= allTradingDays.length) {
      return allTradingDays.last;
    }
    return allTradingDays[targetIndex];
  }

  int _countRealTradingDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime current =
    DateTime(start.year, start.month, start.day).add(const Duration(days: 1));
    DateTime endDate = DateTime(end.year, end.month, end.day);

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      if (current.weekday != DateTime.friday &&
          current.weekday != DateTime.saturday) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  List<QueryDocumentSnapshot> _filterTradingDays(
      List<QueryDocumentSnapshot> docs, int tradingDays, DateTime simDate) {
    final filtered = <QueryDocumentSnapshot>[];
    for (int i = docs.length - 1; i >= 0 && filtered.length < tradingDays; i--) {
      final date = _parseDate(docs[i]['date']);
      if (date.isAfter(simDate)) continue;
      filtered.insert(0, docs[i]);
    }
    return filtered;
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    throw Exception("نوع غير مدعوم للتاريخ: $value");
  }

  DateTime _convertToRealDate(
      DateTime firebaseDate, List<DateTime> allTradingDays, DateTime simDate) {
    int indexInSim = allTradingDays.indexWhere((d) =>
    d.year == firebaseDate.year &&
        d.month == firebaseDate.month &&
        d.day == firebaseDate.day);
    if (indexInSim == -1) return firebaseDate;

    int currentIndex = allTradingDays.indexWhere((d) =>
    d.year == simDate.year &&
        d.month == simDate.month &&
        d.day == simDate.day);
    if (currentIndex == -1) return firebaseDate;

    int daysDiff = currentIndex - indexInSim;

    DateTime realToday = DateTime.now();
    if (realToday.weekday == DateTime.friday) {
      realToday = realToday.subtract(const Duration(days: 1));
    } else if (realToday.weekday == DateTime.saturday) {
      realToday = realToday.subtract(const Duration(days: 2));
    }

    DateTime resultDate = realToday;
    int tradingDaysSubtracted = 0;
    while (tradingDaysSubtracted < daysDiff) {
      resultDate = resultDate.subtract(const Duration(days: 1));
      if (resultDate.weekday != DateTime.friday &&
          resultDate.weekday != DateTime.saturday) {
        tradingDaysSubtracted++;
      }
    }
    return resultDate;
  }

  // ————— UI Widgets Helper —————

  Widget _buildReceiptRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                fontSize: 14
            ),
          ),
        ],
      ),
    );
  }

  // ————— Build Method —————

  @override
  Widget build(BuildContext context) {
    if (simulationStartRealDate == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('companies')
          .where('name', isEqualTo: widget.companyName)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("الشركة غير موجودة"));
        }

        final companyDoc = snapshot.data!.docs.first;
        final data = companyDoc.data() as Map<String, dynamic>;
        final companyId = companyDoc.id;

        // الرمز قد يكون id أو symbol
        final symbol = (data['id'] ?? '').toString().isNotEmpty
            ? (data['id']).toString()
            : (data['symbol'] ?? data['name'] ?? widget.companyName).toString();
        final displayName = (data['name'] ?? widget.companyName).toString();

        return Column(
          children: [
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<int>(
                  value: daysFilter,
                  items: const [
                    DropdownMenuItem(value: 5, child: Text("أسبوع")),
                    DropdownMenuItem(value: 22, child: Text("شهر")),
                    DropdownMenuItem(value: 66, child: Text("3 شهور")),
                  ],
                  onChanged: (val) => setState(() => daysFilter = val!),
                ),
                Expanded(
                  child: Text(
                    'الرسم البياني لأسهم $displayName',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    softWrap: true,
                  ),
                ),
              ],
            ),

            Container(
              height: 350,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8)],
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('companies')
                    .doc(companyId)
                    .collection('PriceRecords_full')
                    .orderBy('date')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = snapshot.data!.docs;
                  final allTradingDays =
                  allDocs.map((doc) => _parseDate(doc['date'])).toList();

                  if (allTradingDays.isEmpty) {
                    return const Center(child: Text("لا توجد بيانات"));
                  }

                  final currentSimDate = _calculateSimulatedDate(allTradingDays);
                  _lastComputedSimDate = currentSimDate;

                  final docs =
                  _filterTradingDays(allDocs, daysFilter, currentSimDate);

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("لا توجد بيانات لهذه الفترة في المحاكاة"),
                          const SizedBox(height: 10),
                          Text(
                            "تاريخ المحاكاة الحالي: ${currentSimDate.day}/${currentSimDate.month}/${currentSimDate.year}",
                            style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  final spots = <FlSpot>[];
                  for (int i = 0; i < docs.length; i++) {
                    final record = docs[i].data() as Map<String, dynamic>;
                    final y = (record['close'] as num).toDouble();
                    spots.add(FlSpot(i.toDouble(), y));
                  }
                  _currentSimPrice = spots.isNotEmpty ? spots.last.y : null;

                  double minY =
                  spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
                  double maxY =
                  spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
                  double padding = (maxY - minY) * 0.05;
                  if (padding == 0) padding = 1;
                  minY -= padding;
                  maxY += padding;
                  final intervalY =
                  ((maxY - minY) / 2.8).clamp(0.1, double.infinity);

                  List<int> displayIndices = [];
                  if (docs.length == 1) {
                    displayIndices = [0];
                  } else if (docs.length <= 5) {
                    for (int i = 0; i < docs.length; i++) {
                      displayIndices.add(i);
                    }
                  } else {
                    for (int i = 0; i < 5; i++) {
                      int index = ((docs.length - 1) * i / 4).round();
                      displayIndices.add(index);
                    }
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 55,
                                  interval: intervalY,
                                  getTitlesWidget: (value, meta) => Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(
                                          fontSize: 10, color: Color(0xFF666666)),
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 50,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (!displayIndices.contains(index)) {
                                      return const SizedBox.shrink();
                                    }
                                    final firebaseDate =
                                    _parseDate(docs[index]['date']);
                                    final displayDate = _convertToRealDate(
                                        firebaseDate,
                                        allTradingDays,
                                        currentSimDate);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Transform.rotate(
                                        angle: -0.5,
                                        child: Text(
                                          "${displayDate.day}/${displayDate.month}",
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: true),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                preventCurveOverShooting: true,
                                color: _customGreen,
                                barWidth: 2.5,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: _customGreen.withOpacity(0.2),
                                ),
                              ),
                            ],
                            // ✅ تحديث TouchData لتجنب الخطأ
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) => Colors.black87,
                                tooltipRoundedRadius: 8,
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    return LineTooltipItem(
                                      spot.y.toStringAsFixed(2),
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          TextButton(
                          onPressed: () {
                          final reason = _marketCloseReason();
                          if (reason != null) {
                          _showBottomMessage(message: reason, isSell: true);
                            return;
                          }

                          if (_currentSimPrice != null) {
                            _openTradePopup(
                              side: 'BUY',
                              companyId: companyId,
                              symbol: symbol,
                              name: displayName,
                            );
                          }
                        },

                            style: TextButton.styleFrom(
                              backgroundColor: _customGreen,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              padding:
                              const EdgeInsets.symmetric(horizontal: 32),
                            ),
                            child: const Text('شراء',
                                style: TextStyle(color: Colors.white)),
                          ),
                          // ✅ زر البيع أحمر
                          ElevatedButton(
                           onPressed: () {
                            final reason = _marketCloseReason();
                            if (reason != null) {
                              _showBottomMessage(message: reason, isSell: true);
                              return;
                            }

                            if (_currentSimPrice != null) {
                              _openTradePopup(
                                side: 'SELL',
                                companyId: companyId,
                                symbol: symbol,
                                name: displayName,
                              );
                            }
                          },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: _customRed,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                              padding:
                              const EdgeInsets.symmetric(horizontal: 32),
                              elevation: 0,
                            ),
                            child: const Text('بيع',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 10)],
              ),
              child: Text(
                data['description']?.toString() ?? "لا يوجد وصف",
                style: const TextStyle(fontSize: 14, height: 1.6),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        );
      },
    );
  }


Future<void> _showModernDialog({
  required String message,
  required bool isError,
  required String side,
}) async {
  final Color mainColor =
      side == "SELL" ? Color(0xFFD32F2F) : Color(0xFF609966);

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: mainColor, // ✔ استخدم اللون الصحيح هنا
            ),
            SizedBox(width: 8),
            Text(
              isError ? "تنبيه" : "تم بنجاح",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "حسناً",
              style: TextStyle(
                color: mainColor, // ✔ وهنا أيضاً
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  // ========= التداول =========

  int _ownedFor({required String symbol, required String name}) {
    return _ownedBySymbol[symbol] ?? _ownedByName[name] ?? 0;
  }

String? _marketCloseReason() {
  final now = DateTime.now();

  // عطلة نهاية الأسبوع (جمعة + سبت)
  if (now.weekday == DateTime.friday || now.weekday == DateTime.saturday) {
    return "السوق مغلق — عطلة نهاية الأسبوع";
  }

  // إغلاق يومي (من 3 العصر إلى 10 الصباح)
  if (now.hour >= 15 || now.hour < 10) {
    return "السوق مغلق الآن — التداول متاح من 10 صباحًا إلى 3 مساءً";
  }

  return null; // السوق مفتوح
}


  Future<void> _openTradePopup({
    required String side,
    required String companyId,
    required String symbol,
    required String name,
  }) async {

final reason = _marketCloseReason();
if (reason != null) {
_showBottomMessage(message: reason, isSell: true);
  return;
}

    final price = _currentSimPrice;
    if (price == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final owned = _ownedFor(symbol: symbol, name: name);

    if (side == 'SELL' && owned <= 0) {
      await showDialog(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 36),
                  const SizedBox(height: 10),
                  const Text('لا تملك أسهماً من هذه الشركة',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('لا توجد أسهم مملوكة في $name (الرمز: $symbol) لبيعها حالياً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _customGreen,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('حسناً'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    int qty = side == 'SELL' ? (owned > 0 ? 1 : 0) : 1;
    bool sellAll = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (context, setLocal) {
              final total = qty * price;
              String fmt(double v) => v.toStringAsFixed(2);

              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // عنوان
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 10),
                        child: Text(
                          side == 'BUY' ? 'أمر شراء' : 'أمر بيع',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),

                      // بطاقة معلومات
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xfff6f4f9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.business,
                                    size: 18, color: _customGreen),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(name,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.tag,
                                    size: 18, color: _customGreen),
                                const SizedBox(width: 6),
                                Text('الرمز: $symbol',
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.inventory_2,
                                    size: 18, color: _customGreen),
                                const SizedBox(width: 6),
                                Text('تملك حالياً: $owned سهم',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // السعر
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('سعر السهم (محاكاة):',
                              style:
                              TextStyle(fontSize: 14, color: Colors.black54)),
                          Text(fmt(price),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // كمية (تعطّل إذا بيع الكل)
                      if (!(side == 'SELL' && sellAll)) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('الكمية',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade700)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => setLocal(
                                        () => qty = (qty > 1) ? qty - 1 : 1),
                                icon: const Icon(Icons.remove),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(qty.toString(),
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              IconButton(
                                onPressed: () => setLocal(() {
                                  if (side == 'SELL') {
                                    if (qty < owned) qty += 1;
                                  } else {
                                    qty += 1;
                                  }
                                }),
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (side == 'SELL' && owned > 0) ...[
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: sellAll,
                          onChanged: (v) {
                            setLocal(() {
                              sellAll = v ?? false;
                              if (sellAll) {
                                qty = owned;
                              } else {
                                qty = qty.clamp(1, owned);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('بيع كل الأسهم المملوكة'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],

                      const SizedBox(height: 10),

                      // الإجمالي
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي:',
                              style:
                              TextStyle(fontSize: 14, color: Colors.black54)),
                          Text((total).toStringAsFixed(2),
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // أزرار
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: _customGreen),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('إلغاء',
                                  style: TextStyle(color: _customGreen)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (side == 'SELL' && sellAll) {
                                  final sure = await showDialog<bool>(
                                    context: ctx,
                                    builder: (_) => Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: AlertDialog(
                                        title: const Text('تأكيد بيع الكل'),
                                        content: Text(
                                            'هل أنت متأكد من بيع جميع أسهمك ($owned) في $name؟'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('لا')),
                                          ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('نعم، بيع الكل')),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (sure != true) return;
                                }

                                Navigator.pop(ctx);
                                await _confirmAndPlace(
                                  side: side,
                                  qty: qty,
                                  price: price,
                                  companyId: companyId,
                                  symbol: symbol,
                                  name: name,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _customGreen,
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('تأكيد'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

void _showBottomMessage({
  required String message,
  required bool isSell,
}) {
  showModalBottomSheet(
    context: context,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSell ? _customRed : _customGreen,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: isSell ? _customRed : _customGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "حسناً",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}


  Future<void> _confirmAndPlace({
    required String side,
    required int qty,
    required double price,
    required String companyId,
    required String symbol,
    required String name,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final total = qty * price;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Icon Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (side == 'BUY' ? _customGreen : _customRed).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    side == 'BUY' ? Icons.assured_workload : Icons.assured_workload_outlined,
                    color: side == 'BUY' ? _customGreen : _customRed,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Title
                const Text(
                  'تأكيد الأمر',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'يرجى مراجعة تفاصيل العملية أدناه',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 24),

                // 3. Receipt Details Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildReceiptRow('الشركة', name),
                      _buildReceiptRow('الرمز', symbol),
                      const Divider(height: 24),
                      _buildReceiptRow(
                          'نوع الأمر',
                          side == "BUY" ? "شراء" : "بيع",
                          valueColor: side == "BUY" ? _customGreen : _customRed,
                          isBold: true
                      ),
                      _buildReceiptRow('الكمية', '$qty سهم'),
                      _buildReceiptRow('سعر السهم', '${price.toStringAsFixed(2)} ر.س'),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            '${total.toStringAsFixed(2)} ر.س',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 4. Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('إلغاء', style: TextStyle(color: Colors.grey.shade600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: side == 'BUY' ? _customGreen : _customRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'تأكيد وتنفيذ',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true) return;

    final simulatedDate = _lastComputedSimDate ?? now;

    try {
      final result = await _trading.placeOrder(
        uid: uid,
        companyId: companyId,
        symbol: symbol,
        name: name,
        side: side,
        qty: qty,
        price: price,
        simDate: simulatedDate,
      );

      // ✅ رسالة نجاح خضراء
      final sideAr = (result['side'] == 'BUY') ? 'شراء' : 'بيع';
      final msg = 'تم تنفيذ الأمر: $sideAr $qty سهم في $symbol';
      _showBottomMessage(
        message: msg,
        isSell: side == 'SELL',
      );


    } catch (e) {
      // ❌ رسالة خطأ حمراء
      var msg = 'حدث خطأ غير متوقع';
      final s = e.toString();
      if (s.contains('INSUFFICIENT_CASH')) msg = 'رصيد المحفظة غير كافٍ';
      if (s.contains('INSUFFICIENT_SHARES')) msg = 'عدد الأسهم أقل من المطلوب للبيع';

      _showBottomMessage(message: msg, isSell: true);
    }
  }
}

