import '../../models/app_settings.dart';
import '../../models/grammar_book_models.dart';
import '../../models/level_curriculum.dart';
import '../../models/reading_rules_book.dart';
import 'ai_router_client.dart';

/// Generates AI-powered CEFR Level Path lessons and the Reading & Writing Rules
/// Handbook ("Книжечка з правилами") tailored to any of the 92 languages and the
/// user's chosen [LearningTopic].
class AiCurriculumService {
  AiCurriculumService(this._router);

  final AiRouterClient _router;

  Future<Map<String, dynamic>> generateLevelRuleExplanation({
    required String cefrCode,
    required String topicTitle,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
    required Map<String, dynamic> offlineFallback,
  }) async {
    final topicDirective = settings.learningTopic.aiPromptDirective;
    final prompt = '''
You are an expert language teacher for ${targetLang.englishName} (${targetLang.code}), explaining to a student whose native language is ${nativeLang.englishName} (${nativeLang.code}).
Level: CEFR $cefrCode.
Topic: "$topicTitle".
$topicDirective

Return ONLY a valid JSON object with this exact structure (no markdown fences):
{
  "ruleSummary": "Clear, concise 2-3 sentence explanation of the grammar/lexical rule in ${nativeLang.englishName} (${nativeLang.code})",
  "keyTip": "1 short practical tip or pattern formula in ${nativeLang.englishName}",
  "examples": [
    {
      "target": "Natural example sentence 1 in ${targetLang.englishName}",
      "native": "Accurate translation in ${nativeLang.englishName}"
    },
    {
      "target": "Natural example sentence 2 in ${targetLang.englishName}",
      "native": "Accurate translation in ${nativeLang.englishName}"
    },
    {
      "target": "Natural example sentence 3 in ${targetLang.englishName}",
      "native": "Accurate translation in ${nativeLang.englishName}"
    }
  ]
}
''';

    try {
      final res = await _router.generateTextSmart(
        prompt: prompt,
        rawKeys: settings.geminiApiKey,
        expectJson: true,
        fastTask: true,
        maxTokens: 900,
        timeout: const Duration(seconds: 10),
      );
      final parsed = _router.extractJsonObject(res.text);
      if (parsed != null &&
          (parsed['ruleSummary']?.toString().trim().isNotEmpty ?? false) &&
          parsed['examples'] is List &&
          (parsed['examples'] as List).isNotEmpty) {
        return {
          ...offlineFallback,
          'ruleSummary': parsed['ruleSummary'].toString().trim(),
          if (parsed['keyTip'] != null)
            'keyTip': parsed['keyTip'].toString().trim(),
          'examples': (parsed['examples'] as List)
              .whereType<Map<String, dynamic>>()
              .map(
                (e) => {
                  'target': (e['target'] ?? '').toString().trim(),
                  'native': (e['native'] ?? '').toString().trim(),
                },
              )
              .where((e) => e['target']!.isNotEmpty)
              .toList(),
          'usedAi': true,
        };
      }
    } catch (_) {}

    return offlineFallback;
  }

