// lib/market_overview_chart.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

enum MarketWindow { w1, m1, m3 }

class LinePoint {
  final DateTime x;
  final double? y;
  LinePoint(this.x, this.y);
}

class MarketOverviewChart extends StatefulWidget {
  final String? uid;
  final EdgeInsetsGeometry? padding;
  final double height;

  const MarketOverviewChart({
    super.key,
    this.uid,
    this.padding,
    this.height = 260,
  });

  @override
  State<MarketOverviewChart> createState() => _MarketOverviewChartState();
}

class _MarketOverviewChartState extends State<MarketOverviewChart> {
  MarketWindow _window = MarketWindow.w1;
  Future<Map<String, List<LinePoint>>>? _future;

  static final DateTime _baseAnchor = DateTime(2019, 3, 31);
  DateTime? _simulationStartRealDate;

  late ZoomPanBehavior _zoomPanBehavior;
  late TrackballBehavior _trackballBehavior;

  final Set<String> _selectedCompanies = {};
  List<String> _allCompanyNames = [];

  bool _useLogScale = false;

  final List<Color> _palette = const [
    Color(0xFF1E88E5),
    Color(0xFFD81B60),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Color(0xFFF4511E),
    Color(0xFF7CB342),
    Color(0xFF5C6BC0),
    Color(0xFF00897B),
  ];

  // ====== الكاش ======
  bool _cacheReady = false;
  final Set<DateTime> _allMarketTradingDates = {};
  final Map<String, Map<String, dynamic>> _companyMeta = {};
  final Map<String, List<Map<String, dynamic>>> _companyRecords = {};
  List<DateTime> _sortedMarketDates = [];


String shortenName(String name, [int max = 14]) {
  return name.length > max ? '${name.substring(0, max)}...' : name;
}

