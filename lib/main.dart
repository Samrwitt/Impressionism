import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/prediction_result.dart';
import 'services/classifier_service.dart';
import 'widgets/hero_header.dart';
import 'widgets/image_selector.dart';
import 'widgets/verdict_card.dart';
import 'widgets/insights_card.dart';
import 'widgets/history_panel.dart';
import 'widgets/settings_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ImpressionismApp());
}

class ImpressionismApp extends StatelessWidget {
  const ImpressionismApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Impressionist AI - Art Style Classifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0F14),
        primaryColor: const Color(0xFFE6B86A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE6B86A),
          secondary: Color(0xFF34D399),
          surface: Color(0xFF131722),
          background: Color(0xFF0D0F14),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const ImpressionismHomeScreen(),
    );
  }
}

class ImpressionismHomeScreen extends StatefulWidget {
  const ImpressionismHomeScreen({super.key});

  @override
  State<ImpressionismHomeScreen> createState() =>
      _ImpressionismHomeScreenState();
}

class _ImpressionismHomeScreenState extends State<ImpressionismHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = false;
  Uint8List? _currentImageBytes;
  PredictionResult? _currentResult;

  final List<Map<String, dynamic>> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _initClassifier();
  }

  Future<void> _initClassifier() async {
    await ClassifierService.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _processImage(Uint8List bytes,
      {String? path, String? url}) async {
    setState(() {
      _isLoading = true;
      _currentImageBytes = bytes;
    });

    try {
      final result = await ClassifierService.predictImage(
        bytes,
        imageUrl: url,
        imagePath: path,
      );

      setState(() {
        _currentResult = result;
        _isLoading = false;

        // Save to history
        _historyItems.insert(0, {
          'bytes': bytes,
          'result': result,
          'timestamp': DateTime.now(),
        });
      });
    } catch (e) {
      print('Error predicting image: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to classify image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _resetSelection() {
    setState(() {
      _currentImageBytes = null;
      _currentResult = null;
    });
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        onSaved: () {
          setState(() {});
        },
      ),
    );
  }

  void _openHistory() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: HistoryPanel(
        historyItems: _historyItems,
        onItemSelect: (item) {
          setState(() {
            _currentResult = item['result'] as PredictionResult;
            _currentImageBytes = item['bytes'] as Uint8List?;
          });
          Navigator.of(context).pop();
        },
        onClearHistory: () {
          setState(() {
            _historyItems.clear();
          });
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Hero Header
            HeroHeader(
              onOpenSettings: _openSettings,
              onOpenHistory: _openHistory,
              historyCount: _historyItems.length,
              isBackendOnline: true,
            ),

            // Scrollable Body Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Loading indicator overlay
                        if (_isLoading)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131722),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF2E384D)),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3.5,
                                    color: Color(0xFFE6B86A),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Analyzing Artwork Style...',
                                  style: GoogleFonts.playfairDisplay(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Executing On-Device Tensor Inference...',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )

                        else if (_currentResult != null &&
                            _currentImageBytes != null) ...[
                          // Result Verdict Card
                          VerdictCard(
                            result: _currentResult!,
                            imageBytes: _currentImageBytes!,
                            onReset: _resetSelection,
                          ),
                          const SizedBox(height: 20),

                          // Insights Card
                          InsightsCard(
                            detectedTraits: _currentResult!.analysis.traits,
                          ),
                        ] else ...[
                          // Main Image Selector (Camera / Upload / Samples)
                          ImageSelector(
                            onImageSelected: _processImage,
                            isLoading: _isLoading,
                          ),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
