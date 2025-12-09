// lib/stock_market_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'user_profile.dart';
import 'market_prediction_page.dart';
import 'portfolio_page.dart';
import 'Learning page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'company_chart.dart';
import 'market_overview_chart.dart';
import 'simulation_utils.dart';

// Helper class for Gainer data
class _Gainer {
  final String companyId;
  final String name;
  final String logoAsset;
  final double lastPrice;
  final double changePct;
  _Gainer({
    required this.companyId,
    required this.name,
    required this.logoAsset,
    required this.lastPrice,
    required this.changePct,
  });
}

class MarketSimulationPage extends StatefulWidget {
  @override
  _MarketSimulationPageState createState() => _MarketSimulationPageState();
}

class _MarketSimulationPageState extends State<MarketSimulationPage> {
  static const Color _customGreen = Color(0xFF609966);
  int _selectedIndex = 2;
  String? selectedCompany;
  DateTime? simulationStartRealDate;
  OverlayEntry? _topGainersInfoEntry;
  OverlayEntry? _chartInfoEntry;

  // Cache to store the calculation result
  List<_Gainer>? _cachedWeeklyGainers;

  // --- LOADING STATE VARIABLES ---
  bool _isLoadingGainers = false;
  String _loadingProgressText = "0%";
  double _loadingPercent = 0.0;

  // Engaging Text Logic
  Timer? _msgTimer;
  int _msgIndex = 0;
  final List<String> _loadingMessages = [
    "جاري مسح السوق...",             // Scanning market...
    "تحليل أداء الشركات...",           // Analyzing performance...
    "البحث عن الفرص الأفضل...",      // Looking for best opportunities...
    "مقارنة الأسعار التاريخية...",     // Comparing historical prices...
    "تجهيز قائمة الرابحين...",         // Preparing winners list...
  ];

