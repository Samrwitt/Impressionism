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
        isImp ? const Color(0xFF16A34A) : const Color(0xFF2563EB);
    final accentGlow =
        isImp ? const Color(0xFF15803D) : const Color(0xFF1D4ED8);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE5E0D8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
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
                  color: const Color(0xFFF3F0E8),
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
                                color: Colors.black26, size: 64),
                          ),
                  ),
                ),

                // Gradient soft overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.65),
                        ],
                      ),
                    ),
                  ),
                ),

                // Close / Reset button top right
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: onReset,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.9),
                      foregroundColor: const Color(0xFF1F2937),
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
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
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
                            color: isImp
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFEFF6FF),
                          ),
                          child: Icon(
                            isImp
                                ? Icons.verified_rounded
                                : Icons.palette_outlined,
                            color: primaryColor,
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                isImp
                                    ? 'Confidence: ${result.impressionismPercentage}%'
                                    : 'Top Style: ${result.topStyle} (${result.topPercentage}%)',
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF4B5563),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
                    color: const Color(0xFF1F2937),
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
                          minHeight: 10,
                          backgroundColor: const Color(0xFFF3F0E8),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              isImp ? const Color(0xFF16A34A) : const Color(0xFFD97706)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      '${result.impressionismPercentage}%',
                      style: GoogleFonts.firaCode(
                        color: isImp ? const Color(0xFF15803D) : const Color(0xFFD97706),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Top Art Style Breakdown Header
                Text(
                  'Art Style Classification Breakdown',
                  style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFF1F2937),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'On-device predictions (WikiArt-Style fine-tuned model)',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF6B7280),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 14),

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
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF374151),
                                fontSize: 13,
                                fontWeight: isCurrentImp
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${styleItem.percentage}%',
                              style: GoogleFonts.firaCode(
                                color: const Color(0xFF6B7280),
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
                            backgroundColor: const Color(0xFFF3F0E8),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isCurrentImp
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF9CA3AF),
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
                      backgroundColor: const Color(0xFFFAF8F5),
                      foregroundColor: const Color(0xFF374151),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
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
