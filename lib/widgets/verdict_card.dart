import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/prediction_result.dart';

class VerdictCard extends StatelessWidget {
  final PredictionResult result;
  final Uint8List imageBytes;
  final VoidCallback onReset;

  const VerdictCard({
    super.key,
    required this.result,
    required this.imageBytes,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isImp = result.isImpressionism;
    final primaryColor =
        isImp ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final accentGlow =
        isImp ? const Color(0xFF34D399) : const Color(0xFF60A5FA);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryColor.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Image Preview with Overlay Verdict Ribbon
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Stack(
              children: [
                Container(
                  height: 240,
                  width: double.infinity,
                  color: Colors.black,
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => result.imageUrl != null
                        ? Image.network(
                            result.imageUrl!,
                            fit: BoxFit.cover,
                          )
                        : const Center(
                            child: Icon(Icons.art_track_rounded,
                                color: Colors.white24, size: 64),
                          ),
                  ),
                ),

                // Gradient dark overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),
                ),

                // Reset / New Scan button top right
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: onReset,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.6),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ),

                // Verdict Badge Ribbon on bottom of image preview
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.2),
                          ),
                          child: Icon(
                            isImp
                                ? Icons.verified_rounded
                                : Icons.palette_outlined,
                            color: accentGlow,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isImp
                                    ? 'IS IMPRESSIONISM'
                                    : 'NOT IMPRESSIONISM',
                                style: GoogleFonts.plusJakartaSans(
                                  color: accentGlow,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                isImp
                                    ? 'Confidence: ${result.impressionismPercentage}%'
                                    : 'Top Style: ${result.topStyle} (${result.topPercentage}%)',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Details Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Impressionism Probability Meter
                Text(
                  'Impressionism Score',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (result.impressionismScore).clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: const Color(0xFF1E2638),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              isImp ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '${result.impressionismPercentage}%',
                      style: GoogleFonts.firaCode(
                        color: isImp ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Top Art Style Breakdown Header
                Text(
                  'Art Style Classification Breakdown',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Predictions from HuggingFace model prithivMLmods/WikiArt-Style',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),

                // Style Bars
                ...result.topStyles.map((styleItem) {
                  final isCurrentImp =
                      styleItem.style.toLowerCase().contains('impressionism') &&
                          !styleItem.style.toLowerCase().contains('post');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              styleItem.style,
                              style: GoogleFonts.plusJakartaSans(
                                color: isCurrentImp
                                    ? const Color(0xFFE6B86A)
                                    : const Color(0xFFCBD5E1),
                                fontSize: 13,
                                fontWeight: isCurrentImp
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${styleItem.percentage}%',
                              style: GoogleFonts.firaCode(
                                color: const Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (styleItem.score).clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: const Color(0xFF1E2638),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCurrentImp
                                  ? const Color(0xFFE6B86A)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 20),

                // Scan Another Image Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Analyze Another Artwork'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF242C3F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF475569)),
                      ),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
