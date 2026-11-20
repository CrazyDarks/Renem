import '../models/supported_languages.dart';

/// Writing script categories used for instant, zero-API-cost validation of
/// vocabulary input against the active target language.
enum WritingScript {
  latin('script_latin'),
  cyrillic('script_cyrillic'),
  greek('script_greek'),
  arabic('script_arabic'),
  hebrew('script_hebrew'),
  cjk('script_cjk'),
  japaneseKana('script_japanese'),
  hangul('script_korean'),
  devanagari('script_devanagari'),
  bengali('script_bengali'),
  gurmukhi('script_gurmukhi'),
  gujarati('script_gujarati'),
  tamil('script_tamil'),
  telugu('script_telugu'),
  kannada('script_kannada'),
  malayalam('script_malayalam'),
  sinhala('script_sinhala'),
  thai('script_thai'),
  lao('script_lao'),
  myanmar('script_myanmar'),
  khmer('script_khmer'),
  georgian('script_georgian'),
  armenian('script_armenian'),
  ethiopic('script_ethiopic');

  const WritingScript(this.l10nKey);
  final String l10nKey;
}

class ScriptValidationResult {
  const ScriptValidationResult({
    required this.isCompatible,
    this.detectedUnexpectedScript,
    this.expectedScripts = const {},
    this.isMixedToken = false,
  });

  final bool isCompatible;
  final WritingScript? detectedUnexpectedScript;
  final Set<WritingScript> expectedScripts;
  final bool isMixedToken;

  static const ScriptValidationResult compatible =
      ScriptValidationResult(isCompatible: true);
}

/// Validates locally whether an entered word or phrase uses a writing script
/// compatible with the target language before sending any AI/translation call.
class WordScriptValidator {
  const WordScriptValidator._();

  static const Map<String, Set<WritingScript>> _nonLatinLanguageScripts = {
    // Cyrillic languages
    'uk': {WritingScript.cyrillic},
    'be': {WritingScript.cyrillic},
    'bg': {WritingScript.cyrillic},
    'mk': {WritingScript.cyrillic},
    'kk': {WritingScript.cyrillic},
    'ky': {WritingScript.cyrillic},
    'tg': {WritingScript.cyrillic},
    'mn': {WritingScript.cyrillic},
    'ru': {WritingScript.cyrillic},

    // Dual-script languages
    'sr': {WritingScript.cyrillic, WritingScript.latin},
    'uz': {WritingScript.latin, WritingScript.cyrillic},
    'ku': {WritingScript.latin, WritingScript.arabic},
    'pa': {WritingScript.gurmukhi, WritingScript.arabic},

    // Greek, Armenian, Georgian
    'el': {WritingScript.greek},
    'hy': {WritingScript.armenian},
    'ka': {WritingScript.georgian},

    // Semitic / RTL scripts
    'ar': {WritingScript.arabic},
    'fa': {WritingScript.arabic},
    'ur': {WritingScript.arabic},
    'ps': {WritingScript.arabic},
    'he': {WritingScript.hebrew},
    'yi': {WritingScript.hebrew},
    'am': {WritingScript.ethiopic},

    // East Asian scripts
    'ja': {WritingScript.japaneseKana, WritingScript.cjk},
    'zh': {WritingScript.cjk},
    'zh-tw': {WritingScript.cjk},
    'ko': {WritingScript.hangul, WritingScript.cjk},

    // South & Southeast Asian scripts
    'hi': {WritingScript.devanagari},
    'mr': {WritingScript.devanagari},
    'ne': {WritingScript.devanagari},
    'bn': {WritingScript.bengali},
    'gu': {WritingScript.gujarati},
    'ta': {WritingScript.tamil},
    'te': {WritingScript.telugu},
    'kn': {WritingScript.kannada},
    'ml': {WritingScript.malayalam},
    'si': {WritingScript.sinhala},
    'th': {WritingScript.thai},
    'lo': {WritingScript.lao},
    'my': {WritingScript.myanmar},
    'km': {WritingScript.khmer},
  };

  /// Returns the allowed [WritingScript] set for [langCode].
  static Set<WritingScript> expectedScriptsForLanguage(String langCode) {
    final normalized = langCode.trim().toLowerCase();
    return _nonLatinLanguageScripts[normalized] ?? const {WritingScript.latin};
  }

