import '../errors/app_exceptions.dart';

/// Unicode-aware-ish slug generator. Latin letters pass through (with common
/// diacritics folded), everything else collapses to single dashes.
/// Throws [ValidationException] when no usable slug can be produced so
/// callers never persist an empty slug.
class SlugGenerator {
  SlugGenerator._();

  /// Common Latin diacritic fold (Dart core has no NFKD normalization).
  static const _diacriticMap = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
    'ý': 'y', 'ÿ': 'y',
    'ñ': 'n', 'ç': 'c', 'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
    'š': 's', 'ž': 'z',
  };

  static String generate(String input) {
    var text = input.trim().toLowerCase();
    text = text.split('').map((ch) => _diacriticMap[ch] ?? ch).join();
    text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    text = text.replaceAll(RegExp(r'-{2,}'), '-');
    text = text.replaceAll(RegExp(r'(^-+|-+$)'), '');
    if (text.isEmpty) {
      throw const ValidationException(
        'Could not generate a slug from the provided text.',
      );
    }
    return text;
  }
}
