import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lectura/services/speech_recognition_service.dart';
import 'package:lectura/services/document_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  final DocumentService _documentService = DocumentService();

  bool _isListening = false;
  String _transcribedText = '';
  Timer? _recordingTimer;
  final ScrollController _scrollController = ScrollController();

  // Layout constants (DO NOT MODIFY)
  static const double _textContainerHeight = 300; // Fixed height
  static const Duration _recordingLimit = Duration(hours: 1);
  static const EdgeInsets _screenPadding = EdgeInsets.all(16);

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startTranscription() async {
    setState(() {
      _isListening = true;
      _transcribedText = '';
    });

    _recordingTimer = Timer(_recordingLimit, _handleAutoStop);

    await _speechService.startListening((result) {
      setState(() => _transcribedText = result);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleAutoStop() async {
    await _stopTranscription();
    await _autoSaveRecording();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("? 1-hour limit reached. Auto-saved.")),
    );
  }

  Future<void> _stopTranscription() async {
    _recordingTimer?.cancel();
    _speechService.stopListening();
    if (mounted) setState(() => _isListening = false);
  }

  Future<void> _autoSaveRecording() async {
    if (_transcribedText.isEmpty) return;
    final filename = 'Recording_${DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}';
    await _documentService.export(_transcribedText, 'docx', filename);
  }

  Future<void> _exportText(String format) async {
    final defaultName = 'Note_${DateTime.now().toString().replaceAll(RegExp(r'[^\d]'), '').substring(0, 8)}';
    final fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save As'),
        content: TextField(
          controller: TextEditingController(text: defaultName),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "e.g. Lecture_Notes",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 
                (ModalRoute.of(context)!.settings.arguments as TextEditingController).text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (fileName == null || fileName.isEmpty) return;

    try {
      await _documentService.export(_transcribedText, format, fileName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('? Saved as $fileName.$format')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('? Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lectura'),
        actions: [
          if (_isListening)
            IconButton(
              icon: const Icon(Icons.emergency, color: Colors.red),
              onPressed: _handleAutoStop,
              tooltip: 'Emergency Stop',
            ),
        ],
      ),
      body: Padding(
        padding: _screenPadding,
        child: Column(
          children: [
            // 1. Fixed Top Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(_isListening ? Icons.stop : Icons.mic),
                label: Text(_isListening ? 'STOP RECORDING' : 'START RECORDING'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _isListening ? Colors.red : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isListening ? _stopTranscription : _startTranscription,
              ),
            ),

            const SizedBox(height: 16),

            // 2. Fixed-Height Scrollable Container
            Container(
              height: _textContainerHeight, // Critical fixed height
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  _transcribedText.isEmpty
                      ? 'Transcription will appear here...'
                      : _transcribedText,
                  style: const TextStyle(fontSize: 16),
                ),
