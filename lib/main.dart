

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:docx_template/docx_template.dart';
import 'services/paypal_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lectura App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PayPalService _payPalService = PayPalService();
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _text = 'Sample transcript...';

  Future<void> _createOrder(double amount) async {
    try {
      final order = await _payPalService.createOrder(amount);
      print('? PayPal Order created: $order');
      await openPayPalApprovalUrl(order);
    } catch (e) {
      print('? Error creating PayPal order: $e');
    }
  }

  Future<void> _testGoogleLaunch() async {
    final uri = Uri.parse('https://www.google.com');
    if (await canLaunchUrl(uri)) {
      print('?? Launching Google...');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print('?? Could not launch Google');
    }
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) => setState(() => _text = result.recognizedWords),
        );
      }
    } else {
      await _speech.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _exportToWord() async {
    try {
      final bytes = await rootBundle.load('assets/template.docx');
      final docx = await DocxTemplate.fromBytes(bytes.buffer.asUint8List());

      final content = Content()
        ..add(TextContent("text", _text)); // matches {text} in template.docx

      final docGenerated = await docx.generate(content);
      if (docGenerated == null) {
        print('?? Failed to generate DOCX');
        return;
      }

      final filePath = '${Directory.systemTemp.path}/lectura_transcript.docx';
      final file = File(filePath);
      await file.writeAsBytes(docGenerated);


      print('?? Word file saved: $filePath');
      await OpenFilex.open(file.path);
    } catch (e) {
      print('? Error exporting to Word: $e');
    }
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Text(_text),
        ),
      ),
    );

    final output = await File('${Directory.systemTemp.path}/export.pdf').create();
    await output.writeAsBytes(await pdf.save());
    OpenFilex.open(output.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lectura App'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- Speech Section ---
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    Text(_text, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 15),
                    FilledButton.icon(
                      icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
                      label: Text(_isListening ? 'STOP' : 'START MIC'),
                      onPressed: _toggleListening,
                      style: FilledButton.styleFrom(
                        backgroundColor: _isListening ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- Export Buttons ---
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.description),
                  label: const Text('Word'),
                  onPressed: _exportToWord,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('PDF'),
                  onPressed: _exportToPDF,
                ),
              ],
            ),

            // --- Payment + Test Buttons ---
            const SizedBox(height: 30),
            const Divider(),
            Wrap(
              spacing: 10,
              children: [
                FilledButton(
                  onPressed: () => _createOrder(10.00),
                  child: const Text('PayPal'),
                ),
                OutlinedButton(
                  onPressed: _testGoogleLaunch,
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
