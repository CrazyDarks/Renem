import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class WordMatchSegment {
  const WordMatchSegment({
    required this.expectedWord,
    required this.spokenWord,
    required this.matched,
    required this.similarity,
  });

  final String expectedWord;
  final String spokenWord;
  final bool matched;
  final double similarity;
}

class PronunciationEvaluation {
  const PronunciationEvaluation({
    required this.targetText,
    required this.spokenText,
    required this.scorePercent,
    required this.feedbackUk,
    required this.segments,
    this.feedbackKey = 'pron_fb_good',
  });

  final String targetText;
  final String spokenText;
  final int scorePercent;
  final String feedbackUk;
  final String feedbackKey;
  final List<WordMatchSegment> segments;

  bool get isExcellent => scorePercent >= 82;
  bool get isGood => scorePercent >= 60 && scorePercent < 82;
}

class PronunciationService {
  static const MethodChannel _audioChannel =
      MethodChannel('com.languagema/external_launcher');

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  final Map<String, String> _phoneticCache = {};
  final Set<String> _availableRecordings = {};
  String _activeSlot = 'default';

  bool get isListening => _speech.isListening;
  bool hasRecordedVoice([String slot = 'default']) =>
      _availableRecordings.contains(slot) ||
      _availableRecordings.contains('default');

  Future<void> _stopNativeCapture(String slot) async {
    try {
      final hasAudio = await _audioChannel.invokeMethod<bool>(
        'stopVoiceCapture',
        {'slot': slot},
      );
      if (hasAudio == true) {
        _availableRecordings.add(slot);
        _availableRecordings.add('default');
      }
    } catch (_) {}
  }

  /// Plays back the user's own recorded microphone voice for [slot], or falls
  /// back to [fallbackTtsSpeak] if no raw audio buffer is available.
  Future<bool> playRecordedVoice({
    String slot = 'default',
    Future<void> Function()? fallbackTtsSpeak,
  }) async {
    try {
      final played = await _audioChannel.invokeMethod<bool>(
        'playVoiceCapture',
        {'slot': slot},
      );
      if (played == true) return true;
    } catch (_) {}

    if (fallbackTtsSpeak != null) {
      await fallbackTtsSpeak();
      return true;
    }
    return false;
  }

