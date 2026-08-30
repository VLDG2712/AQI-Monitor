// lib/screens/neopixel_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';

class NeoPixelScreen extends StatefulWidget {
  const NeoPixelScreen({super.key});
  @override
  State<NeoPixelScreen> createState() => _NeoPixelScreenState();
}

class _NeoPixelScreenState extends State<NeoPixelScreen> {
  bool _enabled   = true;
  bool _manual    = false;
  int  _effect    = 1;
  int  _brightness= 175;
  int  _speed     = 128;
  int  _r = 0, _g = 200, _b = 100;
  bool _loading   = true;

  static const _effects = [
    (0, 'Static'),
    (1, 'Breathing'),
    (2, 'Chase / Spin'),
    (3, 'Rainbow'),
    (4, 'Strobe'),
    (5, 'Fire'),
    (6, 'Theater Chase'),
    (7, 'Sparkle'),
    (8, 'Color Cycle'),
  ];

  static const _scenes = [
    ('RELAX',  1, 255, 140, 0,   55,  120),
    ('FOCUS',  0, 180, 210, 255, 128, 210),
    ('PARTY',  3, 0,   0,   0,   220, 255),
    ('ALERT',  4, 255, 0,   0,   210, 255),
    ('CHILL',  1, 0,   80,  255, 35,  100),
    ('FIRE',   5, 0,   0,   0,   160, 200),
  ];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  String get _baseUrl {
    final ip = context.read<AppProvider>().deviceIp;
    return 'http://$ip:9091';
  }

  Future<void> _loadState() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/neo'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _enabled    = j['enabled'] as bool? ?? true;
          _manual     = j['manual']  as bool? ?? false;
          _effect     = (j['effect'] as num?)?.toInt() ?? 1;
          _brightness = (j['brightness'] as num?)?.toInt() ?? 175;
          _speed      = (j['speed'] as num?)?.toInt() ?? 128;
          _r          = (j['r'] as num?)?.toInt() ?? 0;
          _g          = (j['g'] as num?)?.toInt() ?? 200;
          _b          = (j['b'] as num?)?.toInt() ?? 100;
          _loading    = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String get _token => context.read<AppProvider>().apiToken;

