import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:docx_template/docx_template.dart';

class DocumentService {
  /// Unified export used by HomeScreen: type must be 'TXT', 'PDF', or 'DOCX' (case-insensitive)
  Future<void> exportTranscript(String type, String text) async {
    final fmt = type.toUpperCase().trim();
    final ts = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');

    switch (fmt) {
      case 'TXT':
        await _exportTxt(text, 'lectura_$ts.txt');
        break;
      case 'PDF':
        await _exportPdf(text, 'lectura_$ts.pdf');
        break;
      case 'DOCX':
        await _exportDocx(text, 'lectura_$ts.docx');
        break;
      default:
        throw UnsupportedError('Unsupported export type: $type');
    }
  }

  Future<void> _exportTxt(String text, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(text);
    await OpenFilex.open(file.path);
  }

  Future<void> _exportPdf(String text, String filename) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Text(
          text,
          style: const pw.TextStyle(fontSize: 12),
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    await OpenFilex.open(file.path);
  }

  Future<void> _exportDocx(String text, String filename) async {
    // Ensure you have an asset at assets/empty.docx with {{body}} placeholder
    final bytes = await rootBundle.load('assets/empty.docx');
    final tpl = await DocxTemplate.fromBytes(bytes.buffer.asUint8List());

    final content = Content()..add(TextContent('body', text));
    final generated = await tpl.generate(content);
    if (generated == null) {
      throw Exception('Failed to generate DOCX');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(generated);
    await OpenFilex.open(file.path);
  }
}
