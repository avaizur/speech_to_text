import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/listen_mode.dart';

class SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();
  bool _shouldContinue = false;
  String _fullTranscript = '';

  Future<void> startListening(Function(String) onResult) async {
    _fullTranscript = ''; // Reset transcript
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('??? Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (_shouldContinue) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _restartListening(onResult);
            });
          }
        }
      },
      onError: (error) {
        print('? Speech error: $error');
      },
    );

    if (available) {
      _shouldContinue = true;
      _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          final text = result.recognizedWords.trim();

          // ?? Check for book or URL mention
          if (text.contains(RegExp(r'\bhttps?://\S+\b'))) {
            print('?? URL Mentioned!');
          }
          if (text.contains('chapter') || text.contains('book')) {
            print('?? Book Reference Detected!');
          }

          if (result.finalResult && text.isNotEmpty) {
            // Add paragraph break on final result
            _fullTranscript += '\n\n$text';
          } else {
            // Remove trailing break if continuing same thought
            _fullTranscript = _fullTranscript.replaceAll(RegExp(r'\n\n$'), '');
            _fullTranscript += ' $text';
          }

          onResult(_fullTranscript.trim());
        },
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
      );
    } else {
      print('? Speech recognition not available');
    }
  }

  void _restartListening(Function(String) onResult) {
    if (!_speech.isAvailable || !_shouldContinue) return;

    _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final text = result.recognizedWords.trim();

        if (text.contains(RegExp(r'\bhttps?://\S+\b'))) {
          print('?? URL Mentioned!');
        }
        if (text.contains('chapter') || text.contains('book')) {
          print('?? Book Reference Detected!');
        }

        if (result.finalResult && text.isNotEmpty) {
          _fullTranscript += '\n\n$text';
        } else {
          _fullTranscript = _fullTranscript.replaceAll(RegExp(r'\n\n$'), '');
          _fullTranscript += ' $text';
        }

        onResult(_fullTranscript.trim());
      },
      listenMode: ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
    );
  }

  void stopListening() {
    _shouldContinue = false;
    _speech.stop();
  }
}
