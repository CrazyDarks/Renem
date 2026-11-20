import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/app_settings.dart';
import '../../models/exam_models.dart';
import 'ai_router_client.dart';

/// Handles contextual word lookup (tailored to [LearningTopic]), fast sentence
/// and batch translations, subtitle translation, and image OCR.
class AiTranslationService {
  AiTranslationService(this._router);

  final AiRouterClient _router;

  Future<WordLookupResult> lookupWordInContext({
    required String word,
    required String contextSentence,
    required AppSettings settings,
  }) async {
    final targetLang = settings.targetLanguage;
    final nativeLang = settings.nativeLanguage;
    final topicDirective = settings.learningTopic.aiPromptDirective;

    final prompt = '''
You are a concise language tutor.
Target language: ${targetLang.englishName}
User native language: ${nativeLang.englishName}
$topicDirective
Word to translate: "$word"
Context sentence: "$contextSentence"

Respond ONLY with valid JSON (no markdown fences) using this exact schema:
{
  "translation": "most accurate translation in ${nativeLang.englishName} considering the context",
  "partOfSpeech": "short part of speech in ${nativeLang.englishName}",
  "example": "one clear natural example sentence in ${targetLang.englishName} using this word (fitting the learning focus domain if natural)",
  "explanation": "1 short sentence nuance/usage tip in ${nativeLang.englishName}"
}
''';

    try {
      final aiRes = await _router.generateTextSmart(
        prompt: prompt,
        rawKeys: settings.geminiApiKey,
        timeout: const Duration(seconds: 10),
        fastTask: true,
      );
      final map = _router.extractJsonObject(aiRes.text);
      if (map != null && (map['translation'] as String? ?? '').isNotEmpty) {
        return WordLookupResult(
          word: word,
          translation: (map['translation'] as String).trim(),
          partOfSpeech: (map['partOfSpeech'] as String? ?? '').trim(),
          example: (map['example'] as String? ?? contextSentence).trim(),
          explanation: (map['explanation'] as String? ?? '').trim(),
          usedAi: true,
        );
      }
    } catch (_) {}

    return _fallbackTranslate(
      word: word,
      contextSentence: contextSentence,
      targetLang: targetLang,
      nativeLang: nativeLang,
    );
  }

  Future<String> translateSentence({
    required String sentence,
    required String sourceLangCode,
    required String targetLangCode,
  }) async {
    final cleaned = sentence.trim();
    if (cleaned.isEmpty) return '';
    if (sourceLangCode == targetLangCode) return cleaned;
    try {
      final uri = Uri.https(
        'translate.googleapis.com',
        '/translate_a/single',
        {
          'client': 'gtx',
          'sl': sourceLangCode.isEmpty ? 'auto' : sourceLangCode,
          'tl': targetLangCode,
          'dt': 't',
          'q': cleaned,
        },
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as List<dynamic>;
        final segments = decoded.first as List<dynamic>?;
        if (segments != null) {
          final translated = segments
              .whereType<List<dynamic>>()
              .map((s) => s.isNotEmpty ? (s.first?.toString() ?? '') : '')
              .join()
              .trim();
          if (translated.isNotEmpty) return translated;
        }
      }
    } catch (_) {}
    return cleaned;
  }

