import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/listen_mode.dart';

class SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();
  bool _shouldContinue = false;
  String _fullTranscript = '';
  Function(String)? _onResultCallback;

  Future<void> startListening(Function(String) onResult) async {
    _fullTranscript = '';
    _onResultCallback = onResult;

    bool available = await _speech.initialize(
      onStatus: (status) {
        print('??? Speech status: $status');

        if (status == 'done' || status == 'notListening') {
          if (_shouldContinue) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _restartListening();
            });
          }
        }
      },
      onError: (error) {
        print('? Speech error: $error');
        if (_shouldContinue &&
            (error.errorMsg.contains('7') || // Network error
             error.permanent == false)) {
          // Attempt auto-restart after error
          Future.delayed(const Duration(seconds: 1), () {
            _restartListening();
          });
        }
      },
    );

    if (available) {
      _shouldContinue = true;
      _listen();
    } else {
      print('? Speech recognition not available');
    }
  }

  void _listen() {
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

        _onResultCallback?.call(_fullTranscript.trim());
      },
      listenMode: ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
    );
  }

  void _restartListening() {
    if (!_speech.isAvailable || !_shouldContinue) return;
    _listen();
  }

  void stopListening() {
    _shouldContinue = false;
    _speech.stop();
  }
}