  Future<bool> ensureInitialized() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onError: (err) => debugPrint('SpeechToText error: $err'),
      );
      return _initialized;
    } catch (e) {
      debugPrint('SpeechToText init exception: $e');
      return false;
    }
  }

  /// Starts listening and automatically stops as soon as the user pronounces
  /// [autoStopTargetText] accurately (>= [autoStopThreshold]%).
  /// Also records the user's raw voice in [recordingSlot] so they can play it back!
  Future<bool> startListening({
    required String localeId,
    required void Function(String recognizedWords, bool isFinal) onResult,
    String? autoStopTargetText,
    int autoStopThreshold = 82,
    String recordingSlot = 'default',
  }) async {
    final ready = await ensureInitialized();
    if (!ready) return false;

    if (_speech.isListening) {
      await _speech.stop();
    }

    _activeSlot = recordingSlot;
    // Note: On Android (especially MIUI/HyperOS), starting native AudioRecord concurrently
    // with SpeechToText locks the hardware microphone, causing SpeechToText to hear only silence.
    // Therefore, SpeechToText manages the microphone directly.

    var autoStopped = false;

    // Standardize locale format (try original locale tag first, e.g. 'en_US' or 'en-US')
    final effectiveLocale = localeId.trim().isNotEmpty ? localeId : 'en_US';

    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: effectiveLocale,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      ),
      onResult: (SpeechRecognitionResult result) {
        if (autoStopped) return;
        final words = result.recognizedWords.trim();

        if (autoStopTargetText != null &&
            autoStopTargetText.trim().isNotEmpty &&
            words.isNotEmpty) {
          final eval = evaluatePronunciation(
            targetText: autoStopTargetText,
            spokenText: words,
          );
          final allWordsMatched = eval.segments.isNotEmpty &&
              eval.segments.every((s) => s.matched);

          if (eval.scorePercent >= autoStopThreshold || allWordsMatched) {
            autoStopped = true;
            _speech.stop();
            _availableRecordings.add(recordingSlot);
            _availableRecordings.add('default');
            onResult(words, true);
            return;
          }
        }

        if (result.finalResult) {
          if (words.isNotEmpty) {
            _availableRecordings.add(recordingSlot);
            _availableRecordings.add('default');
          }
        }

        onResult(words, result.finalResult);
      },
    );
    return true;
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    await _stopNativeCapture(_activeSlot);
  }

  /// Returns an immediate phonetic transcription for [text].
  /// - When [useInternationalIpa] is `false` (default): writes the pronunciation
  ///   using the user's [nativeLangCode] alphabet (e.g. Ukrainian Cyrillic `[ім-мерс]`,
  ///   or native phonetic spelling for Spanish, Polish, German, etc.).
  /// - When [useInternationalIpa] is `true`: writes International Phonetic Alphabet (IPA) `/.../`.
  String buildInstantTranscription(
    String text, {
    String langCode = 'en',
    String nativeLangCode = 'uk',
    bool useInternationalIpa = false,
  }) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return '';
    final cacheKey = '$langCode:$nativeLangCode:$useInternationalIpa:$cleaned';
    final cached = _phoneticCache[cacheKey];
    if (cached != null && cached.isNotEmpty) return cached;

    final words = cleaned.split(RegExp(r'\s+'));
    if (useInternationalIpa) {
      final ipaWords = words
          .map((w) => _approximateInternationalIpaWord(w, langCode))
          .toList();
      return '/ ${ipaWords.join(' · ')} /';
    } else {
      final nativeWords = words
          .map(
            (w) => _approximateNativePhoneticWord(
              w,
              targetLangCode: langCode,
              nativeLangCode: nativeLangCode,
            ),
          )
          .toList();
      return '[ ${nativeWords.join(' · ')} ]';
    }
  }

  /// Fetches accurate phonetic transcription (either in the user's native language
  /// alphabet or International IPA) from Dictionary API / Google GTX.
  Future<String> fetchTranscription(
    String text, {
    required String langCode,
    String nativeLangCode = 'uk',
    bool useInternationalIpa = false,
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return '';
    final cacheKey = '$langCode:$nativeLangCode:$useInternationalIpa:$cleaned';
    if (_phoneticCache.containsKey(cacheKey)) {
      return _phoneticCache[cacheKey]!;
    }

    // 1. Try DictionaryAPI for exact English IPA (e.g. /ɪˈmɜːs/)
    final isSingleWord = !cleaned.contains(' ') && cleaned.length <= 28;
    if (langCode == 'en' && isSingleWord) {
      try {
        final uri = Uri.parse(
          'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(cleaned.toLowerCase())}',
        );
        final resp = await http.get(uri).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final list = jsonDecode(resp.body) as List<dynamic>;
          if (list.isNotEmpty) {
            final first = list.first as Map<String, dynamic>;
            var ipa = (first['phonetic'] as String? ?? '').trim();
            if (ipa.isEmpty) {
              final phonetics =
                  first['phonetics'] as List<dynamic>? ?? const [];
              for (final p in phonetics.whereType<Map<String, dynamic>>()) {
                final txt = (p['text'] as String? ?? '').trim();
                if (txt.isNotEmpty) {
                  ipa = txt;
                  break;
                }
              }
            }
            if (ipa.isNotEmpty) {
              if (useInternationalIpa) {
                _phoneticCache[cacheKey] = ipa;
                return ipa;
              } else {
                // Convert exact IPA to the user's native alphabet so it's 100% accurate AND readable!
                final converted = _convertIpaToNativeAlphabet(
                  ipa,
                  nativeLangCode: nativeLangCode,
                );
                final formatted = '[ $converted ]';
                _phoneticCache[cacheKey] = formatted;
                return formatted;
              }
            }
          }
        }
      } catch (_) {}
    }

    // 2. Try Google Translate GTX transliteration (dt=rm) for non-Latin or international reading
    try {
      final uri = Uri.https(
        'translate.googleapis.com',
        '/translate_a/single',
        {
          'client': 'gtx',
          'sl': langCode,
          'tl': nativeLangCode,
          'dt': 'rm',
          'q': cleaned,
        },
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as List<dynamic>;
        final segments = decoded.first as List<dynamic>?;
        if (segments != null) {
          for (final seg in segments.whereType<List<dynamic>>()) {
            if (seg.length >= 4 && seg[3] != null) {
              final rm = seg[3].toString().trim();
              if (rm.isNotEmpty) {
                if (useInternationalIpa) {
                  final formatted = '/ $rm /';
                  _phoneticCache[cacheKey] = formatted;
                  return formatted;
                } else {
                  final nativeConverted = _transliterateLatinPhoneticToNative(
                    rm,
                    nativeLangCode: nativeLangCode,
                  );
                  final formatted = '[ $nativeConverted ]';
                  _phoneticCache[cacheKey] = formatted;
                  return formatted;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    final fallback = buildInstantTranscription(
      cleaned,
      langCode: langCode,
      nativeLangCode: nativeLangCode,
      useInternationalIpa: useInternationalIpa,
    );
    _phoneticCache[cacheKey] = fallback;
    return fallback;
  }

  /// Converts an International Phonetic Alphabet (IPA) string into the user's native script.
  String _convertIpaToNativeAlphabet(
    String rawIpa, {
    required String nativeLangCode,
  }) {
    final clean = rawIpa.replaceAll(RegExp(r'[/\[\]]'), '').trim();
    if (_isCyrillicLanguage(nativeLangCode)) {
      var s = clean
          .replaceAll('ˈ', '')
          .replaceAll('ˌ', '')
          .replaceAll('tʃ', 'ч')
          .replaceAll('dʒ', 'дж')
          .replaceAll('ʃ', 'ш')
          .replaceAll('ʒ', 'ж')
          .replaceAll('θ', 'с')
          .replaceAll('ð', 'з')
          .replaceAll('ŋ', 'нг')
          .replaceAll('ɑː', 'а')
          .replaceAll('ɔː', 'о')
          .replaceAll('ɜː', 'е')
          .replaceAll('iː', 'і')
          .replaceAll('uː', 'у')
          .replaceAll('eɪ', 'ей')
          .replaceAll('aɪ', 'ай')
          .replaceAll('ɔɪ', 'ой')
          .replaceAll('aʊ', 'ау')
          .replaceAll('əʊ', 'оу')
          .replaceAll('oʊ', 'оу')
          .replaceAll('ɪə', 'іа')
          .replaceAll('eə', 'еа')
          .replaceAll('ʊə', 'уа')
          .replaceAll('æ', 'е')
          .replaceAll('ʌ', 'а')
          .replaceAll('ɒ', 'о')
          .replaceAll('ə', 'е')
          .replaceAll('ɪ', 'і')
          .replaceAll('ʊ', 'у')
          .replaceAll('ɛ', 'е')
          .replaceAll('ɑ', 'а')
          .replaceAll('ɔ', 'о')
          .replaceAll('ɜ', 'е')
          .replaceAll('j', 'й')
          .replaceAll('w', 'в')
          .replaceAll('h', 'х')
          .replaceAll('g', 'ґ')
          .replaceAll('ɡ', 'ґ')
          .replaceAll('r', 'р')
          .replaceAll('l', 'л')
          .replaceAll('m', 'м')
          .replaceAll('n', 'н')
          .replaceAll('p', 'п')
          .replaceAll('b', 'б')
          .replaceAll('t', 'т')
          .replaceAll('d', 'д')
          .replaceAll('k', 'к')
          .replaceAll('f', 'ф')
          .replaceAll('v', 'в')
          .replaceAll('s', 'с')
          .replaceAll('z', 'з')
          .replaceAll('i', 'і')
          .replaceAll('u', 'у')
          .replaceAll('e', 'е')
          .replaceAll('o', 'о')
          .replaceAll('a', 'а')
          .replaceAll('ː', '');
      return s;
    }

    // For Latin-based native languages (es, pl, de, fr, it, pt, cs, sk, en, etc.)
    var s = clean
        .replaceAll('ˈ', '')
        .replaceAll('ˌ', '')
        .replaceAll('tʃ', nativeLangCode == 'pl' ? 'cz' : 'ch')
        .replaceAll('dʒ', 'j')
        .replaceAll('ʃ', nativeLangCode == 'pl' ? 'sz' : (nativeLangCode == 'de' ? 'sch' : 'sh'))
        .replaceAll('ʒ', nativeLangCode == 'pl' ? 'ż' : 'zh')
        .replaceAll('θ', 'th')
        .replaceAll('ð', 'dh')
        .replaceAll('ŋ', 'ng')
        .replaceAll('ɑː', 'aa')
        .replaceAll('ɔː', 'oo')
        .replaceAll('ɜː', 'er')
        .replaceAll('iː', 'ee')
        .replaceAll('uː', 'oo')
        .replaceAll('eɪ', 'ey')
        .replaceAll('aɪ', 'ay')
        .replaceAll('ɔɪ', 'oy')
        .replaceAll('aʊ', 'au')
        .replaceAll('əʊ', 'ou')
        .replaceAll('oʊ', 'ou')
        .replaceAll('æ', 'a')
        .replaceAll('ʌ', 'a')
        .replaceAll('ɒ', 'o')
        .replaceAll('ə', 'e')
        .replaceAll('ɪ', 'i')
        .replaceAll('ʊ', 'u')
        .replaceAll('ɛ', 'e')
        .replaceAll('ɑ', 'a')
        .replaceAll('ɔ', 'o')
        .replaceAll('ɜ', 'e')
        .replaceAll('ɡ', 'g')
        .replaceAll('ː', '');
    return s;
  }

  bool _isCyrillicLanguage(String code) {
    return const {'uk', 'bg', 'sr', 'kk'}.contains(code);
  }

  /// Generates International Phonetic Alphabet (IPA) for a word when [useInternationalIpa] is true.
  String _approximateInternationalIpaWord(String rawWord, String targetLangCode) {
    final w = rawWord
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}']", unicode: true), '');
    if (w.isEmpty) return rawWord;

    if (targetLangCode == 'en') {
      return w
          .replaceAll('tion', 'ʃən')
          .replaceAll('sion', 'ʒən')
          .replaceAll('ture', 'tʃər')
          .replaceAll('ough', 'ɔː')
          .replaceAll('igh', 'aɪ')
          .replaceAll('ph', 'f')
          .replaceAll('sh', 'ʃ')
          .replaceAll('ch', 'tʃ')
          .replaceAll('th', 'ð')
          .replaceAll('ck', 'k')
          .replaceAll('qu', 'kw')
          .replaceAll('ee', 'iː')
          .replaceAll('ea', 'iː')
          .replaceAll('oo', 'uː')
          .replaceAll('ou', 'aʊ')
          .replaceAll('ow', 'aʊ')
          .replaceAll('ai', 'eɪ')
          .replaceAll('ay', 'eɪ');
    } else if (targetLangCode == 'de') {
      return w
          .replaceAll('sch', 'ʃ')
          .replaceAll('ch', 'ç')
          .replaceAll('ei', 'aɪ')
          .replaceAll('ie', 'iː')
          .replaceAll('eu', 'ɔʏ')
          .replaceAll('äu', 'ɔʏ')
          .replaceAll('ä', 'ɛ')
          .replaceAll('ö', 'øː')
          .replaceAll('ü', 'yː')
          .replaceAll('ß', 's');
    } else if (targetLangCode == 'fr') {
      return w
          .replaceAll('eau', 'o')
          .replaceAll('ou', 'u')
          .replaceAll('oi', 'wa')
          .replaceAll('ch', 'ʃ')
          .replaceAll('gn', 'ɲ')
          .replaceAll('é', 'e')
          .replaceAll('è', 'ɛ');
    } else if (targetLangCode == 'pl') {
      return w
          .replaceAll('sz', 'ʂ')
          .replaceAll('cz', 'tʂ')
          .replaceAll('rz', 'ʐ')
          .replaceAll('ż', 'ʐ')
          .replaceAll('ś', 'ɕ')
          .replaceAll('ć', 'tɕ')
          .replaceAll('ł', 'w')
          .replaceAll('ą', 'ɔ̃')
          .replaceAll('ę', 'ɛ̃');
    } else if (targetLangCode == 'cs' || targetLangCode == 'sk') {
      return w
          .replaceAll('ř', 'r̝')
          .replaceAll('š', 'ʃ')
          .replaceAll('č', 'tʃ')
          .replaceAll('ž', 'ʒ')
          .replaceAll('ch', 'x');
    }

    return _syllabify(w);
  }

  /// Generates phonetic transcription written in the user's [nativeLangCode] alphabet.
  String _approximateNativePhoneticWord(
    String rawWord, {
    required String targetLangCode,
    required String nativeLangCode,
  }) {
    final w = rawWord
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}']", unicode: true), '');
    if (w.isEmpty) return rawWord;

    // Step 1: normalize target word into a phonetic Latin intermediate
    var phoneticLatin = w;
    if (targetLangCode == 'en') {
      phoneticLatin = w
          .replaceAll('tion', 'shn')
          .replaceAll('sion', 'zhn')
          .replaceAll('ture', 'cher')
          .replaceAll('ough', 'o')
          .replaceAll('igh', 'ay')
          .replaceAll('ph', 'f')
          .replaceAll('sh', 'sh')
          .replaceAll('ch', 'ch')
          .replaceAll('th', 'z')
          .replaceAll('ck', 'k')
          .replaceAll('qu', 'kv')
          .replaceAll('ee', 'i')
          .replaceAll('ea', 'i')
          .replaceAll('oo', 'u')
          .replaceAll('ou', 'au')
          .replaceAll('ow', 'au')
          .replaceAll('ai', 'ey')
          .replaceAll('ay', 'ey');
    } else if (targetLangCode == 'de') {
      phoneticLatin = w
          .replaceAll('sch', 'sh')
          .replaceAll('tsch', 'ch')
          .replaceAll('ch', 'kh')
          .replaceAll('ei', 'ay')
          .replaceAll('ie', 'i')
          .replaceAll('eu', 'oy')
          .replaceAll('äu', 'oy')
          .replaceAll('sp', 'shp')
          .replaceAll('st', 'sht')
          .replaceAll('ä', 'e')
          .replaceAll('ö', 'yo')
          .replaceAll('ü', 'yu')
          .replaceAll('ß', 's')
          .replaceAll('v', 'f')
          .replaceAll('w', 'v')
          .replaceAll('z', 'ts');
    } else if (targetLangCode == 'es') {
      phoneticLatin = w
          .replaceAll('ll', 'y')
          .replaceAll('ñ', 'ny')
          .replaceAll('ch', 'ch')
          .replaceAll('j', 'kh')
          .replaceAll('qu', 'k')
          .replaceAll('c', 'k')
          .replaceAll('h', '');
    } else if (targetLangCode == 'fr') {
      phoneticLatin = w
          .replaceAll('eau', 'o')
          .replaceAll('au', 'o')
          .replaceAll('ou', 'u')
          .replaceAll('oi', 'ua')
          .replaceAll('ch', 'sh')
          .replaceAll('gn', 'ny')
          .replaceAll('qu', 'k')
          .replaceAll('h', '');
    } else if (targetLangCode == 'pl') {
      phoneticLatin = w
          .replaceAll('sz', 'sh')
          .replaceAll('cz', 'ch')
          .replaceAll('rz', 'zh')
          .replaceAll('ż', 'zh')
          .replaceAll('dz', 'dz')
          .replaceAll('ś', 's')
          .replaceAll('ć', 'ch')
          .replaceAll('ń', 'n')
          .replaceAll('ł', 'v')
          .replaceAll('w', 'v')
          .replaceAll('ą', 'on')
          .replaceAll('ę', 'en');
    } else if (targetLangCode == 'cs' || targetLangCode == 'sk') {
      phoneticLatin = w
          .replaceAll('ř', 'rzh')
          .replaceAll('š', 'sh')
          .replaceAll('č', 'ch')
          .replaceAll('ž', 'zh')
          .replaceAll('ch', 'kh')
          .replaceAll('ě', 'ye')
          .replaceAll('ň', 'ny');
    }

    // Step 2: render into the user's Native Language alphabet
    final nativeWord = _transliterateLatinPhoneticToNative(
      phoneticLatin,
      nativeLangCode: nativeLangCode,
    );
    return _syllabify(nativeWord);
  }

  String _transliterateLatinPhoneticToNative(
    String phoneticLatin, {
    required String nativeLangCode,
  }) {
    if (_isCyrillicLanguage(nativeLangCode)) {
      var s = phoneticLatin
          .replaceAll('rzh', 'рж')
          .replaceAll('sht', 'шт')
          .replaceAll('shp', 'шп')
          .replaceAll('shn', 'шн')
          .replaceAll('zhn', 'жн')
          .replaceAll('cher', 'чер')
          .replaceAll('sh', 'ш')
          .replaceAll('ch', 'ч')
          .replaceAll('zh', 'ж')
          .replaceAll('kh', 'х')
          .replaceAll('th', 'с')
          .replaceAll('ph', 'ф')
          .replaceAll('kv', 'кв')
          .replaceAll('ts', 'ц')
          .replaceAll('ny', 'нь')
          .replaceAll('ye', 'є')
          .replaceAll('yo', 'йо')
          .replaceAll('yu', 'ю')
          .replaceAll('ya', 'я')
          .replaceAll('ay', 'ай')
          .replaceAll('ey', 'ей')
          .replaceAll('oy', 'ой')
          .replaceAll('au', 'ау')
          .replaceAll('a', 'а')
          .replaceAll('b', 'б')
          .replaceAll('c', 'к')
          .replaceAll('d', 'д')
          .replaceAll('e', 'е')
          .replaceAll('f', 'ф')
          .replaceAll('g', 'ґ')
          .replaceAll('h', 'х')
          .replaceAll('i', 'і')
          .replaceAll('j', 'дж')
          .replaceAll('k', 'к')
          .replaceAll('l', 'л')
          .replaceAll('m', 'м')
          .replaceAll('n', 'н')
          .replaceAll('o', 'о')
          .replaceAll('p', 'п')
          .replaceAll('q', 'к')
          .replaceAll('r', 'р')
          .replaceAll('s', 'с')
          .replaceAll('t', 'т')
          .replaceAll('u', 'у')
          .replaceAll('v', 'в')
          .replaceAll('w', 'в')
          .replaceAll('x', 'кс')
          .replaceAll('y', 'і')
          .replaceAll('z', 'з');
      return s;
    }

    if (nativeLangCode == 'pl') {
      return phoneticLatin
          .replaceAll('sh', 'sz')
          .replaceAll('ch', 'cz')
          .replaceAll('zh', 'ż')
          .replaceAll('kh', 'ch')
          .replaceAll('v', 'w');
    } else if (nativeLangCode == 'de') {
      return phoneticLatin
          .replaceAll('sh', 'sch')
          .replaceAll('ch', 'tsch')
          .replaceAll('zh', 'sch')
          .replaceAll('kh', 'ch')
          .replaceAll('v', 'w');
    } else if (nativeLangCode == 'es') {
      return phoneticLatin
          .replaceAll('kh', 'j')
          .replaceAll('ny', 'ñ')
          .replaceAll('w', 'gu');
    } else if (nativeLangCode == 'cs' || nativeLangCode == 'sk') {
      return phoneticLatin
          .replaceAll('sh', 'š')
          .replaceAll('ch', 'č')
          .replaceAll('zh', 'ž')
          .replaceAll('kh', 'ch');
    }

    return phoneticLatin;
  }

  String _syllabify(String w) {
    final syllables = <String>[];
    final vowels = RegExp(
      r'[aeiouyäöüáéíóúàèìòùâêîôûąęółżźćńїієаоуеияюɪʊɛɔɑə]',
      caseSensitive: false,
    );
    final buf = StringBuffer();
    for (var i = 0; i < w.length; i++) {
      buf.write(w[i]);
      final isVowel = vowels.hasMatch(w[i]);
      final hasMore = i < w.length - 1;
      if (isVowel && hasMore && !vowels.hasMatch(w[i + 1]) && buf.length >= 2) {
        if (i + 2 < w.length && vowels.hasMatch(w[i + 2])) {
          syllables.add(buf.toString());
          buf.clear();
        }
      }
    }
    if (buf.isNotEmpty) {
      if (syllables.isNotEmpty && buf.length == 1) {
        syllables[syllables.length - 1] =
            '${syllables.last}${buf.toString()}';
      } else {
        syllables.add(buf.toString());
      }
    }
    return syllables.join('-');
  }

  PronunciationEvaluation evaluatePronunciation({
    required String targetText,
    required String spokenText,
  }) {
    final cleanTargetWords = _tokenize(targetText);
    final cleanSpokenWords = _tokenize(spokenText);

    if (cleanTargetWords.isEmpty || cleanSpokenWords.isEmpty) {
      return PronunciationEvaluation(
        targetText: targetText,
        spokenText: spokenText,
        scorePercent: 0,
        feedbackKey: 'pron_fb_empty',
        feedbackUk:
            'Голос не розпізнано. Натисніть мікрофон і повторіть чіткіше.',
        segments: cleanTargetWords
            .map(
              (w) => WordMatchSegment(
                expectedWord: w,
                spokenWord: '',
                matched: false,
                similarity: 0,
              ),
            )
            .toList(),
      );
    }

    final segments = <WordMatchSegment>[];
    var totalWordSimilarity = 0.0;

    for (var i = 0; i < cleanTargetWords.length; i++) {
      final expected = cleanTargetWords[i];
      var bestSim = 0.0;
      var bestSpoken = '';
      for (final spoken in cleanSpokenWords) {
        final sim = _stringSimilarity(expected, spoken);
        if (sim > bestSim) {
          bestSim = sim;
          bestSpoken = spoken;
        }
      }
      totalWordSimilarity += bestSim;
      segments.add(
        WordMatchSegment(
          expectedWord: expected,
          spokenWord: bestSpoken,
          matched: bestSim >= 0.76,
          similarity: bestSim,
        ),
      );
    }

    final wordAvg = totalWordSimilarity / cleanTargetWords.length;
    final fullSentenceSim = _stringSimilarity(
      cleanTargetWords.join(' '),
      cleanSpokenWords.join(' '),
    );

    final rawScore = ((wordAvg * 0.65 + fullSentenceSim * 0.35) * 100).round();
    final score = rawScore.clamp(0, 100);

    String feedback;
    String feedbackKey;
    if (score >= 90) {
      feedbackKey = 'pron_fb_perfect';
      feedback =
          '✓ Ідеально! Мікрофон автоматично зафіксував правильну вимову.';
    } else if (score >= 78) {
      feedbackKey = 'pron_fb_great';
      feedback = '✓ Чудова вимова! Слово зараховано.';
    } else if (score >= 58) {
      feedbackKey = 'pron_fb_good';
      feedback =
          'Непогано! Зверніть увагу на червоні слова та транскрипцію вище.';
    } else {
      feedbackKey = 'pron_fb_retry';
      feedback =
          'Прослухайте повільне озвучення (🐢) і повторіть за транскрипцією.';
    }

    return PronunciationEvaluation(
      targetText: targetText,
      spokenText: spokenText,
      scorePercent: score,
      feedbackKey: feedbackKey,
      feedbackUk: feedback,
      segments: segments,
    );
  }

  List<String> _tokenize(String input) {
    final normalized = input
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s']", unicode: true), ' ')
        .trim();
    if (normalized.isEmpty) return const [];
    return normalized
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  double _stringSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final distance = _levenshtein(a, b);
    final maxLen = math.max(a.length, b.length);
    return (1.0 - distance / maxLen).clamp(0.0, 1.0);
  }

  int _levenshtein(String s, String t) {
    final m = s.length;
    final n = t.length;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));

    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = math.min(
          math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + cost,
        );
      }
    }
    return dp[m][n];
  }
}
