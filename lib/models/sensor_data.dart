// lib/models/sensor_data.dart

class ENS160Data {
  final int aqi;   // 1–5
  final int eco2;  // ppm
  final int tvoc;  // ppb

  const ENS160Data({required this.aqi, required this.eco2, required this.tvoc});

  factory ENS160Data.fromJson(Map<String, dynamic> j) => ENS160Data(
    aqi:  (j['aqi']  as num).toInt(),
    eco2: (j['eco2'] as num).toInt(),
    tvoc: (j['tvoc'] as num).toInt(),
  );

  factory ENS160Data.zero() => const ENS160Data(aqi: 0, eco2: 0, tvoc: 0);
}

class AHT21Data {
  final double temperature; // °C
  final double humidity;    // %RH

  const AHT21Data({required this.temperature, required this.humidity});

  factory AHT21Data.fromJson(Map<String, dynamic> j) => AHT21Data(
    temperature: (j['temperature'] as num).toDouble(),
    humidity:    (j['humidity']    as num).toDouble(),
  );

  factory AHT21Data.zero() => const AHT21Data(temperature: 0, humidity: 0);
}

class PMS5003Data {
  final int pm1_0;
  final int pm2_5;
  final int pm10;

  const PMS5003Data({required this.pm1_0, required this.pm2_5, required this.pm10});

  factory PMS5003Data.fromJson(Map<String, dynamic> j) => PMS5003Data(
    pm1_0: (j['pm1_0'] as num).toInt(),
    pm2_5: (j['pm2_5'] as num).toInt(),
    pm10:  (j['pm10']  as num).toInt(),
  );

  factory PMS5003Data.zero() => const PMS5003Data(pm1_0: 0, pm2_5: 0, pm10: 0);
}

class BMP580Data {
  final double pressure; // hPa
  final double altitude; // m

  const BMP580Data({required this.pressure, required this.altitude});

  factory BMP580Data.fromJson(Map<String, dynamic> j) => BMP580Data(
    pressure: (j['pressure'] as num).toDouble(),
    altitude: (j['altitude'] as num).toDouble(),
  );

  factory BMP580Data.zero() => const BMP580Data(pressure: 0, altitude: 0);
}

class SensorPayload {
  final int timestamp;
  final ENS160Data ens160;
  final AHT21Data aht21;
  final PMS5003Data pms5003;
  final BMP580Data bmp580;
  final bool ready;
  final int uptimeS;

  const SensorPayload({
    required this.timestamp,
    required this.ens160,
    required this.aht21,
    required this.pms5003,
    required this.bmp580,
    required this.ready,
    required this.uptimeS,
  });

  factory SensorPayload.fromJson(Map<String, dynamic> j) {
    // Handle both nested WS format and flat HTTP /air format
    if (j.containsKey('ens160')) {
      return SensorPayload(
        timestamp: (j['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
        ens160:  ENS160Data.fromJson(j['ens160'] as Map<String, dynamic>),
        aht21:   AHT21Data.fromJson(j['aht21']   as Map<String, dynamic>),
        pms5003: PMS5003Data.fromJson(j['pms5003'] as Map<String, dynamic>),
        bmp580:  BMP580Data.fromJson(j['bmp580']   as Map<String, dynamic>),
        ready:   j['ready'] as bool? ?? false,
        uptimeS: (j['uptime_s'] as num?)?.toInt() ?? 0,
      );
    }
    // Flat HTTP format
    return SensorPayload(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ens160:  ENS160Data(
        aqi:  (j['aqi']  as num?)?.toInt() ?? 0,
        eco2: (j['eco2'] as num?)?.toInt() ?? 0,
        tvoc: (j['tvoc'] as num?)?.toInt() ?? 0,
      ),
      aht21: AHT21Data(
        temperature: (j['temperature'] as num?)?.toDouble() ?? 0,
        humidity:    (j['humidity']    as num?)?.toDouble() ?? 0,
      ),
      pms5003: PMS5003Data(
        pm1_0: (j['pm1_0'] as num?)?.toInt() ?? 0,
        pm2_5: (j['pm2_5'] as num?)?.toInt() ?? 0,
        pm10:  (j['pm10']  as num?)?.toInt() ?? 0,
      ),
      bmp580: BMP580Data(
        pressure: (j['pressure_hpa'] as num?)?.toDouble() ?? 0,
        altitude: (j['altitude_m']   as num?)?.toDouble() ?? 0,
      ),
      ready:   j['ready'] as bool? ?? false,
      uptimeS: (j['uptime_s'] as num?)?.toInt() ?? 0,
    );
  }

  factory SensorPayload.empty() => SensorPayload(
    timestamp: 0,
    ens160:  ENS160Data.zero(),
    aht21:   AHT21Data.zero(),
    pms5003: PMS5003Data.zero(),
    bmp580:  BMP580Data.zero(),
    ready: false,
    uptimeS: 0,
  );

  Map<String, dynamic> toMap() => {
    'timestamp':   timestamp,
    'aqi':         ens160.aqi,
    'eco2':        ens160.eco2,
    'tvoc':        ens160.tvoc,
    'temperature': aht21.temperature,
    'humidity':    aht21.humidity,
    'pm1_0':       pms5003.pm1_0,
    'pm2_5':       pms5003.pm2_5,
    'pm10':        pms5003.pm10,
    'pressure':    bmp580.pressure,
    'altitude':    bmp580.altitude,
    'ready':       ready ? 1 : 0,
  };
}

// AQI helpers
const Map<int, String> aqiLabels = {
  1: 'Excellent',
  2: 'Good',
  3: 'Moderate',
  4: 'Poor',
  5: 'Unhealthy',
};

String aqiLabel(int aqi) => aqiLabels[aqi] ?? '—';

// Journal entry
class JournalEntry {
  final String id;
  final int timestamp;
  final SensorPayload snapshot;
  final String note;
  final List<String> tags;

  const JournalEntry({
    required this.id,
    required this.timestamp,
    required this.snapshot,
    required this.note,
    required this.tags,
  });
}

// Alert rule
class AlertRule {
  final String id;
  final String sensor;
  final String field;
  final String operator;
  final double threshold;
  final bool enabled;
  final String label;

  const AlertRule({
    required this.id,
    required this.sensor,
    required this.field,
    required this.operator,
    required this.threshold,
    required this.enabled,
    required this.label,
  });

  AlertRule copyWith({bool? enabled}) => AlertRule(
    id: id, sensor: sensor, field: field,
    operator: operator, threshold: threshold,
    enabled: enabled ?? this.enabled, label: label,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'sensor': sensor, 'field': field,
    'operator': operator, 'threshold': threshold,
    'enabled': enabled ? 1 : 0, 'label': label,
  };

  factory AlertRule.fromMap(Map<String, dynamic> m) => AlertRule(
    id: m['id'] as String,
    sensor: m['sensor'] as String,
    field: m['field'] as String,
    operator: m['operator'] as String,
    threshold: (m['threshold'] as num).toDouble(),
    enabled: (m['enabled'] as int) == 1,
    label: m['label'] as String,
  );
}
