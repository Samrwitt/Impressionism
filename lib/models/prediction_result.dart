class StyleScore {
  final String style;
  final double score;
  final double percentage;

  StyleScore({
    required this.style,
    required this.score,
    required this.percentage,
  });

  factory StyleScore.fromJson(Map<String, dynamic> json) {
    return StyleScore(
      style: json['style'] ?? 'Unknown',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ??
          (((json['score'] as num?)?.toDouble() ?? 0.0) * 100),
    );
  }
}

class ArtAnalysis {
  final String verdict;
  final String description;
  final List<String> traits;

  ArtAnalysis({
    required this.verdict,
    required this.description,
    required this.traits,
  });

  factory ArtAnalysis.fromJson(Map<String, dynamic> json) {
    return ArtAnalysis(
      verdict: json['verdict'] ?? '',
      description: json['description'] ?? '',
      traits: (json['traits'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class PredictionResult {
  final bool isImpressionism;
  final double impressionismScore;
  final double impressionismPercentage;
  final double postImpressionismScore;
  final String topStyle;
  final double topScore;
  final double topPercentage;
  final List<StyleScore> topStyles;
  final ArtAnalysis analysis;
  final String? imagePath;
  final String? imageUrl;
  final DateTime timestamp;

  PredictionResult({
    required this.isImpressionism,
    required this.impressionismScore,
    required this.impressionismPercentage,
    required this.postImpressionismScore,
    required this.topStyle,
    required this.topScore,
    required this.topPercentage,
    required this.topStyles,
    required this.analysis,
    this.imagePath,
    this.imageUrl,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory PredictionResult.fromJson(Map<String, dynamic> json,
      {String? imagePath, String? imageUrl}) {
    final stylesList = (json['top_styles'] as List<dynamic>?)
            ?.map((e) => StyleScore.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return PredictionResult(
      isImpressionism: json['is_impressionism'] ?? false,
      impressionismScore:
          (json['impressionism_score'] as num?)?.toDouble() ?? 0.0,
      impressionismPercentage:
          (json['impressionism_percentage'] as num?)?.toDouble() ?? 0.0,
      postImpressionismScore:
          (json['post_impressionism_score'] as num?)?.toDouble() ?? 0.0,
      topStyle: json['top_style'] ?? 'Unknown Style',
      topScore: (json['top_score'] as num?)?.toDouble() ?? 0.0,
      topPercentage: (json['top_percentage'] as num?)?.toDouble() ?? 0.0,
      topStyles: stylesList,
      analysis: ArtAnalysis.fromJson(
          json['analysis'] as Map<String, dynamic>? ?? {}),
      imagePath: imagePath,
      imageUrl: imageUrl,
    );
  }
}

class SampleMasterpiece {
  final String title;
  final String artist;
  final String year;
  final String imageUrl;
  final bool isImpressionism;
  final String expectedStyle;

  const SampleMasterpiece({
    required this.title,
    required this.artist,
    required this.year,
    required this.imageUrl,
    required this.isImpressionism,
    required this.expectedStyle,
  });
}
