import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img_pkg;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/prediction_result.dart';

class ClassifierService {
  static Interpreter? _interpreter;
  static List<(String era, String years)> _labels = [];
  static bool _ready = false;
  static String status = 'Loading model…';

  static bool get isReady => _ready;
  static const _size = 160;

  static Future<void> initialize() async {
    final raw = await rootBundle.loadString('assets/models/labels.txt');
    _labels = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((line) {
          final parts = line.split('|');
          return (parts.first, parts.length > 1 ? parts[1] : '');
        })
        .toList();

    if (kIsWeb) {
      status = 'Use the Android app for the neural model';
      _ready = false;
      return;
    }

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/era_model.tflite',
      );
      _ready = true;
      status = 'On-device · ${_labels.length} eras';
    } catch (e) {
      // Fallback path used by some plugin versions.
      try {
        _interpreter = await Interpreter.fromAsset('models/era_model.tflite');
        _ready = true;
        status = 'On-device · ${_labels.length} eras';
      } catch (_) {
        status = 'Model failed to load';
        _ready = false;
        rethrow;
      }
    }
  }

  static Future<PredictionResult> predict(Uint8List imageBytes) async {
    final interpreter = _interpreter;
    if (!_ready || interpreter == null || _labels.isEmpty) {
      throw Exception(status);
    }

    final decoded = img_pkg.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Could not read that image.');
    }
    final resized = img_pkg.copyResize(
      decoded,
      width: _size,
      height: _size,
      interpolation: img_pkg.Interpolation.cubic,
    );

    final input = List.generate(
      1,
      (_) => List.generate(
        _size,
        (y) => List.generate(_size, (x) {
          final p = resized.getPixel(x, y);
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        }),
      ),
    );

    final output = List.generate(1, (_) => List.filled(_labels.length, 0.0));
    interpreter.run(input, output);

    final probs = _softmax(output[0]);
    final ranked = <EraScore>[];
    for (var i = 0; i < probs.length; i++) {
      ranked.add(
        EraScore(
          era: _labels[i].$1,
          years: _labels[i].$2,
          score: probs[i],
          percentage: double.parse((probs[i] * 100).toStringAsFixed(0)),
        ),
      );
    }
    ranked.sort((a, b) => b.score.compareTo(a.score));
    final top = ranked.first;
    return PredictionResult(
      era: top.era,
      years: top.years,
      confidence: top.score,
      topEras: ranked.take(3).toList(),
    );
  }

  static List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }
}
