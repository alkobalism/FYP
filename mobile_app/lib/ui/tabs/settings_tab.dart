import 'package:flutter/material.dart';
import '../../services/app_settings_service.dart';
import '../../services/ride_history_service.dart';

class SettingsTab extends StatefulWidget {
  final VoidCallback onSettingsChanged;

  const SettingsTab({super.key, required this.onSettingsChanged});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isTestMode = AppSettingsService.isTestMode;
  double _simulatedSpeed = AppSettingsService.simulatedSpeed;
  String _vehicleType = AppSettingsService.vehicleType;
  double _beepVolume = AppSettingsService.beepVolume;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await AppSettingsService.loadSettings();
    setState(() {
      _isTestMode = AppSettingsService.isTestMode;
      _simulatedSpeed = AppSettingsService.simulatedSpeed;
      _vehicleType = AppSettingsService.vehicleType;
      _beepVolume = AppSettingsService.beepVolume;
    });
  }

  void _saveSettings() {
    AppSettingsService.isTestMode = _isTestMode;
    AppSettingsService.simulatedSpeed = _simulatedSpeed;
    AppSettingsService.vehicleType = _vehicleType;
    AppSettingsService.beepVolume = _beepVolume;
    AppSettingsService.saveSettings();
    widget.onSettingsChanged();
  }

  void _clearRideHistory() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Clear History?", style: TextStyle(color: Colors.white)),
          content: const Text(
            "This will permanently delete all logged rides and detected pothole locations. This action cannot be undone.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(context);
                final success = await RideHistoryService.clearHistory();
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("All ride history cleared.")),
                  );
                  widget.onSettingsChanged();
                }
              },
              child: const Text("Clear All"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Vehicle Profile Category
          _buildCategoryHeader("VEHICLE PROFILE"),
          Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text("Electric Scooter (8.5\" wheel)", style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Rigid suspension. High vulnerability to potholes.", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: "scooter",
                  groupValue: _vehicleType,
                  activeColor: Colors.redAccent,
                  onChanged: (val) {
                    setState(() {
                      _vehicleType = val!;
                    });
                    _saveSettings();
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                RadioListTile<String>(
                  title: const Text("Standard Bicycle (26\" wheel)", style: TextStyle(color: Colors.white)),
                  subtitle: const Text("Moderate vulnerability. Larger wheels traverse defects better.", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: "bicycle",
                  groupValue: _vehicleType,
                  activeColor: Colors.redAccent,
                  onChanged: (val) {
                    setState(() {
                      _vehicleType = val!;
                    });
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Alert & Sound settings
          _buildCategoryHeader("ALERTS & SOUNDS"),
          Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Safety Beep Volume", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                          Text("Volume for HIGH risk warnings", style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                      Text("${(_beepVolume * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _beepVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    activeColor: Colors.redAccent,
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setState(() {
                        _beepVolume = val;
                      });
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Testing Settings Category
          _buildCategoryHeader("TEST MODE & SIMULATION"),
          Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Simulate Speed", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                    subtitle: const Text("Simulate cruising speeds to test pothole warning logic while stationary", style: TextStyle(color: Colors.white38, fontSize: 11)),
                    value: _isTestMode,
                    activeColor: Colors.redAccent,
                    onChanged: (val) {
                      setState(() {
                        _isTestMode = val;
                      });
                      _saveSettings();
                    },
                  ),
                  if (_isTestMode) ...[
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Simulated Speed", style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text("${_simulatedSpeed.toInt()} km/h", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: _simulatedSpeed,
                      min: 10.0,
                      max: 40.0,
                      divisions: 6,
                      activeColor: Colors.redAccent,
                      inactiveColor: Colors.white12,
                      onChanged: (val) {
                        setState(() {
                          _simulatedSpeed = val;
                        });
                        _saveSettings();
                      },
                    ),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4. Data Management
          _buildCategoryHeader("DATA MANAGEMENT"),
          Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                  title: const Text("Clear All Ride Logs", style: TextStyle(color: Colors.white, fontSize: 15)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                  onTap: _clearRideHistory,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
