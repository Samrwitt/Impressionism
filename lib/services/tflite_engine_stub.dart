import 'dart:typed_data';
import '../models/prediction_result.dart';

/// Stub TFLite engine for Web platforms where dart:ffi is not supported
class TfliteEngine {
  static bool get isSupported => false;
  static bool get isLoaded => false;

  static Future<bool> initialize(List<String> labels) async {
    return false;
  }

  static PredictionResult? runInference(
    Uint8List imageBytes,
    List<String> labels, {
    String? imageUrl,
    String? imagePath,
  }) {
    return null;
  }
}
