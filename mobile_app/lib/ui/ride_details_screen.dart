import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/ride_history_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RideDetailsScreen extends StatelessWidget {
  final RideSession session;

  const RideDetailsScreen({super.key, required this.session});

  String _formatDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (hours > 0) {
      return "${hours}h ${minutes}m ${seconds}s";
    } else if (minutes > 0) {
      return "${minutes}m ${seconds}s";
    } else {
      return "${seconds}s";
    }
  }

  Color _getRiskColor(String level) {
    if (level == 'HIGH') return Colors.red;
    if (level == 'MEDIUM') return Colors.orange;
    return Colors.green;
  }

  Future<void> _deleteRide(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Delete Ride Log?", style: TextStyle(color: Colors.white)),
          content: const Text(
            "This will permanently delete this ride log and its pothole mappings. This action cannot be undone.",
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
                
                // Read existing, remove this session, write back
                final directory = await getApplicationDocumentsDirectory();
                final file = File('${directory.path}/rides.json');
                if (await file.exists()) {
                  final content = await file.readAsString();
                  final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
                  final List<RideSession> rides = jsonList
                      .map((item) => RideSession.fromJson(item as Map<String, dynamic>))
                      .toList();
                  
                  rides.removeWhere((r) => r.id == session.id);
                  
                  final updatedContent = jsonEncode(rides.map((r) => r.toJson()).toList());
                  await file.writeAsString(updatedContent);
                }

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Ride log deleted.")),
                  );
                  Navigator.pop(context); // Go back to dashboard
                }
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = "${session.date.day}/${session.date.month}/${session.date.year} at ${session.date.hour.toString().padLeft(2, '0')}:${session.date.minute.toString().padLeft(2, '0')}";
    
    // Map Center calculation
    LatLng mapCenter = const LatLng(2.222, 102.251);
    if (session.path.isNotEmpty) {
      mapCenter = session.path[session.path.length ~/ 2];
    } else if (session.potholes.isNotEmpty) {
      mapCenter = LatLng(session.potholes.first.lat, session.potholes.first.lng);
    }

    // Pothole Markers
    final List<Marker> markers = session.potholes.map((p) {
      final Color riskColor = _getRiskColor(p.riskLevel);
      return Marker(
        point: LatLng(p.lat, p.lng),
        width: 32,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: riskColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ],
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Ride Details"),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _deleteRide(context),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Dynamic Map Panel
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 14.5,
                    maxZoom: 18.0,
                    minZoom: 3.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      userAgentPackageName: 'com.example.pothole_detection.mobile_app',
                      tileBuilder: (context, tileWidget, tile) {
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            -0.2126, -0.7152, -0.0722, 0, 255,
                            -0.2126, -0.7152, -0.0722, 0, 255,
                            -0.2126, -0.7152, -0.0722, 0, 255,
                            0,       0,       0,       1, 0,
                          ]),
                          child: tileWidget,
                        );
                      },
                    ),
                    if (session.path.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: session.path,
                            color: Colors.redAccent,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: markers),
                  ],
                ),
                
                // Floating Pothole count
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orangeAccent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "${session.potholes.length} hazards logged",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Metrics Detail Panel
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFF161616),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Ride Performance Metrics",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Stats Grid
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 2.8,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      children: [
                        _buildMetricCard("DISTANCE", "${session.distanceKm.toStringAsFixed(2)} km"),
                        _buildMetricCard("DURATION", _formatDuration(session.durationSeconds)),
                        _buildMetricCard("AVG SPEED", "${session.avgSpeedKmh.toStringAsFixed(1)} km/h"),
                        _buildMetricCard("MAX SPEED", "${session.maxSpeedKmh.toStringAsFixed(1)} km/h"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