  Future<List<String>> batchTranslateTexts({
    required List<String> texts,
    required String sourceLangCode,
    required String targetLangCode,
  }) async {
    if (texts.isEmpty) return const [];
    if (sourceLangCode == targetLangCode) return List<String>.from(texts);

    final results = List<String>.from(texts);
    final workFutures = <Future<void>>[];

    var currentBatchIndices = <int>[];
    var currentChars = 0;

    void flushBatch() {
      if (currentBatchIndices.isEmpty) return;
      final batchIndices = List<int>.from(currentBatchIndices);
      currentBatchIndices = <int>[];
      currentChars = 0;

      workFutures.add(() async {
        final slice = batchIndices.map((idx) => texts[idx]).toList();
        try {
          final encodedLines = slice
              .map((item) => item.replaceAll('\n', ' ⏎ ').trim())
              .toList();
          final joined = encodedLines.join('\n');

          final uri = Uri.https(
            'translate.googleapis.com',
            '/translate_a/single',
            {
              'client': 'gtx',
              'sl': sourceLangCode,
              'tl': targetLangCode,
              'dt': 't',
              'q': joined,
            },
          );
          final resp = await http.get(uri).timeout(const Duration(seconds: 9));
          if (resp.statusCode == 200) {
            final decoded = jsonDecode(resp.body) as List<dynamic>;
            final segments = decoded.first as List<dynamic>?;
            if (segments != null) {
              final fullTranslated = segments
                  .whereType<List<dynamic>>()
                  .map(
                    (seg) => seg.isNotEmpty ? (seg.first?.toString() ?? '') : '',
                  )
                  .join();
              final lines = fullTranslated
                  .split('\n')
                  .map((l) => l.trim())
                  .where((l) => l.isNotEmpty)
                  .toList();

              if (lines.length == slice.length) {
                for (var i = 0; i < slice.length; i++) {
                  results[batchIndices[i]] = lines[i]
                      .replaceAll(' ⏎ ', '\n')
                      .replaceAll('⏎', '\n')
                      .trim();
                }
                return;
              }
            }
          }
        } catch (_) {}

        final singles = await Future.wait(
          slice.map(
            (item) => _translateLongTextSafely(
              item,
              sourceLangCode: sourceLangCode,
              targetLangCode: targetLangCode,
            ),
          ),
        );
        for (var i = 0; i < singles.length; i++) {
          if (singles[i].isNotEmpty) {
            results[batchIndices[i]] = singles[i];
          }
        }
      }());
    }

    for (var i = 0; i < texts.length; i++) {
      final item = texts[i].trim();
      if (item.isEmpty) continue;

      if (item.length > 750) {
        flushBatch();
        final idx = i;
        workFutures.add(() async {
          results[idx] = await _translateLongTextSafely(
            item,
            sourceLangCode: sourceLangCode,
            targetLangCode: targetLangCode,
          );
        }());
        continue;
      }

      if (currentBatchIndices.length >= 12 ||
          currentChars + item.length > 1050) {
        flushBatch();
      }
      currentBatchIndices.add(i);
      currentChars += item.length + 4;
    }
    flushBatch();

    await Future.wait(workFutures);
    return results;
  }

  Future<String> _translateLongTextSafely(
    String text, {
    required String sourceLangCode,
    required String targetLangCode,
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty || sourceLangCode == targetLangCode) return cleaned;
    if (cleaned.length <= 950) {
      return translateSentence(
        sentence: cleaned,
        sourceLangCode: sourceLangCode,
        targetLangCode: targetLangCode,
      );
    }

    final paragraphs = cleaned.split('\n');
    final translatedParas = await Future.wait(
      paragraphs.map((p) async {
        final trimmed = p.trim();
        if (trimmed.isEmpty) return '';
        if (trimmed.length <= 950) {
          return translateSentence(
            sentence: trimmed,
            sourceLangCode: sourceLangCode,
            targetLangCode: targetLangCode,
          );
        }
        final sentences = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
        final chunks = <String>[];
        final buf = StringBuffer();
        for (final s in sentences) {
          if (buf.length + s.length + 1 > 900 && buf.isNotEmpty) {
            chunks.add(buf.toString().trim());
            buf.clear();
          }
          if (buf.isNotEmpty) buf.write(' ');
          buf.write(s);
        }
        if (buf.isNotEmpty) chunks.add(buf.toString().trim());

        final translatedChunks = await Future.wait(
          chunks.map(
            (c) => translateSentence(
              sentence: c,
              sourceLangCode: sourceLangCode,
              targetLangCode: targetLangCode,
            ),
          ),
        );
        return translatedChunks.join(' ');
      }),
    );

    return translatedParas.join('\n').trim();
  }

