import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class SettingsDialog extends StatefulWidget {
  final VoidCallback onSaved;

  const SettingsDialog({
    super.key,
    required this.onSaved,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _urlController;
  late TextEditingController _hfTokenController;
  bool _testingConnection = false;
  String? _testMessage;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiService.baseUrl);
    _hfTokenController = TextEditingController(text: ApiService.hfToken ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _hfTokenController.dispose();
    super.dispose();
  }

  Future<void> _testServer() async {
    setState(() {
      _testingConnection = true;
      _testMessage = null;
    });

    ApiService.baseUrl = _urlController.text.trim();
    final isOnline = await ApiService.checkBackendHealth();

    setState(() {
      _testingConnection = false;
      _testMessage = isOnline
          ? 'Connected successfully to local model server!'
          : 'Could not reach server. Hybrid/Offline fallback mode active.';
    });
  }

  void _saveSettings() {
    ApiService.baseUrl = _urlController.text.trim();
    ApiService.hfToken = _hfTokenController.text.trim().isEmpty
        ? null
        : _hfTokenController.text.trim();
    widget.onSaved();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131722),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.settings_suggest_rounded,
                    color: Color(0xFFE6B86A),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AI Model & Server Settings',
                    style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Model Information Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2638),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hugging Face Model:',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'prithivMLmods/WikiArt-Style',
                      style: GoogleFonts.firaCode(
                        color: const Color(0xFFE6B86A),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SigLIP-2 architecture fine-tuned on WikiArt style dataset (137 classes)',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFCBD5E1),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Server URL input
              Text(
                'Backend Server URL:',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _urlController,
                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'http://localhost:8008',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1A2130),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE6B86A)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Test connection button
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _testingConnection ? null : _testServer,
                    icon: _testingConnection
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFFE6B86A)),
                          )
                        : const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text('Test Connection'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE6B86A),
                      side: const BorderSide(color: Color(0xFFE6B86A)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (_testMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _testMessage!,
                  style: GoogleFonts.plusJakartaSans(
                    color: _testMessage!.contains('successfully')
                        ? const Color(0xFF34D399)
                        : const Color(0xFFFBBF24),
                    fontSize: 11,
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Optional HF Token
              Text(
                'Hugging Face API Token (Optional):',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _hfTokenController,
                obscureText: true,
                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'hf_xxxxxxxxxxxxxxxxxxxxxx',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1A2130),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE6B86A)),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainState.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF94A3B8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE6B86A),
                      foregroundColor: const Color(0xFF0D0F14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Save Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
