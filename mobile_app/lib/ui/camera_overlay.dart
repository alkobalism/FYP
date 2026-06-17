import 'package:flutter/material.dart';
import 'dart:math' as math;

class CameraOverlay extends StatelessWidget {
  final List<dynamic> recognitions;
  final int previewH;
  final int previewW;
  final double screenH;
  final double screenW;

  const CameraOverlay({
    super.key, 
    required this.recognitions,
    required this.previewH,
    required this.previewW,
    required this.screenH,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ...recognitions.map((re) {
          var _x = re["rect"]["x"];
          var _w = re["rect"]["w"];
          var _y = re["rect"]["y"];
          var _h = re["rect"]["h"];
          var x, y, w, h;

          // Input is 640x640 (Square)
          // Preview is Rotated (e.g. 720x1280)
          // Screen is Portrait (e.g. 400x800)
          
          // We need to map 0..1 (from 640x640) to Screen Coordinates
          // BUT, the 0..1 really represents the Camera Preview which is cropped to fit 640x640
          // actually, YOLO 640x640 is usually Letterboxed or Stretched.
          // In our code: img.copyResize(image, width: inputSize, height: inputSize) -> STRETCHED.
          
          // Correct Aspect Ratio Mapping (Center Crop)
          // 1. Calculate the scale factor that makes the preview fill the screen
          double scale = math.max(screenW / previewW, screenH / previewH);
          
          // 2. Calculate the size of the scaled preview
          double scaledW = previewW * scale;
          double scaledH = previewH * scale;

          // 3. Calculate offset (how much is chopped off)
          double offsetX = (scaledW - screenW) / 2.0;
          double offsetY = (scaledH - screenH) / 2.0;

          // 4. Map normalized coords (0..1) to the Scaled Preview, then subtract offset
          x = (_x * scaledW) - offsetX;
          w = _w * scaledW;
          
          y = (_y * scaledH) - offsetY;
          h = _h * scaledH;

        return Positioned(
          left: math.max(0, x),
          top: math.max(0, y),
          width: w,
          height: h,
          child: Container(
              padding: const EdgeInsets.only(top: 5.0, left: 5.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.red,
                  width: 4.0, // Thicker border
                ),
                color: Colors.red.withOpacity(0.3), // Semi-transparent fill
              ),
              child: Text(
                "${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%", // Just show %
                style: const TextStyle(
                  color: Colors.white,
                  backgroundColor: Colors.red, // Background for text legibility
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
