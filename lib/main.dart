// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/neopixel_screen.dart';
import 'services/widget_service.dart';
import 'services/notification_service.dart';
import 'utils/theme.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'updateWidget') {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString('deviceIp') ?? '192.168.2.116';
      await WidgetService.updateWidgets(ip);
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.init();
  await NotificationService.instance.init();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  await Workmanager().registerPeriodicTask(
    'widgetUpdate',
    'updateWidget',
    // Android clamps periodic work to a 15-minute minimum, so asking for 1
    // minute did not produce minute-by-minute updates — it was silently
    // rounded up. Stating 15 makes the real behaviour visible.
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const AqiApp(),
    ),
  );
}

class AqiApp extends StatelessWidget {
  const AqiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AQI Monitor',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _screens = [
    DashboardScreen(),
    HistoryScreen(),
    JournalScreen(),
    AlertsScreen(),
    NeoPixelScreen(),
    SettingsScreen(),
  ];

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.air),                     label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.show_chart),              label: 'History'),
    BottomNavigationBarItem(icon: Icon(Icons.book_outlined),           label: 'Journal'),
    BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined),  label: 'Alerts'),
    BottomNavigationBarItem(icon: Icon(Icons.lightbulb_outline),       label: 'NeoPixel'),
    BottomNavigationBarItem(icon: Icon(Icons.settings_outlined),       label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: _items,
      ),
    );
  }
}
