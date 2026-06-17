import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ui/home_screen.dart';
import 'ui/tabs/dashboard_tab.dart';
import 'ui/tabs/history_map_tab.dart';
import 'ui/tabs/settings_tab.dart';
import 'services/app_settings_service.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Permission.camera.request();
  await Permission.location.request();
  
  await AppSettingsService.loadSettings();
  
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: $e.code\nError Message: $e.message');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pothole Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationHub(),
    );
  }
}

class MainNavigationHub extends StatefulWidget {
  const MainNavigationHub({super.key});

  @override
  State<MainNavigationHub> createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _currentIndex = 0;
  final GlobalKey<DashboardTabState> _dashboardKey = GlobalKey<DashboardTabState>();
  final GlobalKey<HistoryMapTabState> _mapKey = GlobalKey<HistoryMapTabState>();

  void _onSettingsChanged() {
    setState(() {}); // Force rebuild of other tabs when settings change
  }

  @override
  Widget build(BuildContext context) {
    // We instantiate tabs dynamically to ensure settings/history reload
    final List<Widget> tabs = [
      DashboardTab(
        key: _dashboardKey,
        onStartRidePressed: () {
          setState(() {
            _currentIndex = 1; // Switch to Record scan tab
          });
        },
      ),
      const HomeScreen(), // Record session scan screen
      HistoryMapTab(
        key: _mapKey,
      ), // Aggregate map showing all potholes
      SettingsTab(onSettingsChanged: _onSettingsChanged), // App settings
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0) {
            _dashboardKey.currentState?.loadHistory();
          } else if (index == 2) {
            _mapKey.currentState?.loadPotholesAndLocation();
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.white38,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_outline),
            activeIcon: Icon(Icons.play_circle_fill),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
