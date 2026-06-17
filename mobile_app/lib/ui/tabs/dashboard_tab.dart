import 'package:flutter/material.dart';
import '../../services/ride_history_service.dart';
import '../ride_details_screen.dart';

class DashboardTab extends StatefulWidget {
  final VoidCallback onStartRidePressed;

  const DashboardTab({super.key, required this.onStartRidePressed});

  @override
  State<DashboardTab> createState() => DashboardTabState();
}

class DashboardTabState extends State<DashboardTab> {
  List<RideSession> _rides = [];
  bool _isLoading = true;

  double _totalDistance = 0.0;
  int _totalDurationSeconds = 0;
  int _totalPotholes = 0;
  double _avgSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    setState(() => _isLoading = true);
    final rides = await RideHistoryService.loadRides();
    
    double dist = 0.0;
    int dur = 0;
    int potholes = 0;
    double speedSum = 0.0;

    for (var r in rides) {
      dist += r.distanceKm;
      dur += r.durationSeconds;
      potholes += r.potholes.length;
      speedSum += r.avgSpeedKmh;
    }

    setState(() {
      _rides = rides;
      _totalDistance = dist;
      _totalDurationSeconds = dur;
      _totalPotholes = potholes;
      _avgSpeed = rides.isNotEmpty ? speedSum / rides.length : 0.0;
      _isLoading = false;
    });
  }

  String _formatDuration(int totalSeconds) {
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else if (minutes > 0) {
      return "${minutes}m ${seconds}s";
    } else {
      return "${seconds}s";
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning 🌅';
    if (hour < 17) return 'Good Afternoon ☀️';
    return 'Good Evening 🌌';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadHistory,
          color: Colors.redAccent,
          backgroundColor: const Color(0xFF1E1E1E),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Sleek Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Rider Dashboard",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Statistics Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.redAccent.withOpacity(0.15), Colors.orangeAccent.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.25), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "TOTAL PERFORMANCE STATS",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem("Distance", "${_totalDistance.toStringAsFixed(1)} km", Icons.space_bar),
                            _buildStatItem("Duration", _formatDuration(_totalDurationSeconds), Icons.timer),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem("Potholes Logged", "$_totalPotholes", Icons.warning_amber_rounded, color: Colors.orangeAccent),
                            _buildStatItem("Avg Speed", "${_avgSpeed.toStringAsFixed(1)} km/h", Icons.speed),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Section Title: Recent Scans
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 28.0, bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recent Rides",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_rides.isNotEmpty)
                        Text(
                          "${_rides.length} rides",
                          style: const TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ),

              // 4. Loading indicator or list of runs
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  ),
                )
              else if (_rides.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_bike, color: Colors.white24, size: 60),
                          const SizedBox(height: 16),
                          const Text(
                            "No recorded rides yet",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Start scanning while riding to track safety stats and log pothole hazard maps.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: widget.onStartRidePressed,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text("Start Scanning Ride"),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final r = _rides[index];
                      return _buildRideCard(context, r);
                    },
                    childCount: _rides.length,
                  ),
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color color = Colors.white}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white30, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRideCard(BuildContext context, RideSession r) {
    final formattedDate = "${r.date.day}/${r.date.month}/${r.date.year} at ${r.date.hour.toString().padLeft(2, '0')}:${r.date.minute.toString().padLeft(2, '0')}";
    final rideDuration = _formatDuration(r.durationSeconds);
    // We could store vehicle in session metadata, but for now fallback to defaults or path size
    
    final String rideTitle;
    final hour = r.date.hour;
    if (hour < 12) {
      rideTitle = "Morning Ride 🌅";
    } else if (hour < 17) {
      rideTitle = "Afternoon Ride ☀️";
    } else if (hour < 21) {
      rideTitle = "Evening Ride 🌌";
    } else {
      rideTitle = "Night Ride 🌙";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RideDetailsScreen(session: r),
            ),
          ).then((_) => loadHistory()); // reload stats in case deleted
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              // Ride icon circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  r.potholes.isNotEmpty ? Icons.warning_amber_rounded : Icons.navigation_rounded,
                  color: r.potholes.isNotEmpty ? Colors.orangeAccent : Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rideTitle,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (r.potholes.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1),
                            ),
                            child: Text(
                              "${r.potholes.length} ⚠️",
                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRideMetric("${r.distanceKm.toStringAsFixed(2)} km"),
                        _buildMetricSeparator(),
                        _buildRideMetric(rideDuration),
                        _buildMetricSeparator(),
                        _buildRideMetric("${r.avgSpeedKmh.toStringAsFixed(1)} km/h"),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRideMetric(String label) {
    return Text(
      label,
      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildMetricSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        "•",
        style: TextStyle(color: Colors.white24),
      ),
    );
  }
}
