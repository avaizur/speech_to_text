import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/speech_recognition_service.dart';
import 'services/document_service.dart';
import 'services/paypal_service.dart';
import 'services/text_formatter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  final DocumentService _documentService = DocumentService();
  final PayPalService _payPalService = PayPalService();
  final ScrollController _scrollController = ScrollController();

  bool _isListening = false;
  bool _cleanView = false; // <— Clean View toggle

  @override
  void initState() {
    super.initState();
    _speechService.initSpeech();
    _speechService.transcriptNotifier.addListener(_scrollToBottom);
    // If your service exposes partials:
    try {
      // ignore: invalid_use_of_protected_member
      _speechService.partialNotifier.addListener(_scrollToBottom);
    } catch (_) {}
  }

  @override
  void dispose() {
    _speechService.transcriptNotifier.removeListener(_scrollToBottom);
    try {
      // ignore: invalid_use_of_protected_member
      _speechService.partialNotifier.removeListener(_scrollToBottom);
    } catch (_) {}
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startMic() async {
    setState(() => _isListening = true);
    _speechService.startListening();
  }

  Future<void> _stopMic() async {
    _speechService.stopListening();
    setState(() => _isListening = false);
  }

  Future<void> _export(String type) async {
    final full = _speechService.transcriptNotifier.value.trim();
    String partial = '';
    try {
      partial = _speechService.partialNotifier.value.trim();
    } catch (_) {}
    final combined = (full.isEmpty && partial.isEmpty)
        ? ''
        : (partial.isEmpty ? full : '$full $partial');

    if (combined.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text to export')),
      );
      return;
    }

    await _documentService.exportTranscript(type, combined);
  }

  Future<void> _upgradeToPro({String plan = 'monthly'}) async {
    try {
      final env = (dotenv.env['PAYPAL_ENV'] ?? '').isNotEmpty;
      final hasId = (dotenv.env['PAYPAL_CLIENT_ID'] ?? '').isNotEmpty;
      final hasSecret = (dotenv.env['PAYPAL_CLIENT_SECRET'] ?? '').isNotEmpty;
      if (!env || !hasId || !hasSecret) {
        if (!mounted) return;
        final missing = [
          if (!env) 'PAYPAL_ENV',
          if (!hasId) 'PAYPAL_CLIENT_ID',
          if (!hasSecret) 'PAYPAL_CLIENT_SECRET',
        ].join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PayPal not configured: missing $missing')),
        );
        return;
      }

      final approvalUrl = await _payPalService.createOrder(plan: plan);
      final ok = await launchUrl(Uri.parse(approvalUrl), mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch PayPal approval URL')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PayPal error: $e')),
      );
    }
  }

  Future<void> _openGoogle() async {
    final uri = Uri.parse('https://www.google.com');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google')),
      );
    }
  }

  Widget _buildTranscript(String finalized, String livePartial) {
    // Render based on Clean View toggle
    final raw = livePartial.isNotEmpty ? '$finalized $livePartial' : finalized;
    final display = _cleanView ? TextFormatter.polish(raw) : raw;

    // Show partial in grey/italic ONLY in live (non-clean) mode
    if (!_cleanView && livePartial.isNotEmpty) {
      final base = finalized.isEmpty ? '' : '$finalized ';
      return SelectableText.rich(
        TextSpan(children: [
          TextSpan(text: base),
          TextSpan(
            text: livePartial,
            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ]),
        style: const TextStyle(fontSize: 16, height: 1.4),
      );
    }

    // Clean view or no partials: normal text
    return SelectableText(
      display,
      style: const TextStyle(fontSize: 16, height: 1.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lectura'),
        actions: [
          IconButton(
            tooltip: _cleanView ? 'Switch to Live View' : 'Switch to Clean View',
            icon: Icon(_cleanView ? Icons.cleaning_services : Icons.remove_red_eye),
            onPressed: () => setState(() => _cleanView = !_cleanView),
          ),
          if (_isListening)
            IconButton(
              tooltip: 'Stop Recording',
              icon: const Icon(Icons.stop_circle),
              onPressed: _stopMic,
            ),
        ],
      ),
      floatingActionButton: _isListening
          ? FloatingActionButton.extended(
              onPressed: _stopMic,
              icon: const Icon(Icons.mic),
              label: const Text('Listening… Tap to stop'),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _speechService.transcriptNotifier,
                builder: (context, finalized, _) {
                  ValueListenable<String>? partialLn;
                  try {
                    partialLn = _speechService.partialNotifier;
                  } catch (_) {}
                  if (partialLn == null) {
                    return SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      child: _buildTranscript(finalized, ''),
                    );
                  }
                  return ValueListenableBuilder<String>(
                    valueListenable: partialLn,
                    builder: (context, partial, __) {
                      return SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        child: _buildTranscript(finalized, partial),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                  label: Text(_isListening ? 'STOP' : 'START MIC'),
                  onPressed: _isListening ? _stopMic : _startMic,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.text_snippet),
                  label: const Text('TXT'),
                  onPressed: () => _export('TXT'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                  onPressed: () => _export('PDF'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.description),
                  label: const Text('DOCX'),
                  onPressed: () => _export('DOCX'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.workspace_premium),
                  label: const Text('Upgrade (Monthly)'),
                  onPressed: () => _upgradeToPro(plan: 'monthly'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Upgrade (Yearly)'),
                  onPressed: () => _upgradeToPro(plan: 'yearly'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.bolt),
                  label: const Text('Pay as you go'),
                  onPressed: () => _upgradeToPro(plan: 'payg'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.public),
                  label: const Text('Open Google'),
                  onPressed: _openGoogle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
