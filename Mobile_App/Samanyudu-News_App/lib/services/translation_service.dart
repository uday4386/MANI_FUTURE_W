import 'package:translator/translator.dart';
import 'package:flutter/foundation.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();
  static final Map<String, String> _cache = {};

  /// Normalizes language input to a standard code ('te' or 'en').
  static String normalizeLanguage(String lang) {
    if (lang.isEmpty) return 'en';
    final l = lang.toLowerCase();
    if (l.contains('telugu') || l.contains('తెలుగు')) return 'te';
    if (l.contains('english') || l.contains('ఇంగ్లీష్')) return 'en';
    return l;
  }

  /// Translates text to the target language with caching.
  static Future<String> translate(String text, {required String to}) async {
    if (text.isEmpty) return text;
    
    final targetCode = normalizeLanguage(to);
    final cacheKey = "${targetCode}_$text";
    
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    int retries = 3;
    for (int i = 0; i < retries; i++) {
      try {
        final translation = await _translator.translate(text, to: targetCode);
        String result = translation.text;
        
        if (targetCode == 'te') {
          result = result.replaceAll(RegExp(r'YouTube', caseSensitive: false), 'యూట్యూబ్');
        }

        _cache[cacheKey] = result;
        return result;
      } catch (e) {
        if (i == retries - 1) {
          debugPrint("Translation failed after $retries attempts ($to): $e");
          return text;
        }
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
    return text;
  }

  /// Clears the translation cache.
  static void clearCache() {
    _cache.clear();
  }
}
