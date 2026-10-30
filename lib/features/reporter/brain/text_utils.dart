// Text helpers for the reporter "brain": everything works on a NORMALIZED
// copy of what was said (lower case, no diacritics, punctuation → spaces).
//
// The normalized text has EXACTLY the same length as the original, so a match
// found in it can be cut out of the original ("o pată cât o farfurie").

const Map<String, String> _fold = <String, String>{
  'ă': 'a', 'â': 'a', 'î': 'i', 'ș': 's', 'ş': 's', 'ț': 't', 'ţ': 't', //
  'á': 'a', 'à': 'a', 'ä': 'a', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ï': 'i', 'ó': 'o', 'ö': 'o', 'ô': 'o', 'ú': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

String normalizeText(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final lower = input[i].toLowerCase();
    var c = lower.isEmpty ? ' ' : lower[0];
    c = _fold[c] ?? c;
    final code = c.codeUnitAt(0);
    final isAlnum = (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
    buffer.write(isAlnum ? c : ' ');
  }
  return buffer.toString();
}

List<String> tokensOf(String normalized) =>
    normalized.split(' ').where((token) => token.isNotEmpty).toList();

/// Number words (Romanian + English, normalized) → value. Whisper often
/// writes "poarta doisprezece" instead of "poarta 12".
const Map<String, int> kNumberWords = <String, int>{
  'unu': 1, 'doi': 2, 'doua': 2, 'trei': 3, 'patru': 4,
  'cinci': 5, 'sase': 6, 'sapte': 7, 'opt': 8, 'noua': 9, 'zece': 10,
  'unsprezece': 11, 'unspe': 11, 'doisprezece': 12, 'douasprezece': 12,
  'doispe': 12, 'treisprezece': 13, 'paisprezece': 14, 'cincisprezece': 15,
  'saisprezece': 16, 'saptesprezece': 17, 'optsprezece': 18,
  'nouasprezece': 19, 'douazeci': 20, 'treizeci': 30, //
  'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7,
  'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
  'thirteen': 13, 'fourteen': 14, 'fifteen': 15, 'sixteen': 16,
  'seventeen': 17, 'eighteen': 18, 'nineteen': 19, 'twenty': 20,
  'thirty': 30,
};

/// Alternation of the number words, longest first (regex-safe).
final String kNumberWordsPattern = (kNumberWords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length)))
    .join('|');

/// "12" → "12", "doisprezece" → "12", anything else → null.
String? numberFromToken(String token) {
  if (RegExp(r'^\d{1,3}$').hasMatch(token)) return token;
  final word = kNumberWords[token];
  return word == null ? null : '$word';
}