  @override
  void initState() {
    super.initState();
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      zoomMode: ZoomMode.xy,
      enableDoubleTapZooming: true,
      maximumZoomLevel: 0.2,
    );
    _trackballBehavior = TrackballBehavior(enable: false);


    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await initializeDateFormatting('en_US', null);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      _simulationStartRealDate = (data != null && data.containsKey('createdAt'))
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now();
    } else {
      _simulationStartRealDate = DateTime.now();
    }

    // Load optimized cache
    await _loadAllToCacheOnce();

    setState(() {
      _future = Future.value(_buildSeriesFromCache(_window));
    });
  }

  // 🚀🚀🚀 FIXED: ON-DEMAND LOADING 🚀🚀🚀
  Future<void> _loadAllToCacheOnce() async {
    if (_cacheReady) return;

    final companiesSnap = await FirebaseFirestore.instance.collection('companies').get();

    for (var cDoc in companiesSnap.docs) {
      final id = cDoc.id;
      final data = cDoc.data();
      _companyMeta[id] = {'name': (data['name'] ?? id).toString()};
    }

    // Initialize with a safe date to prevent crashes
    _allMarketTradingDates.add(DateTime(2023, 1, 1));

    // ⚡️ OPTIMIZATION: Only load first 5 companies initially
    final initialIds = companiesSnap.docs.take(5).map((e) => e.id).toList();
    await Future.wait(initialIds.map((id) => _loadCompanyDataToCache(id)));

    _sortedMarketDates = _allMarketTradingDates.toList()..sort();
    _cacheReady = true;
  }

  // NEW HELPER: Fetch data for a specific company only when needed
  Future<void> _loadCompanyDataToCache(String companyId) async {
    if (_companyRecords.containsKey(companyId)) return; // Already loaded

    final pr = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('PriceRecords_full')
        .orderBy('date')
        .get();

    final records = <Map<String, dynamic>>[];
    for (final d in pr.docs) {
      final row = d.data();
      try {
        final dt = _parseDate(row['date']);
        if (dt == null) continue;
        final justDate = DateTime(dt.year, dt.month, dt.day);
        final close = (row['close'] is num) ? (row['close'] as num).toDouble() : double.tryParse('${row['close']}');

        if (close != null) {
          records.add({'date': justDate, 'close': close});
          _allMarketTradingDates.add(justDate);
        }
      } catch (_) {}
    }
    if (records.isNotEmpty) {
      records.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      _companyRecords[companyId] = records;
    }
  }

  void _setWindow(MarketWindow w) {
    if (_window == w) return;
    setState(() {
      _window = w;
      _future = Future.value(_buildSeriesFromCache(w));
      _zoomPanBehavior.reset();
    });
  }

  bool _isWorkday(DateTime d) =>
      d.weekday != DateTime.friday && d.weekday != DateTime.saturday;

  int _windowSpanTradingDays(MarketWindow w) {
    switch (w) {
      case MarketWindow.w1: return 5;
      case MarketWindow.m1: return 22;
      case MarketWindow.m3: return 66;
    }
  }

  Map<String, List<LinePoint>> _buildSeriesFromCache(MarketWindow w) {
    if (!_cacheReady || _simulationStartRealDate == null) return {};

    final spanTrading = _windowSpanTradingDays(w);
    if (_sortedMarketDates.isEmpty) return {};

    final currentSimDate = _calculateSimulatedDate(_sortedMarketDates);

    int currentIndex = _sortedMarketDates.indexWhere((d) =>
    d.year == currentSimDate.year &&
        d.month == currentSimDate.month &&
        d.day == currentSimDate.day);

    if (currentIndex == -1) {
      currentIndex =
          _sortedMarketDates.indexWhere((d) => d.isAfter(currentSimDate));
      if (currentIndex == -1) {
        currentIndex = _sortedMarketDates.length - 1;
      } else if (currentIndex > 0) {
        currentIndex--;
      }
    }

    int startIdx = (currentIndex - (spanTrading - 1)).clamp(0, currentIndex);
    final windowDates = _sortedMarketDates.sublist(startIdx, currentIndex + 1);

    if (windowDates.isEmpty) return {};

    final displayDates = _convertToDisplayDates(windowDates, _sortedMarketDates, currentSimDate);

    final seriesByCompany = <String, List<LinePoint>>{};

    // 🚀🚀🚀 UPDATED LOOP LOGIC 🚀🚀🚀
    _companyRecords.forEach((companyId, records) {
      final name = _companyMeta[companyId]?['name'] ?? companyId;
      final out = <LinePoint>[];

      for (int i = 0; i < windowDates.length; i++) {
        final simDate = windowDates[i];
        final displayDate = displayDates[i];

        double? close;
        for (final rec in records) {
          if ((rec['date'] as DateTime).compareTo(simDate) == 0) {
            close = rec['close'];
            break;
          }
        }
        out.add(LinePoint(displayDate, close));
      }

      if (out.isNotEmpty) {
        seriesByCompany[name] = out;
      }
    });

    _allCompanyNames = _companyMeta.entries.map((e) => e.value['name'] as String).toList()..sort();

    // Default selection logic
    if (_selectedCompanies.isEmpty && seriesByCompany.isNotEmpty) {
      final ranked = _rankByVariance(seriesByCompany);
      _selectedCompanies..clear()..addAll(ranked.take(5).map((e) => e.key));
    }

    return seriesByCompany;
  }

  // (Helper functions preserved from original)
  DateTime _calculateSimulatedDate(List<DateTime> allTradingDays) {
    if (_simulationStartRealDate == null || allTradingDays.isEmpty) {
      return _baseAnchor;
    }
    int startIndex = allTradingDays.indexWhere((date) =>
    date.year == _baseAnchor.year && date.month == _baseAnchor.month && date.day == _baseAnchor.day);

    if (startIndex == -1) {
      startIndex = allTradingDays.indexWhere((date) => date.isAfter(_baseAnchor));
    }
    if (startIndex == -1) return _baseAnchor;

    DateTime today = DateTime.now();
    int realTradingDays = _countRealTradingDays(_simulationStartRealDate!, today);
    int targetIndex = startIndex + realTradingDays;

    if (targetIndex >= allTradingDays.length) return allTradingDays.last;
    return allTradingDays[targetIndex];
  }

  int _countRealTradingDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime current = DateTime(start.year, start.month, start.day).add(const Duration(days: 1));
    DateTime endDate = DateTime(end.year, end.month, end.day);
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      if (_isWorkday(current)) count++;
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  List<DateTime> _convertToDisplayDates(List<DateTime> windowDates, List<DateTime> allTradingDays, DateTime currentSimDate) {
    List<DateTime> displayDates = [];
    int currentIndex = -1;
    for (int i = 0; i < allTradingDays.length; i++) {
      if (allTradingDays[i].year == currentSimDate.year &&
          allTradingDays[i].month == currentSimDate.month &&
          allTradingDays[i].day == currentSimDate.day) {
        currentIndex = i;
        break;
      }
    }
    if (currentIndex == -1) return windowDates;

    DateTime realToday = DateTime.now();
    if (realToday.weekday == DateTime.friday) realToday = realToday.subtract(const Duration(days: 1));
    else if (realToday.weekday == DateTime.saturday) realToday = realToday.subtract(const Duration(days: 2));

    for (final simDate in windowDates) {
      int indexInSim = -1;
      for (int i = 0; i < allTradingDays.length; i++) {
        if (allTradingDays[i].year == simDate.year &&
            allTradingDays[i].month == simDate.month &&
            allTradingDays[i].day == simDate.day) {
          indexInSim = i;
          break;
        }
      }
      if (indexInSim == -1) {
        displayDates.add(simDate);
        continue;
      }
      int daysDiff = currentIndex - indexInSim;
      DateTime resultDate = realToday;
      int tradingDaysSubtracted = 0;
      while (tradingDaysSubtracted < daysDiff) {
        resultDate = resultDate.subtract(const Duration(days: 1));
        if (_isWorkday(resultDate)) tradingDaysSubtracted++;
      }
      displayDates.add(resultDate);
    }
    return displayDates;
  }

  DateTime? _parseDate(dynamic v) {
    if (v is String) {
      try {
        final s = v.replaceAll('/', '-').trim();
        final dt = DateTime.parse(s);
        return DateTime(dt.year, dt.month, dt.day);
      } catch (_) { return null; }
    }
    if (v is Timestamp) {
      final dt = v.toDate();
      return DateTime(dt.year, dt.month, dt.day);
    }
    return null;
  }

  List<MapEntry<String, double>> _rankByVariance(Map<String, List<LinePoint>> map) {
    final scores = <String, double>{};
    for (final e in map.entries) {
      final ys = e.value.where((p) => p.y != null).map((p) => p.y!).toList();
      if (ys.length < 2) {
        scores[e.key] = 0;
        continue;
      }
      final mean = ys.reduce((a, b) => a + b) / ys.length;
      final varSum = ys.fold<double>(0, (acc, v) => acc + (v - mean) * (v - mean));
      scores[e.key] = varSum / (ys.length - 1);
    }
    final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return ranked;
  }

  ChartAxis _buildXAxisForWindow(MarketWindow w, DateTime minX, DateTime maxX) {
    final df = DateFormat('d/M', 'en_US');
    switch (w) {
      case MarketWindow.w1:
        return DateTimeCategoryAxis(minimum: minX, maximum: maxX, intervalType: DateTimeIntervalType.days, interval: 1, dateFormat: df, rangePadding: ChartRangePadding.none, majorGridLines: const MajorGridLines(width: 0.2), labelPlacement: LabelPlacement.onTicks, edgeLabelPlacement: EdgeLabelPlacement.shift);
      case MarketWindow.m1:
        return DateTimeCategoryAxis(minimum: minX, maximum: maxX, intervalType: DateTimeIntervalType.days, interval: 3, dateFormat: df, rangePadding: ChartRangePadding.none, majorGridLines: const MajorGridLines(width: 0.2), labelPlacement: LabelPlacement.onTicks, edgeLabelPlacement: EdgeLabelPlacement.shift);
      case MarketWindow.m3:
        return DateTimeCategoryAxis(minimum: minX, maximum: maxX, intervalType: DateTimeIntervalType.days, interval: 7, dateFormat: df, rangePadding: ChartRangePadding.none, majorGridLines: const MajorGridLines(width: 0.2), labelPlacement: LabelPlacement.onTicks, edgeLabelPlacement: EdgeLabelPlacement.shift);
    }
  }

  ChartAxis _buildYAxis(bool useLog, double? yMin, double? yMax) {
    if (useLog) return LogarithmicAxis(logBase: 10, majorGridLines: const MajorGridLines(width: 0.2));
    else return NumericAxis(majorGridLines: const MajorGridLines(width: 0.2), minimum: (yMin != null && yMin.isFinite) ? yMin : null, maximum: (yMax != null && yMax.isFinite) ? yMax : null);
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    return Card(
      elevation: 2,
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'تصفية الشركات',
                  icon: const Icon(Icons.filter_list),
                  onPressed: _allCompanyNames.isEmpty ? null : _openCompanyFilter,
                ),
                IconButton(
                  tooltip: _useLogScale ? 'تعطيل العرض النسبي' : 'تفعيل العرض النسبي',
                  icon: Icon(_useLogScale ? Icons.signal_cellular_alt_2_bar : Icons.signal_cellular_alt),
                  onPressed: () => setState(() => _useLogScale = !_useLogScale),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out, semanticLabel: 'إعادة ضبط التكبير'),
                  onPressed: () => _zoomPanBehavior.reset(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TfChip(label: '1W', selected: _window == MarketWindow.w1, onTap: () => _setWindow(MarketWindow.w1)),
                const SizedBox(width: 8),
                _TfChip(label: '1M', selected: _window == MarketWindow.m1, onTap: () => _setWindow(MarketWindow.m1)),
                const SizedBox(width: 8),
                _TfChip(label: '3M', selected: _window == MarketWindow.m3, onTap: () => _setWindow(MarketWindow.m3)),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, List<LinePoint>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
                if (snap.hasError) return const SizedBox(height: 240, child: Center(child: Text('تعذر تحميل البيانات')));
                final map = snap.data ?? const <String, List<LinePoint>>{};
                if (map.isEmpty) return const SizedBox(height: 240, child: Center(child: Text('لا توجد بيانات')));

                DateTime? minX, maxX;
                double? minY, maxY;
                final List<CartesianSeries> series = [];
                // Only show selected companies
                final Iterable<String> names = _selectedCompanies.isEmpty
                    ? map.keys.take(5)
                    : _selectedCompanies.take(5);

                for (final name in names) {
                  final pts = map[name];
                  if (pts == null || pts.isEmpty) continue;
                  pts.sort((a, b) => a.x.compareTo(b.x));
                  minX = (minX == null || pts.first.x.isBefore(minX!)) ? pts.first.x : minX;
                  maxX = (maxX == null || pts.last.x.isAfter(maxX!)) ? pts.last.x : maxX;
                  for (final p in pts) {
                    if (p.y == null) continue;
                    minY = (minY == null || p.y! < minY!) ? p.y! : minY;
                    maxY = (maxY == null || p.y! > maxY!) ? p.y! : maxY;
                  }
                  series.add(
                    LineSeries<LinePoint, DateTime>(
                      dataSource: pts,
                      xValueMapper: (p, _) => p.x,
                      yValueMapper: (p, _) => p.y,
                      name: shortenName(name),
                      width: 2,
                      opacity: 0.95,
                      emptyPointSettings: const EmptyPointSettings(mode: EmptyPointMode.gap),
                      markerSettings: MarkerSettings(isVisible: _window == MarketWindow.w1, width: 4, height: 4),
                    ),
                  );
                }

                if (minX == null || maxX == null) return const SizedBox(height: 240, child: Center(child: Text('لا توجد بيانات')));

                final hasY = (minY != null && maxY != null);
                final yPad = hasY ? ((maxY! - minY!).abs() * 0.05) : null;
                final yMin = hasY ? (minY! - (yPad ?? 0)) : null;
                final yMax = hasY ? (maxY! + (yPad ?? 0)) : null;

                return SizedBox(
                  height: widget.height,
                  child: SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    palette: _palette,
                    legend: Legend(isVisible: true, position: LegendPosition.bottom, overflowMode: LegendItemOverflowMode.wrap, toggleSeriesVisibility: true),
                    primaryXAxis: _buildXAxisForWindow(_window, minX!, maxX!),
                    primaryYAxis: _buildYAxis(_useLogScale, yMin, yMax),
                    tooltipBehavior: TooltipBehavior(
                      enable: true,
                      shared: true,  // يعرض كل الشركات معاً
                      color: Colors.black87,
                    ),
                    zoomPanBehavior: _zoomPanBehavior,
                    trackballBehavior: _trackballBehavior,
                    series: series,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openCompanyFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final tmpSelected = Set<String>.from(_selectedCompanies);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(999)),
                    ),
                    Text('تصفية الشركات (اختر حتى 5)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _allCompanyNames.length,
                        itemBuilder: (context, i) {
                          final name = _allCompanyNames[i];
                          final checked = tmpSelected.contains(name);
                          return CheckboxListTile(
                            value: checked,
                            onChanged: (v) {
                              setSheetState(() {
                                if (v == true) {
                                  if (tmpSelected.length < 5) tmpSelected.add(name);
                                } else {
                                  tmpSelected.remove(name);
                                }
                              });
                            },
                            title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Spacer(),
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);

                            // Find IDs for selected names and Load Data if missing
                            final selectedIds = <String>[];
                            _companyMeta.forEach((id, meta) {
                              if (tmpSelected.contains(meta['name'])) selectedIds.add(id);
                            });

                            // Show loading indicator in parent if needed, or just await
                            await Future.wait(selectedIds.map((id) => _loadCompanyDataToCache(id)));

                            if (mounted) {
                              setState(() {
                                _selectedCompanies..clear()..addAll(tmpSelected);
                                _future = Future.value(_buildSeriesFromCache(_window)); // Rebuild
                                _zoomPanBehavior.reset();
                              });
                            }
                          },
                          child: const Text('تطبيق'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
class _TfChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TfChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 🟢 التعديل: استخدام اللون الأخضر بدلاً من لون الثيم الأساسي (البنفسجي)
    const color = Color(0xFF609966);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: selected ? color : Colors.grey.shade300,
                width: selected ? 1.6 : 1)),
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? color : Colors.black87)),
      ),
    );
  }
}