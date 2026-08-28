// lib/providers/app_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';
import '../services/device_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';

class AppProvider extends ChangeNotifier {
  final DeviceService device = DeviceService();
  final DatabaseService database = DatabaseService();

  // Settings
  String deviceIp        = '192.168.2.116';
  bool   autoConnect     = true;
  String tempUnit        = '°C';
  int    storageInterval = 30000;
  String apiToken        = 'changeme-generate-a-real-token';

  // Live data
  SensorPayload? latestReading;
  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;

  // Journal
  List<JournalEntry> journalEntries = [];

  // Alerts
  List<AlertRule> alertRules = [];

  // Storage throttle
  int _lastStoredAt = 0;

  StreamSubscription? _dataSub;
  StreamSubscription? _statusSub;

  AppProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadSettings();
    await _loadJournal();
    await _loadAlerts();
    await database.pruneOldReadings();

    device.setDevice(deviceIp);

    _statusSub = device.statusStream.listen((s) {
      connectionStatus = s;
      notifyListeners();
    });

    _dataSub = device.dataStream.listen((payload) {
      latestReading = payload;
      notifyListeners();

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastStoredAt >= storageInterval) {
        _lastStoredAt = now;
        database.insertReading(payload);
      }

      _evaluateAlerts(payload);
    });

    if (autoConnect) device.connect();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    deviceIp        = prefs.getString('deviceIp')    ?? '192.168.2.116';
    autoConnect     = prefs.getBool('autoConnect')   ?? true;
    tempUnit        = prefs.getString('tempUnit')     ?? '°C';
    storageInterval = prefs.getInt('storageInterval') ?? 30000;
    apiToken        = prefs.getString('apiToken') ?? 'changeme-generate-a-real-token';
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceIp',        deviceIp);
    await prefs.setBool('autoConnect',        autoConnect);
    await prefs.setString('tempUnit',         tempUnit);
    await prefs.setInt('storageInterval',     storageInterval);
    await prefs.setString('apiToken',           apiToken);
    device.setDevice(deviceIp);
    notifyListeners();
  }

  Future<void> _loadJournal() async {
    journalEntries = await database.getJournalEntries();
    notifyListeners();
  }

  Future<void> addJournalEntry(JournalEntry entry) async {
    await database.insertJournalEntry(entry);
    journalEntries = [entry, ...journalEntries];
    notifyListeners();
  }

  Future<void> removeJournalEntry(String id) async {
    await database.deleteJournalEntry(id);
    journalEntries = journalEntries.where((e) => e.id != id).toList();
    notifyListeners();
  }

  Future<void> _loadAlerts() async {
    alertRules = await database.getAlertRules();
    notifyListeners();
  }

  Future<void> upsertAlertRule(AlertRule rule) async {
    await database.upsertAlertRule(rule);
    final idx = alertRules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      alertRules = [...alertRules]..[idx] = rule;
    } else {
      alertRules = [...alertRules, rule];
    }
    notifyListeners();
  }

  Future<void> removeAlertRule(String id) async {
    await database.deleteAlertRule(id);
    alertRules = alertRules.where((r) => r.id != id).toList();
    notifyListeners();
  }

  void _evaluateAlerts(SensorPayload p) {
    for (final rule in alertRules) {
      if (!rule.enabled) continue;
      final value = _extractValue(p, rule.sensor, rule.field);
      if (value == null) continue;
      if (_checkThreshold(value, rule.operator, rule.threshold)) {
        NotificationService.instance.fireAlert(
          ruleId:    rule.id,
          label:     rule.label,
          value:     value,
          operator:  rule.operator,
          threshold: rule.threshold,
        );
      }
    }
  }

  double? _extractValue(SensorPayload p, String sensor, String field) {
    switch (sensor) {
      case 'ens160':
        switch (field) {
          case 'aqi':  return p.ens160.aqi.toDouble();
          case 'eco2': return p.ens160.eco2.toDouble();
          case 'tvoc': return p.ens160.tvoc.toDouble();
        }
      case 'aht21':
        switch (field) {
          case 'temperature': return p.aht21.temperature;
          case 'humidity':    return p.aht21.humidity;
        }
      case 'pms5003':
        switch (field) {
          case 'pm2_5': return p.pms5003.pm2_5.toDouble();
          case 'pm10':  return p.pms5003.pm10.toDouble();
        }
    }
    return null;
  }

  bool _checkThreshold(double value, String op, double threshold) {
    switch (op) {
      case '>=': return value >= threshold;
      case '<=': return value <= threshold;
      case '>':  return value > threshold;
      case '<':  return value < threshold;
      default:   return false;
    }
  }

  double convertTemp(double c) =>
      tempUnit == '°F' ? (c * 9 / 5) + 32 : c;

  String formatTemp(double c) =>
      '${convertTemp(c).toStringAsFixed(1)}$tempUnit';

  @override
  void dispose() {
    _dataSub?.cancel();
    _statusSub?.cancel();
    device.dispose();
    super.dispose();
  }
}
