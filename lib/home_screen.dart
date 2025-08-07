import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lectura/services/paypal_service.dart';
import 'package:lectura/services/speech_recognition_service.dart';
import 'package:lectura/services/document_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PayPalService _payPalService = PayPalService();
  final SpeechRecognitionService _speechService = SpeechRecognitionService();
  final DocumentService _documentService = DocumentService();

  bool _isListening = false;
  String _transcribedText = '';
  Timer? _recordingTimer;

  void _startTranscription() async {
    setState(() {
      _isListening = true;
      _transcribedText = '';
    });

    _recordingTimer = Timer(const Duration(hours: 1), () {
      _stopTranscription();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("?? 1 hour reached. Recording stopped.")),
      );
    });

    await _speechService.startListening((result) {
      setState(() {
        _transcribedText = result;
      });
    });
  }

  void _stopTranscription() {
    _recordingTimer?.cancel();
    _speechService.stopListening();
    setState(() {
      _isListening = false;
    });
  }

  void _exportText(String format) async {
    if (_transcribedText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No transcription to export.")),
      );
      return;
    }

    final filenameController = TextEditingController();

    final fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter file name'),
        content: TextField(
          controller: filenameController,
          decoration: const InputDecoration(hintText: "e.g. lecture_notes"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, filenameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (fileName == null || fileName.trim().isEmpty) return;

    try {
      await _documentService.export(_transcribedText, format, fileName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Exported as $fileName.$format")),
      );
    } catch (e) {
      print("? Export failed: $e");
    }
  }

  Future<void> _handlePayPalOrder() async {
    try {
      final order = await _payPalService.createOrder(1.99);
      await openPayPalApprovalUrl(order);
    } catch (e) {
      print("? PayPal error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lectura – Transcribe & Export')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: _isListening ? _stopTranscription : _startTranscription,
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              label: Text(_isListening ? 'Stop Listening' : 'Start Transcription'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _transcribedText.isEmpty
                        ? 'Transcribed text will appear here...'
                        : _transcribedText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _exportText('txt'),
                  child: const Text("Export as TXT"),
                ),
                ElevatedButton(
                  onPressed: () => _exportText('pdf'),
                  child: const Text("Export as PDF"),
                ),
                ElevatedButton(
                  onPressed: () => _exportText('docx'),
                  child: const Text("Export as DOCX"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _handlePayPalOrder,
              child: const Text("Create PayPal Order"),
            ),
          ],
        ),
      ),
    );
  }
}
