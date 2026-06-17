# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# GPU Delegate
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.gpu.GpuDelegate** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# Flutter TFLite Plugin
-keep class com.tflite_flutter.** { *; }
