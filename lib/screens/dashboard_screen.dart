// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/device_service.dart';
import '../utils/theme.dart';
import '../models/sensor_data.dart';
import '../widgets/sensor_tile.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final reading  = provider.latestReading;
    final status   = provider.connectionStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AQI Monitor'),
        actions: [
          _StatusDot(status: status, onTap: () {
            if (status == ConnectionStatus.disconnected ||
                status == ConnectionStatus.error) {
              provider.device.connect();
            } else {
              provider.device.disconnect();
            }
          }),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // AQI Card
            _AqiCard(reading: reading, status: status, onConnect: provider.device.connect),
            const SizedBox(height: 12),

            // Sensor Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: [
                SensorTile(
                  label: 'Temperature',
                  value: reading != null
                      ? provider.formatTemp(reading.aht21.temperature)
                      : '—',
                  color: AppColors.temp,
                  //emoji: '🌡️',
                  iconText: 'Temp',
                ),
                SensorTile(
                  label: 'Humidity',
                  value: reading != null
                      ? '${reading.aht21.humidity.toStringAsFixed(1)}%'
                      : '—',
                  color: AppColors.humidity,
                  //emoji: '💧',
                  iconText: 'Hum',
                ),
                SensorTile(
                  label: 'eCO₂',
                  value: reading != null ? '${reading.ens160.eco2} ppm' : '—',
                  color: reading != null
                      ? AppColors.co2Color(reading.ens160.eco2)
                      : AppColors.text2,
                  iconText: 'CO₂',
                ),
                SensorTile(
                  label: 'TVOC',
                  value: reading != null ? '${reading.ens160.tvoc} ppb' : '—',
                  color: AppColors.co2,
                  iconText: 'VOC',
                ),
                SensorTile(
                  label: 'PM1.0',
                  value: reading != null ? '${reading.pms5003.pm1_0} µg/m³' : '—',
                  color: reading != null
                      ? AppColors.pmColor(reading.pms5003.pm1_0)
                      : AppColors.text2,
                  iconText: 'PM1.0',
                ),
                SensorTile(
                  label: 'PM2.5',
                  value: reading != null ? '${reading.pms5003.pm2_5} µg/m³' : '—',
                  color: reading != null
                      ? AppColors.pmColor(reading.pms5003.pm2_5)
                      : AppColors.text2,
                  iconText: 'PM2.5',
                ),
                SensorTile(
                  label: 'PM10',
                  value: reading != null ? '${reading.pms5003.pm10} µg/m³' : '—',
                  color: reading != null
                      ? AppColors.pmColor(reading.pms5003.pm10)
                      : AppColors.text2,
                  iconText: 'PM10',
                ),
                SensorTile(
                  label: 'Pressure',
                  value: reading != null
                      ? '${reading.bmp580.pressure.toStringAsFixed(1)} hPa'
                      : '—',
                  color: AppColors.pressure,
                  //emoji: '🔵',
                  iconText: 'Pressure',
                ),
                SensorTile(
                  label: 'Altitude',
                  value: reading != null
                      ? '${reading.bmp580.altitude.toStringAsFixed(0)} m'
                      : '—',
                  color: AppColors.pressure,
                  //emoji: '⛰️',
                  iconText: 'Alt',
                ),
              ],
            ),

            if (reading != null) ...[
              const SizedBox(height: 8),
              Text(
                '${provider.deviceIp}:9091  •  uptime ${reading.uptimeS}s',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.text2,
                  fontFamily: 'SpaceMono',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final ConnectionStatus status;
  final VoidCallback onTap;

  const _StatusDot({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConnectionStatus.connected    => AppColors.connected,
      ConnectionStatus.connecting   => AppColors.accent,
      ConnectionStatus.error        => AppColors.error,
      ConnectionStatus.disconnected => AppColors.disconnected,
    };
    final label = switch (status) {
      ConnectionStatus.connected    => 'connected',
      ConnectionStatus.connecting   => 'connecting...',
      ConnectionStatus.error        => 'tap to retry',
      ConnectionStatus.disconnected => 'tap to connect',
    };

    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _AqiCard extends StatelessWidget {
  final SensorPayload? reading;
  final ConnectionStatus status;
  final VoidCallback onConnect;

  const _AqiCard({
    required this.reading,
    required this.status,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final aqi      = reading?.ens160.aqi ?? 0;
    final aqiC     = AppColors.aqiColor(aqi);
    final isNoData = reading == null ||
        status == ConnectionStatus.disconnected ||
        status == ConnectionStatus.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: aqiC.withValues(alpha: isNoData ? 0.1 : 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Air Quality Index',
            style: TextStyle(fontSize: 13, color: AppColors.text1),
          ),
          const SizedBox(height: 12),

          if (status == ConnectionStatus.connecting)
            const CircularProgressIndicator(color: AppColors.accent)
          else if (isNoData) ...[
            const Text('📡', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            const Text('Not Connected',
                style: TextStyle(fontSize: 18, color: AppColors.text1, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Make sure your ESP32 is on',
                style: TextStyle(fontSize: 12, color: AppColors.text2)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.bg0,
              ),
              child: const Text('Connect'),
            ),
          ] else ...[
            Text(
              '$aqi',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: aqiC,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: aqiC.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                aqiLabel(aqi),
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 14,
                  color: aqiC,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],

          if (reading != null) ...[
            const SizedBox(height: 12),
            Text(
              DateTime.fromMillisecondsSinceEpoch(reading!.timestamp)
                  .toLocal()
                  .toString()
                  .substring(11, 19),
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 11,
                color: AppColors.text2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
