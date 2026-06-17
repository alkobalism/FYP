import 'dart:isolate';
import 'dart:ui';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';

class IsolateUtils {
  static const String DEBUG_NAME = "InferenceIsolate";

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;

  SendPort? get sendPort => _sendPort;

  Future<void> start(Uint8List modelBytes) async {
    _receivePort = ReceivePort();
    
    // We need to pass the RootIsolateToken to allow background isolate to use plugins if needed
    // (though TFLite flutter might need it for asset loading)
    RootIsolateToken? rootIsolateToken = RootIsolateToken.instance;
    
    _isolate = await Isolate.spawn<IsolateData>(
      entryPoint,
      IsolateData(
        token: rootIsolateToken,
        answerPort: _receivePort!.sendPort,
        modelBytes: modelBytes,
      ),
      debugName: DEBUG_NAME,
    );

    _sendPort = await _receivePort!.first;
  }

  void stop() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    _isolate = null;
    _sendPort = null;
  }

  static void entryPoint(IsolateData info) async {
    // 1. Register Background Isolate
    if (info.token != null) {
      BackgroundIsolateBinaryMessenger.ensureInitialized(info.token!);
    }
    
    // 2. Setup Ports
    final port = ReceivePort();
    info.answerPort.send(port.sendPort);

    // 3. Load Model (From Buffer - Safer in Isolate)
    Interpreter? interpreter;
    try {
        final options = InterpreterOptions();
        if (Platform.isAndroid) options.addDelegate(XNNPackDelegate());
        interpreter = Interpreter.fromBuffer(info.modelBytes, options: options);
        print("Background Isolate: Model Loaded from Buffer.");
    } catch (e) {
        print("Background Isolate Error: $e");
    }

    // 4. Listen for Frames
    await for (final dynamic message in port) {
      if (interpreter == null) continue;
      
      // Parse message: [InferenceMessage, SendPort]
      if (message is! List || message.length != 2) continue;
      
      final InferenceMessage info = message[0];
      final SendPort replyTo = message[1];

      try {
        // A. Image Processing (YUV -> RGB -> Resize -> Rotate)
        final width = info.cameraImage.width;
        final height = info.cameraImage.height;
        final uvRowStride = info.cameraImage.strides[1];
        final uvPixelStride = info.cameraImage.pixelStrides[1];
        final yBytes = info.cameraImage.planes[0];
        final uBytes = info.cameraImage.planes[1];
        final vBytes = info.cameraImage.planes[2];

        final image = img.Image(width: width, height: height);

        for (int w = 0; w < width; w++) {
          for (int h = 0; h < height; h++) {
            final int uvIndex =
                uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
            final int index = h * width + w;

            final int y = yBytes[index];
            final int u = uBytes[uvIndex];
            final int v = vBytes[uvIndex];

            // YUV to RGB conversion
            int r = (y + (1.370705 * (v - 128))).round().clamp(0, 255);
            int g = (y - (0.337633 * (u - 128)) - (0.698001 * (v - 128))).round().clamp(0, 255);
            int b = (y + (1.732446 * (u - 128))).round().clamp(0, 255);

            image.setPixelRgb(w, h, r, g, b);
          }
        }

        // Rotate & Resize
        var processed = img.copyRotate(image, angle: 90);
        processed = img.copyResize(processed, width: info.inputSize, height: info.inputSize);

        // Normalize
        var inputBytes = Float32List(1 * info.inputSize * info.inputSize * 3);
        var buffer = Float32List.view(inputBytes.buffer);
        int pixelIndex = 0;
        for (var y = 0; y < info.inputSize; y++) {
          for (var x = 0; x < info.inputSize; x++) {
            var pixel = processed.getPixel(x, y);
            buffer[pixelIndex++] = pixel.r / 255.0;
            buffer[pixelIndex++] = pixel.g / 255.0;
            buffer[pixelIndex++] = pixel.b / 255.0;
          } 
        }

        // B. Inference (Interpreter Run)
        var output = List<List<List<double>>>.filled(1, List.generate(5, (_) => List.filled(2100, 0.0)));
        interpreter.run(inputBytes.reshape([1, info.inputSize, info.inputSize, 3]), output);

        // C. Send Results Back
        replyTo.send(output[0]); // Send just the output list

      } catch (e) {
        print("Inference Error: $e");
      }
    }
  }
}

class IsolateData {
  final RootIsolateToken? token;
  final SendPort answerPort;
  final Uint8List modelBytes;

  IsolateData({this.token, required this.answerPort, required this.modelBytes});
}

class InferenceMessage {
  final CameraImageStruct cameraImage;
  final int inputSize;

  InferenceMessage({required this.cameraImage, required this.inputSize});
}

// Minimal Struct to pass CameraImage data across Isolates
class CameraImageStruct {
  final int width;
  final int height;
  final List<Uint8List> planes;
  final List<int> strides;
  final List<int> pixelStrides;

  CameraImageStruct({
      required this.width, 
      required this.height, 
      required this.planes,
      required this.strides, 
      required this.pixelStrides
  });
}
