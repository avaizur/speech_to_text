import 'package:speech_to_text/speech_to_text.dart';

class SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _lastRecognized = '';
  Function(String)? _onResult;

  /// Initialize the speech recognition engine
  Future<bool> initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        // Auto-restart if stopped but should still be listening
        if (status == 'done' && _isListening) {
          _restartListening();
        }
      },
      onError: (error) {
        // Try to restart after an error (like audio focus loss)
        if (_isListening) {
          _restartListening();
        }
      },
    );
    return available;
  }

  /// Start listening for speech
  Future<void> startListening(Function(String) onResult) async {
    _onResult = onResult;
    _isListening = true;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _lastRecognized = result.recognizedWords;
        }
        _onResult?.call(result.recognizedWords);
      },
      pauseFor: const Duration(seconds: 6), // tolerate short pauses
      listenFor: const Duration(hours: 1), // long sessions
      partialResults: true,
      cancelOnError: false,
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
  }

  /// Returns whether the service is actively listening
  bool isListening() {
    return _isListening;
  }

  /// Internal: restart listening after a pause or interruption
  void _restartListening() async {
    if (!_isListening) return;
    await _speech.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    if (_onResult != null) {
      await startListening(_onResult!);
    }
  }
}