  /// Classifies a Unicode scalar value [rune] into its [WritingScript], or
  /// returns `null` for neutral characters (spaces, digits, punctuation, etc.).
  static WritingScript? detectRuneScript(int rune) {
    // Basic Latin letters + Latin-1 Supplement + Latin Extended-A/B + Extended Additional
    if ((rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A) ||
        (rune >= 0x00C0 && rune <= 0x00D6) ||
        (rune >= 0x00D8 && rune <= 0x00F6) ||
        (rune >= 0x00F8 && rune <= 0x024F) ||
        (rune >= 0x1E00 && rune <= 0x1EFF)) {
      return WritingScript.latin;
    }

    // Greek and Coptic + Greek Extended
    if ((rune >= 0x0370 && rune <= 0x03FF) ||
        (rune >= 0x1F00 && rune <= 0x1FFF)) {
      return WritingScript.greek;
    }

    // Cyrillic + Cyrillic Supplement
    if (rune >= 0x0400 && rune <= 0x052F) {
      return WritingScript.cyrillic;
    }

    // Armenian
    if (rune >= 0x0530 && rune <= 0x058F) {
      return WritingScript.armenian;
    }

    // Hebrew
    if (rune >= 0x0590 && rune <= 0x05FF) {
      return WritingScript.hebrew;
    }

    // Arabic (excluding Arabic-Indic digits and punctuation)
    if ((rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0x08A0 && rune <= 0x08FF) ||
        (rune >= 0xFB50 && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF)) {
      if ((rune >= 0x0660 && rune <= 0x0669) ||
          (rune >= 0x06F0 && rune <= 0x06F9) ||
          rune == 0x060C ||
          rune == 0x061B ||
          rune == 0x061F) {
        return null;
      }
      return WritingScript.arabic;
    }

    // Devanagari (Hindi, Marathi, Nepali)
    if (rune >= 0x0900 && rune <= 0x097F) {
      if (rune >= 0x0966 && rune <= 0x096F) return null;
      return WritingScript.devanagari;
    }

    // Bengali
    if (rune >= 0x0980 && rune <= 0x09FF) {
      if (rune >= 0x09E6 && rune <= 0x09EF) return null;
      return WritingScript.bengali;
    }

    // Gurmukhi (Punjabi)
    if (rune >= 0x0A00 && rune <= 0x0A7F) {
      if (rune >= 0x0A66 && rune <= 0x0A6F) return null;
      return WritingScript.gurmukhi;
    }

    // Gujarati
    if (rune >= 0x0A80 && rune <= 0x0AFF) {
      if (rune >= 0x0AE6 && rune <= 0x0AEF) return null;
      return WritingScript.gujarati;
    }

    // Tamil
    if (rune >= 0x0B80 && rune <= 0x0BFF) {
      return WritingScript.tamil;
    }

    // Telugu
    if (rune >= 0x0C00 && rune <= 0x0C7F) {
      return WritingScript.telugu;
    }

    // Kannada
    if (rune >= 0x0C80 && rune <= 0x0CFF) {
      return WritingScript.kannada;
    }

    // Malayalam
    if (rune >= 0x0D00 && rune <= 0x0D7F) {
      return WritingScript.malayalam;
    }

    // Sinhala
    if (rune >= 0x0D80 && rune <= 0x0DFF) {
      return WritingScript.sinhala;
    }

    // Thai
    if (rune >= 0x0E00 && rune <= 0x0E7F) {
      if (rune >= 0x0E50 && rune <= 0x0E59) return null;
      return WritingScript.thai;
    }

    // Lao
    if (rune >= 0x0E80 && rune <= 0x0EFF) {
      if (rune >= 0x0ED0 && rune <= 0x0ED9) return null;
      return WritingScript.lao;
    }

    // Myanmar
    if (rune >= 0x1000 && rune <= 0x109F) {
      if (rune >= 0x1040 && rune <= 0x1049) return null;
      return WritingScript.myanmar;
    }

    // Georgian
    if ((rune >= 0x10A0 && rune <= 0x10FF) ||
        (rune >= 0x1C90 && rune <= 0x1CBF)) {
      return WritingScript.georgian;
    }

    // Ethiopic (Amharic)
    if (rune >= 0x1200 && rune <= 0x137F) {
      return WritingScript.ethiopic;
    }

    // Khmer
    if (rune >= 0x1780 && rune <= 0x17FF) {
      if (rune >= 0x17E0 && rune <= 0x17E9) return null;
      return WritingScript.khmer;
    }

    // Japanese Hiragana / Katakana
    if ((rune >= 0x3040 && rune <= 0x309F) ||
        (rune >= 0x30A0 && rune <= 0x30FF) ||
        (rune >= 0xFF65 && rune <= 0xFF9F)) {
      return WritingScript.japaneseKana;
    }

    // Korean Hangul
    if ((rune >= 0xAC00 && rune <= 0xD7AF) ||
        (rune >= 0x1100 && rune <= 0x11FF) ||
        (rune >= 0x3130 && rune <= 0x318F)) {
      return WritingScript.hangul;
    }

    // CJK Unified Ideographs
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      return WritingScript.cjk;
    }

