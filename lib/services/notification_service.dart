// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // Cooldown tracking: rule id → last fired timestamp ms
  final Map<String, int> _lastFired = {};
  static const _cooldownMs = 5 * 60 * 1000; // 5 minutes per rule

  // Stable notification channel
  static const _channelId   = 'aqi_alerts';
  static const _channelName = 'AQI Alerts';
  static const _channelDesc = 'Air quality threshold alerts';

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // Create the notification channel (Android 8+)
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request runtime permission (Android 13+ / API 33+)
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    debugPrint('[NotificationService] init complete, permission granted: $granted');
  }

  /// Fire a notification for a triggered alert rule.
  /// Respects per-rule cooldown — won't spam the same rule repeatedly.
  Future<void> fireAlert({
    required String ruleId,
    required String label,
    required double value,
    required String operator,
    required double threshold,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastFired[ruleId] ?? 0;

    if (now - last < _cooldownMs) {
      debugPrint('[NotificationService] suppressed (cooldown): $label');
      return;
    }

    _lastFired[ruleId] = now;

    // Use a stable int id derived from the ruleId string so the same rule
    // replaces its own previous notification rather than stacking.
    final notifId = ruleId.hashCode.abs() % 100000;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin.show(
      notifId,
      '⚠️ AQI Alert: $label',
      '${_formatValue(value)} $operator ${_formatThreshold(threshold)}',
      const NotificationDetails(android: androidDetails),
    );

    debugPrint('[NotificationService] fired: $label ($value $operator $threshold)');
  }

  String _formatValue(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  String _formatThreshold(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}
