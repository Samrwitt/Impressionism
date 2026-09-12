import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img_pkg;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/prediction_result.dart';

class ClassifierService {
  static Interpreter? _eraInterpreter;
  static Interpreter? _artistInterpreter;
  static Interpreter? _impPostInterpreter;
  static List<(String era, String years)> _eraLabels = [];
  static List<String> _artistLabels = [];
  static List<String> _impPostLabels = [];
  static bool _ready = false;
  static String status = 'Loading model…';

  static late List<List<List<List<double>>>> _eraInput;
  static List<List<List<List<double>>>>? _artistInput;
  static List<List<List<List<double>>>>? _impPostInput;
  static late List<List<double>> _eraOut;
  static late List<List<double>> _artistOut;
  static late List<List<double>> _impPostOut;
  static int _eraSize = 192;
  static int _artistSize = 160;
  static int _impPostSize = 224;

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

    try {
      final impPostRaw =
          await rootBundle.loadString('assets/models/imp_post_labels.txt');
      _impPostLabels = impPostRaw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      _impPostLabels = [];
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
      if (_impPostLabels.length >= 2) {
        try {
          _impPostInterpreter = await Interpreter.fromAsset(
            'assets/models/imp_post_model.tflite',
            options: InterpreterOptions()..threads = 2,
          );
        } catch (_) {
          _impPostInterpreter = null;
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
    _eraSize = eraShape.length >= 3 ? eraShape[1] : 192;
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

    final impPostInterp = _impPostInterpreter;
    if (impPostInterp != null && _impPostLabels.length >= 2) {
      final shape = impPostInterp.getInputTensor(0).shape;
      _impPostSize = shape.length >= 3 ? shape[1] : 224;
      _impPostInput = _allocInput(_impPostSize);
      _impPostOut = List.generate(1, (_) => List<double>.filled(2, 0.0));
    } else {
      _impPostInput = null;
      _impPostOut = List.generate(1, (_) => List<double>.filled(2, 0.0));
    }

    _ready = true;
    final extras = <String>[];
    if (_artistInterpreter != null) {
      extras.add('${_artistLabels.length} artists');
    }
    if (_impPostInterpreter != null) {
      extras.add('Imp/Post specialist');
    }
    final note = extras.isEmpty ? '' : ' · ${extras.join(' · ')}';
    status = 'On-device · ${_eraLabels.length} eras$note';
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

    // Monet/Renoir/Degas/Pissarro only make sense for Impressionism.
    // Still run the head early when Imp is competitive so Imp↔Post
    // calibration can use it; hide the guess unless final era is Imp.
    final impIdx = _eraLabels.indexWhere((e) => e.$1 == 'Impressionism');
    final rankedBefore = List<int>.generate(eraProbs.length, (i) => i)
      ..sort((a, b) => eraProbs[b].compareTo(eraProbs[a]));
    final impCompetitive = impIdx >= 0 &&
        (rankedBefore.first == impIdx ||
            (rankedBefore.length > 1 &&
                rankedBefore[1] == impIdx &&
                eraProbs[impIdx] >= 0.18));

    final artistInterpreter = _artistInterpreter;
    final artistInput = _artistInput;
    if (impCompetitive &&
        artistInterpreter != null &&
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

    eraProbs = _resolveImpPost(eraProbs, decoded, artistConfidence);

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

    if (topEra.era != 'Impressionism') {
      artist = null;
      artistConfidence = null;
      topArtists = [];
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

  /// When the 8-era model is torn between Impressionism and Post-Impressionism,
  /// defer to the dedicated binary specialist (plus a mild artist prior).
  static List<double> _resolveImpPost(
    List<double> probs,
    img_pkg.Image decoded,
    double? artistConfidence,
  ) {
    final impIdx = _eraLabels.indexWhere((e) => e.$1 == 'Impressionism');
    final postIdx =
        _eraLabels.indexWhere((e) => e.$1 == 'Post-Impressionism');
    if (impIdx < 0 || postIdx < 0) return probs;

    final out = List<double>.from(probs);
    final imp = out[impIdx];
    final post = out[postIdx];
    final pairMass = imp + post;
    final gap = (imp - post).abs();
    final ranked = List<double>.from(out)..sort((a, b) => b.compareTo(a));
    final topIsPair = ranked.isNotEmpty &&
        (ranked.first == imp || ranked.first == post);
    final secondIsPair = ranked.length > 1 &&
        (ranked[1] == imp || ranked[1] == post);
    final contested = topIsPair &&
        (secondIsPair || gap < 0.22) &&
        pairMass >= 0.28;

    final impPostInterp = _impPostInterpreter;
    final impPostInput = _impPostInput;
    if (contested &&
        impPostInterp != null &&
        impPostInput != null &&
        _impPostLabels.length >= 2) {
      _fillBuffer(impPostInput, decoded, _impPostSize);
      impPostInterp.run(impPostInput, _impPostOut);
      final pair = _softmax(_impPostOut[0]);
      // Blend: specialist dominates the Imp/Post slice; keep other eras.
      final other = (1.0 - pairMass).clamp(0.0, 1.0);
      final specialistImp = pair[0];
      final specialistPost = pair[1];
      var artistLean = 0.0;
      if ((artistConfidence ?? 0) >= 0.40) {
        artistLean = 0.06 + ((artistConfidence! - 0.40) * 0.12);
      }
      final blendedImp =
          (specialistImp * 0.78 + (imp / math.max(pairMass, 1e-6)) * 0.22 +
                  artistLean)
              .clamp(0.0, 1.0);
      final blendedPost =
          (specialistPost * 0.78 + (post / math.max(pairMass, 1e-6)) * 0.22 -
                  artistLean * 0.7)
              .clamp(0.0, 1.0);
      final norm = math.max(blendedImp + blendedPost, 1e-6);
      out[impIdx] = pairMass * (blendedImp / norm);
      out[postIdx] = pairMass * (blendedPost / norm);
      // Preserve relative mass of other eras.
      final otherSum = out.asMap().entries
          .where((e) => e.key != impIdx && e.key != postIdx)
          .fold<double>(0, (a, e) => a + e.value);
      if (otherSum > 0 && other > 0) {
        final scale = other / otherSum;
        for (var i = 0; i < out.length; i++) {
          if (i == impIdx || i == postIdx) continue;
          out[i] *= scale;
        }
      }
    } else if ((artistConfidence ?? 0) >= 0.45 &&
        pairMass >= 0.40 &&
        post >= imp &&
        gap < 0.20) {
      final boost = 0.08 + ((artistConfidence! - 0.45) * 0.2);
      out[impIdx] = (imp + boost).clamp(0.0, 0.95);
      out[postIdx] = (post - boost * 0.8).clamp(0.0, 1.0);
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

    final prepSide = math.max(
      448,
      math.max(_eraSize, math.max(_artistSize, _impPostSize)) * 2,
    );
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
