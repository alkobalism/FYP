import 'package:flutter/material.dart';
import 'dart:isolate';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../services/risk_service.dart';
import '../services/ride_history_service.dart';
import '../services/app_settings_service.dart';
import '../main.dart'; // for cameras list
import 'camera_overlay.dart'; 
import 'ride_details_screen.dart';
import '../utils/isolate_utils.dart';
import 'package:audioplayers/audioplayers.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? controller;
  bool isDetecting = false;
  
  // Isolate Stuff
  late IsolateUtils _isolateUtils;
  
  List<String> labels = ["pothole"];
  double currentSpeed = 0.0;
  Position? _lastPosition;
  String riskLevel = "LOW";
  List<dynamic> recognitions = [];
  
  int _imageHeight = 0;
  int _imageWidth = 0;
  int lastRunTime = 0;
  int frameCounter = 0; // Keeping frame skipper just in case
  
  final AudioPlayer audioPlayer = AudioPlayer();
  int lastBeepTime = 0;

  final int inputSize = 320; 

  // Recording variables
  bool _isRecording = false;
  List<LatLng> _sessionPath = [];
  List<PotholeHazard> _sessionPotholes = [];
  DateTime? _sessionStartTime;
  double _maxSpeed = 0.0;
  double _speedSum = 0.0;
  int _speedCount = 0;
  double _rideDistanceKm = 0.0;
  Position? _lastLoggedPosition;
  int _lastLoggedPotholeTime = 0;
  
  StreamSubscription<Position>? _positionSubscription;
  
  @override
  void initState() {
    super.initState();
    _isolateUtils = IsolateUtils();
    
    // Start AI in background once on startup
    startInferenceService();
  }

  void startInferenceService() async {
    try {
        final ByteData data = await DefaultAssetBundle.of(context).load('assets/best_int8.tflite');
        final Uint8List bytes = data.buffer.asUint8List();
        
        await _isolateUtils.start(bytes);
        print("Inference Service Started");
    } catch (e) {
        print("Failed to start inference service: $e");
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _sessionPath = [];
      _sessionPotholes = [];
      _sessionStartTime = DateTime.now();
      _maxSpeed = 0.0;
      _speedSum = 0.0;
      _speedCount = 0;
      _rideDistanceKm = 0.0;
      _lastLoggedPosition = null;
      _lastPosition = null;
      _lastLoggedPotholeTime = 0;
      currentSpeed = 0.0;
      riskLevel = "LOW";
      recognitions = [];
    });

    initCamera();
    initGeoLocation();
  }

  void _stopRecording(bool save) async {
    // Stop camera stream & dispose controller
    if (controller != null) {
      try {
        await controller!.stopImageStream();
      } catch (_) {}
      await controller!.dispose();
      controller = null;
    }
    
    // Cancel location subscription
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    if (save && _sessionStartTime != null) {
      final durationSeconds = DateTime.now().difference(_sessionStartTime!).inSeconds;
      final avgSpeed = _speedCount > 0 ? _speedSum / _speedCount : 0.0;
      
      final session = RideSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: _sessionStartTime!,
        durationSeconds: durationSeconds,
        distanceKm: _rideDistanceKm,
        avgSpeedKmh: avgSpeed,
        maxSpeedKmh: _maxSpeed,
        path: _sessionPath,
        potholes: _sessionPotholes,
      );

      await RideHistoryService.saveRide(session);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ride session saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RideDetailsScreen(session: session),
          ),
        );
      }
    }

    setState(() {
      _isRecording = false;
      recognitions = [];
      riskLevel = "LOW";
    });
  }

  void initCamera() {
    if (cameras.isEmpty) {
      print("No cameras found");
      return;
    }

    controller = CameraController(cameras[0], ResolutionPreset.medium, enableAudio: false);
    controller!.initialize().then((_) {
      if (!mounted) return;
      setState(() {});

      controller!.startImageStream((CameraImage img) {
        if (!_isRecording) return;
        if (!isDetecting) {
           isDetecting = true;
           
           // Simple Frame Skipping (1 in 2) to ensure main thread is free
           frameCounter++;
           if (frameCounter % 2 == 0) {
              runInference(img);
           } else {
              isDetecting = false;
           }
        }
      });
    });
  }

  void initGeoLocation() {
    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.otherNavigation,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (!mounted) return;
      setState(() {
        Position? lastPos = _lastPosition;
        _lastPosition = position;

        double speedMps = position.speed;

        // Fallback: Calculate speed manually if GPS reports 0.0 or negative speed
        if (speedMps <= 0.0 && lastPos != null) {
          final double distance = Geolocator.distanceBetween(
            lastPos.latitude,
            lastPos.longitude,
            position.latitude,
            position.longitude,
          );
          final double timeDiffSeconds = position.timestamp.difference(lastPos.timestamp).inMilliseconds / 1000.0;
          if (timeDiffSeconds > 0.0) {
            final double calculatedSpeedMps = distance / timeDiffSeconds;
            // Noise threshold to ignore GPS drift/jitter when stationary
            if (distance > 0.5 && calculatedSpeedMps > 0.5) {
              speedMps = calculatedSpeedMps;
            }
          }
        }

        if (speedMps < 0.0) {
          speedMps = 0.0;
        }

        currentSpeed = speedMps * 3.6;

        // Logging route path during active recording session
        if (_isRecording) {
          final currentLatLng = LatLng(position.latitude, position.longitude);
          _sessionPath.add(currentLatLng);

          // Calculate accumulated distance
          if (_lastLoggedPosition != null) {
            final double stepDistanceMeters = Geolocator.distanceBetween(
              _lastLoggedPosition!.latitude,
              _lastLoggedPosition!.longitude,
              position.latitude,
              position.longitude,
            );
            if (stepDistanceMeters > 0.5) {
              _rideDistanceKm += stepDistanceMeters / 1000.0;
            }
          }
          _lastLoggedPosition = position;

          // Track speed stats (using simulated speed if test mode active)
          final double currentSpeedStats = AppSettingsService.isTestMode ? AppSettingsService.simulatedSpeed : currentSpeed;
          if (currentSpeedStats > _maxSpeed) {
            _maxSpeed = currentSpeedStats;
          }
          _speedSum += currentSpeedStats;
          _speedCount++;
        }
      });
    }, onError: (error) {
      print("Error in location stream: $error");
    });
  }
  
  Future<void> runInference(CameraImage cameraImage) async {
    // 1. Check if isolate is ready or recording stopped
    if (_isolateUtils.sendPort == null || !_isRecording) {
        isDetecting = false;
        return;
    }

    _imageHeight = cameraImage.height;
    _imageWidth = cameraImage.width;

    // 2. Convert CameraImage to struct
    final imageStruct = CameraImageStruct(
        width: cameraImage.width,
        height: cameraImage.height,
        planes: cameraImage.planes.map((p) => p.bytes).toList(),
        strides: cameraImage.planes.map((p) => p.bytesPerRow).toList(),
        pixelStrides: cameraImage.planes.map((p) => p.bytesPerPixel!).toList(),
    );

    final responsePort = ReceivePort();
    
    // Send data + port to reply to
    _isolateUtils.sendPort?.send([
        InferenceMessage(cameraImage: imageStruct, inputSize: inputSize),
        responsePort.sendPort
    ]);
    
    // Await result
    final result = await responsePort.first;
    
    // Update UI
    if (mounted && _isRecording) {
        List<dynamic> parsed = _processOutput(result as List<List<double>>);
        setState(() {
          recognitions = parsed;
          riskLevel = "Found: ${parsed.length}";
          if (parsed.isNotEmpty) {
              double maxArea = 0.0;
              for (var res in parsed) {
                double area = res['rect']['w'] * res['rect']['h'];
                if (area > maxArea) maxArea = area;
              }
              
              double speedForCalculation = AppSettingsService.isTestMode ? AppSettingsService.simulatedSpeed : currentSpeed;
              Map<String, dynamic> riskData = RiskService.calculateRisk(maxArea, speedForCalculation);
              String rLevel = riskData['level'];
              int rPerc = riskData['percentage'];
              riskLevel = "$rPerc% Risk ($rLevel)\n${parsed.length} Potholes";

              // Log pothole hazard to session (with 2.5 seconds debounce to avoid duplicate entries)
              if (_lastPosition != null) {
                int now = DateTime.now().millisecondsSinceEpoch;
                if (now - _lastLoggedPotholeTime > 2500) {
                  _lastLoggedPotholeTime = now;
                  _sessionPotholes.add(
                    PotholeHazard(
                      lat: _lastPosition!.latitude,
                      lng: _lastPosition!.longitude,
                      riskPercentage: rPerc,
                      riskLevel: rLevel,
                    ),
                  );
                }
              }

              // Audio warning for high risk
              if (rPerc >= 75) {
                int now = DateTime.now().millisecondsSinceEpoch;
                if (now - lastBeepTime > 1000) {
                  lastBeepTime = now;
                  audioPlayer.setVolume(AppSettingsService.beepVolume);
                  audioPlayer.play(AssetSource('audio/beep.wav'));
                }
              }
          }
        });
    }
    
    isDetecting = false;
  }
  
  List<dynamic> _processOutput(List<List<double>> output) {
    List<dynamic> detections = [];
    for (int i = 0; i < 2100; i++) {
        double confidence = output[4][i];
        if (confidence > 0.40) {
            double x = output[0][i];
            double y = output[1][i];
            double w = output[2][i];
            double h = output[3][i];
            
            if (x > 1.0 || y > 1.0 || w > 1.0 || h > 1.0) {
                x /= inputSize;
                y /= inputSize;
                w /= inputSize;
                h /= inputSize;
            }
            
            detections.add({
                "rect": {
                    "x": (x - w / 2), 
                    "y": (y - h / 2),
                    "w": w,
                    "h": h
                },
                "confidenceInClass": confidence,
                "detectedClass": "pothole"
            });
        }
    }
    return _nms(detections);
  }

  // Simple NMS (Non-Max Suppression)
  List<dynamic> _nms(List<dynamic> list) {
    if (list.isEmpty) return [];
    list.sort((a, b) => b["confidenceInClass"].compareTo(a["confidenceInClass"]));
    List<dynamic> result = [];
    while (list.isNotEmpty) {
      var best = list.first;
      result.add(best);
      list.removeAt(0);
      list.removeWhere((other) {
        return _iou(best["rect"], other["rect"]) > 0.45; 
      });
    }
    return result;
  }

  double _iou(Map r1, Map r2) {
    double xA = math.max(r1["x"], r2["x"]);
    double yA = math.max(r1["y"], r2["y"]);
    double xB = math.min(r1["x"] + r1["w"], r2["x"] + r2["w"]);
    double yB = math.min(r1["y"] + r1["h"], r2["y"] + r2["h"]);

    double interArea = math.max(0, xB - xA) * math.max(0, yB - yA);
    double boxAArea = r1["w"] * r1["h"];
    double boxBArea = r2["w"] * r2["h"];

    return interArea / (boxAArea + boxBArea - interArea);
  }

  @override
  void dispose() {
    controller?.dispose();
    _positionSubscription?.cancel();
    _isolateUtils.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRecording) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: const Text("Record Scan"),
          backgroundColor: const Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Header
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Pothole Hazard Radar",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Mount your phone securely on your vehicle's handlebars. The system will track your route, calculate impact risks, and alert you in real-time.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 48),
                // Glowing Circular Start Button
                GestureDetector(
                  onTap: _startRecording,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                        )
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                        SizedBox(height: 4),
                        Text(
                          "START SCAN",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Camera Preview initialized check
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. Camera Preview
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller!.value.previewSize!.height,
                height: controller!.value.previewSize!.width,
                child: CameraPreview(controller!),
              ),
            ),
          ),

          // 2. YOLO Bounding Box Overlay
          CameraOverlay(
            recognitions: recognitions,
            previewH: _imageHeight,
            previewW: _imageWidth,
            screenH: MediaQuery.of(context).size.height,
            screenW: MediaQuery.of(context).size.width,
          ),

          // 3. Medium Risk Banner
          if (riskLevel.contains("MEDIUM"))
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Pothole Warning",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            "Medium risk level. Current speed is ${(AppSettingsService.isTestMode ? AppSettingsService.simulatedSpeed : currentSpeed).toStringAsFixed(1)} km/h.",
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Bottom Control HUD
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Stats info
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppSettingsService.isTestMode
                                ? "Speed: ${AppSettingsService.simulatedSpeed.toStringAsFixed(1)} km/h (Sim)"
                                : "Speed: ${currentSpeed.toStringAsFixed(1)} km/h",
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Risk: $riskLevel",
                            style: TextStyle(
                              color: riskLevel.contains("HIGH")
                                  ? Colors.redAccent
                                  : (riskLevel.contains("MEDIUM") ? Colors.orangeAccent : Colors.greenAccent),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Dist: ${_rideDistanceKm.toStringAsFixed(2)} km",
                            style: const TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                        ],
                      ),
                      // Stop button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                backgroundColor: const Color(0xFF1E1E1E),
                                title: const Text("Complete Commute?", style: TextStyle(color: Colors.white)),
                                content: const Text("Would you like to save this scanned commute or discard it?", style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _stopRecording(false); // Discard
                                    },
                                    child: const Text("Discard", style: TextStyle(color: Colors.redAccent)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _stopRecording(true); // Save
                                    },
                                    child: const Text("Save Ride", style: TextStyle(color: Colors.green)),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: const Icon(Icons.stop, size: 24),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
