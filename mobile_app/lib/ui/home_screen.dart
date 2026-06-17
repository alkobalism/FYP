import 'package:flutter/material.dart';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../services/risk_service.dart';
import '../main.dart'; // for cameras list
import 'camera_overlay.dart'; 
import '../utils/isolate_utils.dart'; // IMPORT NEW UTILS
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
  bool isTestMode = false;
  double simulatedSpeed = 25.0;
  String riskLevel = "LOW";
  List<dynamic> recognitions = [];
  
  int _imageHeight = 0;
  int _imageWidth = 0;
  int lastRunTime = 0;
  int frameCounter = 0; // Keeping frame skipper just in case
  
  final AudioPlayer audioPlayer = AudioPlayer();
  int lastBeepTime = 0;

  final int inputSize = 320; 
  
  @override
  void initState() {
    super.initState();
    _isolateUtils = IsolateUtils();
    
    // Start Camera IMMEDIATELY (Don't wait for AI)
    initCamera();
    initGeoLocation();
    
    // Start AI in background
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

    Geolocator.getPositionStream(
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
      });
    }, onError: (error) {
      print("Error in location stream: $error");
    });
  }
  
  Future<void> runInference(CameraImage cameraImage) async {
    // 1. Check if isolate is ready
    if (_isolateUtils.sendPort == null) {
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

    // 3. Send to Isolate (Fire and Forget? No, we need result)
    // We need a specific port for THIS result, or a shared stream.
    // For simplicity, let's assume IsolateUtils sends results to a global listener.
    // WAIT: My IsolateUtils implementation is incomplete for receiving results.
    // I will use a request-response pattern here using a temporary ReceivePort.
    
    final responsePort = ReceivePort();
    
    // Send data + port to reply to
    _isolateUtils.sendPort?.send([
        InferenceMessage(cameraImage: imageStruct, inputSize: inputSize),
        responsePort.sendPort
    ]);
    
    // Await result (non-blocking for UI, but blocks this async function)
    final result = await responsePort.first;
    
    // 4. Update UI
    if (mounted) {
        List<dynamic> parsed = _processOutput(result as List<List<double>>);
        setState(() {
          recognitions = parsed;
          riskLevel = "Found: ${parsed.length}";
          if (parsed.isNotEmpty) {
               // ... risk logic ...
              double maxArea = 0.0;
              for (var res in parsed) {
                double area = res['rect']['w'] * res['rect']['h'];
                if (area > maxArea) maxArea = area;
              }
              double speedForCalculation = isTestMode ? simulatedSpeed : currentSpeed;
              Map<String, dynamic> riskData = RiskService.calculateRisk(maxArea, speedForCalculation);
              String rLevel = riskData['level'];
              int rPerc = riskData['percentage'];
              riskLevel = "$rPerc% Risk ($rLevel)\n${parsed.length} Potholes";

              // Audio warning for high risk (debounce to 1 beep per second)
              if (rPerc >= 75) {
                int now = DateTime.now().millisecondsSinceEpoch;
                if (now - lastBeepTime > 1000) {
                  lastBeepTime = now;
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
    _isolateUtils.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return Container();
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Pothole Detector")),
      body: Stack(
        children: [
          // 1. Camera Preview (Full Screen, Cropped)
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
          
          CameraOverlay(
              recognitions: recognitions,
              previewH: _imageHeight,
              previewW: _imageWidth,
              screenH: MediaQuery.of(context).size.height,
              screenW: MediaQuery.of(context).size.width,
          ),

          // Medium Risk Notification Banner
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
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
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
                            "Medium risk level. Current speed is ${(isTestMode ? simulatedSpeed : currentSpeed).toStringAsFixed(1)} km/h.",
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Risk Overlay (Glassmorphism card)
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row 1: Speed and Risk Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isTestMode
                                      ? "Speed: ${simulatedSpeed.toStringAsFixed(1)} km/h (Simulated)"
                                      : "Speed: ${currentSpeed.toStringAsFixed(1)} km/h",
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Risk: $riskLevel",
                                  style: TextStyle(
                                    color: riskLevel.contains("HIGH")
                                        ? Colors.redAccent
                                        : (riskLevel.contains("MEDIUM") ? Colors.orangeAccent : Colors.greenAccent),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: Colors.white12, height: 1),
                      ),
                      // Row 2: Test Mode Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.science_outlined, color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Simulate Test Speed",
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 28,
                            child: Switch(
                              value: isTestMode,
                              onChanged: (val) {
                                setState(() {
                                  isTestMode = val;
                                });
                              },
                              activeColor: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      if (isTestMode) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              "${simulatedSpeed.toStringAsFixed(0)} km/h",
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: Slider(
                                value: simulatedSpeed,
                                min: 10.0,
                                max: 40.0,
                                divisions: 6,
                                label: "${simulatedSpeed.toStringAsFixed(0)} km/h",
                                activeColor: Colors.redAccent,
                                inactiveColor: Colors.white24,
                                onChanged: (val) {
                                  setState(() {
                                    simulatedSpeed = val;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                audioPlayer.play(AssetSource('audio/beep.wav'));
                              },
                              icon: const Icon(Icons.volume_up_outlined, size: 16),
                              label: const Text("Test Warning Beep", style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
