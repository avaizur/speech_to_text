import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Continuous listening with pause-based paragraphing and duplicate prevention.
/// Public API used by HomeScreen:
///   - initSpeech()
///   - startListening()
///   - stopListening()
///   - transcriptNotifier (ValueNotifier<String>)
class SpeechRecognitionService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _ready = false;
  bool _isListening = false;
  DateTime _lastSpeechTime = DateTime.now();

  final ValueNotifier<String> transcriptNotifier = ValueNotifier<String>('');

  // Paragraph control
  static const Duration _paragraphPause = Duration(seconds: 3);
  static const int _maxWordsPerParagraph = 80;
  int _currentWordCount = 0;
  String _lastFinalText = '';

  Future<void> initSpeech() async {
    _ready = await _speech.initialize(
      onStatus: (status) {
        // auto-restart if engine drops while we want to keep listening
        if (status == 'notListening' && _isListening) {
          _startInternal();
        }
      },
      onError: (error) {
        debugPrint('Speech error: $error');
      },
    );
  }

  void startListening() {
    if (!_ready) return;
    if (_isListening) return;
    _isListening = true;

    _currentWordCount = 0;
    _lastFinalText = '';
    _lastSpeechTime = DateTime.now();

    _startInternal();
  }

  void _startInternal() {
    _speech.listen(
      onResult: (result) {
        final now = DateTime.now();
        final newText = result.recognizedWords.trim();
        if (newText.isEmpty) return;

        final pause = now.difference(_lastSpeechTime);
        final shouldBreak =
            pause > _paragraphPause || _currentWordCount >= _maxWordsPerParagraph;

        if (result.finalResult) {
          var full = transcriptNotifier.value;

          // paragraph break if long pause/length
          if (shouldBreak && full.isNotEmpty) {
            full += '\n\n';
            _currentWordCount = 0;
          } else if (full.isNotEmpty) {
            full += ' ';
          }

          // avoid re-appending duplicates
          if (!full.endsWith(newText)) {
            full += newText;
          }

          _currentWordCount += newText.split(RegExp(r'\s+')).length;
          _lastFinalText = newText;
          transcriptNotifier.value = full;
        } else {
          // We ignore partials here to avoid bracketed highlights in the UI.
          // Timing still updated so pauses are detected correctly.
        }

        _lastSpeechTime = now;
      },
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
    );
  }

  void stopListening() {
    _speech.stop();
    _isListening = false;
  }

  void cancelListening() {
    _speech.cancel();
    _isListening = false;
  }
}
