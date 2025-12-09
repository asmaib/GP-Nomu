// 📄 lib/market_prediction_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'user_profile.dart';
import 'stock_market_page.dart';
import 'portfolio_page.dart';
import 'Learning page.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MarketPredictionPage extends StatefulWidget {
  const MarketPredictionPage({Key? key}) : super(key: key);

  @override
  State<MarketPredictionPage> createState() => _MarketPredictionPageState();
}

class _MarketPredictionPageState extends State<MarketPredictionPage> {
  // ----- THEME -----
  static const Color _green = Color(0xFF609966);
  static const Color _chipBg = Color(0xFFE8F5E9);
  int _selectedIndex = 2;

  // ----- FAVORITES STATE -----
  Set<String> _favoriteCompanies = {};

  // ----- SIMULATION -----
  static final DateTime _baseSimulationDate = DateTime(2019, 3, 31);
  DateTime? _simulationStartRealDate;
  DateTime? _currentSimDate;

  // ----- ROW FUTURE CACHE -----
  final Map<String, Future<Map<String, dynamic>?>> _rowFutureCache = {};

  // 🚀 OPTIMIZATION: Cache the valid Date ID to prevent repeated failures
  String? _cachedLatestAvailableDateId;

  // ----- PAGINATION STATE -----
  static const int _pageSize = 8;
  final List<DocumentSnapshot> _companies = [];
  DocumentSnapshot? _lastCompanyDoc;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _companiesError;

  // ----- FUN LOADING STATE -----
  Timer? _loadingTimer;
  int _loadingTextIndex = 0;
  String _loadingProgressText = "0%";

  final List<String> _loadingMessages = [
    "جاري الاتصال بقاعدة البيانات...",  // Connecting...
    "تحليل بيانات السوق التاريخية...",    // Analyzing history...
    "حساب مؤشرات المحاكاة...",          // Calculating simulation...
    "جلب توقعات الذكاء الاصطناعي...",   // Fetching AI predictions...
    "تحضير قائمة الشركات...",           // Preparing companies...
    "نوشك على الانتهاء..."              // Almost done...
  ];

