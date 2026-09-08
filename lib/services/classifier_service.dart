import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img_pkg;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/prediction_result.dart';

class ClassifierService {
  static Interpreter? _eraInterpreter;
  static Interpreter? _artistInterpreter;
  static List<(String era, String years)> _eraLabels = [];
  static List<String> _artistLabels = [];
  static bool _ready = false;
  static String status = 'Loading model…';

  static bool get isReady => _ready;
  static const _size = 160;

  static Future<void> initialize() async {
    final eraRaw = await rootBundle.loadString('assets/models/labels.txt');
    _eraLabels = eraRaw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((line) {
          final parts = line.split('|');
          return (parts.first, parts.length > 1 ? parts[1] : '');
        })
        .toList();

    try {
      final artistRaw =
          await rootBundle.loadString('assets/models/artist_labels.txt');
      _artistLabels = artistRaw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      _artistLabels = [];
    }

    if (kIsWeb) {
      status = 'Use the Android app for the neural model';
      _ready = false;
      return;
    }

    try {
      _eraInterpreter = await Interpreter.fromAsset(
        'assets/models/era_model.tflite',
      );
      if (_artistLabels.isNotEmpty) {
        try {
          _artistInterpreter = await Interpreter.fromAsset(
            'assets/models/artist_model.tflite',
          );
        } catch (_) {
          _artistInterpreter = null;
        }
      }
      _ready = true;
      final artistNote =
          _artistInterpreter != null ? ' · ${_artistLabels.length} artists' : '';
      status = 'On-device · ${_eraLabels.length} eras$artistNote';
    } catch (e) {
      try {
        _eraInterpreter = await Interpreter.fromAsset('models/era_model.tflite');
        _ready = true;
        status = 'On-device · ${_eraLabels.length} eras';
      } catch (_) {
        status = 'Model failed to load';
        _ready = false;
        rethrow;
      }
    }
  }

  static Future<PredictionResult> predict(Uint8List imageBytes) async {
    final eraInterpreter = _eraInterpreter;
    if (!_ready || eraInterpreter == null || _eraLabels.isEmpty) {
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

    final eraOut = List.generate(1, (_) => List.filled(_eraLabels.length, 0.0));
    eraInterpreter.run(input, eraOut);
    final eraProbs = _softmax(eraOut[0]);
    final rankedEras = <EraScore>[];
    for (var i = 0; i < eraProbs.length; i++) {
      rankedEras.add(
        EraScore(
          era: _eraLabels[i].$1,
          years: _eraLabels[i].$2,
          score: eraProbs[i],
          percentage: double.parse((eraProbs[i] * 100).toStringAsFixed(0)),
        ),
      );
    }
    rankedEras.sort((a, b) => b.score.compareTo(a.score));
    final topEra = rankedEras.first;

    String? artist;
    double? artistConfidence;
    var topArtists = <ArtistScore>[];

    // Artist guess among Monet / Renoir / Degas / Pissarro when Impressionism.
    final artistInterpreter = _artistInterpreter;
    if (artistInterpreter != null &&
        _artistLabels.isNotEmpty &&
        topEra.era == 'Impressionism') {
      final artistOut =
          List.generate(1, (_) => List.filled(_artistLabels.length, 0.0));
      artistInterpreter.run(input, artistOut);
      final artistProbs = _softmax(artistOut[0]);
      for (var i = 0; i < artistProbs.length; i++) {
        topArtists.add(
          ArtistScore(
            artist: _artistLabels[i],
            score: artistProbs[i],
            percentage:
                double.parse((artistProbs[i] * 100).toStringAsFixed(0)),
          ),
        );
      }
      topArtists.sort((a, b) => b.score.compareTo(a.score));
      artist = topArtists.first.artist;
      artistConfidence = topArtists.first.score;
      topArtists = topArtists.take(3).toList();
    }

    return PredictionResult(
      era: topEra.era,
      years: topEra.years,
      confidence: topEra.score,
      topEras: rankedEras.take(3).toList(),
      artist: artist,
      artistConfidence: artistConfidence,
      topArtists: topArtists,
    );
  }

  static List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }
}