  /// Generates a complete CEFR Level Path module in ONE Multi-AI JSON request
  /// tailored specifically to ANY of the 92 target languages and the selected
  /// [LearningTopic], explained in the user's native language.
  Future<GeneratedLevelContent> generateLevelModuleContent({
    required CurriculumModuleNode node,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
    required GeneratedLevelContent offlineFallback,
  }) async {
    final topicDirective = settings.learningTopic.aiPromptDirective;
    final prompt = '''
You are a senior language teacher creating an interactive CEFR ${node.cefr.code} lesson module.
Target language being learned: ${targetLang.englishName} (${targetLang.displayNativeName}, code: ${targetLang.code}).
Student's native / UI language: ${nativeLang.englishName} (${nativeLang.displayNativeName}, code: ${nativeLang.code}).
Module #${node.stepNumber}: "${node.titleEn}"
Pedagogical focus: ${node.aiTopicPrompt}
$topicDirective

IMPORTANT RULES:
1. Tailor the grammar rule, examples, and ALL exercises 100% specifically to the real grammar, script, and usage of ${targetLang.englishName} (${targetLang.code})!
2. Write "grammarRule", "commonMistakes", "keyTip", translations, question instructions, and answer "explanation" in ${nativeLang.englishName} (${nativeLang.code}).
3. Write the target-language example sentences and the answer options / target phrases inside questions in authentic, natural ${targetLang.englishName} (${targetLang.code}) appropriate for CEFR ${node.cefr.code} and the learning focus domain above.
4. Randomize which option index (0, 1, 2, or 3) is correct across exercises so the answer is NOT always 0!
5. Provide EXACTLY:
   - 4 natural examples in "examples"
   - 5 interactive multiple-choice exercises in "practiceExercises" (4 options each)
   - 5 final test questions in "finalTest" (4 options each) that are distinct from practiceExercises
6. Return ONLY a valid JSON object (no markdown fences, no commentary) with this exact schema:
{
  "grammarRule": "Clear, structured 3-4 sentence explanation of how this topic works in ${targetLang.englishName}, written in ${nativeLang.englishName}.",
  "commonMistakes": "1-2 concrete common mistakes learners make with this rule in ${targetLang.englishName} and how to avoid them, written in ${nativeLang.englishName}.",
  "keyTip": "Short memorable formula or pattern in ${nativeLang.englishName} with ${targetLang.englishName} cue.",
  "examples": [
    {"target": "Natural sentence in ${targetLang.englishName}", "native": "Accurate translation in ${nativeLang.englishName}"}
  ],
  "practiceExercises": [
    {
      "question": "Clear exercise prompt in ${nativeLang.englishName} testing a ${targetLang.englishName} phrase/sentence",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctIndex": 1,
      "explanation": "Concise explanation in ${nativeLang.englishName}"
    }
  ],
  "finalTest": [
    {
      "question": "Final test question in ${nativeLang.englishName} testing mastery of ${targetLang.englishName}",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctIndex": 2,
      "explanation": "Concise explanation in ${nativeLang.englishName}"
    }
  ]
}
''';

    try {
      final res = await _router.generateTextSmart(
        prompt: prompt,
        rawKeys: settings.geminiApiKey,
        expectJson: true,
        fastTask: false,
        maxTokens: 3600,
        timeout: const Duration(seconds: 14),
      );
      final parsed = _router.extractJsonObject(res.text);
      if (parsed != null) {
        final content = GeneratedLevelContent.fromJson({
          ...parsed,
          'usedAi': true,
          'providerName': res.provider,
        });
        if (content.grammarRule.isNotEmpty &&
            content.examples.length >= 2 &&
            content.practiceExercises.length >= 3 &&
            content.finalTest.length >= 4) {
          return content;
        }
      }
    } catch (_) {}

    return offlineFallback;
  }

