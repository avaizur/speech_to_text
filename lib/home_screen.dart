import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/speech_recognition_service.dart';
import 'services/document_service.dart';
import 'services/paypal_service.dart';

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

  @override
  void initState() {
    super.initState();
    _speechService.initSpeech();
    _speechService.transcriptNotifier.addListener(_scrollToBottom);
    _speechService.partialNotifier.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _speechService.transcriptNotifier.removeListener(_scrollToBottom);
    _speechService.partialNotifier.removeListener(_scrollToBottom);
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
    final partial = _speechService.partialNotifier.value.trim();
    final text = (full.isEmpty && partial.isEmpty)
        ? ''
        : (partial.isEmpty ? full : '$full $partial');

    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text to export')),
      );
      return;
    }

    await _documentService.exportTranscript(type, text);
  }

  // Patched version with .env check
  Future<void> _upgradeToPro() async {
    try {
      // On-device .env health check (no secrets shown)
      final hasId = (dotenv.env['PAYPAL_CLIENT_ID'] ?? '').isNotEmpty;
      final hasSecret = (dotenv.env['PAYPAL_CLIENT_SECRET'] ?? '').isNotEmpty;
      if (!hasId || !hasSecret) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PayPal not configured: missing client credentials (.env).')),
        );
        return;
      }

      final approvalUrl = await _payPalService.createOrder();
      if (approvalUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PayPal: No approval URL returned')),
        );
        return;
      }

      final ok = await launchUrl(
        Uri.parse(approvalUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch PayPal approval URL')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PayPal error: ${e.toString()}')),
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
    final spans = <TextSpan>[];

    if (finalized.isNotEmpty) {
      final parts = finalized.split('\n\n');
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        spans.add(TextSpan(text: parts[i]));
        if (i < parts.length - 1) {
          spans.add(const TextSpan(text: '\n\n'));
        }
      }
    }

    if (livePartial.isNotEmpty) {
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' '));
      spans.add(
        TextSpan(
          text: livePartial,
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontSize: 16, height: 1.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lectura'),
        actions: [
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
              label: const Text('Listening Tap to stop'),
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
                  return ValueListenableBuilder<String>(
                    valueListenable: _speechService.partialNotifier,
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
                  label: const Text('Upgrade to Pro'),
                  onPressed: _upgradeToPro,
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
