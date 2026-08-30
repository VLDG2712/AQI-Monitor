// lib/services/device_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/sensor_data.dart';
import 'package:flutter/foundation.dart';


enum ConnectionStatus { disconnected, connecting, connected, error }

class DeviceService {
  static const _wsPort   = 9092;
  static const _httpPort = 9091;

  /// Whether to try a WebSocket before falling back to HTTP polling.
  ///
  /// Off by default: the firmware serves no WebSocket on 9092. Attempting it
  /// cost a timeout on every connect and, worse, raised an unhandled
  /// SocketException — web_socket_channel does its upgrade over HttpClient,
  /// and that refusal escapes both the try/catch here and the stream's
  /// onError. Flip this back on if a WebSocket server is ever added.
  static const _wsEnabled = false;

  /// How long to wait for a first WebSocket message before falling back.
  /// Only relevant when [_wsEnabled] is true.
  static const _wsProbeTimeout = Duration(milliseconds: 1500);

  String _ip = '192.168.2.116';
  ConnectionStatus _status = ConnectionStatus.disconnected;
  WebSocketChannel? _ws;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  bool _useWebSocket = _wsEnabled;

  final _dataController   = StreamController<SensorPayload>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();

  Stream<SensorPayload>      get dataStream   => _dataController.stream;
  Stream<ConnectionStatus>   get statusStream  => _statusController.stream;
  ConnectionStatus           get status        => _status;

  String get ip => _ip;

  void setDevice(String ip) {
    // A different device may well support WebSockets even if the last one did
    // not, so re-arm the probe — but only on an actual change.
    if (ip != _ip) _useWebSocket = _wsEnabled;
    _ip = ip;
  }

  void _setStatus(ConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }

  void connect() {
    disconnect();
    _setStatus(ConnectionStatus.connecting);
    _useWebSocket ? _connectWS() : _startPolling();
  }

  void _connectWS() {
    try {
      final uri = Uri.parse('ws://$_ip:$_wsPort/');
      _ws = WebSocketChannel.connect(uri);

      // Fall back if no message arrives promptly.
      final timeout = Timer(_wsProbeTimeout, () {
        if (_status == ConnectionStatus.connecting) {
          debugPrint('[DeviceService] WS timeout — falling back to polling');
          _useWebSocket = false;
          _ws?.sink.close();
          _startPolling();
        }
      });

      _ws!.stream.listen(
        (message) {
          timeout.cancel();
          _setStatus(ConnectionStatus.connected);
          try {
            final json = jsonDecode(message as String) as Map<String, dynamic>;
            _dataController.add(SensorPayload.fromJson(json));
          } catch (e) {
            debugPrint('[DeviceService] WS parse error: $e');
          }
        },
        onError: (e) {
          timeout.cancel();
          debugPrint('[DeviceService] WS error: $e — falling back to polling');
          _useWebSocket = false;
          _startPolling();
        },
        onDone: () {
          timeout.cancel();
          if (_status != ConnectionStatus.disconnected) {
            _setStatus(ConnectionStatus.disconnected);
            _scheduleReconnect();
          }
        },
      );
    } catch (e) {
      _setStatus(ConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  void _startPolling([int intervalMs = 2000]) {
    debugPrint('[DeviceService] HTTP polling mode');
    _pollTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) async {
      try {
        final res = await http
            .get(Uri.parse('http://$_ip:$_httpPort/air'))
            .timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          _setStatus(ConnectionStatus.connected);
          _dataController.add(SensorPayload.fromJson(json));
        }
      } catch (_) {
        _setStatus(ConnectionStatus.error);
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_status == ConnectionStatus.disconnected ||
          _status == ConnectionStatus.error) {
        connect();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    _ws?.sink.close();
    _ws = null;
    _pollTimer = null;
    // _useWebSocket is deliberately NOT reset here. connect() calls
    // disconnect() first, so resetting it threw away the discovery that this
    // device has no WebSocket and re-paid the probe timeout on every single
    // reconnect. setDevice() re-arms it when the address actually changes.
    _setStatus(ConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _dataController.close();
    _statusController.close();
  }
}

