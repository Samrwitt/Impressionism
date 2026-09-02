import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HeroHeader extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHistory;
  final int historyCount;

  const HeroHeader({
    super.key,
    required this.onOpenSettings,
    required this.onOpenHistory,
    required this.historyCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Main Title: "Is It Impressionism?"
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE0F2FE),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: const Icon(
                  Icons.palette_rounded,
                  color: Color(0xFF0284C7),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Is It Impressionism?',
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'On-Device Art Classifier',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right Header Actions (History & Specs)
          Row(
            children: [
              if (historyCount > 0)
                IconButton(
                  onPressed: onOpenHistory,
                  tooltip: 'History',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF334155),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 20),
                ),
              IconButton(
                onPressed: onOpenSettings,
                tooltip: 'Engine Specs',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF334155),
                ),
                icon: const Icon(Icons.info_outline_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
