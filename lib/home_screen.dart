import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/speech_recognition_service.dart';
import 'services/document_service.dart';
import 'services/paypal_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  final DocumentService _documentService = DocumentService();
  final PayPalService _payPalService = PayPalService();
  final ScrollController _scrollController = ScrollController();

  String _transcript = '';
  bool _isListening = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _appendTranscript(String text) {
    setState(() {
      _transcript += (text.isNotEmpty ? '$text ' : '');
    });

    // Keep latest text in view (auto-scroll to bottom)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechService.stopListening();
      setState(() => _isListening = false);
    } else {
      final ok = await _speechService.initSpeech();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech not available')),
        );
        return;
      }
      await _speechService.startListening(_appendTranscript);
      setState(() => _isListening = true);
    }
  }

  Future<void> _export(String type) async {
    if (_transcript.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text to export')),
      );
      return;
    }
    await _documentService.exportTranscript(type, _transcript);
  }

  // ---- Helper to safely extract the approval URL from various PayPal responses
  String? _extractApprovalUrl(dynamic approval) {
    if (approval is String) return approval;

    if (approval is Map) {
      if (approval['href'] is String) return approval['href'] as String;
      if (approval['approvalUrl'] is String) return approval['approvalUrl'] as String;

      // Some responses return a list of links with rel labels
      final links = approval['links'];
      if (links is List) {
        for (final item in links) {
          if (item is Map &&
              item['href'] is String &&
              (item['rel'] == 'approve' || item['rel'] == 'approval_url')) {
            return item['href'] as String;
          }
        }
      }
    }

    return null;
  }

  Future<void> _createOrder(double amount) async {
    try {
      final approval = await _payPalService.createOrder(amount);
      final link = _extractApprovalUrl(approval);

      if (link == null || link.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid PayPal approval URL')),
        );
        return;
      }

      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PayPal error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lectura App'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Transcript area (grows inside scroll, controls stay visible)
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Text(
                  _transcript.isEmpty ? 'Transcript will appear here...' : _transcript,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Mic control
            FilledButton.icon(
              icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
              label: Text(_isListening ? 'STOP' : 'START MIC'),
              style: FilledButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.green,
              ),
              onPressed: _toggleListening,
            ),
            const SizedBox(height: 12),

            // Export buttons
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
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
              ],
            ),
            const SizedBox(height: 12),

            // PayPal + Google
            Wrap(
              spacing: 10,
              children: [
                FilledButton(
                  onPressed: () => _createOrder(10.00),
                  child: const Text('PayPal'),
                ),
                OutlinedButton(
                  onPressed: () => launchUrl(
                    Uri.parse('https://www.google.com'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('Test Google'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
