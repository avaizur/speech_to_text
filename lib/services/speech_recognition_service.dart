mport 'package:speech_to_text/speech_to_text.dart';

class SpeechRecognitionService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';

  Future<void> startListening() async {
    bool available = await _speechToText.initialize();
    if (available) {
      _speechToText.listen(onResult: (result) {
        _recognizedText = result.recognizedWords;
      });
      _isListening = true;
    }
  }

  void stopListening() {
    _speechToText.stop();
    _isListening = false;
  }

  String get recognizedText => _recognizedText;
}

