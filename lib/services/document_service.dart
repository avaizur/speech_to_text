import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:docx_template/docx_template.dart';

import 'text_formatter.dart';

class DocumentService {
  /// Unified export used by HomeScreen: type must be 'TXT', 'PDF', or 'DOCX'
  Future<void> exportTranscript(String type, String text, {String? filenameNoExt}) async {
    final cleaned = TextFormatter.polish(text);

    // Use provided filename or fallback to timestamp
    final fallbackTs = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final base = (filenameNoExt == null || filenameNoExt.isEmpty) ? 'lectura_$fallbackTs' : filenameNoExt;

    switch (type.toUpperCase().trim()) {
      case 'TXT':
        await _exportTxt(cleaned, '$base.txt');
        break;
      case 'PDF':
        await _exportPdf(cleaned, '$base.pdf');
        break;
      case 'DOCX':
        await _exportDocx(cleaned, '$base.docx');
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
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Text(text),
        ),
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    await OpenFilex.open(file.path);
  }

  Future<void> _exportDocx(String text, String filename) async {
    // Load template from assets. The template should contain {{body}} placeholder.
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
