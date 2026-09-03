import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'models/prediction_result.dart';
import 'services/classifier_service.dart';

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

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _busy = true;
        _image = bytes;
        _result = null;
        _error = null;
      });
      final result = await ClassifierService.predict(bytes);
      if (!mounted) return;
      setState(() {
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
                                      onCamera: kIsWeb
                                          ? null
                                          : () => _pick(ImageSource.camera),
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
  final VoidCallback? onCamera;
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
              onTap: ready ? onChoose : null,
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
                            'Place a painting in the frame.\nNothing leaves this device.',
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
          child: FilledButton(
            onPressed: ready ? onChoose : null,
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
            child: const Text('Choose a painting'),
          ),
        ),
        if (onCamera != null) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: ready ? onCamera : null,
            style: TextButton.styleFrom(
              foregroundColor: _muted,
              textStyle: GoogleFonts.sourceSans3(
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
            child: const Text('Or take a photo'),
          ),
        ],
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
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _card,
                    border: Border.all(color: const Color(0xFFC4B8A4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.memory(image, fit: BoxFit.contain),
                ),
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