  @override
  void initState() {
    super.initState();
    _loadSimulationStartDate();
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    _topGainersInfoEntry?.remove();
    _chartInfoEntry?.remove();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['selectedCompany'] != null && selectedCompany == null) {
      setState(() {
        selectedCompany = args['selectedCompany'] as String;
      });
    }
  }

  // Starts the engaging text timer
  void _startLoadingMessages() {
    _msgTimer?.cancel();
    _msgIndex = 0;
    _msgTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (mounted) {
        setState(() {
          _msgIndex = (_msgIndex + 1) % _loadingMessages.length;
        });
      }
    });
  }

  Future<void> _loadSimulationStartDate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (mounted) {
        setState(() {
          simulationStartRealDate = (data != null && data.containsKey('createdAt'))
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now();
        });
        // Start the robust fetch immediately
        _fetchTopGainersWTD_StringQuery();
      }
    }
  }

  // --- Date Helpers ---
  bool _isWorkday(DateTime d) => SimulationUtils.isWorkday(d);

  // 🟢 Helper to format Date like your DB: "2019-01-01"
  String _formatDateForDB(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  DateTime _getLastThursday(DateTime from) {
    DateTime date = DateTime(from.year, from.month, from.day).subtract(const Duration(days: 1));
    while (date.weekday != DateTime.thursday) {
      date = date.subtract(const Duration(days: 1));
    }
    return date;
  }

  int _countRealTradingDaysWithCloseRule(DateTime start, DateTime end) {
    final now = DateTime.now();
    DateTime effectiveEnd = DateTime(end.year, end.month, end.day);
    if (effectiveEnd.weekday == DateTime.friday || effectiveEnd.weekday == DateTime.saturday) {
      while (effectiveEnd.weekday != DateTime.thursday) {
        effectiveEnd = effectiveEnd.subtract(const Duration(days: 1));
      }
    } else if (_isWorkday(effectiveEnd)) {
      final isBeforeClose = now.hour < 15 || (now.hour == 15 && now.minute == 0);
      if (isBeforeClose) {
        do {
          effectiveEnd = effectiveEnd.subtract(const Duration(days: 1));
        } while (!_isWorkday(effectiveEnd));
      }
    }
    int count = 0;
    DateTime current = DateTime(start.year, start.month, start.day).add(const Duration(days: 1));
    while (current.isBefore(effectiveEnd) || current.isAtSameMomentAs(effectiveEnd)) {
      if (_isWorkday(current)) count++;
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  DateTime _calculateSimulatedDateWithCloseRule() {
    if (simulationStartRealDate == null) return SimulationUtils.baseAnchor;
    DateTime today = DateTime.now();
    int realTradingDays = _countRealTradingDaysWithCloseRule(simulationStartRealDate!, today);
    DateTime simDate = SimulationUtils.baseAnchor;
    int daysAdded = 0;
    while(daysAdded < realTradingDays) {
      simDate = simDate.add(const Duration(days: 1));
      if(_isWorkday(simDate)) daysAdded++;
    }
    return simDate;
  }

  // 🚀🚀🚀 FINAL FIX: STRING DATE QUERY 🚀🚀🚀
  Future<void> _fetchTopGainersWTD_StringQuery() async {
    if (simulationStartRealDate == null) return;
    if (_cachedWeeklyGainers != null && _cachedWeeklyGainers!.isNotEmpty) return;

    setState(() {
      _isLoadingGainers = true;
      _loadingPercent = 0.0;
      _loadingProgressText = "0%";
    });
    _startLoadingMessages();

    try {
      final currentSimDate = _calculateSimulatedDateWithCloseRule();

      // Convert simulation date to String "YYYY-MM-DD" for Firestore comparison
      final String simDateStr = _formatDateForDB(currentSimDate);

      final firestore = FirebaseFirestore.instance;
      final companiesSnap = await firestore.collection('companies').get();
      final totalCompanies = companiesSnap.docs.length;

      List<_Gainer> allResults = [];
      int processedCount = 0;
      int batchSize = 20;

      for (var i = 0; i < totalCompanies; i += batchSize) {
        final end = (i + batchSize < totalCompanies) ? i + batchSize : totalCompanies;
        final batch = companiesSnap.docs.sublist(i, end);

        await Future.wait(batch.map((cDoc) async {
          final data = cDoc.data();
          final name = (data['name'] ?? cDoc.id).toString();
          final logo = (data['logoAsset'] ?? '').toString();

          try {
            // 💡 QUERY FIX: Using String Comparison
            // "Give me the last 5 days ON OR BEFORE the simulation date"
            final snapshot = await cDoc.reference
                .collection('PriceRecords_full')
                .where('date', isLessThanOrEqualTo: simDateStr) // String compare works for ISO dates
                .orderBy('date', descending: true)
                .limit(5)
                .get();

            if (snapshot.docs.isNotEmpty) {
              // Latest price (The record closest to simulation date)
              final endPrice = (snapshot.docs.first.data()['close'] as num).toDouble();

              // Oldest price in the batch (up to 5 days ago)
              // If we have 5 days, use the 5th. If we only have 2, use the 2nd.
              final startPrice = (snapshot.docs.last.data()['close'] as num).toDouble();

              if (startPrice > 0 && endPrice > 0) {
                // If only 1 record exists (new company), change is 0.0
                final changePct = (snapshot.docs.length < 2)
                    ? 0.0
                    : ((endPrice - startPrice) / startPrice) * 100.0;

                // Keep everything so the list isn't empty, logic handles sorting
                allResults.add(_Gainer(
                  companyId: cDoc.id,
                  name: name,
                  logoAsset: logo,
                  lastPrice: endPrice,
                  changePct: changePct,
                ));
              }
            }
          } catch (_) {}
        }));

        processedCount += batch.length;
        if (mounted) {
          setState(() {
            _loadingPercent = processedCount / totalCompanies;
            _loadingProgressText = "${(processedCount / totalCompanies * 100).toInt()}%";
          });
        }
        await Future.delayed(const Duration(milliseconds: 1));
      }

      // Sort: Highest gains first
      allResults.sort((a, b) => b.changePct.compareTo(a.changePct));

      if (mounted) {
        setState(() {
          // Take Top 5. If list is empty, UI will show "No Data" gracefully.
          _cachedWeeklyGainers = allResults.take(5).toList();
          _isLoadingGainers = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading gainers: $e");
      if (mounted) setState(() => _isLoadingGainers = false);
    } finally {
      _msgTimer?.cancel();
    }
  }

  // ----- UI Builders -----

  void _showIconExplanation(BuildContext context, Offset position) {
    if (_chartInfoEntry != null) return;
    final overlay = Overlay.of(context);
    if (overlay == null) return;
    final screenSize = MediaQuery.of(context).size;
    const double bubbleWidth = 230.0;
    const double bubbleHeight = 140.0;
    const double hPadding = 16.0;
    const double vPadding = 16.0;
    double left = position.dx - (bubbleWidth / 2);
    if (left < hPadding) left = hPadding;
    else if (left + bubbleWidth > screenSize.width - hPadding) left = screenSize.width - bubbleWidth - hPadding;
    double top = position.dy + 10;
    if (top + bubbleHeight > screenSize.height - vPadding) top = position.dy - bubbleHeight - 10;

    _chartInfoEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left, top: top,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(12),
            width: bubbleWidth,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.88),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.filter_list, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('تصفية الشركات المعروضة', style: TextStyle(color: Colors.white, fontSize: 13)))]),
                const SizedBox(height: 10),
                const Row(children: [Icon(Icons.signal_cellular_alt, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('العرض النسبي ', style: TextStyle(color: Colors.white, fontSize: 13)))]),
                const SizedBox(height: 10),
                const Row(children: [Icon(Icons.zoom_out, color: Colors.white, size: 18), SizedBox(width: 8), Expanded(child: Text('إعادة ضبط التكبير للرسم البياني', style: TextStyle(color: Colors.white, fontSize: 13)))]),
                const SizedBox(height: 10),
                Row(children: [SizedBox(width: 24, height: 10, child: Stack(alignment: Alignment.center, children: [Container(height: 2, width: 24, color: Colors.white), Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white))])), const SizedBox(width: 8), const Expanded(child: Text('اضغط على اسم الشركة أسفل الرسم لإخفاء خطها أو لإظهاره مرة أخرى.', style: TextStyle(color: Colors.white, fontSize: 13)))]),
              ],
            ),
          ),
        ),
      ),
    );
    overlay.insert(_chartInfoEntry!);
    Future.delayed(const Duration(seconds: 3), () {
      _chartInfoEntry?.remove();
      _chartInfoEntry = null;
    });
  }

  // 🆕 Custom Loader Widget
  Widget _buildTopGainersLoader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 40, width: 40,
            child: CircularProgressIndicator(value: _loadingPercent > 0 ? _loadingPercent : null, color: _customGreen, strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _loadingMessages[_msgIndex],
              key: ValueKey<int>(_msgIndex),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(_loadingProgressText, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDefaultMarketView() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTapDown: (details) => _showIconExplanation(context, details.globalPosition),
                child: const Icon(Icons.info_outline, size: 18),
              ),
              const SizedBox(width: 6),
              const Text('نظرة عامة عن السوق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: MarketOverviewChart(),
        ),
        _buildTopGainersSection(),
      ],
    );
  }

  Widget _buildTopGainersSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTapDown: (details) {
                  if (_topGainersInfoEntry != null) return;
                  final overlay = Overlay.of(context);
                  if (overlay == null) return;
                  final screenSize = MediaQuery.of(context).size;
                  const double bubbleWidth = 220.0; const double bubbleHeight = 60.0;
                  const double hPadding = 16.0; const double vPadding = 16.0;
                  double left = details.globalPosition.dx - (bubbleWidth / 2);
                  if (left < hPadding) left = hPadding; else if (left + bubbleWidth > screenSize.width - hPadding) left = screenSize.width - bubbleWidth - hPadding;
                  double top = details.globalPosition.dy + 10;
                  if (top + bubbleHeight > screenSize.height - vPadding) top = details.globalPosition.dy - bubbleHeight - 10;
                  _topGainersInfoEntry = OverlayEntry(builder: (context) => Positioned(left: left, top: top, child: Material(color: Colors.transparent, child: Container(padding: const EdgeInsets.all(12), width: bubbleWidth, decoration: BoxDecoration(color: Colors.black.withOpacity(0.88), borderRadius: BorderRadius.circular(12)), child: const Text("أفضل خمس شركات من حيث نسبة الإرتفاع السعري خلال هذا الأسبوع (في المحاكاة).", style: TextStyle(color: Colors.white, fontSize: 13))))));
                  overlay.insert(_topGainersInfoEntry!);
                  Future.delayed(const Duration(seconds: 3), () { _topGainersInfoEntry?.remove(); _topGainersInfoEntry = null; });
                },
                child: const Icon(Icons.info_outline, size: 18),
              ),
              const SizedBox(width: 6),
              const Text('الأكثر ارتفاعًا هذا الأسبوع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // 🆕 DISPLAY LOGIC
        if (_isLoadingGainers)
          _buildTopGainersLoader()
        else if (_cachedWeeklyGainers != null && _cachedWeeklyGainers!.isNotEmpty)
          Column(children: _cachedWeeklyGainers!.map((g) => _gainerCard(g)).toList())
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('لا توجد بيانات متاحة', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
      ],
    );
  }

  Widget _gainerCard(_Gainer g) {
    final isSelected = selectedCompany == g.name;
    final priceText = g.lastPrice.toStringAsFixed(2);
    final pctText = "${g.changePct.toStringAsFixed(1)}%";
    final Color itemColor = g.changePct > 0 ? _customGreen : Colors.grey;
    final IconData itemIcon = g.changePct > 0 ? Icons.trending_up : Icons.remove;

    return GestureDetector(
      onTap: () => setState(() => selectedCompany = isSelected ? null : g.name),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, spreadRadius: 1, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(itemIcon, color: itemColor),
                const SizedBox(width: 6),
                Image.asset('assets/saudi_riyal_green.png', width: 18),
                const SizedBox(width: 4),
                Text(priceText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: itemColor)),
                const SizedBox(width: 6),
                Text('($pctText)', style: TextStyle(fontSize: 13, color: itemColor)),
              ],
            ),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(g.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600), textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.visible),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? _customGreen : Colors.transparent, width: 3),
                      boxShadow: [if (isSelected) BoxShadow(color: _customGreen.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)],
                    ),
                    child: Container(
                      width: 70, height: 70,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: ClipOval(
                        child: Image.asset('assets/company-logos/${g.logoAsset}', fit: BoxFit.contain, errorBuilder: (c, o, s) => Image.asset('assets/company-logos/default.png')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyDetails(String companyName) {
    return CompanyChartWidget(companyName: companyName);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfilePage()));
    else if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => PortfolioPage()));
    else if (index == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => LearningPage()));
    else if (index == 4) Navigator.push(context, MaterialPageRoute(builder: (_) => HomePage()));
  }

  Widget _buildTabSwitcher(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(color: _customGreen, borderRadius: BorderRadius.circular(30)),
              child: const Center(child: Text('المحاكاة', style: TextStyle(color: Colors.white, fontSize: 20))),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MarketPredictionPage())),
              child: Container(
                height: 50,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(30)),
                child: const Center(child: Text('توقعات السوق', style: TextStyle(color: Colors.grey, fontSize: 20))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBalance() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Text('0.000', style: TextStyle(fontSize: 30, color: _customGreen, fontWeight: FontWeight.bold));
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('wallet').doc('main').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 34, child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))));
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final cash = (data?['cash'] is num) ? (data!['cash'] as num).toDouble() : 0.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/saudi_riyal_green.png', height: 24),
            const SizedBox(width: 6),
            Text(cash.toStringAsFixed(3), style: const TextStyle(fontSize: 30, color: _customGreen, fontWeight: FontWeight.bold)),
          ],
        );
      },
    );
  }

  Widget _buildCompanyLogos() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('companies').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final companies = snapshot.data!.docs;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selectedCompany == null ? Icons.swipe : Icons.undo, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Text(selectedCompany == null ? 'اسحب لرؤية جميع الشركات' : 'اضغط على الشعار مرة أخرى للعودة إلى عرض السوق العام', style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Stack(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    children: companies.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] as String;
                      final logoAsset = data['logoAsset'] as String;
                      final isSelected = selectedCompany == name;
                      return GestureDetector(
                        onTap: () => setState(() => selectedCompany = isSelected ? null : name),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? _customGreen : Colors.transparent, width: 3),
                            boxShadow: [if (isSelected) BoxShadow(color: _customGreen.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)],
                          ),
                          child: Container(
                            width: 70, height: 70,
                            decoration: const BoxDecoration(shape: BoxShape.circle),
                            child: ClipOval(
                              child: Image.asset('assets/company-logos/$logoAsset', fit: BoxFit.contain, errorBuilder: (c, o, s) => Image.asset('assets/company-logos/default.png')),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 40, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.white, Colors.white.withOpacity(0)])), child: Center(child: Icon(Icons.chevron_left, color: _customGreen.withOpacity(0.7), size: 28)))),
                Positioned(right: 0, top: 0, bottom: 0, child: Container(width: 40, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Colors.white, Colors.white.withOpacity(0)])), child: Center(child: Icon(Icons.chevron_right, color: _customGreen.withOpacity(0.7), size: 28)))),
              ],
            ),
          ],
        );
      },
    );
  }

