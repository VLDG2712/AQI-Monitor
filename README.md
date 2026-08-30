# AQI Monitor — Flutter

Companion app for the Hexair ESP32 air quality monitor
(https://github.com/VLDG2712/Hexair). Shows live readings, historical charts, a
journal, threshold alerts, NeoPixel control and a home screen widget.

## Setup

### 1. Flutter

```bash
yay -S flutter          # Arch
# or https://docs.flutter.dev/get-started/install/linux
```

### 2. Dependencies

```bash
flutter pub get
```

### 3. Fonts

Download SpaceMono from Google Fonts into `assets/fonts/`:

- `SpaceMono-Regular.ttf`
- `SpaceMono-Bold.ttf`

Or drop the font references from `pubspec.yaml` and `theme.dart` to fall back to
the system monospace.

### 4. Run

```bash
flutter run                    # debug, device attached
flutter build apk --release    # release build
```

### 5. Release signing

A release build needs a keystore. `android/key.properties` and `*.jks` are both
gitignored.

```bash
keytool -genkey -v -keystore ~/aqi-monitor-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties`:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/aqi-monitor-upload.jks
```

Without it the build fails with `SigningConfig "release" is missing required
property "storeFile"`.

Version comes from `pubspec.yaml` (`version: <name>+<code>`) and flows into
Gradle via `flutter.versionName` / `flutter.versionCode`. Android refuses any
update whose `versionCode` is not strictly higher than the installed one, so
bump the `+N` for every release you intend to install over an older build.

## Connecting

Two independent connections, configured separately in **Settings**:

**The device** (Device section) — the ESP32's IP. The app polls
`http://<ip>:9091/air`. The API token here is only needed for NeoPixel control;
`/air` is unauthenticated.

WebSocket support exists in `device_service.dart` but is off behind
`_wsEnabled`, because the firmware serves nothing on 9092. Probing it cost a
timeout on every connect and raised an unhandled `SocketException`, since
`web_socket_channel` performs its upgrade over `HttpClient` and that refusal
escapes both the `try/catch` and the stream's `onError`. Flip the flag if a
WebSocket server is ever added.

**The history server** (History Server section) — the optional service from the
Hexair repo's `server/` directory. Set a LAN address, optionally a Tailscale
address, and its bearer token, then switch **Source** to `Server`. Without it,
History falls back to whatever the app itself recorded while running.

The LAN address is tried first on a short timeout, with Tailscale as fallback —
away from home the LAN address is not slow but unroutable, so failing fast
matters. Whichever answered is preferred for the next few minutes.

## Screens

| Screen | Contents |
|---|---|
| Dashboard | Live AQI and a sensor grid |
| History | Charts over 1H–1Y with a scrub readout |
| Journal | Timestamped snapshots with notes and tags |
| Alerts | Threshold rules with push notifications |
| NeoPixel | Ring control: mode, effect, colour, brightness, scenes |
| Settings | Device, display, storage, history server |

**History** charts AQI, temperature, humidity, PM2.5, eCO2, TVOC and pressure
over ranges from 1H to 1Y. Dragging any chart moves all seven to the same
moment, with the date and time shown above; the server aggregates server-side,
so a year returns a few hundred points rather than a million. 30D and 1Y are
only meaningful against the server, since the local database holds only what
the app saw while running.

Note that TVOC and eCO2 track each other closely. That is the sensor, not a
bug: the ENS160 derives both from one MOX element, so eCO2 is a model output
from the VOC response rather than an independent CO2 measurement.

## Architecture

```
lib/
├── main.dart                     # Entry, bottom nav shell, widget background task
├── models/
│   └── sensor_data.dart          # SensorPayload, AlertRule, JournalEntry
├── providers/
│   └── app_provider.dart         # Global state (ChangeNotifier), settings
├── services/
│   ├── device_service.dart       # HTTP polling to the ESP32 (WS behind a flag)
│   ├── database_service.dart     # sqflite: readings, journal, alerts
│   ├── history_service.dart      # Remote history API, LAN → Tailscale fallback
│   ├── notification_service.dart # Local push for alert rules
│   └── widget_service.dart       # Android home screen widget
├── screens/                      # One file per screen above
├── widgets/
│   └── sensor_tile.dart
└── utils/
    └── theme.dart                # Dark palette
```

Settings persist through `SharedPreferences` and are loaded asynchronously.
Because `main.dart` uses an `IndexedStack`, every screen is built at startup —
`SettingsScreen` therefore re-syncs its text controllers once that load
completes, and refuses to write back until it has. Skipping that is how stored
values get silently overwritten with defaults.

## Home screen widget

An Android widget shows current AQI, temperature, humidity, eCO2 and TVOC,
refreshed by `workmanager`. Android enforces a **15 minute minimum** on
periodic work, so a shorter interval is silently clamped rather than honoured.
