mport 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';

class DocumentService {
  Future<void> saveAsWord(String content, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename.docx');
    await file.writeAsString(content);
    await FileSaver.instance.saveAs(filename, file.readAsBytesSync(), "docx", MimeType.MICROSOFTWORD);
  }
}

