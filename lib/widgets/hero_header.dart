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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF131722),
            Color(0xFF1A2133),
            Color(0xFF0F121C),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainState.spaceBetween,
            children: [
              // Brand logo & title
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE6B86A), Color(0xFFFF9E80)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE6B86A).withOpacity(0.4),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.palette_rounded,
                      color: Color(0xFF0D0F14),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Impressionist AI',
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Art Style Classification Engine',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Actions: History & Settings
              Row(
                children: [
                  // History button with count badge
                  Stack(
                    children: [
                      IconButton(
                        onPressed: onOpenHistory,
                        tooltip: 'Scan History',
                        icon: const Icon(
                          Icons.history_toggle_off_rounded,
                          color: Color(0xFFCBD5E1),
                          size: 24,
                        ),
                      ),
                      if (historyCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6B86A),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$historyCount',
                              style: const TextStyle(
                                color: Color(0xFF0D0F14),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 4),

                  // Settings button
                  IconButton(
                    onPressed: onOpenSettings,
                    tooltip: 'AI Model & Server Settings',
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: Color(0xFFCBD5E1),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 0, height: 16),

          // Model Badge & Server Status bar
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Model Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF242C3F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE6B86A).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFE6B86A),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'prithivMLmods/WikiArt-Style',
                      style: GoogleFonts.firaCode(
                        color: const Color(0xFFF1F5F9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Server Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isBackendOnline
                      ? const Color(0xFF064E3B).withOpacity(0.5)
                      : const Color(0xFF78350F).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isBackendOnline
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isBackendOnline
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFBBF24),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBackendOnline ? 'Backend Online' : 'Hybrid Model Mode',
                      style: GoogleFonts.plusJakartaSans(
                        color: isBackendOnline
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFDE68A),
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
