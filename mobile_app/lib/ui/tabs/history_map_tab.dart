import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/ride_history_service.dart';

class HistoryMapTab extends StatefulWidget {
  const HistoryMapTab({super.key});

  @override
  State<HistoryMapTab> createState() => _HistoryMapTabState();
}

class _HistoryMapTabState extends State<HistoryMapTab> {
  List<PotholeHazard> _potholes = [];
  bool _isLoading = true;
  LatLng _mapCenter = const LatLng(2.222, 102.251); // Default center (UTeM Melaka!)
  double _mapZoom = 13.0;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadPotholesAndLocation();
  }

  Future<void> _loadPotholesAndLocation() async {
    setState(() => _isLoading = true);
    
    // Load potholes
    final potholes = await RideHistoryService.getAllPotholes();

    // Get current location to center map
    LatLng center = const LatLng(2.222, 102.251);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      );
      center = LatLng(position.latitude, position.longitude);
    } catch (_) {
      // Fallback to first pothole if available
      if (potholes.isNotEmpty) {
        center = LatLng(potholes.first.lat, potholes.first.lng);
      }
    }

    setState(() {
      _potholes = potholes;
      _mapCenter = center;
      _isLoading = false;
    });

    // Animate map controller to center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(center, _mapZoom);
      }
    });
  }

  Color _getRiskColor(String level) {
    if (level == 'HIGH') return Colors.red;
    if (level == 'MEDIUM') return Colors.orange;
    return Colors.green;
  }

  void _showPotholeDetail(PotholeHazard p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final Color riskColor = _getRiskColor(p.riskLevel);
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Hazard Bounding Log",
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: riskColor, width: 1),
                    ),
                    child: Text(
                      "${p.riskPercentage}% Risk (${p.riskLevel})",
                      style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Pothole Detected",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Coordinates: ${p.lat.toStringAsFixed(6)}, ${p.lng.toStringAsFixed(6)}",
                style: const TextStyle(color: Colors.white30, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: riskColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.riskLevel == 'HIGH'
                          ? "Critical impact threat. Riding through this defect at high speed can cause loss of control or tire blowout."
                          : (p.riskLevel == 'MEDIUM'
                              ? "Moderate threat. Recommend taking precautionary detours."
                              : "Minor surface defect. Exercise caution."),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E2E2E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Generate markers
    final List<Marker> markers = _potholes.map((p) {
      final Color riskColor = _getRiskColor(p.riskLevel);
      return Marker(
        point: LatLng(p.lat, p.lng),
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _showPotholeDetail(p),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rippling outer glow
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
              ),
              // Inner core icon
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: riskColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Hazard Map"),
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPotholesAndLocation,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: _mapZoom,
                    maxZoom: 18.0,
                    minZoom: 3.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                      tileBuilder: (context, tileWidget, tile) {
                        // Blend dark filter over standard OSM tiles to fit dark mode aesthetics
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix(<double>[
                            -0.2126, -0.7152, -0.0722, 0, 255, // Red
                            -0.2126, -0.7152, -0.0722, 0, 255, // Green
                            -0.2126, -0.7152, -0.0722, 0, 255, // Blue
                            0,       0,       0,       1, 0,   // Alpha
                          ]),
                          child: tileWidget,
                        );
                      },
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),

                // Map Legend Overlay (Top Right)
                Positioned(
                  top: 16,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: const Color(0xFF1E1E1E).withOpacity(0.9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("HAZARD RISK", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildLegendRow("High Risk", Colors.red),
                          const SizedBox(height: 6),
                          _buildLegendRow("Medium Risk", Colors.orange),
                          const SizedBox(height: 6),
                          _buildLegendRow("Low Risk", Colors.green),
                        ],
                      ),
                    ),
                  ),
                ),

                // Potholes count badge (Bottom Left)
                Positioned(
                  bottom: 24,
                  left: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: Colors.black.withOpacity(0.75),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orangeAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Total Hazards: ${_potholes.length}",
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLegendRow(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
