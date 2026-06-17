import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppSettingsService {
  static bool isTestMode = false;
  static double simulatedSpeed = 25.0;
  static String vehicleType = "scooter"; // "scooter" or "bicycle"
  static double beepVolume = 1.0;

  static const String _fileName = 'settings.json';

  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  static Future<void> loadSettings() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        isTestMode = data['isTestMode'] ?? false;
        simulatedSpeed = (data['simulatedSpeed'] ?? 25.0).toDouble();
        vehicleType = data['vehicleType'] ?? "scooter";
        beepVolume = (data['beepVolume'] ?? 1.0).toDouble();
      }
    } catch (e) {
      print("Error loading settings: $e");
    }
  }

  static Future<void> saveSettings() async {
    try {
      final file = await _getFile();
      final content = jsonEncode({
        'isTestMode': isTestMode,
        'simulatedSpeed': simulatedSpeed,
        'vehicleType': vehicleType,
        'beepVolume': beepVolume,
      });
      await file.writeAsString(content);
    } catch (e) {
      print("Error saving settings: $e");
    }
  }
}
