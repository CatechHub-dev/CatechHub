/// Formattazione nomi e cognomi (es. "mario rossi" → "Mario Rossi").
class NameFormatting {
  static String capitalizeWords(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;

    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          if (word.length == 1) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }
}
