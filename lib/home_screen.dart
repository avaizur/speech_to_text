import 'package:flutter/material.dart';
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
  }

  @override
  void dispose() {
    _speechService.transcriptNotifier.removeListener(_scrollToBottom);
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
    final text = _speechService.transcriptNotifier.value.trim();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No text to export')),
      );
      return;
    }
    // Uses your existing exportTranscript(type, text)
    await _documentService.exportTranscript(type, text);
  }

  String? _extractApprovalUrl(dynamic approval) {
    if (approval is String) return approval;
    if (approval is Map) {
      if (approval['href'] is String) return approval['href'] as String;
      if (approval['approvalUrl'] is String) return approval['approvalUrl'] as String;
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
    final transcriptListenable = _speechService.transcriptNotifier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lectura'),
        actions: [
          if (_isListening)
            IconButton(
              icon: const Icon(Icons.stop_circle),
              tooltip: 'Stop Recording',
              onPressed: _stopMic,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Transcript area
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: transcriptListenable,
                builder: (context, transcript, _) {
                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      transcript.isEmpty
                          ? 'Transcript will appear here...'
                          : transcript,
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Listening indicator (non-intrusive, only UI)
            AnimatedOpacity(
              opacity: _isListening ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _PulseDot(),
                  SizedBox(width: 8),
                  Text('Listening…'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Controls
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
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

class _PulseDot extends StatefulWidget {
  const _PulseDot({Key? key}) : super(key: key);

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);
  late final Animation<double> _scale = Tween(begin: 0.8, end: 1.2).animate(
    CurvedAnimation(parent: _c, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