    return null;
  }

  /// Checks whether [text] matches the expected writing script(s) of
  /// [targetLangCode].
  ///
  /// - Ignores punctuation, digits, and whitespace.
  /// - Detects full script mismatch (e.g. Cyrillic entered for a Latin language
  ///   or Latin entered for a Cyrillic/Arabic/CJK language).
  /// - Detects mixed-alphabet typos inside a single word token (e.g. Cyrillic
  ///   lookalike letter inside a Latin word).
  static ScriptValidationResult validate({
    required String text,
    required String targetLangCode,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return ScriptValidationResult.compatible;

    final expected = expectedScriptsForLanguage(targetLangCode);
    var allowedLetters = 0;
    var disallowedLetters = 0;
    final disallowedCounts = <WritingScript, int>{};

    var tokenHasAllowed = false;
    var tokenHasDisallowed = false;
    var hasMixedToken = false;

    for (final rune in trimmed.runes) {
      final script = detectRuneScript(rune);
      if (script == null) {
        // Separator (space, hyphen, punctuation, digit) resets token tracking
        tokenHasAllowed = false;
        tokenHasDisallowed = false;
        continue;
      }

      if (expected.contains(script)) {
        allowedLetters++;
        tokenHasAllowed = true;
      } else {
        disallowedLetters++;
        tokenHasDisallowed = true;
        disallowedCounts[script] = (disallowedCounts[script] ?? 0) + 1;
      }

      if (tokenHasAllowed && tokenHasDisallowed) {
        hasMixedToken = true;
      }
    }

    if (disallowedLetters == 0) {
      return ScriptValidationResult.compatible;
    }

    WritingScript? dominantUnexpected;
    var bestCount = -1;
    for (final entry in disallowedCounts.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        dominantUnexpected = entry.key;
      }
    }

    final isLatinOnlyTarget =
        expected.length == 1 && expected.contains(WritingScript.latin);

    // Mismatch conditions:
    // 1. No allowed letters at all (100% wrong script).
    // 2. A single word mixes allowed and disallowed letters (keyboard layout typo).
    // 3. Target is Latin-only and any non-Latin letter appears.
    // 4. Target is non-Latin and disallowed letters make up at least half the text.
    final isMismatch = allowedLetters == 0 ||
        hasMixedToken ||
        isLatinOnlyTarget ||
        disallowedLetters >= allowedLetters;

    if (!isMismatch) {
      return ScriptValidationResult.compatible;
    }

    return ScriptValidationResult(
      isCompatible: false,
      detectedUnexpectedScript: dominantUnexpected,
      expectedScripts: expected,
      isMixedToken: hasMixedToken,
    );
  }

  static const Set<String> _genericLanguageFillers = {
    'мова',
    'мови',
    'мовою',
    'language',
    'lang',
    'variant',
    'dialect',
    'варіант',
    'діалект',
    'форма',
    'sprache',
    'langue',
    'idioma',
    'lingua',
    'język',
    'jazyk',
    'язык',
    'زبان',
    'simplified',
    'traditional',
    'спрощена',
    'традиційна',
    'te',
    'reo',
    'bahasa',
    'harshen',
    'asụsụ',
    'èdè',
    'тілі',
  };

  /// Extra world-language names not present in [supportedLanguages] so
  /// mismatches (e.g. Russian entered for Ukrainian/Polish/Czech) are caught
  /// universally without hardcoding any single target language.
  static const List<List<String>> _extraKnownLanguageAliases = [
    ['russian', 'російська', 'русский', 'русская'],
  ];

  /// Normalizes an ISO 639 language code (handling common aliases & regions).
  static String normalizeLanguageCode(String rawCode) {
    final cleaned = rawCode.trim().toLowerCase().replaceAll('_', '-');
    if (cleaned.isEmpty) return '';
    if (cleaned == 'zh-tw' || cleaned == 'zh-hant') return 'zh-tw';
    if (cleaned == 'zh-cn' || cleaned == 'zh-hans' || cleaned == 'zh-sg') {
      return 'zh';
    }
    final base = cleaned.split('-').first;
    switch (base) {
      case 'nb':
      case 'nn':
        return 'no';
      case 'fil':
        return 'tl';
      case 'iw':
        return 'he';
      case 'in':
        return 'id';
      default:
        return base;
    }
  }

  /// Universally checks whether AI-reported [detectedLanguage] (and optional
  /// ISO [detectedLanguageCode]) corresponds to [targetLang].
  ///
  /// Works across all 90+ languages in [supportedLanguages] without hardcoding
  /// any single language pair.
  static bool doesDetectedLanguageMatchTarget({
    required String detectedLanguage,
    String detectedLanguageCode = '',
    required LanguageOption targetLang,
    String? localizedTargetName,
  }) {
    final normDetectedCode = normalizeLanguageCode(detectedLanguageCode);
    final normTargetCode = normalizeLanguageCode(targetLang.code);

    if (normDetectedCode.isNotEmpty &&
        RegExp(r'^[a-z]{2,3}(-[a-z]{2})?$').hasMatch(normDetectedCode)) {
      if (normDetectedCode == normTargetCode) {
        return true;
      }
      // Handle Chinese variants gracefully when base matches
      if (normTargetCode == 'zh-tw' && normDetectedCode == 'zh') {
        return true;
      }
      return false;
    }

    final detectedWords = _extractSignificantWords(detectedLanguage);
    if (detectedWords.isEmpty) return true;

    if (_wordsMatchLanguageOption(
      detectedWords,
      targetLang,
      extraName: localizedTargetName,
    )) {
      return true;
    }

    // If detected words clearly name another known language, flag mismatch.
    for (final lang in supportedLanguages) {
      if (normalizeLanguageCode(lang.code) == normTargetCode) continue;
      if (_wordsMatchLanguageOption(detectedWords, lang)) {
        return false;
      }
    }

    for (final aliasGroup in _extraKnownLanguageAliases) {
      if (_wordsMatchReferenceTokens(detectedWords, aliasGroup)) {
        return false;
      }
    }

    return true;
  }

  static List<String> _extractSignificantWords(String raw) {
    return raw
        .toLowerCase()
        .split(RegExp(r'[^\p{L}]+', unicode: true))
        .where((w) => w.length >= 2 && !_genericLanguageFillers.contains(w))
        .toList();
  }

  static bool _wordsMatchLanguageOption(
    List<String> detectedWords,
    LanguageOption lang, {
    String? extraName,
  }) {
    final refWords = <String>[
      ..._extractSignificantWords(lang.englishName),
      ..._extractSignificantWords(lang.nameUk),
      ..._extractSignificantWords(lang.nativeName),
      if (extraName != null && extraName.isNotEmpty)
        ..._extractSignificantWords(extraName),
    ];
    return _wordsMatchReferenceTokens(detectedWords, refWords);
  }

  static bool _wordsMatchReferenceTokens(
    List<String> detectedWords,
    List<String> referenceWords,
  ) {
    for (final d in detectedWords) {
      for (final r in referenceWords) {
        if (_tokenMatches(d, r)) return true;
      }
    }
    return false;
  }

  static bool _tokenMatches(String a, String b) {
    if (a == b) return true;
    if (a.length < 5 || b.length < 5) return false;
    if ((a.length - b.length).abs() > 2) return false;

    final minLen = a.length < b.length ? a.length : b.length;
    var commonPrefix = 0;
    while (commonPrefix < minLen && a.codeUnitAt(commonPrefix) == b.codeUnitAt(commonPrefix)) {
      commonPrefix++;
    }
    return commonPrefix >= minLen - 1 && commonPrefix >= 4;
  }
}
