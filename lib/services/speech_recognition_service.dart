import 'package:speech_to_text/speech_to_text.dart';

class SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();

  Future<void> startListening(Function(String) onResult) async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('?? Speech status: $status'),
      onError: (error) => print('? Speech error: $error'),
    );

    if (available) {
      _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
      );
    } else {
      print('? Speech recognition not available');
    }
  }

  void stopListening() {
    _speech.stop();
  }
}

