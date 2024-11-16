import 'package:speech_to_text/speech_to_text.dart';

class SpeechRecognitionService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';

  Future<void> startListening() async {
    bool available = await _speechToText.initialize(
      onStatus: (status) => print('Speech recognition status: $status'),
      onError: (error) => print('Speech recognition error: $error'),
    );
    if (available) {
      _speechToText.listen(onResult: (result) {
        _recognizedText = result.recognizedWords;
      });
      _isListening = true;
    } else {
      print('The user has denied the use of speech recognition.');
    }
  }

  void stopListening() {
    _speechToText.stop();
    _isListening = false;
  }

  String get recognizedText => _recognizedText;
}

