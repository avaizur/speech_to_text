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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  final DocumentService _documentService = DocumentService();
  final PayPalService _payPalService = PayPalService();
  final ScrollController _scrollController = ScrollController();

  bool _isListening = false;
  bool _cleanView = false; // Clean View toggle
  bool _autoScroll = true; // follow transcript

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speechService.initSpeech();
    _speechService.transcriptNotifier.addListener(_onTranscriptUpdate);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speechService.transcriptNotifier.removeListener(_onTranscriptUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  void _onTranscriptUpdate() {
    if (!_autoScroll) return;
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

  Future<String?> _askFilename(BuildContext ctx, String suggested) async {
    final controller = TextEditingController(text: suggested);
    return showDialog<String>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('File name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter file name (without extension)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
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

    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final suggested = 'lectura_$ts';

    final name = await _askFilename(context, suggested);
    if (name == null || name.isEmpty) return;

    await _documentService.exportTranscript(type, text, filenameNoExt: name);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported $type as $name')),
    );
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

  Widget _buildTranscript(String transcript) {
    final display = _cleanView ? TextFormatter.polish(transcript) : transcript;
    return SelectableText(
      display.isEmpty ? 'Your transcript will appear here…' : display,
      style: const TextStyle(fontSize: 16, height: 1.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthly = dotenv.env['PRICE_MONTHLY'] ?? '7.99';
    final yearly = dotenv.env['PRICE_YEARLY'] ?? '79.99';
    final payg = dotenv.env['PRICE_PAY_AS_YOU_GO'] ?? '0.10';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Lectura'),
        actions: [
          IconButton(
            tooltip: 'Open Google',
            icon: const Icon(Icons.public),
            onPressed: () => launchUrl(
              Uri.parse('https://www.google.com'),
              mode: LaunchMode.externalApplication,
            ),
          ),
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

      // Body: transcript scrolls independently
      body: Column(
        children: [
          // Small status row with auto-follow toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(_isListening ? Icons.mic : Icons.mic_none, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isListening
                        ? 'Listening… Your controls stay visible below.'
                        : 'Tap Start to begin. Text scrolls; controls stay pinned.',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: _autoScroll ? 'Auto-scroll on (tap to pause)' : 'Auto-scroll off (tap to follow)',
                  child: InkWell(
                    onTap: () => setState(() => _autoScroll = !_autoScroll),
                    child: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.push_pin_outlined, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Transcript pane
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ValueListenableBuilder<String>(
                    valueListenable: _speechService.transcriptNotifier,
                    builder: (context, transcript, _) {
                      return NotificationListener<UserScrollNotification>(
                        onNotification: (notif) {
                          // If user scrolls manually, pause auto-follow
                          _autoScroll = false;
                          return false;
                        },
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          child: _buildTranscript(transcript),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // Sticky bottom controls + in-app tip
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // One-line tip about start beep
              Row(
                children: const [
                  Icon(Icons.info_outline, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tip: Some phones play a short beep when starting transcription. Switch device to silent to avoid.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Mic toggle (blue primary)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 4,
                    ),
                    onPressed: _isListening ? _stopMic : _startMic,
                    icon: Icon(_isListening ? Icons.stop : Icons.mic),
                    label: Text(_isListening ? 'Stop' : 'Start'),
                  ),
                  const SizedBox(width: 8),

                  // Export menu (outlined, secondary)
                  PopupMenuButton<String>(
                    tooltip: 'Export',
                    onSelected: (val) => _export(val),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'TXT', child: Text('Export as TXT')),
                      PopupMenuItem(value: 'PDF', child: Text('Export as PDF')),
                      PopupMenuItem(value: 'DOCX', child: Text('Export as DOCX')),
                    ],
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: null, // open via popup
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Export'),
                    ),
                  ),
                  const Spacer(),

                  // Upgrade (premium color) with prices
                  PopupMenuButton<String>(
                    tooltip: 'Upgrade',
                    onSelected: (plan) => _upgradeToPro(plan: plan),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'monthly', child: Text('Monthly – £$monthly')),
                      PopupMenuItem(value: 'yearly', child: Text('Yearly – £$yearly')),
                      PopupMenuItem(value: 'payg', child: Text('Pay as you go – £$payg/min')),
                    ],
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        elevation: 4,
                      ),
                      onPressed: null,
                      icon: const Icon(Icons.workspace_premium),
                      label: const Text('Upgrade'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // Optional listening FAB (kept from your UX)
      floatingActionButton: _isListening
          ? FloatingActionButton.extended(
              onPressed: _stopMic,
              icon: const Icon(Icons.mic),
              label: const Text('Listening… Tap to stop'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endContained,
    );
  }
}
