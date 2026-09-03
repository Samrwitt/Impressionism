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

class PredictionResult {
  final String era;
  final String years;
  final double confidence;
  final List<EraScore> topEras;
  final DateTime timestamp;

  PredictionResult({
    required this.era,
    required this.years,
    required this.confidence,
    required this.topEras,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  double get confidencePercent =>
      double.parse((confidence * 100).toStringAsFixed(0));
}
