// lib/screens/journal_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/sensor_data.dart';
import '../utils/theme.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _noteController = TextEditingController();
  final _tags = <String>{};

  static const _presetTags = [
    'Cooking', 'Cleaning', 'Candles', 'Outdoor',
    'Humidity', 'Dusty', 'Note',
  ];

  Future<void> _save() async {
    final provider = context.read<AppProvider>();
    final reading = provider.latestReading;
    if (reading == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No live reading — connect device first')),
      );
      return;
    }
    await provider.addJournalEntry(JournalEntry(
      id: const Uuid().v4(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      snapshot: reading,
      note: _noteController.text,
      tags: _tags.toList(),
    ));
    _noteController.clear();
    setState(() => _tags.clear());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // New entry card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bg1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bg3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Log current reading',
                    style: TextStyle(fontSize: 12, color: AppColors.text1, letterSpacing: 1)),
                const SizedBox(height: 10),

                // Snapshot preview
                if (provider.latestReading != null)
                  _SnapshotPreview(reading: provider.latestReading!)
                else
                  const Text('No live reading — connect device first',
                      style: TextStyle(fontSize: 12, color: AppColors.text2)),

                const SizedBox(height: 12),

                // Tag chips
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _presetTags.map((tag) {
                    final selected = _tags.contains(tag);
                    return GestureDetector(
                      onTap: () => setState(() {
                        selected ? _tags.remove(tag) : _tags.add(tag);
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.accent.withOpacity(0.15)
                              : AppColors.bg2,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? AppColors.accent : AppColors.bg3,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected ? AppColors.accent : AppColors.text1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  maxLength: 500,
                  style: const TextStyle(color: AppColors.text0, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Add a note...',
                    hintStyle: const TextStyle(color: AppColors.text2),
                    filled: true,
                    fillColor: AppColors.bg2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    counterStyle: const TextStyle(color: AppColors.text2),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.bg0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save Entry',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text('${provider.journalEntries.length} entries',
              style: const TextStyle(fontSize: 12, color: AppColors.text1, letterSpacing: 1)),

          const SizedBox(height: 8),

          ...provider.journalEntries.map((entry) => _EntryCard(
            entry: entry,
            onDelete: () => provider.removeJournalEntry(entry.id),
          )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}

class _SnapshotPreview extends StatelessWidget {
  final SensorPayload reading;
  const _SnapshotPreview({required this.reading});

  @override
  Widget build(BuildContext context) {
    final aqi = reading.ens160.aqi;
    final color = AppColors.aqiColor(aqi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AQI $aqi — ${aqiLabel(aqi)}',
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${reading.aht21.temperature.toStringAsFixed(1)}°C  •  '
          '${reading.aht21.humidity.toStringAsFixed(0)}%  •  '
          'PM2.5 ${reading.pms5003.pm2_5}',
          style: const TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 11,
            color: AppColors.text2,
          ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onDelete;

  const _EntryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final aqi = entry.snapshot.ens160.aqi;
    final color = AppColors.aqiColor(aqi);
    final time = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bg3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AQI $aqi  •  ${aqiLabel(aqi)}',
                  style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
              Text(
                '${time.day}/${time.month}  ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11, color: AppColors.text2, fontFamily: 'SpaceMono'),
              ),
            ],
          ),
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: entry.tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(t, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
              )).toList(),
            ),
          ],
          if (entry.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(entry.note, style: const TextStyle(fontSize: 13, color: AppColors.text1)),
          ],
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton(
              onPressed: onDelete,
              style: TextButton.styleFrom(foregroundColor: AppColors.error, padding: EdgeInsets.zero),
              child: const Text('Delete', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
