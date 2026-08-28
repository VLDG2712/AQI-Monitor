// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;
  late TextEditingController _tokenController;
  late AppProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _ipController = TextEditingController(text: _provider.deviceIp);
    _tokenController = TextEditingController(text: _provider.apiToken);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _applyIp() {
    _provider.deviceIp = _ipController.text.trim();
    _provider.saveSettings();
  }

  void _applyToken() {
    _provider.apiToken = _tokenController.text.trim();
    _provider.saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _Section(label: 'Device', children: [
            _Row(
              label: 'IP Address',
              child: SizedBox(
                width: 160,
                child: TextField(
                  controller: _ipController,
                  onSubmitted: (_) => _applyIp(),
                  onEditingComplete: _applyIp,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 13,
                    color: AppColors.text0,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.bg2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ),
            _Row(
              label: 'API Token',
              child: SizedBox(
                width: 160,
                child: TextField(
                  controller: _tokenController,
                  onSubmitted: (_) => _applyToken(),
                  onEditingComplete: _applyToken,
                  obscureText: true,
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    color: AppColors.text0,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Bearer token',
                    hintStyle: const TextStyle(color: AppColors.text2, fontSize: 11),
                    filled: true,
                    fillColor: AppColors.bg2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ),
            _Row(
              label: 'Auto Connect',
              child: Switch(
                value: provider.autoConnect,
                onChanged: (v) {
                  provider.autoConnect = v;
                  provider.saveSettings();
                },
                activeColor: AppColors.accent,
              ),
            ),
          ]),

          _Section(label: 'Display', children: [
            _Row(
              label: 'Temperature Unit',
              child: _ToggleGroup(
                options: const ['°C', '°F'],
                selected: provider.tempUnit,
                onSelect: (v) {
                  provider.tempUnit = v;
                  provider.saveSettings();
                },
              ),
            ),
          ]),

          _Section(label: 'Data', children: [
            _Row(
              label: 'Store Reading Every',
              child: _ToggleGroup(
                options: const ['10s', '30s', '60s'],
                selected: _msToLabel(provider.storageInterval),
                onSelect: (v) {
                  provider.storageInterval = _labelToMs(v);
                  provider.saveSettings();
                },
              ),
            ),
          ]),
  _Section(label: 'App', children: [
            InkWell(
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'AQI Monitor',
                  applicationVersion: 'v0.2.1',
                  applicationLegalese: '© 2026 Promethium',
                  children: const [
                    SizedBox(height: 20),
                    Text(
                      'A beautiful and simple app to track the Air Quality Index and weather conditions in real-time.',
                      style: TextStyle(color: AppColors.text1), 
                    ),
                  ],
                );
              },
              child: const _Row(
                label: 'About AQI Monitor',
                child: Icon(
                  Icons.chevron_right,
                  color: AppColors.text2,
                  size: 20,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'AQI Monitor  •  v0.2.1',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 11,
                color: AppColors.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _msToLabel(int ms) {
    switch (ms) {
      case 10000: return '10s';
      case 60000: return '60s';
      default:    return '30s';
    }
  }

  int _labelToMs(String l) {
    switch (l) {
      case '10s': return 10000;
      case '60s': return 60000;
      default:    return 30000;
    }
  }
}

class _Section extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _Section({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.text1,
                letterSpacing: 2,
              )),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.bg3),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final Widget child;

  const _Row({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.bg3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: AppColors.text0)),
          child,
        ],
      ),
    );
  }
}

class _ToggleGroup extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _ToggleGroup({required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accent.withOpacity(0.15)
                  : AppColors.bg2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.accent : Colors.transparent,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'SpaceMono',
                color: isSelected ? AppColors.accent : AppColors.text1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
