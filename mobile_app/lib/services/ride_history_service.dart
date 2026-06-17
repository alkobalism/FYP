import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:latlong2/latlong.dart';

class PotholeHazard {
  final double lat;
  final double lng;
  final int riskPercentage;
  final String riskLevel;

  PotholeHazard({
    required this.lat,
    required this.lng,
    required this.riskPercentage,
    required this.riskLevel,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'riskPercentage': riskPercentage,
        'riskLevel': riskLevel,
      };

  factory PotholeHazard.fromJson(Map<String, dynamic> json) => PotholeHazard(
        lat: json['lat'] as double,
        lng: json['lng'] as double,
        riskPercentage: json['riskPercentage'] as int,
        riskLevel: json['riskLevel'] as String,
      );
}

class RideSession {
  final String id;
  final DateTime date;
  final int durationSeconds;
  final double distanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final List<LatLng> path;
  final List<PotholeHazard> potholes;

  RideSession({
    required this.id,
    required this.date,
    required this.durationSeconds,
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.path,
    required this.potholes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'durationSeconds': durationSeconds,
        'distanceKm': distanceKm,
        'avgSpeedKmh': avgSpeedKmh,
        'maxSpeedKmh': maxSpeedKmh,
        'path': path.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        'potholes': potholes.map((p) => p.toJson()).toList(),
      };

  factory RideSession.fromJson(Map<String, dynamic> json) {
    var rawPath = json['path'] as List<dynamic>;
    var rawPotholes = json['potholes'] as List<dynamic>;

    return RideSession(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      durationSeconds: json['durationSeconds'] as int,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      avgSpeedKmh: (json['avgSpeedKmh'] as num).toDouble(),
      maxSpeedKmh: (json['maxSpeedKmh'] as num).toDouble(),
      path: rawPath
          .map((item) => LatLng(
                (item['lat'] as num).toDouble(),
                (item['lng'] as num).toDouble(),
              ))
          .toList(),
      potholes: rawPotholes
          .map((item) => PotholeHazard.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RideHistoryService {
  static const String _fileName = 'rides.json';

  // Get path to local storage file
  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  // Load all sessions from file
  static Future<List<RideSession>> loadRides() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
      return jsonList
          .map((item) => RideSession.fromJson(item as Map<String, dynamic>))
          .toList()
          .reversed // Show newest rides first
          .toList();
    } catch (e) {
      print("Error loading rides: $e");
      return [];
    }
  }

  // Save a new ride session
  static Future<bool> saveRide(RideSession session) async {
    try {
      final file = await _getFile();
      List<RideSession> rides = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
        rides = jsonList
            .map((item) => RideSession.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      // Add to list and write back
      rides.add(session);
      final updatedContent = jsonEncode(rides.map((r) => r.toJson()).toList());
      await file.writeAsString(updatedContent);
      return true;
    } catch (e) {
      print("Error saving ride: $e");
      return false;
    }
  }

  // Clear all ride logs
  static Future<bool> clearHistory() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      print("Error clearing history: $e");
      return false;
    }
  }

  // Fetch all potholes across all sessions for general mapping
  static Future<List<PotholeHazard>> getAllPotholes() async {
    final rides = await loadRides();
    List<PotholeHazard> potholes = [];
    for (var ride in rides) {
      potholes.addAll(ride.potholes);
    }
    return potholes;
  }
}
