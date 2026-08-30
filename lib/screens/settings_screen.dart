// lib/screens/settings_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/history_service.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;
  late TextEditingController _tokenController;
  late TextEditingController _lanController;
  late TextEditingController _tsController;
  late TextEditingController _serverTokenController;
  late AppProvider _provider;

  String? _testResult;
  bool _testing = false;
  bool _revealTokens = false;

  /// Whether the controllers have been populated from loaded preferences.
  bool _synced = false;

  /// Coalesces keystrokes so every character doesn't hit disk.
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _ipController = TextEditingController(text: _provider.deviceIp);
    _tokenController = TextEditingController(text: _provider.apiToken);
    _lanController = TextEditingController(text: _provider.serverLanHost);
    _tsController = TextEditingController(text: _provider.serverTailscaleHost);
    _serverTokenController =
        TextEditingController(text: _provider.serverToken);

    // IndexedStack builds this screen at startup, before the async settings
    // load has finished, so the controllers above may hold defaults. Re-read
    // them once the load completes.
    _syncFromProvider();
    _provider.addListener(_syncFromProvider);
  }

  void _syncFromProvider() {
    if (_synced || !_provider.settingsLoaded) return;
    _synced = true;
    // No setState: each controller is a Listenable its TextField already
    // watches, and this also runs from initState where setState is invalid.
    _ipController.text = _provider.deviceIp;
    _tokenController.text = _provider.apiToken;
    _lanController.text = _provider.serverLanHost;
    _tsController.text = _provider.serverTailscaleHost;
    _serverTokenController.text = _provider.serverToken;
  }

  @override
  void dispose() {
    _provider.removeListener(_syncFromProvider);
    // Flush rather than drop: a pending debounce here means the user typed
    // within the last moment and would otherwise lose that edit.
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _applyAll();
    }
    _saveDebounce?.cancel();
    _ipController.dispose();
    _tokenController.dispose();
    _lanController.dispose();
    _tsController.dispose();
    _serverTokenController.dispose();
    super.dispose();
  }

  /// Persist after a short pause in typing, so navigating away without
  /// pressing "done" still saves.
  void _saveSoon() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _applyAll);
  }

  /// Writes every field from its own controller.
  ///
  /// Deliberately all-at-once rather than per-field partial writes: each value
  /// comes from its own controller, so no field can clobber another.
  void _applyAll() {
    if (!_synced) return; // never write defaults over stored values
    _provider
      ..deviceIp = _ipController.text.trim()
      ..apiToken = _tokenController.text.trim()
      ..serverLanHost = _lanController.text.trim()
      ..serverTailscaleHost = _tsController.text.trim()
      ..serverToken = _serverTokenController.text.trim();
    _provider.saveSettings();
  }

  void _applyServer() => _applyAll();

  Future<void> _testServer() async {
    _applyServer();
    setState(() {
      _testing = true;
      _testResult = null;
    });
    String result;
    try {
      final s = await _provider.remoteHistory.stats();
      final rows = s['rows'] ?? 0;
      final host = _provider.remoteHistory.activeHost ?? '?';
      result = 'OK — $rows rows via $host';
    } catch (e) {
      result = e is HistoryUnavailable ? e.message : '$e';
    }
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = result;
    });
  }

  void _applyIp() => _applyAll();

  void _applyToken() => _applyAll();

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
                  onChanged: (_) => _saveSoon(),
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
                  onChanged: (_) => _saveSoon(),
                  obscureText: !_revealTokens,
                  autocorrect: false,
                  enableSuggestions: false,
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

          _Section(label: 'History Server', children: [
            _Row(
              label: 'Source',
              child: _ToggleGroup(
                options: const ['Local', 'Server'],
                selected: provider.historySource == HistorySource.server
                    ? 'Server'
                    : 'Local',
                onSelect: (v) {
                  provider.historySource =
                      v == 'Server' ? HistorySource.server : HistorySource.local;
                  provider.saveSettings();
                },
              ),
            ),
            _Row(
              label: 'LAN Address',
              child: _ServerField(
                controller: _lanController,
                hint: '192.168.2.54:9101',
                onDone: _applyServer,
                onChanged: _saveSoon,
              ),
            ),
            _Row(
              label: 'Tailscale Address',
              child: _ServerField(
                controller: _tsController,
                hint: '100.90.171.26:9101',
                onDone: _applyServer,
                onChanged: _saveSoon,
              ),
            ),
            _Row(
              label: 'Server Token',
              child: _ServerField(
                controller: _serverTokenController,
                hint: 'Bearer token',
                obscure: !_revealTokens,
                onDone: _applyServer,
                onChanged: _saveSoon,
              ),
            ),
            _Row(
              label: 'Show Tokens',
              child: Switch(
                value: _revealTokens,
                onChanged: (v) => setState(() => _revealTokens = v),
                activeColor: AppColors.accent,
              ),
            ),
            InkWell(
              onTap: _testing ? null : _testServer,
              child: _Row(
                label: 'Test Connection',
                child: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : const Icon(Icons.wifi_find,
                        color: AppColors.text2, size: 20),
              ),
            ),
            if (_testResult != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    color: _testResult!.startsWith('OK')
                        ? AppColors.connected
                        : AppColors.error,
                  ),
                ),
              ),
          ]),

  _Section(label: 'App', children: [
            InkWell(
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'AQI Monitor',
                  applicationVersion: 'v0.2.2',
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
              'AQI Monitor  •  v0.2.2',
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

/// Right-aligned text field used by the History Server section.
class _ServerField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onDone;
  final VoidCallback? onChanged;

  const _ServerField({
    required this.controller,
    required this.hint,
    required this.onDone,
    this.obscure = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: TextField(
        controller: controller,
        onSubmitted: (_) => onDone(),
        onEditingComplete: onDone,
        onChanged: onChanged == null ? null : (_) => onChanged!(),
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 11,
          color: AppColors.text0,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.text2, fontSize: 11),
          filled: true,
          fillColor: AppColors.bg2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }
}