  Future<List<String>> translateSubtitleCues({
    required List<String> texts,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
  }) async {
    if (texts.isEmpty) return const [];
    return batchTranslateTexts(
      texts: texts,
      sourceLangCode: targetLang.code,
      targetLangCode: nativeLang.code,
    );
  }

  Future<WordLookupResult> _fallbackTranslate({
    required String word,
    required String contextSentence,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
  }) async {
    String translation = '';
    String partOfSpeech = '';
    String example = contextSentence;

    try {
      final gtxUri = Uri.https(
        'translate.googleapis.com',
        '/translate_a/single',
        {
          'client': 'gtx',
          'sl': targetLang.code,
          'tl': nativeLang.code,
          'dt': 't',
          'q': word,
        },
      );
      final resp = await http.get(gtxUri).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as List<dynamic>;
        final segments = decoded.first as List<dynamic>?;
        if (segments != null && segments.isNotEmpty) {
          final firstSeg = segments.first as List<dynamic>;
          if (firstSeg.isNotEmpty) {
            translation = (firstSeg.first?.toString() ?? '').trim();
          }
        }
      }
    } catch (_) {}

    if (translation.isEmpty) {
      try {
        final uri = Uri.https('api.mymemory.translated.net', '/get', {
          'q': word,
          'langpair': '${targetLang.code}|${nativeLang.code}',
        });
        final resp = await http.get(uri).timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          final jsonMap = jsonDecode(resp.body) as Map<String, dynamic>;
          final responseData =
              jsonMap['responseData'] as Map<String, dynamic>?;
          translation =
              (responseData?['translatedText'] as String? ?? '').trim();
        }
      } catch (_) {}
    }

    if (targetLang.code == 'en') {
      try {
        final dictUri = Uri.parse(
          'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word.toLowerCase())}',
        );
        final resp =
            await http.get(dictUri).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final list = jsonDecode(resp.body) as List<dynamic>;
          if (list.isNotEmpty) {
            final entry = list.first as Map<String, dynamic>;
            final meanings = entry['meanings'] as List<dynamic>? ?? const [];
            if (meanings.isNotEmpty) {
              final firstMeaning = meanings.first as Map<String, dynamic>;
              partOfSpeech =
                  (firstMeaning['partOfSpeech'] as String? ?? '').trim();
              final defs =
                  firstMeaning['definitions'] as List<dynamic>? ?? const [];
              for (final d in defs.whereType<Map<String, dynamic>>()) {
                final ex = (d['example'] as String? ?? '').trim();
                if (ex.isNotEmpty) {
                  example = ex;
                  break;
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    if (translation.isEmpty) {
      translation = 'Переклад тимчасово недоступний (перевірте інтернет)';
    }

    return WordLookupResult(
      word: word,
      translation: translation,
      partOfSpeech: partOfSpeech,
      example: example,
      explanation: 'Автоматичний безкоштовний переклад Reman.',
      usedAi: true,
    );
  }

  Future<String> extractTextFromImage({
    required Uint8List imageBytes,
    required String mimeType,
    required AppSettings settings,
  }) async {
    final keys = _router.parseKeys(settings.geminiApiKey);
    final googleKeys = keys
        .where((k) => k.startsWith('AIza') || k.startsWith('AQ'))
        .toList();

    final prompt = '''
Extract all readable text from this image accurately, preserving natural paragraphs and punctuation.
Primary expected language: ${settings.targetLanguage.englishName}.
Return ONLY the extracted text without any introductory or closing commentary.
''';

    final base64Data = base64Encode(imageBytes);

    for (final key in googleKeys) {
      final isVertex = key.startsWith('AQ');
      final providerId = isVertex ? 'vertex' : 'gemini';
      final cKey = _router.cacheKey(providerId, key, fastTask: true);
      final eKey = _router.exhaustedKey(providerId, key);
      final discovered = await _router.discoverGeminiModels(key, fastTask: true);
      final candidates = _router.buildOrderedCandidates(cKey, eKey, discovered);
      final encodedKey = Uri.encodeQueryComponent(key);

      Future<({String? text, int? statusCode})> callVisionEndpoint(
        String url,
        String modelName,
      ) async {
        try {
          final resp = await http
              .post(
                Uri.parse(url),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode({
                  'contents': [
                    {
                      'role': 'user',
                      'parts': [
                        {'text': prompt},
                        {
                          'inlineData': {
                            'mimeType': mimeType,
                            'data': base64Data,
                          },
                        },
                      ],
                    },
                  ],
                }),
              )
              .timeout(const Duration(seconds: 14));
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body) as Map<String, dynamic>;
            final candidatesList = data['candidates'] as List<dynamic>?;
            if (candidatesList != null && candidatesList.isNotEmpty) {
              final content =
                  (candidatesList.first as Map<String, dynamic>)['content']
                      as Map<String, dynamic>?;
              final parts = content?['parts'] as List<dynamic>?;
              final text = parts
                      ?.whereType<Map<String, dynamic>>()
                      .where((p) => p['thought'] != true)
                      .map((p) => (p['text'] as String? ?? '').trim())
                      .where((t) => t.isNotEmpty)
                      .join('\n')
                      .trim() ??
                  '';
              if (text.isNotEmpty) {
                return (text: text, statusCode: 200);
              }
            }
            return (text: null, statusCode: 200);
          }
          debugPrint(
            '[Reman AI] Gemini Vision ($modelName) HTTP ${resp.statusCode}: ${_router.preview300(resp.body)}',
          );
          return (text: null, statusCode: resp.statusCode);
        } catch (e) {
          debugPrint('[Reman AI] Gemini Vision ($modelName) error: $e');
          return (text: null, statusCode: null);
        }
      }

      var geminiRestAuthFailed = false;
      for (final modelName in candidates) {
        final restUrl =
            'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$encodedKey';
        final res = await callVisionEndpoint(restUrl, modelName);
        if (res.text != null) {
          _router.recordModelSuccess(cKey, modelName, exhaustedKey: eKey);
          return res.text!;
        }
        _router.handleFailedModelStatus(
          cacheKey: cKey,
          exhaustedKey: eKey,
          model: modelName,
          statusCode: res.statusCode,
        );
        if (res.statusCode == 401 || res.statusCode == 403) {
          geminiRestAuthFailed = true;
          break;
        }
      }

      if (isVertex && geminiRestAuthFailed) {
        final vertexCandidates =
            _router.buildOrderedCandidates(cKey, eKey, discovered);
        for (final modelName in vertexCandidates) {
          final vertexUrl =
              'https://aiplatform.googleapis.com/v1/publishers/google/models/$modelName:generateContent?key=$encodedKey';
          final res = await callVisionEndpoint(vertexUrl, modelName);
          if (res.text != null) {
            _router.recordModelSuccess(cKey, modelName, exhaustedKey: eKey);
            return res.text!;
          }
          _router.handleFailedModelStatus(
            cacheKey: cKey,
            exhaustedKey: eKey,
            model: modelName,
            statusCode: res.statusCode,
          );
          if (res.statusCode == 401 || res.statusCode == 403) break;
        }
      }
    }

    try {
      final base64Image =
          'data:$mimeType;base64,${base64Encode(imageBytes)}';
      final resp = await http
          .post(
            Uri.parse('https://api.ocr.space/parse/image'),
            headers: {'apikey': 'helloworld'},
            body: {
              'base64Image': base64Image,
              'language': 'eng',
              'isOverlayRequired': 'false',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final parsedResults = data['ParsedResults'] as List<dynamic>?;
        if (parsedResults != null && parsedResults.isNotEmpty) {
          final text = parsedResults
              .whereType<Map<String, dynamic>>()
              .map((r) => (r['ParsedText'] as String? ?? '').trim())
              .where((t) => t.isNotEmpty)
              .join('\n\n');
          if (text.isNotEmpty) return text;
        }
      }
    } catch (e) {
      debugPrint('Free OCR fallback error: $e');
    }

    throw StateError(
      'Не вдалося розпізнати текст на фото. Переконайтеся, що текст чіткий або додайте ключ Google Gemini у Налаштуваннях.',
    );
  }
}
