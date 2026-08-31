import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../models/prediction_result.dart';
import '../services/api_service.dart';

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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          widget.onImageSelected(file.bytes!, path: file.path);
        }
      }
    } catch (e) {
      print('File pick error: $e');
    }
  }

  Future<void> _selectSample(SampleMasterpiece sample) async {
    try {
      // Download sample image bytes
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
        // Main dropzone / uploader card
        GestureDetector(
          onTap: widget.isLoading ? null : _pickFromFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF131722).withOpacity(0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF334155),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E2638),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE6B86A).withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 38,
                    color: Color(0xFFE6B86A),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Capture or Upload Artwork',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Take a picture of a painting, sketch, or photo to detect Impressionism',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Button options
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    // Take Picture button
                    ElevatedButton.icon(
                      onPressed: widget.isLoading ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Take Picture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE6B86A),
                        foregroundColor: const Color(0xFF0D0F14),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    // Pick File button
                    OutlinedButton.icon(
                      onPressed: widget.isLoading ? null : _pickFromFile,
                      icon: const Icon(Icons.photo_library_rounded, size: 18),
                      label: const Text('Upload File'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE2E8F0),
                        side: const BorderSide(color: Color(0xFF475569)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
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

        const SizedBox(height: 24),

        // Section Title: Sample Masterpieces
        Row(
          mainAxisAlignment: MainState.spaceBetween,
          children: [
            Text(
              'Or Try Sample Masterpieces',
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '1-Click AI Test',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFE6B86A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Carousel of Masterpieces
        SizedBox(
          height: 125,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ApiService.sampleMasterpieces.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final sample = ApiService.sampleMasterpieces[index];
              return GestureDetector(
                onTap: widget.isLoading ? null : () => _selectSample(sample),
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2130),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sample.isImpressionism
                          ? const Color(0xFFE6B86A).withOpacity(0.4)
                          : const Color(0xFF334155),
                    ),
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
                                  color: const Color(0xFF242C3F),
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: Colors.white54,
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
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF475569),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    sample.isImpressionism
                                        ? 'Impressionism'
                                        : 'Non-Imp.',
                                    style: const TextStyle(
                                      color: Colors.white,
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
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${sample.artist} (${sample.year})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF94A3B8),
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
