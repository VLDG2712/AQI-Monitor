# AQI Monitor — Flutter

ESP32 air quality companion app. Connects to the AQI Monitor hardware via WebSocket (port 9092) with HTTP fallback (port 9091).

## Setup

### 1. Install Flutter
```bash
# Arch Linux
yay -S flutter

# Or follow https://docs.flutter.dev/get-started/install/linux
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Add fonts
Download SpaceMono from Google Fonts and place in `assets/fonts/`:
- `SpaceMono-Regular.ttf`
- `SpaceMono-Bold.ttf`

Or remove font references from `pubspec.yaml` and `theme.dart` to use system monospace.

### 4. Run on device
```bash
# Connect Android phone via USB with USB debugging on
flutter run

# Build release APK
flutter build apk --release
# APK at: build/app/outputs/flutter-apk/app-release.apk
```

## Architecture

```
lib/
├── main.dart                  # App entry, bottom nav shell
├── models/
│   └── sensor_data.dart       # All typed models (SensorPayload, AlertRule, JournalEntry)
├── providers/
│   └── app_provider.dart      # Global state (ChangeNotifier)
├── services/
│   ├── device_service.dart    # WebSocket + HTTP connectivity
│   └── database_service.dart  # SQLite (sqflite) — history, journal, alerts
├── screens/
│   ├── dashboard_screen.dart  # Live AQI + sensor grid
│   ├── history_screen.dart    # fl_chart line graphs
│   ├── journal_screen.dart    # Snapshot log with tags + notes
│   ├── alerts_screen.dart     # Push alert rule management
│   └── settings_screen.dart   # Device IP, units, storage interval
├── widgets/
│   └── sensor_tile.dart       # Reusable sensor card
└── utils/
    └── theme.dart             # Dark theme + color constants
```

## Connection
!! You need to run my firmware here: https://github.com/VLDG2712/Hexair
The app connects to `ws://<ip>:9092` first (live push data), falls back to `http://<ip>:9091/air` polling if WebSocket unavailable. Auto-reconnects on disconnect.

## Build APK

```bash
flutter build apk --release
```

Install on phone:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```
