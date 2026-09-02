import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img_pkg;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/prediction_result.dart';

/// Native TFLite engine for Android/iOS/Linux/macOS/Windows (uses dart:ffi)
class TfliteEngine {
  static Interpreter? _interpreter;
  static bool _isLoaded = false;

  static bool get isSupported => true;
  static bool get isLoaded => _isLoaded;

  static Future<bool> initialize(List<String> labels) async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/wikiart_model.tflite');
      _isLoaded = true;
      print('Native TFLite model loaded successfully!');
      return true;
    } catch (e) {
      _isLoaded = false;
      print('Native TFLite model load deferred: $e');
      return false;
    }
  }

  static PredictionResult? runInference(
    Uint8List imageBytes,
    List<String> labels, {
    String? imageUrl,
    String? imagePath,
  }) {
    if (!_isLoaded || _interpreter == null) return null;

    try {
      final decodedImg = img_pkg.decodeImage(imageBytes);
      if (decodedImg == null) return null;

      final resizedImg = img_pkg.copyResize(decodedImg, width: 224, height: 224);

      var input = List.generate(
        1,
        (b) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) {
              final pixel = resizedImg.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      final outputLen = labels.isNotEmpty ? labels.length : 20;
      var output = List.generate(1, (b) => List.filled(outputLen, 0.0));

      _interpreter!.run(input, output);

      final logits = output[0];
      final probs = _softmax(logits);

      List<StyleScore> styleScores = [];
      double impScore = 0.0;
      double postImpScore = 0.0;

      for (int i = 0; i < probs.length; i++) {
        final label = i < labels.length ? labels[i] : 'Style #$i';
        final prob = probs[i];
        final pct = double.parse((prob * 100).toStringAsFixed(2));

        styleScores.add(StyleScore(style: label, score: prob, percentage: pct));

        if (label.toLowerCase().contains('impressionism') &&
            !label.toLowerCase().contains('post')) {
          impScore = prob;
        } else if (label.toLowerCase().contains('post-impressionism')) {
          postImpScore = prob;
        }
      }

      styleScores.sort((a, b) => b.score.compareTo(a.score));

      final topStyle =
          styleScores.isNotEmpty ? styleScores.first.style : 'Impressionism';
      final topScore = styleScores.isNotEmpty ? styleScores.first.score : 0.0;

      final isImp = (topStyle.toLowerCase().contains('impressionism') &&
              !topStyle.toLowerCase().contains('post')) ||
          (impScore >= 0.25);

      return PredictionResult(
        isImpressionism: isImp,
        impressionismScore: impScore,
        impressionismPercentage:
            double.parse((impScore * 100).toStringAsFixed(1)),
        postImpressionismScore: postImpScore,
        topStyle: topStyle,
        topScore: topScore,
        topPercentage: double.parse((topScore * 100).toStringAsFixed(1)),
        topStyles: styleScores.take(5).toList(),
        analysis: ArtAnalysis(
          verdict: isImp
              ? 'Authentic Impressionism'
              : 'Non-Impressionist Style ($topStyle)',
          description:
              'Classified on-device via TFLite neural model. Identified primary artistic style as $topStyle with ${double.parse((topScore * 100).toStringAsFixed(1))}% confidence.',
          traits: isImp
              ? [
                  'Vibrant natural light play',
                  'Textured, open brushwork',
                  'En-plein-air outdoor color harmony'
                ]
              : [
                  'Style matched: $topStyle',
                  'Lacks signature Impressionist light diffusion'
                ],
        ),
        imagePath: imagePath,
        imageUrl: imageUrl,
      );
    } catch (e) {
      print('Error during native TFLite inference: $e');
      return null;
    }
  }

  static List<double> _softmax(List<double> logits) {
    double maxLogit = logits.reduce(math.max);
    List<double> exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    double sumExps = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sumExps).toList();
  }
}
