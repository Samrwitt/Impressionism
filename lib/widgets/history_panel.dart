import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/prediction_result.dart';

class HistoryPanel extends StatelessWidget {
  final List<Map<String, dynamic>> historyItems;
  final Function(Map<String, dynamic>) onItemSelect;
  final VoidCallback onClearHistory;

  const HistoryPanel({
    super.key,
    required this.historyItems,
    required this.onItemSelect,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        color: Color(0xFF0284C7),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Scan History',
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFF0F172A),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (historyItems.isNotEmpty)
                    TextButton(
                      onPressed: onClearHistory,
                      child: Text(
                        'Clear',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE2E8F0), height: 1),

            // History Items List
            Expanded(
              child: historyItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.photo_album_outlined,
                            color: Color(0xFF94A3B8),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No scan history yet',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF475569),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scanned artwork will appear here',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: historyItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = historyItems[index];
                        final result = item['result'] as PredictionResult;
                        final bytes = item['bytes'] as Uint8List?;

                        return GestureDetector(
                          onTap: () => onItemSelect(item),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: result.isImpressionism
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: bytes != null
                                        ? Image.memory(bytes, fit: BoxFit.cover)
                                        : result.imageUrl != null
                                            ? Image.network(result.imageUrl!,
                                                fit: BoxFit.cover)
                                            : Container(
                                                color: const Color(0xFFF1F5F9),
                                                child: const Icon(
                                                    Icons.image,
                                                    color: Colors.black38),
                                              ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        result.isImpressionism
                                            ? 'Impressionism (${result.impressionismPercentage}%)'
                                            : result.topStyle,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF0F172A),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        result.isImpressionism
                                            ? 'Impressionist Masterpiece'
                                            : 'Score: ${result.topPercentage}%',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: result.isImpressionism
                                              ? const Color(0xFF047857)
                                              : const Color(0xFF64748B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  result.isImpressionism
                                      ? Icons.check_circle_rounded
                                      : Icons.chevron_right_rounded,
                                  color: result.isImpressionism
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
