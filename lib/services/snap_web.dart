import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _ink = Color(0xFF1C1612);
const _paper = Color(0xFFF3EEE6);
const _muted = Color(0xFF7A7066);

Future<Uint8List?> captureFromLiveCamera(BuildContext context) {
  return showDialog<Uint8List>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => const _LiveCameraDialog(),
  );
}

class _LiveCameraDialog extends StatefulWidget {
  const _LiveCameraDialog();

  @override
  State<_LiveCameraDialog> createState() => _LiveCameraDialogState();
}

class _LiveCameraDialogState extends State<_LiveCameraDialog> {
  html.MediaStream? _stream;
  html.VideoElement? _video;
  late final String _viewType;
  String? _error;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'era-cam-${identityHashCode(this)}';
    _start();
  }

  Future<void> _start() async {
    try {
      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..controls = false
        ..style.border = '0'
        ..style.objectFit = 'cover'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('playsinline', 'true');

      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int id) => video,
      );

      final devices = html.window.navigator.mediaDevices;
      if (devices == null) {
        throw Exception('Camera is not available in this browser.');
      }

      final stream = await devices.getUserMedia({
        'video': {
          'facingMode': {'ideal': 'environment'},
          'width': {'ideal': 1280},
          'height': {'ideal': 960},
        },
        'audio': false,
      });
      video.srcObject = stream;
      await video.play();

      if (!mounted) {
        _stopTracks(stream);
        return;
      }
      setState(() {
        _video = video;
        _stream = stream;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the camera. Allow access, then try again.');
    }
  }

  void _stopTracks(html.MediaStream? stream) {
    stream?.getTracks().forEach((track) => track.stop());
  }

  Future<void> _snap() async {
    final video = _video;
    if (video == null || video.videoWidth == 0) return;
    final canvas = html.CanvasElement(
      width: video.videoWidth,
      height: video.videoHeight,
    );
    canvas.context2D.drawImageScaled(
      video,
      0,
      0,
      video.videoWidth,
      video.videoHeight,
    );
    final blob = await canvas.toBlob('image/jpeg', 0.9);
    final reader = html.FileReader();
    final done = reader.onLoad.first;
    reader.readAsArrayBuffer(blob);
    await done;
    final buffer = reader.result as ByteBuffer;
    if (mounted) Navigator.of(context).pop(Uint8List.view(buffer));
  }

  @override
  void dispose() {
    _stopTracks(_stream);
    _video?.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _paper,
      insetPadding: const EdgeInsets.all(20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: const Color(0xFFC4B8A4)),
                ),
                child: _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.sourceSans3(
                              color: _muted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      )
                    : !_ready
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : HtmlElementView(viewType: _viewType),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _ready ? _snap : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  foregroundColor: _paper,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: const Text('Snap'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: _muted),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
