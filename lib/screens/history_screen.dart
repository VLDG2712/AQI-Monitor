// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/sensor_data.dart';
import '../utils/theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _range = '6h';
  List<SensorPayload> _readings = [];
  bool _loading = false;
  String? _error;

  /// Index into [_readings] currently being scrubbed, shared by every chart so
  /// they all read out the same moment. Null when not touching.
  int? _touchedIndex;

  void _setTouched(int? i) {
    // touchCallback fires on every pointer move; skip redundant rebuilds.
    if (i == _touchedIndex) return;
    if (i != null && (i < 0 || i >= _readings.length)) return;
    setState(() => _touchedIndex = i);
  }

  // 30D/1Y are only really meaningful against the server, which collects
  // around the clock; the local database only has what the app itself saw.
  static const _ranges = [
    ('1H', '1h', Duration(hours: 1)),
    ('6H', '6h', Duration(hours: 6)),
    ('24H', '24h', Duration(hours: 24)),
    ('7D', '7d', Duration(days: 7)),
    ('30D', '30d', Duration(days: 30)),
    ('1Y', '1y', Duration(days: 365)),
  ];

  static const _metrics = [
    _Metric('AQI',         AppColors.accent,   'aqi', curved: false),
    _Metric('Temperature', AppColors.temp,      'temperature'),
    _Metric('Humidity',    AppColors.humidity,  'humidity'),
    _Metric('PM2.5',       AppColors.pm,        'pm2_5'),
    _Metric('eCO₂',        AppColors.co2,       'eco2'),
    _Metric('TVOC',        AppColors.tvoc,      'tvoc'),
    _Metric('Pressure',    AppColors.pressure,  'pressure'),
  ];

  @override
  void initState() {
    super.initState();
    _loadReadings();
  }

  Future<void> _loadReadings() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    final dur = _ranges.firstWhere((r) => r.$2 == _range).$3;
    final now = DateTime.now().millisecondsSinceEpoch;
    final from = DateTime.now().subtract(dur).millisecondsSinceEpoch;
    final data = await provider.getHistory(from, now);
    if (!mounted) return;
    setState(() {
      _readings = data;
      _error = provider.historyError;
      _loading = false;
      // The old index points into a list that no longer exists.
      _touchedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          // Range picker
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: _ranges.map((r) {
                final selected = r.$2 == _range;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _range = r.$2);
                      _loadReadings();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accent.withValues(alpha: 0.15)
                            : AppColors.bg1,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? AppColors.accent : AppColors.bg3,
                        ),
                      ),
                      child: Text(
                        r.$1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'SpaceMono',
                          color: selected ? AppColors.accent : AppColors.text1,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Timestamp readout. Shows the scrubbed point while dragging, and
          // the most recent reading otherwise, so the strip never collapses
          // and shifts the charts around.
          if (_readings.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _touchedIndex != null ? AppColors.bg2 : AppColors.bg1,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _touchedIndex != null
                      ? AppColors.accent
                      : AppColors.bg3,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _touchedIndex != null
                        ? Icons.my_location
                        : Icons.schedule,
                    size: 14,
                    color: _touchedIndex != null
                        ? AppColors.accent
                        : AppColors.text2,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _touchedIndex != null ? 'At point' : 'Latest',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.text2,
                      fontFamily: 'SpaceMono',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatTimestamp(
                      _readings[_touchedIndex ?? _readings.length - 1]
                          .timestamp,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'SpaceMono',
                      color: _touchedIndex != null
                          ? AppColors.accent
                          : AppColors.text1,
                    ),
                  ),
                ],
              ),
            ),

          // Server unreachable — we fell back to the local database, so say so
          // rather than letting a sparse chart look like clean air.
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.aqi3),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_off, size: 16, color: AppColors.aqi3),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Server unreachable — showing local history only',
                      style: TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 11,
                        color: AppColors.aqi3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Charts
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _metrics.length,
                    itemBuilder: (ctx, i) => _ChartCard(
                      metric: _metrics[i],
                      readings: _readings,
                      touchedIndex: _touchedIndex,
                      onTouch: _setTouched,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Above this many points, per-point dots stop being readable.
const _kMaxDots = 60;

const _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// Formats an epoch-ms timestamp for the scrub readout.
///
/// Seconds are included because server buckets can be as fine as 30s, so
/// minute resolution would render adjacent points identically. The year is
/// shown only when it isn't the current one, which keeps the common case short
/// without ever being ambiguous on the 1Y range.
String formatTimestamp(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final year = d.year == DateTime.now().year ? '' : ' ${d.year}';
  return '${d.day} ${_kMonths[d.month - 1]}$year  '
      '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
}

class _Metric {
  final String label;
  final Color color;
  final String key;

  /// Whether to spline-interpolate between points.
  ///
  /// False for discrete series like AQI, which only ever takes integer values
  /// 1–5. Curving a step series invents intermediate values that never existed
  /// and overshoots well past the real range, which reads as alarming spikes.
  final bool curved;

  const _Metric(this.label, this.color, this.key, {this.curved = true});
}

class _ChartCard extends StatelessWidget {
  final _Metric metric;
  final List<SensorPayload> readings;
  final int? touchedIndex;
  final ValueChanged<int?> onTouch;

  const _ChartCard({
    required this.metric,
    required this.readings,
    required this.onTouch,
    this.touchedIndex,
  });

  double _getValue(SensorPayload p) {
    switch (metric.key) {
      case 'aqi':         return p.ens160.aqi.toDouble();
      case 'temperature': return p.aht21.temperature;
      case 'humidity':    return p.aht21.humidity;
      case 'pm2_5':       return p.pms5003.pm2_5.toDouble();
      case 'eco2':        return p.ens160.eco2.toDouble();
      case 'tvoc':        return p.ens160.tvoc.toDouble();
      case 'pressure':    return p.bmp580.pressure;
      default:            return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = readings.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), _getValue(e.value))).toList();

    // While scrubbing, every card reports the touched moment rather than the
    // most recent one — that's what makes the six charts read as one instrument.
    final scrubbing = touchedIndex != null &&
        touchedIndex! >= 0 &&
        touchedIndex! < points.length;
    final latest = points.isEmpty
        ? null
        : (scrubbing ? points[touchedIndex!].y : points.last.y);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: metric.color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(metric.label,
                  style: const TextStyle(fontSize: 14, color: AppColors.text0, fontWeight: FontWeight.bold)),
              if (latest != null)
                Text(latest.toStringAsFixed(1),
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 14,
                      fontWeight:
                          scrubbing ? FontWeight.bold : FontWeight.normal,
                      color: metric.color,
                    )),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: points.length < 2
                ? Center(
                    child: Text(
                      readings.isEmpty ? 'No data — connect device' : 'Not enough points',
                      style: const TextStyle(fontSize: 12, color: AppColors.text2),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => AppColors.bg3,
                          tooltipRoundedRadius: 6,
                          tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          // Cards are short and narrow; without these the
                          // tooltip gets clipped at the edges.
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItems: (spots) => spots.map((s) {
                            final ts = s.spotIndex >= 0 &&
                                    s.spotIndex < readings.length
                                ? readings[s.spotIndex].timestamp
                                : null;
                            return LineTooltipItem(
                              s.y.toStringAsFixed(1),
                              TextStyle(
                                color: metric.color,
                                fontFamily: 'SpaceMono',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              children: [
                                if (ts != null)
                                  TextSpan(
                                    text: '\n${formatTimestamp(ts)}',
                                    style: const TextStyle(
                                      color: AppColors.text1,
                                      fontFamily: 'SpaceMono',
                                      fontSize: 10,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                              ],
                            );
                          }).toList(),
                        ),
                        getTouchedSpotIndicator: (bar, indexes) =>
                            indexes.map((_) {
                          return TouchedSpotIndicatorData(
                            FlLine(
                                color: metric.color.withValues(alpha: 0.6),
                                strokeWidth: 1),
                            FlDotData(
                              show: true,
                              getDotPainter: (s, p, b, i) =>
                                  FlDotCirclePainter(
                                radius: 4,
                                color: metric.color,
                                strokeWidth: 2,
                                strokeColor: AppColors.bg0,
                              ),
                            ),
                          );
                        }).toList(),
                        touchCallback: (event, response) {
                          final spots = response?.lineBarSpots;
                          // isInterestedForInteractions goes false on pointer
                          // up/exit, which is how the readout clears instead
                          // of sticking at the last touched point.
                          if (!event.isInterestedForInteractions ||
                              spots == null ||
                              spots.isEmpty) {
                            onTouch(null);
                            return;
                          }
                          onTouch(spots.first.spotIndex);
                        },
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: points,
                          isCurved: metric.curved,
                          // Even on genuinely continuous series, splines can
                          // overshoot past the real min/max between close
                          // points; this clamps them to the data's range.
                          preventCurveOverShooting: true,
                          color: metric.color,
                          barWidth: 2,
                          // Dots help at ~20 points and merge into a solid
                          // band at 300+, where they only add noise.
                          dotData: FlDotData(show: points.length <= _kMaxDots),
                          belowBarData: BarAreaData(
                            show: true,
                            color: metric.color.withValues(alpha: 0.1),
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
}