  /// Generates the structured Reading & Writing Rules Handbook ("Книжечка з правилами")
  /// for [targetLang] explained in [nativeLang], with strict validity checking.
  Future<ReadingRulesBook> generateReadingRulesBook({
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
    required ReadingRulesBook offlineFallback,
  }) async {
    final topicDirective = settings.learningTopic.aiPromptDirective;
    final transcriptionMode = settings.useInternationalIpa
        ? 'Use International Phonetic Alphabet (IPA) for pronunciation transcriptions.'
        : 'Use easy-to-read phonetic pronunciation cues written in ${nativeLang.englishName} (${nativeLang.code}) letters (plus optional IPA if helpful).';

    final prompt = '''
You are a master linguist and phonetician writing a practical, beginner-friendly "Reading & Writing Rules Handbook" (Книжечка з правилами читання та письма) for learners studying ${targetLang.englishName} (${targetLang.displayNativeName}, code: ${targetLang.code}).
Explain EVERYTHING clearly in the student's UI language: ${nativeLang.englishName} (${nativeLang.displayNativeName}, code: ${nativeLang.code}).
$transcriptionMode
$topicDirective

Cover ALL 4 mandatory sections with authentic ${targetLang.englishName} examples:
1. "alphabetAndDiacritics" (6 to 10 items): Alphabet highlights, special letters, diacritics, or script characters — how they look and how they are pronounced, each with a real speakable exampleWord in ${targetLang.englishName}.
2. "readingRules" (4 to 6 items): Key reading rules — letter combinations/digraphs, soft vs hard consonants, vowel shifts, silent letters, and important exceptions, each with 2-3 speakable examples.
3. "stressAndIntonation" (2 to 4 items): Word stress patterns, sentence rhythm, and question vs statement intonation, each with 1-2 speakable examples.
4. "writingRules" (3 to 5 items): Basic writing rules — capitalization, basic grammatical endings/spelling shifts, punctuation, and classic beginner spelling traps, each with 1-2 speakable examples.

STRICT REQUIREMENTS:
- Every "exampleWord" and "examples[].text" MUST be clean, authentic ${targetLang.englishName} text ready for TTS audio playback (no parentheses or extra notes inside the speakable word/phrase).
- All explanations, titles, and translations MUST be in ${nativeLang.englishName} (${nativeLang.code}).
- Respond ONLY with a single valid JSON object (no markdown fences, no extra prose):
{
  "overview": "2-3 concise sentences introducing the writing system and pronunciation logic of ${targetLang.englishName} in ${nativeLang.englishName}.",
  "alphabetAndDiacritics": [
    {
      "symbol": "special letter or group",
      "pronunciation": "clear pronunciation guide in ${nativeLang.englishName}",
      "exampleWord": "single real word in ${targetLang.englishName}",
      "exampleTranslation": "translation in ${nativeLang.englishName}",
      "note": "optional short tip in ${nativeLang.englishName}"
    }
  ],
  "readingRules": [
    {
      "title": "Rule title in ${nativeLang.englishName}",
      "explanation": "Clear concise rule explanation in ${nativeLang.englishName}",
      "examples": [
        {
          "text": "word or short phrase in ${targetLang.englishName}",
          "pronunciation": "phonetic cue",
          "translation": "translation in ${nativeLang.englishName}"
        }
      ]
    }
  ],
  "stressAndIntonation": [
    {
      "title": "Stress or intonation rule in ${nativeLang.englishName}",
      "explanation": "Clear concise explanation in ${nativeLang.englishName}",
      "examples": [
        {
          "text": "word or short sentence in ${targetLang.englishName}",
          "pronunciation": "stress/intonation cue",
          "translation": "translation in ${nativeLang.englishName}"
        }
      ]
    }
  ],
  "writingRules": [
    {
      "title": "Writing rule or beginner pitfall in ${nativeLang.englishName}",
      "explanation": "Clear concise explanation in ${nativeLang.englishName}",
      "examples": [
        {
          "text": "short example in ${targetLang.englishName}",
          "pronunciation": "",
          "translation": "translation in ${nativeLang.englishName}"
        }
      ]
    }
  ]
}
''';

    try {
      final res = await _router.generateTextSmart(
        prompt: prompt,
        rawKeys: settings.geminiApiKey,
        expectJson: true,
        fastTask: false,
        maxTokens: 4200,
        timeout: const Duration(seconds: 14),
      );
      final parsed = _router.extractJsonObject(res.text);
      if (parsed != null) {
        final book = ReadingRulesBook.fromJson(
          {
            ...parsed,
            'targetLanguageCode': targetLang.code,
            'nativeLanguageCode': nativeLang.code,
            'usedAi': true,
            'providerName': res.provider,
            'generatedAtIso': DateTime.now().toIso8601String(),
          },
          fallbackTargetCode: targetLang.code,
          fallbackNativeCode: nativeLang.code,
        );
        // Mandatory validity verification before accepting
        if (book.isValid) {
          return book;
        }
      }
    } catch (_) {}

    return offlineFallback;
  }

