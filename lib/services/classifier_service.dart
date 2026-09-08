import 'dart:math' as math;
import 'dart:typed_data';

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

  /// Preallocated tensors — avoid rebuilding nested lists every prediction.
  static late List<List<List<List<double>>>> _input;
  static late List<List<double>> _eraOut;
  static late List<List<double>> _artistOut;

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

    _input = List.generate(
      1,
      (_) => List.generate(
        _size,
        (_) => List.generate(_size, (_) => List<double>.filled(3, 0.0)),
      ),
    );
    _eraOut = List.generate(1, (_) => List<double>.filled(_eraLabels.length, 0.0));
    _artistOut = List.generate(
      1,
      (_) => List<double>.filled(math.max(_artistLabels.length, 1), 0.0),
    );

    final options = InterpreterOptions()..threads = 4;

    try {
      _eraInterpreter = await Interpreter.fromAsset(
        'assets/models/era_model.tflite',
        options: options,
      );
      if (_artistLabels.isNotEmpty) {
        try {
          _artistInterpreter = await Interpreter.fromAsset(
            'assets/models/artist_model.tflite',
            options: InterpreterOptions()..threads = 2,
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
        _eraInterpreter = await Interpreter.fromAsset(
          'models/era_model.tflite',
          options: options,
        );
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

    _fillInput(imageBytes);

    eraInterpreter.run(_input, _eraOut);
    final eraProbs = _softmax(_eraOut[0]);
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

    final artistInterpreter = _artistInterpreter;
    if (artistInterpreter != null &&
        _artistLabels.isNotEmpty &&
        topEra.era == 'Impressionism') {
      artistInterpreter.run(_input, _artistOut);
      final artistProbs = _softmax(_artistOut[0]);
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

  /// Decode → cheap downscale → 160² → write into preallocated input tensor.
  static void _fillInput(Uint8List imageBytes) {
    var decoded = img_pkg.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Could not read that image.');
    }

    // Shrink huge camera photos before the final 160² resize.
    const prepSide = 320;
    final maxSide = math.max(decoded.width, decoded.height);
    if (maxSide > prepSide) {
      final scale = prepSide / maxSide;
      decoded = img_pkg.copyResize(
        decoded,
        width: math.max(1, (decoded.width * scale).round()),
        height: math.max(1, (decoded.height * scale).round()),
        interpolation: img_pkg.Interpolation.linear,
      );
    }

    final resized = img_pkg.copyResize(
      decoded,
      width: _size,
      height: _size,
      interpolation: img_pkg.Interpolation.linear,
    );

    final rgb = resized.getBytes(order: img_pkg.ChannelOrder.rgb);
    final plane = _input[0];
    for (var y = 0; y < _size; y++) {
      final row = plane[y];
      final rowBase = y * _size * 3;
      for (var x = 0; x < _size; x++) {
        final o = rowBase + x * 3;
        final px = row[x];
        px[0] = rgb[o] / 255.0;
        px[1] = rgb[o + 1] / 255.0;
        px[2] = rgb[o + 2] / 255.0;
      }
    }
  }

  static List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }
}
