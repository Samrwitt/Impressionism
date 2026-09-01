import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/prediction_result.dart';
import '../services/classifier_service.dart';

class ImageSelector extends StatefulWidget {
  final Function(Uint8List bytes, {String? path, String? url}) onImageSelected;
  final bool isLoading;

  const ImageSelector({
    super.key,
    required this.onImageSelected,
    required this.isLoading,
  });

  @override
  State<ImageSelector> createState() => _ImageSelectorState();
}

class _ImageSelectorState extends State<ImageSelector> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        widget.onImageSelected(bytes, path: photo.path);
      }
    } catch (e) {
      print('Camera pick error: $e');
      _pickFromFile();
    }
  }

  Future<void> _pickFromFile() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        widget.onImageSelected(bytes, path: image.path);
      }
    } catch (e) {
      print('File pick error: $e');
    }
  }

  Future<void> _selectSample(SampleMasterpiece sample) async {
    try {
      final res = await http.get(Uri.parse(sample.imageUrl));
      if (res.statusCode == 200) {
        widget.onImageSelected(res.bodyBytes, url: sample.imageUrl);
      }
    } catch (e) {
      print('Sample download error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Google style uploader card
        GestureDetector(
          onTap: widget.isLoading ? null : _pickFromFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFEF3C7),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 36,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Analyze Artwork Style',
                  style: GoogleFonts.playfairDisplay(
                    color: const Color(0xFF1F2937),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Capture or upload a painting to test Impressionism traits',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),

                // Button options
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    // Take Picture Button
                    ElevatedButton.icon(
                      onPressed: widget.isLoading ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Take Picture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    // Pick File Button
                    OutlinedButton.icon(
                      onPressed: widget.isLoading ? null : _pickFromFile,
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Upload File'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF374151),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        backgroundColor: const Color(0xFFFAF8F5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Section Title: Sample Masterpieces
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sample Masterpieces',
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '1-Click Demo',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFD97706),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Carousel of Masterpieces
        SizedBox(
          height: 135,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ClassifierService.sampleMasterpieces.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final sample = ClassifierService.sampleMasterpieces[index];
              return GestureDetector(
                onTap: widget.isLoading ? null : () => _selectSample(sample),
                child: Container(
                  width: 155,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sample.isImpressionism
                          ? const Color(0xFFFDE68A)
                          : const Color(0xFFE5E0D8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                sample.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFF3F0E8),
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.black38,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: sample.isImpressionism
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: sample.isImpressionism
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Text(
                                    sample.isImpressionism
                                        ? 'Impressionism'
                                        : 'Non-Imp.',
                                    style: TextStyle(
                                      color: sample.isImpressionism
                                          ? const Color(0xFF047857)
                                          : const Color(0xFF4B5563),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sample.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF1F2937),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${sample.artist} (${sample.year})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF6B7280),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
