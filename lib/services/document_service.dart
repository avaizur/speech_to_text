
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:docx_template/docx_template.dart';

class DocumentService {
  Future<void> export(String text, String format, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeName = filename.trim().isEmpty ? 'lecture_notes' : filename.trim();
    final filePath = '${dir.path}/$safeName.${format.toLowerCase()}';

    switch (format.toLowerCase()) {
      case 'txt':
        final file = File(filePath);
        await file.writeAsString(text);
        break;

      case 'pdf':
        final pdf = pw.Document();
        pdf.addPage(pw.Page(
          build: (context) => pw.Text(text),
        ));
        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());
        break;

      case 'docx':
        final doc = await DocxTemplate.fromAsset('assets/empty.docx');
        final content = Content();
        content.add(TextContent("body", text));
        final file = File(filePath);
        await file.writeAsBytes(await doc.generate(content) ?? []);
        break;

      default:
        throw Exception('Unsupported format: $format');
    }

    await OpenFilex.open(filePath);
  }
}
