import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'models/prediction_result.dart';
import 'services/classifier_service.dart';
import 'services/image_polish.dart';
import 'services/snap.dart';

const _ink = Color(0xFF1C1612);
const _muted = Color(0xFF7A7066);
const _paper = Color(0xFFF3EEE6);
const _card = Color(0xFFFBF8F2);
const _line = Color(0xFFD8D0C4);
const _accent = Color(0xFF6E2F2A);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EraApp());
}

class EraApp extends StatelessWidget {
  const EraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final display = GoogleFonts.frauncesTextTheme(ThemeData.light().textTheme);
    final body = GoogleFonts.sourceSans3TextTheme(ThemeData.light().textTheme);

    return MaterialApp(
      title: 'Art Era',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: const ColorScheme.light(
          primary: _accent,
          onPrimary: Colors.white,
          surface: _card,
          onSurface: _ink,
        ),
        textTheme: body.copyWith(
          displayLarge: display.displayLarge?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w500,
            height: 1.05,
          ),
          headlineMedium: display.headlineMedium?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
        ),
      ),
      home: const EraHome(),
    );
  }
}

class EraHome extends StatefulWidget {
  const EraHome({super.key});

  @override
  State<EraHome> createState() => _EraHomeState();
}

class _EraHomeState extends State<EraHome> {
  final _picker = ImagePicker();
  bool _booting = true;
  bool _busy = false;
  Uint8List? _image;
  PredictionResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await ClassifierService.initialize();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _booting = false);
  }

  Future<void> _useBytes(Uint8List bytes) async {
    setState(() {
      _busy = true;
      _image = bytes;
      _result = null;
      _error = null;
    });
    try {
      final result = await ClassifierService.predict(bytes);
      final shown = polishForDisplay(bytes);
      if (!mounted) return;
      setState(() {
        _image = shown;
        _result = result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) return;
      await _useBytes(await file.readAsBytes());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _snap() async {
    try {
      if (kIsWeb) {
        final live = await captureFromLiveCamera(context);
        if (live != null) await _useBytes(live);
        return;
      }
      await _pick(ImageSource.camera);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _reset() {
    setState(() {
      _image = null;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ART ERA',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 12,
                      letterSpacing: 4.2,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _booting
                        ? 'Preparing…'
                        : (_error == null
                            ? 'On this device'
                            : 'Could not load the model'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sourceSans3(
                      fontSize: 13,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: _booting
                          ? const _QuietLoader(key: ValueKey('boot'))
                          : _busy
                              ? const _QuietLoader(
                                  key: ValueKey('busy'),
                                  label: 'Looking…',
                                )
                              : _result != null && _image != null
                                  ? _ResultView(
                                      key: const ValueKey('result'),
                                      image: _image!,
                                      result: _result!,
                                      onReset: _reset,
                                    )
                                  : _EmptyView(
                                      key: const ValueKey('empty'),
                                      error: _error,
                                      ready: ClassifierService.isReady,
                                      onChoose: () =>
                                          _pick(ImageSource.gallery),
                                      onCamera: _snap,
                                    ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietLoader extends StatelessWidget {
  const _QuietLoader({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: _ink,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 16),
            Text(
              label!,
              style: GoogleFonts.sourceSans3(color: _muted, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    super.key,
    required this.ready,
    required this.onChoose,
    required this.onCamera,
    this.error,
  });

  final bool ready;
  final VoidCallback onChoose;
  final VoidCallback onCamera;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Material(
            color: _card,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: const BorderSide(color: _line, width: 1),
            ),
            child: InkWell(
              onTap: ready ? onCamera : null,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: _line.withValues(alpha: 0.9)),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'What era is this?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fraunces(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              color: _ink,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Snap a painting, or upload one.\nNothing leaves this device.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.sourceSans3(
                              fontSize: 15,
                              height: 1.45,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceSans3(
              color: _accent,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: ready ? onCamera : null,
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            label: const Text('Snap a photo'),
            style: FilledButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: _paper,
              disabledBackgroundColor: _line,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
              textStyle: GoogleFonts.sourceSans3(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: ready ? onChoose : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              side: const BorderSide(color: _line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
              textStyle: GoogleFonts.sourceSans3(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            child: const Text('Upload a photo'),
          ),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    super.key,
    required this.image,
    required this.result,
    required this.onReset,
  });

  final Uint8List image;
  final PredictionResult result;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _PaintingFrame(image: image),
              ),
              const SizedBox(height: 28),
              Text(
                'ERA',
                style: GoogleFonts.sourceSans3(
                  fontSize: 11,
                  letterSpacing: 3.6,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.era,
                textAlign: TextAlign.center,
                style: GoogleFonts.fraunces(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: _ink,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.years,
                style: GoogleFonts.sourceSans3(
                  fontSize: 15,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: result.confidence.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: _line,
                    color: _ink,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${result.confidencePercent}%',
                style: GoogleFonts.sourceSans3(
                  fontSize: 12,
                  letterSpacing: 0.8,
                  color: _muted,
                ),
              ),
              if (result.topEras.length > 1) ...[
                const SizedBox(height: 18),
                Text(
                  result.topEras
                      .skip(1)
                      .map((e) => e.era)
                      .join('  ·  '),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 13,
                    color: _muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onReset,
          style: TextButton.styleFrom(
            foregroundColor: _ink,
            textStyle: GoogleFonts.sourceSans3(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          child: const Text('ANOTHER'),
        ),
      ],
    );
  }
}

class _PaintingFrame extends StatelessWidget {
  const _PaintingFrame({required this.image});

  final Uint8List image;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF3D2C22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: ColoredBox(
        color: const Color(0xFFF4EFE4),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: ClipRect(
            child: ColoredBox(
              color: const Color(0xFF111111),
              child: Image.memory(
                image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
