import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/prediction_result.dart';

/// Talks to the heavy Art Era backend (WikiArt style model + CLIP artists).
class ClassifierService {
  static bool _ready = false;
  static String status = 'Connecting…';

  static bool get isReady => _ready;

  static Uri get _healthUri => Uri.parse('${AppConfig.apiBase}/api/health');
  static Uri get _classifyUri => Uri.parse('${AppConfig.apiBase}/api/classify');

  static Future<void> initialize() async {
    try {
      final res = await http
          .get(_healthUri)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw Exception('Backend HTTP ${res.statusCode}');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = body['status'] == 'online';
      _ready = ok;
      status = ok
          ? 'Server · ${body['device'] ?? 'cpu'}'
          : 'Backend degraded — models not loaded';
      if (!ok) {
        throw Exception(status);
      }
    } catch (e) {
      _ready = false;
      status =
          'Cannot reach ${AppConfig.apiBase} — start the backend and check Wi‑Fi';
      rethrow;
    }
  }

  static Future<PredictionResult> predict(Uint8List imageBytes) async {
    if (!_ready) {
      // One more health attempt in case the server started after boot.
      await initialize();
    }

    final req = http.MultipartRequest('POST', _classifyUri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'painting.jpg',
        ),
      );

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) {
      throw Exception('Classify failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final topEras = ((data['top_eras'] as List?) ?? const [])
        .map((e) {
          final m = e as Map<String, dynamic>;
          final score = (m['score'] as num?)?.toDouble() ?? 0;
          return EraScore(
            era: (m['era'] ?? '').toString(),
            years: (m['years'] ?? '').toString(),
            score: score,
            percentage: (m['percentage'] as num?)?.toDouble() ??
                double.parse((score * 100).toStringAsFixed(0)),
          );
        })
        .toList();

    final topArtists = ((data['top_artists'] as List?) ?? const [])
        .map((e) {
          final m = e as Map<String, dynamic>;
          final score = (m['score'] as num?)?.toDouble() ?? 0;
          return ArtistScore(
            artist: (m['artist'] ?? '').toString(),
            score: score,
            percentage: (m['percentage'] as num?)?.toDouble() ??
                double.parse((score * 100).toStringAsFixed(0)),
          );
        })
        .toList();

    return PredictionResult(
      era: (data['era'] ?? topEras.first.era).toString(),
      years: (data['years'] ?? '').toString(),
      confidence: (data['confidence'] as num?)?.toDouble() ??
          (topEras.isNotEmpty ? topEras.first.score : 0),
      topEras: topEras,
      artist: data['artist']?.toString(),
      artistConfidence: (data['artist_confidence'] as num?)?.toDouble(),
      topArtists: topArtists,
    );
  }
}
