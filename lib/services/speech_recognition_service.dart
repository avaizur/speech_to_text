import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/material.dart';

class SpeechRecognitionService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastRecognized = '';
  String _fullTranscript = '';
  DateTime _lastSpeechTime = DateTime.now();

  final ValueNotifier<String> transcriptNotifier = ValueNotifier<String>("");

  Future<void> initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        debugPrint("Speech status: $status");
        if (status == "notListening" && _isListening) {
          // Restart listening to keep it continuous
          _startListening();
        }
      },
      onError: (error) {
        debugPrint("Speech error: $error");
      },
    );
  }

  void startListening() {
    if (!_isListening) {
      _fullTranscript = '';
      transcriptNotifier.value = '';
      _startListening();
    }
  }

  void _startListening() {
    _isListening = true;
    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          String newText = result.recognizedWords.trim();

          if (newText.isNotEmpty && newText != _lastRecognized) {
            final now = DateTime.now();
            final pauseDuration = now.difference(_lastSpeechTime).inMilliseconds;

            // Paragraph break if pause > 2000 ms
            if (pauseDuration > 2000 && _fullTranscript.isNotEmpty) {
              _fullTranscript += "\n\n";
            }

            _fullTranscript +=
                (_fullTranscript.isEmpty ? "" : " ") + newText;
            transcriptNotifier.value = _fullTranscript;
            _lastRecognized = newText;
            _lastSpeechTime = now;
          }
        }
      },
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 30),
      partialResults: true,
      localeId: 'en_US',
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