  /// Generates a deep, academically accurate single chapter of the 9-chapter
  /// Grammar Handbook for [targetLang] explained in [nativeLang], including
  /// complete declension/conjugation/ending tables, exceptions, and 2-3 TTS
  /// examples per rule.
  Future<GrammarChapterContent> generateGrammarChapter({
    required GrammarChapterSpec chapter,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
    required GrammarChapterContent offlineFallback,
  }) async {
    final topicDirective = settings.learningTopic.aiPromptDirective;
    final transcriptionMode = settings.useInternationalIpa
        ? 'Use International Phonetic Alphabet (IPA) for pronunciation cues.'
        : 'Use clear phonetic pronunciation cues written in ${nativeLang.englishName} (${nativeLang.code}) letters (optionally with IPA).';

    final prompt = '''
You are a senior academic linguist and textbook author creating Chapter ${chapter.number} of a comprehensive Grammar Reference Handbook for ${targetLang.englishName} (${targetLang.displayNativeName}, code: ${targetLang.code}).
Explain EVERYTHING clearly, systematically, and thoroughly in the student's UI language: ${nativeLang.englishName} (${nativeLang.displayNativeName}, code: ${nativeLang.code}).
$transcriptionMode
$topicDirective

CHAPTER SCOPE (cover ALL rules deeply and accurately for ${targetLang.englishName}):
${chapter.aiPromptScope}

CONTENT REQUIREMENTS:
1. "summary": 2-4 clear sentences introducing the core logic of this chapter for ${targetLang.englishName}.
2. "tables" (2 to 4 structured reference tables): Include complete, accurate morphological/grammatical tables (e.g., all cases and endings, gender patterns, verb conjugation endings, irregular forms, pronoun declensions, preposition+case mappings, or alphabet/digraph reading tables for Chapter 1). Keep cell values concise and scannable.
3. "sections" (4 to 7 deep rule blocks): Cover ALL essential sub-rules of this chapter thoroughly. Each section MUST contain:
   - "title": clear rule heading in ${nativeLang.englishName}
   - "explanation": thorough, structured explanation in ${nativeLang.englishName} (use bullet lines with "• " where helpful for readability)
   - "exceptions": list of 1-4 concrete exceptions/edge cases for this specific rule in ${nativeLang.englishName}
   - "examples": 2-3 authentic, natural examples in ${targetLang.englishName}. Every "text" field MUST be clean ${targetLang.englishName} ready for TTS playback (no parentheses or notes inside "text").
4. "keyExceptions": 4 to 8 most important high-frequency exceptions of this chapter in ${nativeLang.englishName} (showing the ${targetLang.englishName} forms).
5. "commonMistakes": 3 to 5 classic mistakes learners make in this chapter and how to avoid them, in ${nativeLang.englishName}.

STRICT JSON OUTPUT (respond ONLY with a single valid JSON object, no markdown fences, no commentary):
{
  "summary": "Overview in ${nativeLang.englishName}",
  "tables": [
    {
      "title": "Table title in ${nativeLang.englishName}",
      "headers": ["Column 1", "Column 2", "Column 3"],
      "rows": [
        ["Cell 1", "Cell 2", "Cell 3"]
      ],
      "note": "Optional concise footnote in ${nativeLang.englishName}"
    }
  ],
  "sections": [
    {
      "title": "Rule title in ${nativeLang.englishName}",
      "explanation": "Detailed academic yet clear explanation in ${nativeLang.englishName}",
      "exceptions": ["Exception 1 in ${nativeLang.englishName}"],
      "examples": [
        {
          "text": "Clean speakable example sentence or phrase in ${targetLang.englishName}",
          "pronunciation": "phonetic cue",
          "translation": "Accurate translation in ${nativeLang.englishName}"
        }
      ]
    }
  ],
  "keyExceptions": ["Important exception 1", "Important exception 2"],
  "commonMistakes": ["Common mistake 1 -> correct form"]
}
''';

    String? errorDetail;
    try {
      final res = await _router.generateTextSmart(
        prompt: prompt,
        rawKeys: settings.geminiApiKey,
        expectJson: true,
        fastTask: false,
        maxTokens: 7500,
        timeout: const Duration(seconds: 20),
      );
      errorDetail = res.userKeyErrorSummary ?? res.errorSummary;
      final parsed = _router.extractJsonObject(res.text);
      if (parsed != null) {
        final content = GrammarChapterContent.fromJson(
          {
            ...parsed,
            'chapterId': chapter.id,
            'targetLanguageCode': targetLang.code,
            'nativeLanguageCode': nativeLang.code,
            'usedAi': true,
            'providerName': res.provider,
            'generatedAtIso': DateTime.now().toIso8601String(),
          },
          fallbackChapterId: chapter.id,
          fallbackTargetCode: targetLang.code,
          fallbackNativeCode: nativeLang.code,
        );
        if (content.isValid) {
          return content;
        }
      }
    } catch (e) {
      errorDetail = _router.shortError(e);
    }

    return GrammarChapterContent.buildOfflineFallback(
      spec: chapter,
      targetLang: targetLang,
      nativeLang: nativeLang,
      errorDetail: errorDetail,
    );
  }

