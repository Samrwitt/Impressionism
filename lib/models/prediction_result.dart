class EraScore {
  final String era;
  final String years;
  final double score;
  final double percentage;

  EraScore({
    required this.era,
    required this.years,
    required this.score,
    required this.percentage,
  });
}

class ArtistScore {
  final String artist;
  final double score;
  final double percentage;

  ArtistScore({
    required this.artist,
    required this.score,
    required this.percentage,
  });
}

class PredictionResult {
  final String era;
  final String years;
  final double confidence;
  final List<EraScore> topEras;
  final String? artist;
  final double? artistConfidence;
  final List<ArtistScore> topArtists;
  final DateTime timestamp;

  PredictionResult({
    required this.era,
    required this.years,
    required this.confidence,
    required this.topEras,
    this.artist,
    this.artistConfidence,
    this.topArtists = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get confidencePercent =>
      double.parse((confidence * 100).toStringAsFixed(0));

  double? get artistConfidencePercent => artistConfidence == null
      ? null
      : double.parse((artistConfidence! * 100).toStringAsFixed(0));
}
