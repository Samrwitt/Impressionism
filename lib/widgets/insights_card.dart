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
        color: const Color(0xFF131722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2E384D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: Color(0xFFE6B86A),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Artistic Features & AI Insights',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
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
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFFE6B86A),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        trait,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFCBD5E1),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const Divider(color: Color(0xFF242C3F), height: 24),

          // About Impressionism Card
          Text(
            'What is Impressionism?',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Impressionism originated in 19th-century France with artists like Claude Monet, Pierre-Auguste Renoir, and Camille Pissarro. Key characteristics include open compositions, emphasis on accurate depiction of light in its changing qualities, ordinary subject matter, and small, thin, yet visible brush strokes.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
