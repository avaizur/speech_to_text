import 'dart:math';

class TextFormatter {
  /// Final-polish for readability:
  /// - Normalize whitespace
  /// - Add sentence-ending punctuation if missing
  /// - Capitalize first letter after sentence boundaries
  /// - Remove adjacent duplicate sentences
  /// - Group into paragraphs (2–3 sentences per paragraph)
  static String polish(String input) {
    if (input.trim().isEmpty) return "";

    // Normalize spaces/newlines
    var s = input
        .replaceAll('\u00A0', ' ') // NBSP ? space
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    // Split into sentences keeping punctuation
    final matches = RegExp(r'([^.!?]+[.!?])').allMatches(s).toList();
    if (matches.isEmpty) {
      // If no punctuation at all, chunk by ~20 words and re-run
      final words = s.split(RegExp(r'\s+'));
      for (int i = 20; i < words.length; i += 21) {
        words[i - 1] = '${words[i - 1]}.';
      }
      return polish(words.join(' '));
    }

    String normalizeSentence(String x) {
      var t = x.trim();
      if (!RegExp(r'[.!?]$').hasMatch(t)) t = '$t.';
      // Capitalize the first alphabetic character
      t = t.replaceFirstMapped(RegExp(r'^[\s"\(\[]*[a-z]'), (m) => m.group(0)!.toUpperCase());
      return t;
    }

    final sentences = matches.map((m) => normalizeSentence(m.group(1)!)).toList();

    // De-duplicate adjacent identical sentences
    final deduped = <String>[];
    for (final sent in sentences) {
      if (deduped.isEmpty || deduped.last != sent) deduped.add(sent);
    }

    // Group 2–3 sentences per paragraph
    final paras = <String>[];
    for (int i = 0; i < deduped.length;) {
      final remaining = deduped.length - i;
      final take = remaining <= 2 ? remaining : min(3, remaining);
      paras.add(deduped.sublist(i, i + take).join(' '));
      i += take;
    }

    return paras.join('\n\n').trim();
  }
}
