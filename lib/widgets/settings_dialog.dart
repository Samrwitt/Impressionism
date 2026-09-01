import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/classifier_service.dart';

class SettingsDialog extends StatelessWidget {
  final VoidCallback onSaved;

  const SettingsDialog({
    super.key,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131722),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.memory_rounded,
                    color: Color(0xFFE6B86A),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'On-Device AI Engine Specs',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2638),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            color: Color(0xFF34D399), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Engine Status:',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ClassifierService.statusMessage,
                      style: GoogleFonts.firaCode(
                        color: const Color(0xFFE6B86A),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Model Specs Details
              _buildDetailRow('Model Architecture:', 'SigLIP-2 / WikiArt-Style'),
              _buildDetailRow('Inference Mode:', 'On-Device (100% Offline)'),
              _buildDetailRow('Tensor Input Size:', '224 × 224 × 3 (RGB Float32)'),
              _buildDetailRow('Loaded Art Classes:', '${ClassifierService.labelCount} Styles'),
              _buildDetailRow('Asset Model Path:', 'assets/models/wikiart_model.tflite'),
              _buildDetailRow('Asset Labels Path:', 'assets/models/labels.txt'),

              const SizedBox(height: 18),

              // Instructions Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2130),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adding Custom TFLite Weights:',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFCBD5E1),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Place your converted `wikiart_model.tflite` into the `assets/models/` directory. The application will automatically execute tensor inference offline without backend servers!',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      onSaved();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE6B86A),
                      foregroundColor: const Color(0xFF0D0F14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.firaCode(
                color: const Color(0xFFF1F5F9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
