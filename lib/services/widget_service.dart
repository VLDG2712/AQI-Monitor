// lib/services/widget_service.dart
// Android home screen widgets via home_widget package.
import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WidgetService {
  static const _appGroupId = 'dev.promethium.aqi_monitor';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
    HomeWidget.registerBackgroundCallback(backgroundCallback);
  }

  static Future<void> updateWidgets(String ip) async {
    try {
      final res = await http
          .get(Uri.parse('http://$ip:9091/air'))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode != 200) return;
      final j = jsonDecode(res.body) as Map<String, dynamic>;

      final aqi      = j['aqi']         as int?    ?? 0;
      final aqiLabel = (j['aqi_label']  as String? ?? '—').trim();
      final temp     = (j['temperature']as num?)?.toStringAsFixed(1) ?? '—';
      final hum      = (j['humidity']   as num?)?.toStringAsFixed(0) ?? '—';
      final eco2     = j['eco2']        as int?    ?? 0;
      final tvoc     = j['tvoc']        as int?    ?? 0;
      final ready    = j['ready']       as bool?   ?? false;

      await HomeWidget.saveWidgetData('aqi',       aqi);
      await HomeWidget.saveWidgetData('aqi_label', ready ? aqiLabel : 'Warmup');
      await HomeWidget.saveWidgetData('temp',      '${temp}°C');
      await HomeWidget.saveWidgetData('humidity',  '$hum%');
      await HomeWidget.saveWidgetData('eco2',      '$eco2 ppm');
      await HomeWidget.saveWidgetData('tvoc',      '$tvoc ppb');
      await HomeWidget.saveWidgetData('connected', true);
      await HomeWidget.saveWidgetData('updated',
          '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}');

      await HomeWidget.updateWidget(
        androidName: 'AqiWidgetProvider',
        iOSName: 'AqiWidget',
      );
    } catch (_) {
      await HomeWidget.saveWidgetData('connected', false);
      await HomeWidget.updateWidget(androidName: 'AqiWidgetProvider');
    }
  }
}

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri?.host == 'refresh') {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('deviceIp') ?? '192.168.2.116';
    await WidgetService.updateWidgets(ip);
  }
}
