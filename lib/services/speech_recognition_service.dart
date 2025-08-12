import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Continuous listening service
/// - Paragraph break ONLY when pause >= 3 seconds
/// - No word-count based splits
/// - Live partial in `partialNotifier` (UI shows grey/italic)
/// - Finalized text in `transcriptNotifier` (plain, export-ready)
/// - Light HTML-entity cleanup; adds trailing punctuation to finals if missing
class SpeechRecognitionService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  // Desired state vs engine state
  bool _wantListening = false;
  bool _engineAvailable = false;

  // Transcript state
  String _fullTranscript = '';
  String _lastFinalText = '';
  DateTime _lastSpeechTime = DateTime.now();

  // Break only on long pause
  static const Duration _paragraphPause = Duration(seconds: 3);

  /// Finalized transcript (ready for export)
  final ValueNotifier<String> transcriptNotifier = ValueNotifier<String>('');

  /// Live partial text (preview only)
  final ValueNotifier<String> partialNotifier = ValueNotifier<String>('');

  Future<void> initSpeech() async {
    try {
      _engineAvailable = await _speech.initialize(
        onStatus: _onStatus,
        onError: (e) => debugPrint('Speech error: $e'),
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
      _engineAvailable = false;
    }
  }

  void startListening() {
    _wantListening = true;
    // Keep cumulative transcript between sessions; uncomment to start fresh each time:
    // _resetTranscript();
    if (_engineAvailable) _listen();
  }

  void stopListening() {
    _wantListening = false;
    partialNotifier.value = '';
    _speech.stop();
  }

  void cancelListening() {
    _wantListening = false;
    partialNotifier.value = '';
    _speech.cancel();
  }

  void _resetTranscript() {
    _fullTranscript = '';
    _lastFinalText = '';
    transcriptNotifier.value = '';
    partialNotifier.value = '';
  }

  void _onStatus(String status) {
    if (status == 'notListening' && _wantListening) {
      _listen();
    }
  }

  void _listen() {
    _speech.listen(
      onResult: (result) {
        final now = DateTime.now();
        final recognized = result.recognizedWords.trim();
        if (recognized.isEmpty) return;

        final pauseDuration = now.difference(_lastSpeechTime);
        final shouldBreakParagraph = pauseDuration >= _paragraphPause;

        if (result.finalResult) {
          _applyFinal(recognized, shouldBreakParagraph);
          partialNotifier.value = '';
        } else {
          _applyPartial(recognized);
        }

        _lastSpeechTime = now;
      },
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: false,
    );
  }

  void _applyFinal(String text, bool breakParagraph) {
    final clean = _cleanText(text, ensureSentencePunctuation: true);

    if (breakParagraph && _fullTranscript.isNotEmpty) {
      _fullTranscript += '\n\n';
    } else if (_fullTranscript.isNotEmpty &&
        !_fullTranscript.endsWith('\n\n') &&
        !_fullTranscript.endsWith(' ')) {
      _fullTranscript += ' ';
    }

    _fullTranscript += clean;
    _lastFinalText = clean;

    transcriptNotifier.value = _fullTranscript;
  }

  void _applyPartial(String recognized) {
    // Show only the delta after last finalized text if possible
    String live = recognized;
    if (_lastFinalText.isNotEmpty && recognized.startsWith(_lastFinalText)) {
      live = recognized.substring(_lastFinalText.length).trimLeft();
    }
    // Clean up entities/spacing, but don't force trailing punctuation on partials
    live = _cleanText(live, ensureSentencePunctuation: false);
    partialNotifier.value = live;
  }

  String _cleanText(String input, {required bool ensureSentencePunctuation}) {
    if (input.isEmpty) return input;

    var s = input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (ensureSentencePunctuation && s.isNotEmpty && !RegExp(r'[.?!…]$').hasMatch(s)) {
      s = '$s.';
    }
    return s;
    }
}
