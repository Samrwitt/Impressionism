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

  static late List<List<List<List<double>>>> _eraInput;
  static List<List<List<List<double>>>>? _artistInput;
  static late List<List<double>> _eraOut;
  static late List<List<double>> _artistOut;
  static int _eraSize = 224;
  static int _artistSize = 160;

  static bool get isReady => _ready;

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
    } catch (_) {
      try {
        _eraInterpreter = await Interpreter.fromAsset(
          'models/era_model.tflite',
          options: options,
        );
      } catch (e) {
        status = 'Model failed to load';
        _ready = false;
        rethrow;
      }
    }

    final eraInterp = _eraInterpreter;
    if (eraInterp == null) {
      status = 'Model failed to load';
      _ready = false;
      return;
    }

    final eraShape = eraInterp.getInputTensor(0).shape;
    _eraSize = eraShape.length >= 3 ? eraShape[1] : 224;
    _eraInput = _allocInput(_eraSize);
    _eraOut =
        List.generate(1, (_) => List<double>.filled(_eraLabels.length, 0.0));

    final artistInterp = _artistInterpreter;
    if (artistInterp != null && _artistLabels.isNotEmpty) {
      final artistShape = artistInterp.getInputTensor(0).shape;
      _artistSize = artistShape.length >= 3 ? artistShape[1] : _eraSize;
      _artistInput = _allocInput(_artistSize);
      _artistOut = List.generate(
        1,
        (_) => List<double>.filled(_artistLabels.length, 0.0),
      );
    } else {
      _artistInput = null;
      _artistOut = List.generate(1, (_) => List<double>.filled(1, 0.0));
    }

    _ready = true;
    final artistNote =
        _artistInterpreter != null ? ' · ${_artistLabels.length} artists' : '';
    status = 'On-device · ${_eraLabels.length} eras$artistNote';
  }

  static List<List<List<List<double>>>> _allocInput(int size) {
    return List.generate(
      1,
      (_) => List.generate(
        size,
        (_) => List.generate(size, (_) => List<double>.filled(3, 0.0)),
      ),
    );
  }

  static Future<PredictionResult> predict(Uint8List imageBytes) async {
    final eraInterpreter = _eraInterpreter;
    if (!_ready || eraInterpreter == null || _eraLabels.isEmpty) {
      throw Exception(status);
    }

    final decoded = _decodeForModels(imageBytes);
    _fillBuffer(_eraInput, decoded, _eraSize);
    eraInterpreter.run(_eraInput, _eraOut);
    var eraProbs = _softmax(_eraOut[0]);

    String? artist;
    double? artistConfidence;
    var topArtists = <ArtistScore>[];

    final artistInterpreter = _artistInterpreter;
    final artistInput = _artistInput;
    if (artistInterpreter != null &&
        artistInput != null &&
        _artistLabels.isNotEmpty) {
      _fillBuffer(artistInput, decoded, _artistSize);
      artistInterpreter.run(artistInput, _artistOut);
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

    eraProbs = _calibrateImpressionism(
      eraProbs,
      artistConfidence: artistConfidence,
    );

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

  static List<double> _calibrateImpressionism(
    List<double> probs, {
    double? artistConfidence,
  }) {
    final impIdx = _eraLabels.indexWhere((e) => e.$1 == 'Impressionism');
    final postIdx =
        _eraLabels.indexWhere((e) => e.$1 == 'Post-Impressionism');
    if (impIdx < 0 || postIdx < 0) return probs;

    final out = List<double>.from(probs);
    final imp = out[impIdx];
    final post = out[postIdx];
    final artistOk = (artistConfidence ?? 0) >= 0.35;
    final close = (imp - post).abs() < 0.18;
    final bothLikely = imp + post >= 0.45;

    // When Imp and Post-Imp are close and an Impressionist artist fires, lean Imp.
    if (artistOk && bothLikely && post >= imp && (post - imp) < 0.28) {
      final boost = 0.10 + ((artistConfidence! - 0.35) * 0.22);
      out[impIdx] = (imp + boost).clamp(0.0, 0.96);
      out[postIdx] = (post - boost * 0.85).clamp(0.0, 1.0);
    } else if (!artistOk && bothLikely && close && post > imp) {
      // Mild tempering only — don't invent Impressionism without artist support.
      out[postIdx] = post * 0.92;
    }

    final sum = out.reduce((a, b) => a + b);
    if (sum <= 0) return probs;
    return out.map((e) => e / sum).toList();
  }

  static img_pkg.Image _decodeForModels(Uint8List imageBytes) {
    var decoded = img_pkg.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Could not read that image.');
    }

    final prepSide = math.max(448, math.max(_eraSize, _artistSize) * 2);
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
    return decoded;
  }

  static void _fillBuffer(
    List<List<List<List<double>>>> buffer,
    img_pkg.Image decoded,
    int size,
  ) {
    final resized = img_pkg.copyResize(
      decoded,
      width: size,
      height: size,
      interpolation: img_pkg.Interpolation.linear,
    );

    final rgb = resized.getBytes(order: img_pkg.ChannelOrder.rgb);
    final plane = buffer[0];
    for (var y = 0; y < size; y++) {
      final row = plane[y];
      final rowBase = y * size * 3;
      for (var x = 0; x < size; x++) {
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
