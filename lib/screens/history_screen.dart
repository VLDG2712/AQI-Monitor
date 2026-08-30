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
    _Metric('AQI',         AppColors.accent,   'aqi'),
    _Metric('Temperature', AppColors.temp,      'temperature'),
    _Metric('Humidity',    AppColors.humidity,  'humidity'),
    _Metric('PM2.5',       AppColors.pm,        'pm2_5'),
    _Metric('eCO₂',        AppColors.co2,       'eco2'),
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
                            ? AppColors.accent.withOpacity(0.15)
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
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Metric {
  final String label;
  final Color color;
  final String key;
  const _Metric(this.label, this.color, this.key);
}

class _ChartCard extends StatelessWidget {
  final _Metric metric;
  final List<SensorPayload> readings;

  const _ChartCard({required this.metric, required this.readings});

  double _getValue(SensorPayload p) {
    switch (metric.key) {
      case 'aqi':         return p.ens160.aqi.toDouble();
      case 'temperature': return p.aht21.temperature;
      case 'humidity':    return p.aht21.humidity;
      case 'pm2_5':       return p.pms5003.pm2_5.toDouble();
      case 'eco2':        return p.ens160.eco2.toDouble();
      case 'pressure':    return p.bmp580.pressure;
      default:            return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = readings.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), _getValue(e.value))).toList();

    final latest = points.isNotEmpty ? points.last.y : null;

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
                      lineTouchData: const LineTouchData(enabled: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: points,
                          isCurved: true,
                          color: metric.color,
                          barWidth: 2,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: metric.color.withOpacity(0.1),
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