  @override
  void initState() {
    super.initState();
    _startLoadingTimer();
    _bootstrapPage();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _startLoadingTimer() {
    _loadingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        _loadingTextIndex = (_loadingTextIndex + 1) % _loadingMessages.length;
      });
    });
  }

  Future<void> _bootstrapPage() async {
    // Stage 1: Load User & Favorites
    setState(() => _loadingProgressText = "20%");
    await _loadFavorites();

    // Stage 2: Calculate Simulation Date
    setState(() => _loadingProgressText = "45%");
    await _loadSimulationAnchorAndCompute();

    // Stage 3: Load Companies
    setState(() => _loadingProgressText = "70%");
    await _loadInitialCompanies();

    // Finish
    setState(() => _loadingProgressText = "100%");
  }

  // ====== HELPERS: TIMEOUT ======
  Future<T> _withTimeout<T>(Future<T> f, {int seconds = 10}) {
    return f.timeout(Duration(seconds: seconds));
  }

  // ----- FAVORITES -----
  Future<void> _loadFavorites() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await _withTimeout(
        FirebaseFirestore.instance
            .collection('Favorites')
            .doc(userId)
            .collection('stocks')
            .get(),
      );
      if (!mounted) return;
      setState(() {
        _favoriteCompanies = snapshot.docs.map((doc) => doc.id).toSet();
      });
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(
      String companyId,
      String companyName,
      String logoAsset,
      double close,
      double predicted,
      String decisionAr,
      ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
      );
      return;
    }

    final favRef = FirebaseFirestore.instance
        .collection('Favorites')
        .doc(userId)
        .collection('stocks')
        .doc(companyId);

    try {
      if (_favoriteCompanies.contains(companyId)) {
        await _withTimeout(favRef.delete());
        final positionsSnap = await _withTimeout(
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('positions')
              .where('symbol', isEqualTo: companyId)
              .get(),
        );
        for (var doc in positionsSnap.docs) {
          await _withTimeout(doc.reference.update({'liked': false}));
        }
        if (!mounted) return;
        setState(() => _favoriteCompanies.remove(companyId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تمت إزالة $companyName من المفضلة')),
          );
        }
      } else {
        await _withTimeout(favRef.set({
          'name': companyName,
          'logoAsset': logoAsset,
          'close': close,
          'predicted': predicted,
          'decision': decisionAr,
          'addedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));

        final positionsSnap = await _withTimeout(
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('positions')
              .where('symbol', isEqualTo: companyId)
              .get(),
        );
        for (var doc in positionsSnap.docs) {
          await _withTimeout(doc.reference.update({'liked': true}));
        }
        if (!mounted) return;
        setState(() => _favoriteCompanies.add(companyId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تمت إضافة $companyName إلى المفضلة'), backgroundColor: _green),
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
  }

  // ----- SIM DATE -----
  Future<void> _loadSimulationAnchorAndCompute() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      DateTime anchor;
      if (user != null) {
        final udoc = await _withTimeout(
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        );
        final data = udoc.data();
        anchor = (data != null && data['createdAt'] is Timestamp)
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now();
      } else {
        anchor = DateTime.now();
      }

      anchor = DateTime(anchor.year, anchor.month, anchor.day);
      final today = DateTime.now();
      final tradingDaysPassed = _countRealTradingDays(anchor, today);
      final sim = _advanceByTradingDays(_baseSimulationDate, tradingDaysPassed);

      if (!mounted) return;
      setState(() {
        _simulationStartRealDate = anchor;
        _currentSimDate = sim;
        _rowFutureCache.clear();
        _cachedLatestAvailableDateId = null; // Reset optimization cache
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _simulationStartRealDate = DateTime.now();
        _currentSimDate = _baseSimulationDate;
        _rowFutureCache.clear();
      });
    }
  }

  int _countRealTradingDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime cur = DateTime(start.year, start.month, start.day).add(const Duration(days: 1));
    final endDate = DateTime(end.year, end.month, end.day);
    while (!cur.isAfter(endDate)) {
      if (cur.weekday != DateTime.friday && cur.weekday != DateTime.saturday) {
        count++;
      }
      cur = cur.add(const Duration(days: 1));
    }
    return count;
  }

  DateTime _advanceByTradingDays(DateTime start, int n) {
    DateTime cur = DateTime(start.year, start.month, start.day);
    int advanced = 0;
    while (advanced < n) {
      cur = cur.add(const Duration(days: 1));
      if (cur.weekday != DateTime.friday && cur.weekday != DateTime.saturday) {
        advanced++;
      }
    }
    return cur;
  }

  // ====== PAGINATION: COMPANIES ======
  Future<void> _loadInitialCompanies() async {
    setState(() {
      _isLoadingInitial = true;
      _companiesError = null;
      _companies.clear();
      _lastCompanyDoc = null;
      _hasMore = true;
    });

    try {
      final qs = await _withTimeout(
        FirebaseFirestore.instance
            .collection('companies')
            .orderBy('id')
            .limit(_pageSize)
            .get(),
      );

      // Artificial delay just to show the beautiful loader if needed (Optional)
      // await Future.delayed(Duration(milliseconds: 500));

      if (!mounted) return;
      setState(() {
        _companies.addAll(qs.docs);
        _lastCompanyDoc = qs.docs.isNotEmpty ? qs.docs.last : null;
        _hasMore = qs.docs.length == _pageSize;
        _isLoadingInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _companiesError = 'تعذر تحميل الشركات: $e';
        _isLoadingInitial = false;
      });
    }
  }

  Future<void> _loadMoreCompanies() async {
    if (_isLoadingMore || !_hasMore) return;
    if (_lastCompanyDoc == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final qs = await _withTimeout(
        FirebaseFirestore.instance
            .collection('companies')
            .orderBy('id')
            .startAfterDocument(_lastCompanyDoc!)
            .limit(_pageSize)
            .get(),
      );
      if (!mounted) return;
      setState(() {
        _companies.addAll(qs.docs);
        _lastCompanyDoc = qs.docs.isNotEmpty ? qs.docs.last : _lastCompanyDoc;
        _hasMore = qs.docs.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل المزيد: $e')),
      );
    }
  }

  Future<void> _refreshAll() async {
    // Reset loader text
    _loadingTextIndex = 0;
    _loadingProgressText = "0%";
    _rowFutureCache.clear();
    _cachedLatestAvailableDateId = null;

    // Start sequence again
    await _bootstrapPage();
  }

  // ----- NAV -----
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfilePage()));
    } else if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PortfolioPage()));
    } else if (index == 2) {
      // stay here
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => LearningPage()));
    } else if (index == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => HomePage()));
    }
  }

  // ----- FORMAT HELPERS -----
  String _fmtPct(num v) => '${v.toStringAsFixed(2)}%';

  String _fmt2NoRound(num v) {
    final double x = v.toDouble();
    final double sign = x < 0 ? -1.0 : 1.0;
    final double absx = x.abs();
    final double truncated = ((absx * 100.0) + 1e-9).floor() / 100.0;
    final double val = sign * truncated;
    return val.toStringAsFixed(2);
  }

  String _iso(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _wantedPredictionDocId() {
    final d = _currentSimDate ?? _baseSimulationDate;
    return _iso(d);
  }

  // ----- FIRESTORE HELPERS -----
  Query<Map<String, dynamic>> _latestOnOrBefore(
      CollectionReference<Map<String, dynamic>> col, String wantedId) {
    return col.orderBy(FieldPath.documentId).endAt([wantedId]).limitToLast(1);
  }

  // 🚀🚀🚀 OPTIMIZED LOAD ROW FUNCTION 🚀🚀🚀
  Future<Map<String, dynamic>?> _loadCompanyRow(String companyId) async {
    if (_currentSimDate == null) {
      return {'insufficient': true, 'message': 'جاري التحميل...'};
    }

    // Use cached date ID if possible to speed up
    String wantedId = _cachedLatestAvailableDateId ?? _wantedPredictionDocId();

    final predCol = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('market_predictions_daily');
    final priceCol = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('PriceRecords_full');

    try {
      // Parallel Fetch
      final results = await Future.wait([
        _withTimeout(priceCol.doc(wantedId).get()),
        _withTimeout(predCol.doc(wantedId).get())
      ]);

      DocumentSnapshot<Map<String, dynamic>> priceDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      DocumentSnapshot<Map<String, dynamic>> predDoc  = results[1] as DocumentSnapshot<Map<String, dynamic>>;

      // Fallback: If exact date missing, find latest available (Only runs once ideally)
      if (!priceDoc.exists && _cachedLatestAvailableDateId == null) {
        final snap = await _withTimeout(_latestOnOrBefore(priceCol, wantedId).get());
        if (snap.docs.isNotEmpty) {
          priceDoc = snap.docs.first;
          _cachedLatestAvailableDateId = priceDoc.id; // Cache this ID!
          wantedId = priceDoc.id;
        }
      }

      // Re-fetch prediction if we switched to a fallback date
      if (!predDoc.exists && _cachedLatestAvailableDateId != null) {
        predDoc = await _withTimeout(predCol.doc(_cachedLatestAvailableDateId).get());
      }

      if (!priceDoc.exists || !predDoc.exists) {
        return {'insufficient': true, 'message': 'لا تتوفر بيانات'};
      }

      final latestClose = (priceDoc.data()?['close'] as num?)?.toDouble() ?? 0.0;
      final predicted   = (predDoc.data()?['predicted'] as num?)?.toDouble();

      if (predicted == null || latestClose == 0) {
        return {'insufficient': true, 'message': 'لا تتوفر بيانات'};
      }

      final diff = predicted - latestClose;
      final pct  = (diff / latestClose) * 100.0;
      final decisionAr = (predicted < latestClose) ? 'لا تشتري' : 'اشتري';

      return {
        'close': latestClose,
        'predicted': predicted,
        'decisionAr': decisionAr,
        'pct': pct,
        'simDate': _currentSimDate!.toIso8601String(),
      };
    } catch (e) {
      return {'insufficient': true, 'message': 'خطأ في الاتصال'};
    }
  }

  // ----- UI: TOP SWITCH -----
  Widget _topSwitch() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: _chipBg, borderRadius: BorderRadius.circular(30)),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(30)),
              child: const Center(
                child: Text('توقعات السوق',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => MarketSimulationPage()));
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(30)),
                child: const Center(
                  child: Text('المحاكاة',
                      style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyRow(DocumentSnapshot doc) {
    final company = doc.data() as Map<String, dynamic>;
    final companyName = (company['name'] ?? '') as String;
    final logoAsset = (company['logoAsset'] ?? '') as String;
    final companyId = doc.id;

    final wantedKey = '$companyId|${_wantedPredictionDocId()}';
    _rowFutureCache.putIfAbsent(wantedKey, () => _loadCompanyRow(companyId));

    return FutureBuilder<Map<String, dynamic>?>(
      future: _rowFutureCache[wantedKey],
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting || _currentSimDate == null) {
          return _skeletonCard(logoAsset, companyName, companyId);
        }
        if (!snap.hasData || snap.data == null) {
          return _errorCard(logoAsset, companyName, 'لا تتوفر بيانات كافيه', companyId);
        }

        final row = snap.data!;
        if (row['insufficient'] == true) {
          return _errorCard(logoAsset, companyName, row['message'] as String? ?? 'لا تتوفر بيانات كافيه', companyId);
        }

        final close = (row['close'] as num).toDouble();
        final predicted = (row['predicted'] as num).toDouble();
        final decisionText = (row['decisionAr'] as String);
        final pct = (row['pct'] as num).toDouble();
        final isBuy = decisionText == 'اشتري';
        final isFavorite = _favoriteCompanies.contains(companyId);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MarketSimulationPage(),
                settings: RouteSettings(arguments: {'selectedCompany': companyName}),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                // 1. الشعار (يمين)
                Container(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/company-logos/$logoAsset',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. الاسم والقرار (الوسط)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // ⚠️ محاذاة لليمين تلقائياً في RTL
                    mainAxisSize: MainAxisSize.min, // ⚠️ لمنع التمدد العمودي
                    children: [
                      Text(
                        companyName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1, // ⚠️ منع الاسم من أخذ أكثر من سطر
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isBuy ? _green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          decisionText,
                          style: TextStyle(color: isBuy ? _green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. السعر والتوقعات (يسار)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end, // ⚠️ محاذاة لليسار
                  mainAxisSize: MainAxisSize.min, // ⚠️ منع التمدد العمودي
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fmt2NoRound(close),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        const SizedBox(width: 4),
                        Image.asset('assets/saudi_riyal.png', width: 16, height: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                      Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        // السهم
                        Icon(
                          isBuy ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          color: isBuy ? _green : Colors.red,
                          size: 24,
                        ),

                        const SizedBox(width: 4),

                        // كلمة متوقع
                        Text(
                          'متوقع',
                          style: TextStyle(
                            fontSize: 12,
                            color: isBuy ? _green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),



                        // السعر + النسبة
                        Text(
                          '${_fmt2NoRound(predicted)} (${_fmtPct(pct.abs())})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isBuy ? _green : Colors.red,
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
                const SizedBox(width: 10),

                // 4. زر المفضلة (أقصى اليسار)
                GestureDetector(
                  onTap: () => _toggleFavorite(companyId, companyName, logoAsset, close, predicted, decisionText),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))],
                    ),
                    child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: _green, size: 20),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----- PLACEHOLDERS / ERRORS -----
  Widget _skeletonCard(String logoAsset, String name, String companyId) {
    final isFavorite = _favoriteCompanies.contains(companyId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        // إزالة التوجيه اليدوي للاتجاه هنا أيضًا لتوحيد السلوك
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset(
                  'assets/company-logos/$logoAsset',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 120, color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Container(height: 10, width: 80, color: Colors.grey.shade200),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(
            width: 40,
            height: 40,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _green)),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _toggleFavorite(companyId, name, logoAsset, 0, 0, 'لا تشتري'),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: _green, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String logoAsset, String name, String message, String companyId) {
    final isFavorite = _favoriteCompanies.contains(companyId);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        // إزالة التوجيه اليدوي
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset(
                  'assets/company-logos/$logoAsset',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _toggleFavorite(companyId, name, logoAsset, 0, 0, 'لا تشتري'),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))],
              ),
              child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: _green, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ----- FUN LOADING WIDGET -----
  Widget _buildFunLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo or Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.analytics_outlined, size: 60, color: _green),
            ),
            const SizedBox(height: 30),

            // Progress Indicator
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: _green.withOpacity(0.2),
                color: _green,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 20),

            // Changing Text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _loadingMessages[_loadingTextIndex],
                key: ValueKey<int>(_loadingTextIndex),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 8),
            // Percentage
            Text(
              _loadingProgressText,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- BUILD -----
  @override
  Widget build(BuildContext context) {
    // Show Fun Loader if initializing
    if (_isLoadingInitial || _currentSimDate == null) {
      return _buildFunLoadingScreen();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _topSwitch(),
              const Padding(
                padding: EdgeInsets.only(top: 6.0, right: 20.0, left: 20.0, bottom: 4.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'التوقع أدناه ناتج عن تحليل آلي وقد لا يعكس السعر الفعلي مستقبلاً.',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshAll,
                  child: _buildCompaniesList(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Directionality(
          textDirection: TextDirection.ltr,
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: _green,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: ''),
              const BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: ''),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 5, spreadRadius: 2)],
                  ),
                  child: Image.asset('assets/saudi_riyal.png', width: 30, height: 30),
                ),
                label: '',
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
              const BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompaniesList() {
    if (_companiesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_companiesError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _refreshAll,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_companies.isEmpty) {
      return const Center(child: Text('لا توجد شركات'));
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _companies.length + 1, // +1 for load more button
      itemBuilder: (context, i) {
        if (i < _companies.length) {
          return _companyRow(_companies[i]);
        }

        // Bottom of list logic
        if (!_hasMore) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('تم عرض كل النتائج', style: TextStyle(color: Colors.grey.shade600)),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: _isLoadingMore
                ? const CircularProgressIndicator(color: _green)
                : OutlinedButton(
              onPressed: _loadMoreCompanies,
              child: const Text('تحميل المزيد'),
            ),
          ),
        );
      },
    );
  }
}