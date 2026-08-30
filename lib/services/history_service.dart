// lib/services/history_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/sensor_data.dart';

/// Where the History screen reads from.
enum HistorySource {
  /// The app's own sqflite database — only covers time the app was running.
  local,

  /// The Hexair service on the Pi, which collects around the clock.
  server,
}

class HistoryUnavailable implements Exception {
  final String message;
  HistoryUnavailable(this.message);
  @override
  String toString() => 'HistoryUnavailable: $message';
}

/// Reads history from the Pi, trying the LAN address first and falling back to
/// Tailscale.
///
/// The LAN attempt uses a deliberately short timeout: when you're away from
/// home that address isn't merely slow, it's unroutable, and we want to reach
/// the Tailscale fallback quickly rather than make the user wait.
class RemoteHistoryService {
  static const _lanTimeout = Duration(seconds: 3);
  static const _remoteTimeout = Duration(seconds: 10);

  /// How long a successful host stays the first one we try.
  static const _stickiness = Duration(minutes: 5);

  String lanHost;
  String tailscaleHost;
  String token;

  String? _lastGoodHost;
  DateTime? _lastGoodAt;

  RemoteHistoryService({
    this.lanHost = '',
    this.tailscaleHost = '',
    this.token = '',
  });

  bool get isConfigured => lanHost.isNotEmpty || tailscaleHost.isNotEmpty;

  /// Host that last answered, for display in Settings.
  String? get activeHost => _lastGoodHost;

  /// Candidate hosts, best-first.
  List<String> _candidates() {
    final hosts = <String>[
      if (lanHost.isNotEmpty) lanHost,
      if (tailscaleHost.isNotEmpty) tailscaleHost,
    ];
    final good = _lastGoodHost;
    final at = _lastGoodAt;
    // Promote whichever host worked recently, so the common case is one round
    // trip rather than a timeout followed by a retry.
    if (good != null &&
        at != null &&
        DateTime.now().difference(at) < _stickiness &&
        hosts.contains(good)) {
      hosts.remove(good);
      hosts.insert(0, good);
    }
    return hosts;
  }

  Duration _timeoutFor(String host) =>
      host == lanHost ? _lanTimeout : _remoteTimeout;

  Uri _uri(String host, String path, [Map<String, String>? query]) {
    // Accept "1.2.3.4:9101", "host:9101", or a full "http://…" base.
    final base = host.startsWith('http://') || host.startsWith('https://')
        ? host
        : 'http://$host';
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<http.Response> _get(
      String host, String path, Map<String, String> query) {
    return http
        .get(_uri(host, path, query), headers: {
          'Authorization': 'Bearer $token',
        })
        .timeout(_timeoutFor(host));
  }

  /// Fetch readings between two epoch-ms bounds.
  ///
  /// [bucket] is passed through to the server: 'auto' lets it pick a
  /// granularity that keeps the response small, 'raw' asks for every sample.
  Future<List<SensorPayload>> getReadings(
    int fromMs,
    int toMs, {
    String bucket = 'auto',
  }) async {
    if (!isConfigured) {
      throw HistoryUnavailable('No server address configured');
    }

    final errors = <String>[];
    for (final host in _candidates()) {
      try {
        final res = await _get(host, '/readings', {
          'from': '$fromMs',
          'to': '$toMs',
          'bucket': bucket,
        });

        if (res.statusCode == 401 || res.statusCode == 403) {
          // An auth failure is definitive — the other host shares this token,
          // so retrying there would only produce the same rejection.
          throw HistoryUnavailable(
              'Server rejected the token (HTTP ${res.statusCode})');
        }
        if (res.statusCode != 200) {
          errors.add('$host → HTTP ${res.statusCode}');
          continue;
        }

        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['readings'] as List<dynamic>? ?? const []);

        _lastGoodHost = host;
        _lastGoodAt = DateTime.now();

        return list
            .map((e) => SensorPayload.fromJson(e as Map<String, dynamic>))
            .toList();
      } on HistoryUnavailable {
        rethrow;
      } catch (e) {
        debugPrint('[RemoteHistory] $host failed: $e');
        errors.add('$host → $e');
      }
    }
    throw HistoryUnavailable(errors.join('; '));
  }

  /// Row count and coverage window, for the Settings screen.
  Future<Map<String, dynamic>> stats() async {
    if (!isConfigured) {
      throw HistoryUnavailable('No server address configured');
    }
    final errors = <String>[];
    for (final host in _candidates()) {
      try {
        final res = await _get(host, '/stats', const {});
        if (res.statusCode != 200) {
          errors.add('$host → HTTP ${res.statusCode}');
          continue;
        }
        _lastGoodHost = host;
        _lastGoodAt = DateTime.now();
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (e) {
        errors.add('$host → $e');
      }
    }
    throw HistoryUnavailable(errors.join('; '));
  }
}
