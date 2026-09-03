import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models/prediction_result.dart';
import 'services/classifier_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint(details.toString());
  };
  runApp(const EraApp());
}

class EraApp extends StatelessWidget {
  const EraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Art Era',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4E89),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        ErrorWidget.builder = (details) => Material(
              color: const Color(0xFFF7F4EE),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    details.exceptionAsString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
        return child ?? const SizedBox.shrink();
      },
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
    } catch (e, st) {
      debugPrint('Model load failed: $e\n$st');
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
      backgroundColor: const Color(0xFFF7F4EE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Art Era',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: Color(0xFF1A1510),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _booting ? 'Loading on-device model…' : ClassifierService.status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B6258),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: _booting
                    ? const Center(child: CircularProgressIndicator())
                    : _body(),
              ),
              if (_image != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: _reset, child: const Text('Try another')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_busy) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Looking at the image…'),
          ],
        ),
      );
    }

    if (_image != null && _result != null) {
      return _resultView();
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE6DED0)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.museum_outlined, size: 56, color: Color(0xFF1D4E89)),
                SizedBox(height: 16),
                Text(
                  'What era is this?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1510),
                  ),
                ),
                SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    'Choose a photo of a painting. The guess stays on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B6258), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 20),
        if (!kIsWeb) ...[
          FilledButton.icon(
            onPressed:
                ClassifierService.isReady ? () => _pick(ImageSource.camera) : null,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take photo'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          onPressed:
              ClassifierService.isReady ? () => _pick(ImageSource.gallery) : null,
          icon: const Icon(Icons.photo_outlined),
          label: const Text('Choose photo'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultView() {
    final result = _result!;
    return SingleChildScrollView(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(_image!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            result.era,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            result.years,
            style: const TextStyle(fontSize: 16, color: Color(0xFF6B6258)),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.confidencePercent}% sure',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ...result.topEras.skip(1).map(
            (alt) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Also possible: ${alt.era} (${alt.percentage.toStringAsFixed(0)}%)',
                style: const TextStyle(color: Color(0xFF6B6258)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
