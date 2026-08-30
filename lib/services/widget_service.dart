// lib/services/widget_service.dart
// Android home screen widgets via home_widget package.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WidgetService {
  static const _appGroupId = 'dev.promethium.aqi_monitor';
  static const _devicePort = 9091;
  static const _androidWidget = 'AqiWidgetProvider';
  static const _iosWidget = 'AqiWidget';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
    // registerBackgroundCallback is deprecated and merely forwards to this.
    HomeWidget.registerInteractivityCallback(backgroundCallback);
  }

  /// Two-digit zero padding for clock components.
  static String _two(int n) => n.toString().padLeft(2, '0');

  static Future<void> updateWidgets(String ip) async {
    try {
      final res = await http
          .get(Uri.parse('http://$ip:$_devicePort/air'))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode != 200) {
        await _markDisconnected();
        return;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;

      // Read through `num` rather than casting straight to int: /air is
      // serialized by ArduinoJson, and a value arriving as 2.0 instead of 2
      // would throw on `as int?`. That throw lands in the catch below, so a
      // type mismatch would silently pin the widget to "disconnected" forever.
      final aqi = (j['aqi'] as num?)?.toInt() ?? 0;
      final eco2 = (j['eco2'] as num?)?.toInt() ?? 0;
      final tvoc = (j['tvoc'] as num?)?.toInt() ?? 0;
      final aqiLabel = (j['aqi_label'] as String? ?? '—').trim();
      final tempC = (j['temperature'] as num?)?.toDouble();
      final hum = (j['humidity'] as num?)?.toDouble();
      final ready = j['ready'] as bool? ?? false;

      // The widget runs in a background isolate with no provider, so the unit
      // preference is read straight from storage. Without this the widget
      // always showed °C even when the app was set to °F.
      final prefs = await SharedPreferences.getInstance();
      final unit = prefs.getString('tempUnit') ?? '°C';
      final tempText = tempC == null
          ? '—'
          : '${(unit == '°F' ? tempC * 9 / 5 + 32 : tempC).toStringAsFixed(1)}$unit';

      // One timestamp, read once: calling DateTime.now() separately for the
      // hour and the minute can straddle a minute boundary and render 9:00
      // for what was actually 9:59.
      final now = DateTime.now();

      await HomeWidget.saveWidgetData('aqi', aqi);
      await HomeWidget.saveWidgetData('aqi_label', ready ? aqiLabel : 'Warmup');
      await HomeWidget.saveWidgetData('temp', tempText);
      await HomeWidget.saveWidgetData(
          'humidity', hum == null ? '—' : '${hum.toStringAsFixed(0)}%');
      await HomeWidget.saveWidgetData('eco2', '$eco2 ppm');
      await HomeWidget.saveWidgetData('tvoc', '$tvoc ppb');
      await HomeWidget.saveWidgetData('connected', true);
      await HomeWidget.saveWidgetData(
          'updated', '${_two(now.hour)}:${_two(now.minute)}');

      await HomeWidget.updateWidget(
        androidName: _androidWidget,
        iOSName: _iosWidget,
      );
    } catch (e) {
      debugPrint('[WidgetService] update failed: $e');
      await _markDisconnected();
    }
  }

  /// Leaves the last-known readings in place and flips the connected flag, so
  /// the widget shows stale data marked stale rather than blanking out.
  static Future<void> _markDisconnected() async {
    try {
      await HomeWidget.saveWidgetData('connected', false);
      await HomeWidget.updateWidget(
        androidName: _androidWidget,
        iOSName: _iosWidget,
      );
    } catch (e) {
      debugPrint('[WidgetService] failed to mark disconnected: $e');
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