  Future<void> _send(Map<String, dynamic> patch) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/neo'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(patch),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Color get _color => Color.fromARGB(255, _r, _g, _b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NeoPixel'),
        actions: [
          Switch(
            value: _enabled,
            activeThumbColor: AppColors.accent,
            onChanged: (v) {
              setState(() => _enabled = v);
              _send({'enabled': v});
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Mode toggle
                _Section(label: 'Mode', child: Row(
                  children: [
                    _ModeBtn(
                      label: '🎨  SENSOR',
                      active: !_manual,
                      onTap: () {
                        setState(() => _manual = false);
                        _send({'manual': false});
                      },
                    ),
                    const SizedBox(width: 8),
                    _ModeBtn(
                      label: '🎛  MANUAL',
                      active: _manual,
                      onTap: () {
                        setState(() => _manual = true);
                        _send({'manual': true});
                      },
                    ),
                  ],
                )),

                const SizedBox(height: 16),

                // Brightness
                _Section(label: 'Brightness', child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.brightness_low, color: AppColors.text2, size: 18),
                        Expanded(
                          child: Slider(
                            value: _brightness.toDouble(),
                            min: 0, max: 255,
                            activeColor: AppColors.accent,
                            inactiveColor: AppColors.bg3,
                            onChanged: (v) => setState(() => _brightness = v.toInt()),
                            onChangeEnd: (v) => _send({'brightness': v.toInt()}),
                          ),
                        ),
                        const Icon(Icons.brightness_high, color: AppColors.text0, size: 18),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 32,
                          child: Text('$_brightness',
                              style: const TextStyle(fontFamily: 'SpaceMono', fontSize: 12, color: AppColors.text0)),
                        ),
                      ],
                    ),
                  ],
                )),

                if (_manual) ...[
                  const SizedBox(height: 16),

                  // Quick scenes
                  _Section(label: 'Quick Scenes', child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.2,
                    children: _scenes.map((s) => GestureDetector(
                      onTap: () {
                        setState(() {
                          _effect = s.$2; _r = s.$3; _g = s.$4;
                          _b = s.$5; _speed = s.$6; _brightness = s.$7;
                        });
                        _send({
                          'manual': true, 'effect': s.$2,
                          'r': s.$3, 'g': s.$4, 'b': s.$5,
                          'speed': s.$6, 'brightness': s.$7,
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.bg2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.bg3),
                        ),
                        alignment: Alignment.center,
                        child: Text(s.$1,
                            style: const TextStyle(
                              fontSize: 12, color: AppColors.text1,
                              fontFamily: 'SpaceMono',
                            )),
                      ),
                    )).toList(),
                  )),

                  const SizedBox(height: 16),

                  // Color picker
                  _Section(label: 'Color', child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Color preview
                      Row(
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: _color,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.bg3),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'R:$_r  G:$_g  B:$_b',
                            style: const TextStyle(
                              fontFamily: 'SpaceMono',
                              fontSize: 13,
                              color: AppColors.text1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _RgbSlider(label: 'R', value: _r, color: Colors.red,
                          onChanged: (v) => setState(() => _r = v),
                          onChangeEnd: (v) => _send({'r': v})),
                      _RgbSlider(label: 'G', value: _g, color: Colors.green,
                          onChanged: (v) => setState(() => _g = v),
                          onChangeEnd: (v) => _send({'g': v})),
                      _RgbSlider(label: 'B', value: _b, color: Colors.blue,
                          onChanged: (v) => setState(() => _b = v),
                          onChangeEnd: (v) => _send({'b': v})),
                      const SizedBox(height: 8),
                      // Preset colors
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _ColorDot(color: const Color(0xFFFF2200), onTap: (r,g,b) { setState(() { _r=r;_g=g;_b=b; }); _send({'r':r,'g':g,'b':b}); }),
                          _ColorDot(color: const Color(0xFF00FF44), onTap: (r,g,b) { setState(() { _r=r;_g=g;_b=b; }); _send({'r':r,'g':g,'b':b}); }),
                          _ColorDot(color: const Color(0xFF0088FF), onTap: (r,g,b) { setState(() { _r=r;_g=g;_b=b; }); _send({'r':r,'g':g,'b':b}); }),
                          _ColorDot(color: const Color(0xFFFF8800), onTap: (r,g,b) { setState(() { _r=r;_g=g;_b=b; }); _send({'r':r,'g':g,'b':b}); }),
                          _ColorDot(color: const Color(0xFFCC00FF), onTap: (r,g,b) { setState(() { _r=r;_g=g;_b=b; }); _send({'r':r,'g':g,'b':b}); }),
                          _ColorDot(color: const Color(0xFFFFFFFF), onTap: (r,g,b) { setState(() { _r=r;_g=g;_b=b; }); _send({'r':r,'g':g,'b':b}); }),
                          _ColorDot(color: const Color(0xFF00FFFF), onTap: (r,g,b) { setState(() { _r=r;_g=g;_b=b; }); _send({'r':r,'g':g,'b':b}); }),
                          _ColorDot(color: const Color(0xFFFFFF00), onTap: (r,g,b) { setState(() { _r=r;_g=g;_b=b; }); _send({'r':r,'g':g,'b':b}); }),
                        ],
                      ),
                    ],
                  )),

                  const SizedBox(height: 16),

                  // Effect selector
                  _Section(label: 'Effect', child: Column(
                    children: _effects.map((e) => GestureDetector(
                      onTap: () {
                        setState(() => _effect = e.$1);
                        _send({'effect': e.$1});
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _effect == e.$1
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : AppColors.bg2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _effect == e.$1 ? AppColors.accent : AppColors.bg3,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.$2,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _effect == e.$1 ? AppColors.accent : AppColors.text0,
                                )),
                            if (_effect == e.$1)
                              const Icon(Icons.check, color: AppColors.accent, size: 16),
                          ],
                        ),
                      ),
                    )).toList(),
                  )),

                  if (_effect != 0) ...[
                    const SizedBox(height: 16),

                    // Speed
                    _Section(label: 'Speed', child: Row(
                      children: [
                        const Icon(Icons.slow_motion_video, color: AppColors.text2, size: 18),
                        Expanded(
                          child: Slider(
                            value: _speed.toDouble(),
                            min: 0, max: 255,
                            activeColor: AppColors.accent,
                            inactiveColor: AppColors.bg3,
                            onChanged: (v) => setState(() => _speed = v.toInt()),
                            onChangeEnd: (v) => _send({'speed': v.toInt()}),
                          ),
                        ),
                        const Icon(Icons.fast_forward, color: AppColors.text0, size: 18),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 32,
                          child: Text('$_speed',
                              style: const TextStyle(fontFamily: 'SpaceMono', fontSize: 12, color: AppColors.text0)),
                        ),
                      ],
                    )),
                  ],
                ],

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 11, color: AppColors.text1, letterSpacing: 2)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.bg3),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bg2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? AppColors.accent : AppColors.bg3),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                color: active ? AppColors.accent : AppColors.text1,
                fontFamily: 'SpaceMono',
              )),
        ),
      ),
    );
  }
}

class _RgbSlider extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;
  const _RgbSlider({required this.label, required this.value, required this.color, required this.onChanged, required this.onChangeEnd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 16,
            child: Text(label, style: TextStyle(fontSize: 12, color: color, fontFamily: 'SpaceMono', fontWeight: FontWeight.bold))),
        Expanded(
          child: Slider(
            value: value.toDouble(), min: 0, max: 255,
            activeColor: color,
            inactiveColor: AppColors.bg3,
            onChanged: (v) => onChanged(v.toInt()),
            onChangeEnd: (v) => onChangeEnd(v.toInt()),
          ),
        ),
        SizedBox(width: 32,
            child: Text('$value', style: const TextStyle(fontFamily: 'SpaceMono', fontSize: 11, color: AppColors.text2))),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final void Function(int r, int g, int b) onTap;
  const _ColorDot({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Color.r/g/b are 0..1 doubles now; .red/.green/.blue are deprecated.
      onTap: () => onTap(
        (color.r * 255.0).round().clamp(0, 255),
        (color.g * 255.0).round().clamp(0, 255),
        (color.b * 255.0).round().clamp(0, 255),
      ),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.bg3, width: 2),
        ),
      ),
    );
  }
}
