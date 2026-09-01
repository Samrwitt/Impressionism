import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HeroHeader extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHistory;
  final int historyCount;
  final bool isBackendOnline;

  const HeroHeader({
    super.key,
    required this.onOpenSettings,
    required this.onOpenHistory,
    required this.historyCount,
    required this.isBackendOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFFEFECE6),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand logo & title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFEF3C7), // Warm soft amber
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Icon(
                      Icons.palette_rounded,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Impressionist AI',
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFF1F2937),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Art Style Classification Engine',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Actions: History & Settings Buttons
              Row(
                children: [
                  // History Button
                  Stack(
                    children: [
                      IconButton(
                        onPressed: onOpenHistory,
                        tooltip: 'Scan History',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFF4F1EA),
                          foregroundColor: const Color(0xFF374151),
                        ),
                        icon: const Icon(
                          Icons.history_rounded,
                          size: 20,
                        ),
                      ),
                      if (historyCount > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD97706),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$historyCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),

                  // Settings Button
                  IconButton(
                    onPressed: onOpenSettings,
                    tooltip: 'AI Model & Settings',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF4F1EA),
                      foregroundColor: const Color(0xFF374151),
                    ),
                    icon: const Icon(
                      Icons.tune_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Google Style Pill Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Model Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F1EA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE5E0D8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.memory_rounded,
                      color: Color(0xFFD97706),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'WikiArt-Style On-Device',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF374151),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Offline Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFA7F3D0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Offline Engine Active',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF047857),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
