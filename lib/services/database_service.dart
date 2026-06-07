// lib/services/database_service.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sensor_data.dart';

class DatabaseService {
  static Database? _db;
  static const _maxHistoryDays = 90;

  Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'aqi_history.db');
    return openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE readings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp INTEGER NOT NULL,
          aqi INTEGER, eco2 REAL, tvoc REAL,
          temperature REAL, humidity REAL,
          pm1_0 REAL, pm2_5 REAL, pm10 REAL,
          pressure REAL, altitude REAL, ready INTEGER
        )
      ''');
      await db.execute('CREATE INDEX idx_readings_ts ON readings(timestamp)');
      await db.execute('''
        CREATE TABLE journal (
          id TEXT PRIMARY KEY,
          timestamp INTEGER NOT NULL,
          snapshot_json TEXT,
          note TEXT,
          tags TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE alerts (
          id TEXT PRIMARY KEY,
          sensor TEXT, field TEXT, operator TEXT,
          threshold REAL, enabled INTEGER DEFAULT 1, label TEXT
        )
      ''');
    });
  }

  Future<void> insertReading(SensorPayload p) async {
    final database = await db;
    await database.insert('readings', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<SensorPayload>> getReadings(int fromMs, int toMs) async {
    final database = await db;
    final rows = await database.query('readings',
        where: 'timestamp BETWEEN ? AND ?',
        whereArgs: [fromMs, toMs],
        orderBy: 'timestamp ASC');
    return rows.map(_rowToPayload).toList();
  }

  Future<void> pruneOldReadings() async {
    final database = await db;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: _maxHistoryDays))
        .millisecondsSinceEpoch;
    await database.delete('readings', where: 'timestamp < ?', whereArgs: [cutoff]);
  }

  Future<void> insertJournalEntry(JournalEntry e) async {
    final database = await db;
    await database.insert('journal', {
      'id': e.id,
      'timestamp': e.timestamp,
      'snapshot_json': jsonEncode(e.snapshot.toMap()),
      'note': e.note,
      'tags': e.tags.join(','),
    });
  }

  Future<List<JournalEntry>> getJournalEntries() async {
    final database = await db;
    final rows = await database.query('journal', orderBy: 'timestamp DESC');
    return rows.map((r) => JournalEntry(
      id: r['id'] as String,
      timestamp: r['timestamp'] as int,
      snapshot: SensorPayload.fromJson(
          jsonDecode(r['snapshot_json'] as String) as Map<String, dynamic>),
      note: r['note'] as String,
      tags: (r['tags'] as String).split(',').where((t) => t.isNotEmpty).toList(),
    )).toList();
  }

  Future<void> deleteJournalEntry(String id) async {
    final database = await db;
    await database.delete('journal', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AlertRule>> getAlertRules() async {
    final database = await db;
    final rows = await database.query('alerts');
    return rows.map(AlertRule.fromMap).toList();
  }

  Future<void> upsertAlertRule(AlertRule rule) async {
    final database = await db;
    await database.insert('alerts', rule.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAlertRule(String id) async {
    final database = await db;
    await database.delete('alerts', where: 'id = ?', whereArgs: [id]);
  }

  SensorPayload _rowToPayload(Map<String, dynamic> r) => SensorPayload(
    timestamp: r['timestamp'] as int,
    ens160: ENS160Data(
      aqi:  (r['aqi']  as num?)?.toInt() ?? 0,
      eco2: (r['eco2'] as num?)?.toInt() ?? 0,
      tvoc: (r['tvoc'] as num?)?.toInt() ?? 0,
    ),
    aht21: AHT21Data(
      temperature: (r['temperature'] as num?)?.toDouble() ?? 0,
      humidity:    (r['humidity']    as num?)?.toDouble() ?? 0,
    ),
    pms5003: PMS5003Data(
      pm1_0: (r['pm1_0'] as num?)?.toInt() ?? 0,
      pm2_5: (r['pm2_5'] as num?)?.toInt() ?? 0,
      pm10:  (r['pm10']  as num?)?.toInt() ?? 0,
    ),
    bmp580: BMP580Data(
      pressure: (r['pressure'] as num?)?.toDouble() ?? 0,
      altitude: (r['altitude'] as num?)?.toDouble() ?? 0,
    ),
    ready: (r['ready'] as int?) == 1,
    uptimeS: 0,
  );
}
