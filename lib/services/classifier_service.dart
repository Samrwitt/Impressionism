import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img_pkg;
import '../models/prediction_result.dart';

class _EraMlp {
  _EraMlp(this.eras, this.years, this.mean, this.scale, this.w1, this.b1, this.w2, this.b2);

  final List<String> eras;
  final List<String> years;
  final List<double> mean;
  final List<double> scale;
  final List<List<double>> w1;
  final List<double> b1;
  final List<List<double>> w2;
  final List<double> b2;

  factory _EraMlp.fromJson(Map<String, dynamic> json) {
    final labels = json['labels'] as List;
    return _EraMlp(
      labels.map((e) => (e as Map)['era'] as String).toList(),
      labels.map((e) => (e as Map)['years'] as String).toList(),
      (json['mean'] as List).map((e) => (e as num).toDouble()).toList(),
      (json['scale'] as List).map((e) => (e as num).toDouble()).toList(),
      (json['w1'] as List)
          .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
          .toList(),
      (json['b1'] as List).map((e) => (e as num).toDouble()).toList(),
      (json['w2'] as List)
          .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
          .toList(),
      (json['b2'] as List).map((e) => (e as num).toDouble()).toList(),
    );
  }

  List<double> infer(List<double> features) {
    final n = features.length;
    final x = List<double>.generate(
      n,
      (i) => (features[i] - mean[i]) / (scale[i] == 0 ? 1 : scale[i]),
    );
    final hidden = List<double>.filled(b1.length, 0);
    for (var j = 0; j < b1.length; j++) {
      var s = b1[j];
      for (var i = 0; i < n; i++) {
        s += x[i] * w1[i][j];
      }
      hidden[j] = s > 0 ? s : 0;
    }
    final logits = List<double>.filled(b2.length, 0);
    for (var k = 0; k < b2.length; k++) {
      var s = b2[k];
      for (var j = 0; j < hidden.length; j++) {
        s += hidden[j] * w2[j][k];
      }
      logits[k] = s;
    }
    return _softmax(logits);
  }

  static List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }
}

class ClassifierService {
  static _EraMlp? _model;
  static bool _ready = false;
  static String status = 'Loading model…';

  static bool get isReady => _ready;

  static const _size = 160;
  static const _bins = 8;

  static Future<void> initialize() async {
    final raw = await rootBundle.loadString('assets/models/era_mlp.json');
    _model = _EraMlp.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _ready = true;
    status = 'On-device · ${_model!.eras.length} eras';
  }

  static Future<PredictionResult> predict(Uint8List imageBytes) async {
    final model = _model;
    if (model == null || !_ready) {
      throw Exception('Model is not ready.');
    }
    final decoded = img_pkg.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Could not read that image.');
    }
    final resized = img_pkg.copyResize(
      decoded,
      width: _size,
      height: _size,
      interpolation: img_pkg.Interpolation.linear,
    );
    final features = _extractFeatures(resized);
    final probs = model.infer(features);
    final ranked = <EraScore>[];
    for (var i = 0; i < probs.length; i++) {
      ranked.add(
        EraScore(
          era: model.eras[i],
          years: model.years[i],
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

  static List<double> _histogram(List<double> channel) {
    final hist = List<double>.filled(_bins, 0);
    final width = 256.0 / _bins;
    for (final v in channel) {
      var bin = (v / width).floor();
      if (bin >= _bins) bin = _bins - 1;
      if (bin < 0) bin = 0;
      hist[bin] += 1;
    }
    final density = channel.isEmpty ? 1.0 : channel.length.toDouble();
    // Match numpy density=True: hist / (n * bin_width)
    for (var i = 0; i < _bins; i++) {
      hist[i] = hist[i] / (density * width);
    }
    return hist;
  }

  static List<double> _extractFeatures(img_pkg.Image image) {
    final n = image.width * image.height;
    final r = List<double>.filled(n, 0);
    final g = List<double>.filled(n, 0);
    final b = List<double>.filled(n, 0);
    final lum = List<double>.filled(n, 0);
    var i = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        r[i] = p.r.toDouble();
        g[i] = p.g.toDouble();
        b[i] = p.b.toDouble();
        lum[i] = 0.299 * r[i] + 0.587 * g[i] + 0.114 * b[i];
        i++;
      }
    }
    var satSum = 0.0;
    var satSq = 0.0;
    var warmSum = 0.0;
    for (var k = 0; k < n; k++) {
      final mx = math.max(r[k], math.max(g[k], b[k]));
      final mn = math.min(r[k], math.min(g[k], b[k]));
      final sat = mx > 1e-6 ? (mx - mn) / mx : 0.0;
      satSum += sat;
      satSq += sat * sat;
      warmSum += math.max(0.0, r[k] - b[k]);
    }
    final satMean = satSum / n;
    final satStd = math.sqrt(math.max(0, satSq / n - satMean * satMean));
    final lumMean = lum.reduce((a, b) => a + b) / n;
    var lumSq = 0.0;
    for (final v in lum) {
      lumSq += v * v;
    }
    final lumStd = math.sqrt(math.max(0, lumSq / n - lumMean * lumMean));

    var gx = 0.0;
    var gy = 0.0;
    var gxCount = 0;
    var gyCount = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width - 1; x++) {
        gx += (lum[y * image.width + x + 1] - lum[y * image.width + x]).abs();
        gxCount++;
      }
    }
    for (var y = 0; y < image.height - 1; y++) {
      for (var x = 0; x < image.width; x++) {
        gy += (lum[(y + 1) * image.width + x] - lum[y * image.width + x]).abs();
        gyCount++;
      }
    }

    final rMean = r.reduce((a, b) => a + b) / n;
    final gMean = g.reduce((a, b) => a + b) / n;
    final bMean = b.reduce((a, b) => a + b) / n;

    return [
      ..._histogram(r),
      ..._histogram(g),
      ..._histogram(b),
      ..._histogram(lum),
      lumMean / 255.0,
      lumStd / 255.0,
      satMean,
      satStd,
      gx / gxCount / 255.0,
      gy / gyCount / 255.0,
      warmSum / n / 255.0,
      (rMean - gMean) / 255.0,
      (gMean - bMean) / 255.0,
    ];
  }
}