  /// Answers any free-form user question about grammar, exceptions, spelling,
  /// declension, or usage of [targetLang] via Multi-AI, returning a structured
  /// [GrammarQaEntry] with TTS-ready examples and typical mistakes/exceptions.
  Future<({GrammarQaEntry? entry, String? errorDetail})> askGrammarQuestion({
    required String question,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
  }) async {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) {
      return (entry: null, errorDetail: 'Empty question');
    }

    final topicDirective = settings.learningTopic.aiPromptDirective;
    final transcriptionMode = settings.useInternationalIpa
        ? 'Use International Phonetic Alphabet (IPA) for pronunciation cues.'
        : 'Use clear phonetic pronunciation cues written in ${nativeLang.englishName} (${nativeLang.code}) letters.';

    final prompt = '''
You are an expert, friendly linguist and grammar tutor for ${targetLang.englishName} (${targetLang.displayNativeName}, code: ${targetLang.code}).
Student's native/UI language: ${nativeLang.englishName} (${nativeLang.displayNativeName}, code: ${nativeLang.code}).
$transcriptionMode
$topicDirective

STUDENT'S QUESTION:
"$cleanQuestion"

INSTRUCTIONS:
1. Give a crystal-clear, accurate, well-structured answer in ${nativeLang.englishName} directly answering why/how/when this rule or exception works in ${targetLang.englishName}.
2. Provide 2 to 4 authentic, natural examples in ${targetLang.englishName} illustrating the rule (every "text" must be clean ${targetLang.englishName} ready for TTS playback, with pronunciation and ${nativeLang.englishName} translation).
3. List 2 to 4 concrete exceptions, spelling nuances, or common mistakes related to this question in ${nativeLang.englishName}.
4. If the question asks about a word's declension, conjugation, case endings, or comparison, ALSO include 1 concise reference table in "tables" (otherwise return an empty array []).

Respond ONLY with a single valid JSON object (no markdown fences, no extra prose):
{
  "answer": "Clear, detailed explanation in ${nativeLang.englishName}",
  "tables": [
    {
      "title": "Optional quick table title in ${nativeLang.englishName}",
      "headers": ["Form", "Example"],
      "rows": [["...", "..."]],
      "note": ""
    }
  ],
  "examples": [
    {
      "text": "Clean speakable sentence or phrase in ${targetLang.englishName}",
      "pronunciation": "phonetic cue",
      "translation": "Translation in ${nativeLang.englishName}"
    }
  ],
  "exceptionsAndMistakes": [
    "Exception or typical mistake tip 1 in ${nativeLang.englishName}",
    "Exception or typical mistake tip 2 in ${nativeLang.englishName}"
  ]
}
''';

    try {
      final res = await _router.generateTextSmart(
        prompt: prompt,
        rawKeys: settings.geminiApiKey,
        expectJson: true,
        fastTask: false,
        maxTokens: 3200,
        timeout: const Duration(seconds: 15),
      );

      final parsed = _router.extractJsonObject(res.text);
      if (parsed != null) {
        final entry = GrammarQaEntry.fromJson({
          ...parsed,
          'id': 'qa_${DateTime.now().microsecondsSinceEpoch}',
          'question': cleanQuestion,
          'providerName': res.provider,
          'createdAtIso': DateTime.now().toIso8601String(),
          'usedAi': true,
        });
        if (entry.isValid) {
          return (entry: entry, errorDetail: null);
        }
      }

      // Graceful fallback if AI returned plain text instead of strict JSON
      final plainText = _router.stripCodeFences(res.text).trim();
      if (plainText.isNotEmpty && !plainText.startsWith('{')) {
        final entry = GrammarQaEntry(
          id: 'qa_${DateTime.now().microsecondsSinceEpoch}',
          question: cleanQuestion,
          answer: plainText,
          providerName: res.provider,
          createdAtIso: DateTime.now().toIso8601String(),
          usedAi: true,
        );
        return (entry: entry, errorDetail: null);
      }

      return (
        entry: null,
        errorDetail: res.userKeyErrorSummary ??
            res.errorSummary ??
            'AI could not answer right now',
      );
    } catch (e) {
      return (entry: null, errorDetail: _router.shortError(e));
    }
  }
}