Widget _buildMarketClosedBanner() {
  final now = DateTime.now();

  // إغلاق نهاية الأسبوع (جمعة – سبت)
  final isWeekend = (now.weekday == DateTime.friday || now.weekday == DateTime.saturday);

  // إغلاق يومي بعد الساعة 3 العصر وحتى 10 الصباح
  final isDailyClosed = (now.hour >= 15) || (now.hour < 10);

  if (!isWeekend && !isDailyClosed) {
    return SizedBox.shrink(); // السوق مفتوح
  }

  String message;

  if (isWeekend) {
    message = "السوق مغلق اليوم — إجازة أسبوعية";
  } else if (now.hour >= 15) {
    message = "السوق مغلق. سيبدأ التداول عند الساعة 10:00 صباحًا";
  } else {
    message = "السوق مغلق. سيبدأ التداول عند الساعة 10:00 صباحًا";
  }

  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.redAccent),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_clock, color: Colors.redAccent, size: 20),
        const SizedBox(width: 8),
        Text(
          message,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomNavigationBar(
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
          const BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: ''),
          BottomNavigationBarItem(icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _customGreen, borderRadius: BorderRadius.circular(50)), child: Image.asset('assets/saudi_riyal.png', width: 30, height: 30)), label: ''),
          const BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
        ],
        selectedItemColor: _customGreen, unselectedItemColor: Colors.grey, currentIndex: _selectedIndex, type: BottomNavigationBarType.fixed, onTap: _onItemTapped,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTabSwitcher(context),
              const SizedBox(height: 10),
              _buildMarketClosedBanner(),
              const Text('القوة الشرائية', style: TextStyle(fontSize: 20, color: _customGreen, fontWeight: FontWeight.bold)),
              _buildLiveBalance(),
              const Text('هذا الرصيد وهمي', style: TextStyle(color: Colors.red, fontSize: 14)),
              const Divider(),
              _buildCompanyLogos(),
              selectedCompany == null ? _buildDefaultMarketView() : _buildCompanyDetails(selectedCompany!),
            ],
          ),
        ),
      ),
    );
  }
}