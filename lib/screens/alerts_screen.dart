// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/sensor_data.dart';
import '../utils/theme.dart';

const _presets = [
  AlertRule(id: '', sensor: 'ens160',  field: 'aqi',         operator: '>=', threshold: 3,    enabled: true, label: 'AQI Moderate or worse'),
  AlertRule(id: '', sensor: 'ens160',  field: 'eco2',        operator: '>=', threshold: 1000, enabled: true, label: 'eCO₂ High (>1000 ppm)'),
  AlertRule(id: '', sensor: 'ens160',  field: 'tvoc',        operator: '>=', threshold: 500,  enabled: true, label: 'TVOC High (>500 ppb)'),
  AlertRule(id: '', sensor: 'pms5003', field: 'pm2_5',       operator: '>=', threshold: 25,   enabled: true, label: 'PM2.5 High (>25 µg/m³)'),
  AlertRule(id: '', sensor: 'aht21',   field: 'humidity',    operator: '>=', threshold: 70,   enabled: true, label: 'Humidity High (>70%)'),
  AlertRule(id: '', sensor: 'aht21',   field: 'temperature', operator: '>=', threshold: 30,   enabled: true, label: 'Temperature High (>30°C)'),
];

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final rules = provider.alertRules;
    final available = _presets.where((p) =>
        !rules.any((r) => r.label == p.label)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (rules.isNotEmpty) ...[
            const Text('ACTIVE RULES',
                style: TextStyle(fontSize: 11, color: AppColors.text1, letterSpacing: 2)),
            const SizedBox(height: 8),
            ...rules.map((rule) => _RuleCard(
              rule: rule,
              onToggle: () => provider.upsertAlertRule(rule.copyWith(enabled: !rule.enabled)),
              onDelete: () => provider.removeAlertRule(rule.id),
            )),
            const SizedBox(height: 16),
          ],
          if (available.isNotEmpty) ...[
            const Text('ADD FROM PRESETS',
                style: TextStyle(fontSize: 11, color: AppColors.text1, letterSpacing: 2)),
            const SizedBox(height: 8),
            ...available.map((preset) => GestureDetector(
              onTap: () => provider.upsertAlertRule(
                AlertRule(
                  id: const Uuid().v4(),
                  sensor: preset.sensor,
                  field: preset.field,
                  operator: preset.operator,
                  threshold: preset.threshold,
                  enabled: true,
                  label: preset.label,
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bg1,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.bg3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(preset.label,
                        style: const TextStyle(fontSize: 13, color: AppColors.text0)),
                    const Text('+',
                        style: TextStyle(fontSize: 22, color: AppColors.accent)),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final AlertRule rule;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RuleCard({required this.rule, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
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
            children: [
              Expanded(
                child: Text(rule.label,
                    style: const TextStyle(fontSize: 14, color: AppColors.text0, fontWeight: FontWeight.bold)),
              ),
              Switch(
                value: rule.enabled,
                onChanged: (_) => onToggle(),
                activeThumbColor: AppColors.accent,
              ),
            ],
          ),
          Text(
            '${rule.sensor}.${rule.field} ${rule.operator} ${rule.threshold}',
            style: const TextStyle(fontFamily: 'SpaceMono', fontSize: 11, color: AppColors.text2),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton(
              onPressed: onDelete,
              style: TextButton.styleFrom(foregroundColor: AppColors.error, padding: EdgeInsets.zero),
              child: const Text('Remove', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
