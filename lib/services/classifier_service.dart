import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img_pkg;
import '../models/prediction_result.dart';

class _EraCnn {
  _EraCnn({
    required this.size,
    required this.eras,
    required this.years,
    required this.k1,
    required this.b1,
    required this.k2,
    required this.b2,
    required this.w3,
    required this.b3,
    required this.w4,
    required this.b4,
  });

  final int size;
  final List<String> eras;
  final List<String> years;
  final List k1;
  final List<double> b1;
  final List k2;
  final List<double> b2;
  final List<List<double>> w3;
  final List<double> b3;
  final List<List<double>> w4;
  final List<double> b4;

  factory _EraCnn.fromJson(Map<String, dynamic> json) {
    final labels = json['labels'] as List;
    return _EraCnn(
      size: json['size'] as int,
      eras: labels.map((e) => (e as Map)['era'] as String).toList(),
      years: labels.map((e) => (e as Map)['years'] as String).toList(),
      k1: json['k1'] as List,
      b1: _vec(json['b1']),
      k2: json['k2'] as List,
      b2: _vec(json['b2']),
      w3: _mat(json['w3']),
      b3: _vec(json['b3']),
      w4: _mat(json['w4']),
      b4: _vec(json['b4']),
    );
  }

  static List<double> _vec(dynamic raw) =>
      (raw as List).map((e) => (e as num).toDouble()).toList();

  static List<List<double>> _mat(dynamic raw) => (raw as List)
      .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
      .toList();

  List<double> infer(List<List<List<double>>> image) {
    final c1 = _convRelu(image, k1, b1);
    final p1 = _pool(c1);
    final c2 = _convRelu(p1, k2, b2);
    final p2 = _pool(c2);
    final flat = <double>[];
    for (final row in p2) {
      for (final px in row) {
        flat.addAll(px);
      }
    }
    final h = _denseRelu(flat, w3, b3);
    return _softmax(_dense(h, w4, b4));
  }

  static List<List<List<double>>> _convRelu(
    List<List<List<double>>> input,
    List kernel,
    List<double> bias,
  ) {
    final h = input.length;
    final w = input[0].length;
    final cin = input[0][0].length;
    final cout = bias.length;
    final out = List.generate(
      h,
      (_) => List.generate(w, (_) => List<double>.filled(cout, 0)),
    );
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        for (var oc = 0; oc < cout; oc++) {
          var s = bias[oc];
          for (var ky = 0; ky < 3; ky++) {
            final iy = y + ky - 1;
            if (iy < 0 || iy >= h) continue;
            for (var kx = 0; kx < 3; kx++) {
              final ix = x + kx - 1;
              if (ix < 0 || ix >= w) continue;
              final krow = (kernel[ky] as List)[kx] as List;
              for (var ic = 0; ic < cin; ic++) {
                s += input[iy][ix][ic] *
                    ((krow[ic] as List)[oc] as num).toDouble();
              }
            }
          }
          out[y][x][oc] = s > 0 ? s : 0;
        }
      }
    }
    return out;
  }

  static List<List<List<double>>> _pool(List<List<List<double>>> input) {
    final h = input.length ~/ 2;
    final w = input[0].length ~/ 2;
    final c = input[0][0].length;
    final out = List.generate(
      h,
      (_) => List.generate(w, (_) => List<double>.filled(c, 0)),
    );
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        for (var ic = 0; ic < c; ic++) {
          var m = input[y * 2][x * 2][ic];
          m = math.max(m, input[y * 2][x * 2 + 1][ic]);
          m = math.max(m, input[y * 2 + 1][x * 2][ic]);
          m = math.max(m, input[y * 2 + 1][x * 2 + 1][ic]);
          out[y][x][ic] = m;
        }
      }
    }
    return out;
  }

  static List<double> _denseRelu(
    List<double> x,
    List<List<double>> w,
    List<double> b,
  ) {
    final y = _dense(x, w, b);
    for (var i = 0; i < y.length; i++) {
      if (y[i] < 0) y[i] = 0;
    }
    return y;
  }

  static List<double> _dense(
    List<double> x,
    List<List<double>> w,
    List<double> b,
  ) {
    final out = List<double>.from(b);
    for (var i = 0; i < x.length; i++) {
      final row = w[i];
      final v = x[i];
      for (var j = 0; j < out.length; j++) {
        out[j] += v * row[j];
      }
    }
    return out;
  }

  static List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }
}

class ClassifierService {
  static _EraCnn? _model;
  static bool _ready = false;
  static String status = 'Loading model…';

  static bool get isReady => _ready;

  static Future<void> initialize() async {
    final raw = await rootBundle.loadString('assets/models/era_cnn.json');
    _model = _EraCnn.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
    final sized = img_pkg.copyResize(
      decoded,
      width: model.size,
      height: model.size,
      interpolation: img_pkg.Interpolation.cubic,
    );
    final pixels = List.generate(
      model.size,
      (y) => List.generate(model.size, (x) {
        final p = sized.getPixel(x, y);
        return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
      }),
    );
    final probs = model.infer(pixels);
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
}
