import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class DocumentService {
  Future<void> saveAsWord(String content, String filename) async {
    // Get the application's documents directory
    final directory = await getApplicationDocumentsDirectory();

    // Construct the file path
    final filePath = '${directory.path}/$filename.docx';

    // Write the content to the file
    final file = File(filePath);
    await file.writeAsString(content);

    // Open the file (optional)
    await OpenFilex.open(filePath);
  }
}

