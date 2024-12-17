import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class DocumentService {
  Future<void> saveAsWord(String content, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename.docx';
      final file = File(filePath);

      await file.writeAsString(content);

      try {
        await OpenFilex.open(filePath);
      } catch (e) {
        print('Error opening file: $e');
      }
    } catch (e) {
      print('Error saving file: $e');
      rethrow;
    }
  }
}

