import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InsightsCard extends StatelessWidget {
  final List<String> detectedTraits;

  const InsightsCard({
    super.key,
    required this.detectedTraits,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E0D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFEF3C7),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Artistic Features & AI Insights',
                style: GoogleFonts.playfairDisplay(
                  color: const Color(0xFF1F2937),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Detected traits bullet points
          ...detectedTraits.map((trait) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFFD97706),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        trait,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF374151),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const Divider(color: Color(0xFFEFECE6), height: 24),

          // About Impressionism Card
          Text(
            'What is Impressionism?',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF1F2937),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Impressionism originated in 19th-century France with artists like Claude Monet, Pierre-Auguste Renoir, and Camille Pissarro. Key characteristics include open compositions, emphasis on accurate depiction of light in its changing qualities, ordinary subject matter, and small, thin, yet visible brush strokes.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF6B7280),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
