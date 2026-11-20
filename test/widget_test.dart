import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:languagema/l10n/app_strings.dart';
import 'package:languagema/models/app_settings.dart';
import 'package:languagema/models/exam_models.dart';
import 'package:languagema/models/grammar_book_models.dart';
import 'package:languagema/models/level_curriculum.dart';
import 'package:languagema/models/reading_rules_book.dart';
import 'package:languagema/models/study_material.dart';
import 'package:languagema/models/user_progress.dart';
import 'package:languagema/models/vocab_word.dart';
import 'package:languagema/services/ai/ai_curriculum_service.dart';
import 'package:languagema/services/ai/ai_router_client.dart';
import 'package:languagema/services/ai/ai_translation_service.dart';
import 'package:languagema/services/cefr_exam_blueprints.dart';
import 'package:languagema/services/cefr_question_bank.dart';
import 'package:languagema/services/csv_service.dart';
import 'package:languagema/services/gemini_service.dart';
import 'package:languagema/services/pronunciation_service.dart';
import 'package:languagema/services/storage_service.dart';
import 'package:languagema/services/tts_service.dart';
import 'package:languagema/services/web_article_service.dart';
import 'package:languagema/services/word_script_validator.dart';
import 'package:languagema/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('CSV serialization and parsing round-trip (Anki compatible)', () {
    final csvService = CsvService();
    final now = DateTime.now();
    final sample = [
      VocabWord(
        id: '1',
        word: 'immerse',
        translation: 'занурюватися, поринати',
        contextSentence: 'Immerse yourself in "authentic" content.',
        exampleSentence: 'She immersed herself in German cinema.',
        partOfSpeech: 'verb',
        sourceTitle: 'Sample',
        createdAt: now,
        nextReviewAt: now,
      ),
    ];

    final serialized = csvService.serializeToCsv(sample);
    final parsed = csvService.parseCsvContent(serialized);

    expect(parsed.importedWords.length, 1);
    expect(parsed.importedWords.first.word, 'immerse');
    expect(parsed.importedWords.first.translation, 'занурюватися, поринати');
    expect(
      parsed.importedWords.first.contextSentence,
      'Immerse yourself in "authentic" content.',
    );
  });

  test('SM-2 SRS rating updates interval and repetitions', () {
    final now = DateTime.now();
    final word = VocabWord(
      id: '2',
      word: 'lucid',
      translation: 'ясний',
      createdAt: now,
      nextReviewAt: now,
    );

    final afterGood = word.applySrsRating(SrsRating.good);
    expect(afterGood.repetitions, 1);
    expect(afterGood.intervalDays, 1);

    final afterSecondGood = afterGood.applySrsRating(SrsRating.good);
    expect(afterSecondGood.repetitions, 2);
    expect(afterSecondGood.intervalDays, 6);

    final afterAgain = afterSecondGood.applySrsRating(SrsRating.again);
    expect(afterAgain.repetitions, 0);
    expect(afterAgain.lapses, 1);
  });

  test('Every CEFR level (A1-C2) has 20 exam questions', () {
    for (final level in CefrLevel.values) {
      final questions = CefrQuestionBank.getQuestions(level);
      expect(questions.length, 20,
          reason: 'Level ${level.code} must have 20 questions');
    }
  });

  test('Pronunciation evaluation calculates accuracy score and transcription', () {
    final service = PronunciationService();
    final exact = service.evaluatePronunciation(
      targetText: 'immerse yourself in authentic content',
      spokenText: 'immerse yourself in authentic content',
    );
    expect(exact.scorePercent, 100);
    expect(exact.isExcellent, isTrue);

    final phoneticNative = service.buildInstantTranscription(
      'nation',
      langCode: 'en',
      nativeLangCode: 'uk',
      useInternationalIpa: false,
    );
    expect(phoneticNative, contains('шн'));

    final phoneticIpa = service.buildInstantTranscription(
      'nation',
      langCode: 'en',
      nativeLangCode: 'uk',
      useInternationalIpa: true,
    );
    expect(phoneticIpa, contains('ʃən'));
  });

  test('NVIDIA NIM and Google Vertex AI API key detection and Reman Friends system', () {
    expect(
      GeminiService.detectProviderName('nvapi-1234567890abcdef'),
      contains('NVIDIA NIM'),
    );
    expect(
      GeminiService.detectProviderName('AQ.Ab8RTestVertexExpressKey123'),
      'Google Vertex AI (Gemini)',
    );
    expect(
      GeminiService.detectProviderName('AIzaSyTestGoogleGeminiKey123'),
      contains('Google Gemini AI'),
    );

    const progress = UserProgress();
    expect(progress.displayName, 'Учень Reman');
    expect(progress.remanFriendCode, startsWith('REMAN-'));

    // Verify 90+ world languages including Latin ('la') and Japanese ('ja') UI localization
    expect(supportedLanguages.length, greaterThanOrEqualTo(85));
    expect(supportedLanguages.any((l) => l.code == 'la'), isTrue);
    expect(AppStrings('ja').tr('tab_materials'), '教材');
    expect(AppStrings('la').tr('tab_vocab'), 'Vocabularium');
  });

  test('SubtitleCue strips HTML font and bold tags from YouTube subtitles', () {
    final cue = SubtitleCue(
      startMs: 0,
      durationMs: 2500,
      text: '<font color="#00BCE7"><b> I recreated Hunger Games </b></font> <font color="#00BCE7"><b> in REAL life! </b></font>',
      translation: '<font color="#00BCE7"><b> Я відтворив Голодні ігри </b></font>',
    );
    expect(cue.text, 'I recreated Hunger Games in REAL life!');
    expect(cue.translation, 'Я відтворив Голодні ігри');
  });

  test('Urdu localization keys and natural voice settings defaults work', () {
    expect(AppStrings('ur').tr('translate_sentence_btn'), 'جملے کا ترجمہ کریں');
    expect(AppStrings('ur').tr('voice_section_title'), contains('قدرتی آواز'));
    expect(AppStrings('ur').tr('ach_first_word_title'), 'پہلا قدم');

    const settings = AppSettings();
    expect(settings.voicePreset, 'neural_natural');
    expect(settings.speechRate, 0.48);
  });

  test('Official CEFR Blueprints cover all levels A1-C2 and all 4 subtests', () {
    for (final level in CefrLevel.values) {
      for (final subtest in ExamSubtest.values) {
        final bpJson = CefrExamBlueprints.getBlueprintJson(level, subtest);
        final decoded = jsonDecode(bpJson) as Map<String, dynamic>;
        expect(decoded['level'], level.code);
        expect(decoded['subtest'], subtest.apiName);
        expect(decoded['pass_threshold_percent'], 60);
        expect(
          CefrExamBlueprints.defaultTimeLimitMinutes(level, subtest),
          greaterThan(0),
        );

        final fallback = CefrExamBlueprints.buildEnglishFallbackPaper(
          level: level,
          subtest: subtest,
          targetLanguage: supportedLanguages.firstWhere((l) => l.code == 'de'),
        );
        expect(
          fallback.tasks.length,
          CefrExamBlueprints.plannedTaskCount(subtest),
          reason: '${level.code} ${subtest.apiName} should have full task count',
        );
        expect(fallback.totalMaxPoints, greaterThanOrEqualTo(30));

        // Verify full-length reading articles & long listening dialogues even in demo/fallback
        if (subtest == ExamSubtest.reading ||
            subtest == ExamSubtest.listening) {
          final firstTaskWords = fallback.tasks.first.stimulus.textOrTranscript
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .length;
          expect(
            firstTaskWords,
            greaterThanOrEqualTo(180),
            reason:
                '${level.code} ${subtest.apiName} Task 1 must be a full-length text/dialogue (>=180 words)',
          );
          final totalQs = fallback.tasks
              .fold<int>(0, (sum, t) => sum + t.questions.length);
          expect(totalQs, greaterThanOrEqualTo(15));
        }
      }
    }

    // Verify TTS splits long 2-minute transcripts safely into chunks <= 320 chars
    final longPaper = CefrExamBlueprints.buildEnglishFallbackPaper(
      level: CefrLevel.b2,
      subtest: ExamSubtest.listening,
      targetLanguage: supportedLanguages.firstWhere((l) => l.code == 'en'),
    );
    final chunks = TtsService.splitIntoSpeechChunks(
      longPaper.tasks.first.stimulus.textOrTranscript,
    );
    expect(chunks.length, greaterThanOrEqualTo(4));
    for (final c in chunks) {
      expect(c.length, lessThanOrEqualTo(320));
    }
  });

  test('OfficialExamSubtestPaper.fromJson parses exact certification JSON schema', () {
    final sampleJson = <String, dynamic>{
      'exam_meta': {
        'language': 'German',
        'level': 'B1',
        'subtest': 'Reading',
        'time_limit_minutes': 35,
        'pass_threshold_percent': 60,
      },
      'tasks': [
        {
          'task_number': 1,
          'task_type': 'multiple_choice',
          'instruction_ui': 'Прочитайте оголошення та оберіть правильну відповідь.',
          'instruction_target': 'Lesen Sie die Anzeige und wählen Sie die richtige Antwort.',
          'stimulus': {
            'text_or_transcript': 'Die Bibliothek ist am Samstag von 9 bis 14 Uhr geöffnet.',
            'visual_prompt_description': 'Двері міської бібліотеки з графіком роботи.',
          },
          'questions': [
            {
              'id': 1,
              'question_text': 'Wann schließt die Bibliothek am Samstag?',
              'options': ['A) Um 9 Uhr', 'B) Um 14 Uhr', 'C) Am Sonntag'],
              'correct_answer': 'B',
              'explanation': 'У тексті зазначено: von 9 bis 14 Uhr.',
            },
          ],
          'evaluation_criteria': {
            'min_words': 0,
            'max_points': 6,
            'rubric': '1 бал за правильну відповідь.',
          },
        },
        {
          'task_number': 2,
          'task_type': 'open_writing',
          'instruction_ui': 'Напишіть відповідь другу.',
          'instruction_target': 'Schreiben Sie eine E-Mail an Ihren Freund.',
          'stimulus': {
            'text_or_transcript': 'Hallo! Kommst du am Wochenende mit ins Kino?',
            'visual_prompt_description': null,
          },
          'questions': [],
          'evaluation_criteria': {
            'min_words': 60,
            'max_points': 12,
            'rubric': 'Оцінюється зміст, зв’язність та граматика.',
          },
        },
      ],
    };

    final paper = OfficialExamSubtestPaper.fromJson(
      sampleJson,
      fallbackLanguage: 'German',
      fallbackLevel: 'B1',
      fallbackSubtest: ExamSubtest.reading,
      fallbackTimeMinutes: 35,
      usedAi: true,
      providerUsed: 'NVIDIA NIM',
    );

    expect(paper.examMeta.language, 'German');
    expect(paper.examMeta.level, 'B1');
    expect(paper.examMeta.subtest, ExamSubtest.reading);
    expect(paper.examMeta.timeLimitMinutes, 35);
    expect(paper.examMeta.passThresholdPercent, 60);
    expect(paper.tasks.length, 2);
    expect(paper.totalMaxPoints, 18);

    final t1 = paper.tasks[0];
    expect(t1.taskType, OfficialTaskType.multipleChoice);
    expect(t1.stimulus.hasVisualPrompt, isTrue);
    expect(t1.questions.first.resolveCorrectOptionIndex(), 1);
    expect(t1.questions.first.displayCorrectAnswerText, 'B) Um 14 Uhr');

    final t2 = paper.tasks[1];
    expect(t2.taskType, OfficialTaskType.openWriting);
    expect(t2.stimulus.hasVisualPrompt, isFalse);
    expect(t2.evaluationCriteria.minWords, 60);
  });

  test('OfficialExamSubtestPaper.fromJson handles quirky LLM types without throwing', () {
    final quirkyJson = <String, dynamic>{
      'exam': {
        'meta': {
          'language': 'Spanish',
          'level': 'B2',
          'subtest': 'Listening',
          'time_limit_minutes': '40 minutes',
          'pass_threshold_percent': '60%',
        },
        'sections': [
          {
            'task_number': '1',
            'task_type': 'gap-fill',
            'instruction': 'Fill in the missing detail.',
            'instruction_target': 'Completa la información.',
            'stimulus': {
              'transcript': ['Line one of dialogue.', 'Line two of dialogue.'],
              'visual_prompt_description': 'null',
            },
            'questions': [
              {
                'id': '1',
                'question': 'What time does the train leave?',
                'options': {'A': '08:00', 'B': '09:30', 'C': '11:15'},
                'correct_answer': 'B',
                'explanation': ['Mentioned in line two.'],
              },
            ],
            'evaluation_criteria': {
              'min_words': '0',
              'max_points': '8 pts',
              'rubric': ['1 point per correct item'],
            },
          },
          {
            'task_number': '2',
            'task_type': 'monologue',
            'instruction_ui': 'Speak about the topic.',
            'stimulus': 'Discuss sustainable transport in your city.',
            'questions': ['Give two examples.', 'Compare costs and speed.'],
            'evaluation_criteria': {'min_words': '80', 'max_points': '12'},
          },
        ],
      },
    };

    final paper = OfficialExamSubtestPaper.fromJson(
      quirkyJson,
      fallbackLanguage: 'Spanish',
      fallbackLevel: 'B2',
      fallbackSubtest: ExamSubtest.listening,
      fallbackTimeMinutes: 35,
      usedAi: false,
      providerUsed: 'CEFR Blueprint Bank',
      fallbackReason: 'NVIDIA: HTTP 429 Too Many Requests',
    );

    expect(paper.examMeta.timeLimitMinutes, 40);
    expect(paper.examMeta.passThresholdPercent, 60);
    expect(paper.tasks.length, 2);
    expect(paper.tasks[0].taskType, OfficialTaskType.shortAnswer);
    expect(paper.tasks[0].stimulus.textOrTranscript, contains('Line two'));
    expect(paper.tasks[0].questions.first.options, ['A) 08:00', 'B) 09:30', 'C) 11:15']);
    expect(paper.tasks[0].evaluationCriteria.maxPoints, 8);
    expect(paper.tasks[1].taskType, OfficialTaskType.speakingRoleplay);
    expect(paper.tasks[1].questions.length, 2);
    expect(paper.tasks[1].evaluationCriteria.minWords, 80);

    final session = OfficialExamSession(level: CefrLevel.b2, subtests: [paper]);
    expect(session.hasAnyFallback, isTrue);
    expect(session.aiFallbackReasons.first, contains('HTTP 429'));
  });

  test('Dynamic Gemini model discovery filters and sorts for heavy vs fast tasks', () {
    final rawApiModels = [
      {
        'name': 'models/text-embedding-004',
        'supportedGenerationMethods': ['embedContent'],
      },
      {
        'name': 'models/gemini-3.5-flash-tts',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-image-gen',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-2.0-flash-live',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-computer-use-preview',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-robotics-er',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-3.1-flash-lite',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-3.5-flash-lite',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-3.6-flash',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-4-hydrogen',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-3.8-flash',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-3.8-pro',
        'supportedGenerationMethods': ['generateContent'],
      },
      {
        'name': 'models/gemini-4-neon',
        'supportedGenerationMethods': ['generateContent'],
      },
    ];

    final filtered = GeminiService.filterGeminiModelEntries(rawApiModels);
    expect(filtered, isNot(contains('text-embedding-004')));
    expect(filtered, isNot(contains('gemini-3.5-flash-tts')));
    expect(filtered, isNot(contains('gemini-image-gen')));
    expect(filtered, isNot(contains('gemini-2.0-flash-live')));
    expect(filtered, isNot(contains('gemini-computer-use-preview')));
    expect(filtered, isNot(contains('gemini-robotics-er')));
    expect(filtered.length, 7);

    // Heavy task (exams): flagships (neon/pro) -> balanced (3.8-flash -> 4-hydrogen -> 3.6-flash) -> lite
    final heavy = GeminiService.sortGeminiModels(filtered, fastTask: false);
    expect(heavy.first, 'gemini-4-neon');
    expect(heavy[1], 'gemini-3.8-pro');
    expect(heavy[2], 'gemini-3.8-flash');
    expect(heavy[3], 'gemini-4-hydrogen');
    expect(heavy[4], 'gemini-3.6-flash');
    expect(heavy[5], 'gemini-3.5-flash-lite');
    expect(heavy[6], 'gemini-3.1-flash-lite');

    // Fast task (word lookup / photo OCR): lite first (500 RPD free), then flash, then flagships
    final fast = GeminiService.sortGeminiModels(filtered, fastTask: true);
    expect(fast.first, 'gemini-3.5-flash-lite');
    expect(fast[1], 'gemini-3.1-flash-lite');
    expect(fast[2], 'gemini-3.8-flash');
    expect(fast.last, anyOf('gemini-3.8-pro', 'gemini-4-neon'));
  });

  test('Dynamic OpenAI-compatible discovery, prioritization & smart model cache eviction', () {
    expect(GeminiService.isSupportedOpenAiChatModel('whisper-large-v3'), isFalse);
    expect(GeminiService.isSupportedOpenAiChatModel('nvidia/nv-embedqa-e5-v5'), isFalse);
    expect(GeminiService.isSupportedOpenAiChatModel('black-forest-labs/flux.1-schnell'), isFalse);
    expect(GeminiService.isSupportedOpenAiChatModel('meta/llama-guard-3-8b'), isFalse);
    expect(GeminiService.isSupportedOpenAiChatModel('openai/gpt-oss-120b'), isTrue);

    final groqOrdered = GeminiService.prioritizeOpenAiModels(
      ['llama-3.1-8b-instant', 'openai/gpt-oss-20b', 'qwen/qwen3.8-27b', 'openai/gpt-oss-120b'],
      priorityModels: const ['openai/gpt-oss-120b', 'qwen/qwen3.8-27b', 'openai/gpt-oss-20b'],
    );
    expect(groqOrdered.take(3).toList(), [
      'openai/gpt-oss-120b',
      'qwen/qwen3.8-27b',
      'openai/gpt-oss-20b',
    ]);

    // Key prioritization: Groq (gsk_...) and Gemini (AIza...) before NVIDIA (nvapi-...)
    final mixedKeys = [
      'nvapi-firstSlowKey',
      'AIzaSyGeminiKey',
      'sk-openaiKey',
      'gsk_groqUltraFastKey',
    ];
    final prioritizedKeys = GeminiService.prioritizeKeys(mixedKeys);
    expect(prioritizedKeys.first, 'gsk_groqUltraFastKey');
    expect(prioritizedKeys[1], 'AIzaSyGeminiKey');
    expect(prioritizedKeys.last, 'nvapi-firstSlowKey');

    // NVIDIA models put fast model first
    expect(
      AiRouterClient.nvidiaPriorityModels.first,
      'minimaxai/minimax-m3.1-flash',
    );

    final openRouterFree = GeminiService.prioritizeOpenAiModels(
      ['openai/gpt-4o', 'meta-llama/llama-4-scout:free', 'google/gemma-4-31b-it:free'],
      priorityModels: const [
        'openrouter/free',
        'google/gemma-4-31b-it:free',
        'google/gemma-4-26b-a4b-it:free',
      ],
      onlyFree: true,
    );
    expect(openRouterFree.first, 'openrouter/free');
    expect(openRouterFree, contains('google/gemma-4-31b-it:free'));
    expect(openRouterFree, contains('google/gemma-4-26b-a4b-it:free'));
    expect(openRouterFree, isNot(contains('openai/gpt-4o')));

    // Verify smart working-model cache & eviction on HTTP 429 / 404
    final service = GeminiService();
    const cKey = 'gemini:heavy:AIzaSy_123456';
    const eKey = 'gemini:AIzaSy_123456';
    final models = ['gemini-4-neon', 'gemini-3.8-flash', 'gemini-3.5-flash-lite'];

    // Simulate flagship returning 429 (free key 0/0) -> skipped on next call
    service.handleModelStatusForTest(cKey, eKey, 'gemini-4-neon', 429);
    var nextCandidates = service.buildOrderedCandidatesForTest(cKey, eKey, models);
    expect(nextCandidates.first, 'gemini-3.8-flash');
    expect(nextCandidates, isNot(contains('gemini-4-neon')));

    // Cache working model -> jumps to front on subsequent requests
    service.recordModelSuccessForTest(cKey, 'gemini-3.5-flash-lite');
    nextCandidates = service.buildOrderedCandidatesForTest(cKey, eKey, models);
    expect(nextCandidates.first, 'gemini-3.5-flash-lite');

    // If cached model later returns 404 -> evicted from cache
    service.handleModelStatusForTest(cKey, eKey, 'gemini-3.5-flash-lite', 404);
    expect(service.workingModelCache.containsKey(cKey), isFalse);
    nextCandidates = service.buildOrderedCandidatesForTest(cKey, eKey, models);
    expect(nextCandidates.first, 'gemini-3.8-flash');

    // Verify single-section evaluating label string
    expect(
      AppStrings('uk')
          .tr('exam_evaluating_single')
          .replaceAll('{subtest}', AppStrings('uk').tr('subtest_reading')),
      'ШІ перевіряє секцію «Читання»...',
    );
  });

  test('WebArticleService HTML cleaning and paragraph extraction', () {
    const sampleHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>Site Name -Ignored</title>
  <meta property="og:title" content="How Immersion Accelerates Language Learning" />
  <style>body { color: red; }</style>
  <script>console.log("tracking ad");</script>
</head>
<body>
  <header><nav><a href="/">Home</a><a href="/about">About</a></nav></header>
  <div class="cookie-banner">We use cookies to improve your experience.</div>
  <article>
    <h1>How Immersion Accelerates Language Learning</h1>
    <p>Reading authentic articles in context helps learners remember vocabulary naturally.</p>
    <div class="ad-banner">Advertisement: Buy now!</div>
    <p>When you encounter words inside real stories, your brain forms stronger associations.</p>
  </article>
  <aside><p>Related sidebar links that should be ignored.</p></aside>
  <footer><p>All rights reserved 2026</p></footer>
</body>
</html>
''';
    final parsed = WebArticleService.parseHtmlArticle(
      sampleHtml,
      fallbackUrl: 'https://example.com/immersion',
    );
    expect(parsed.title, 'How Immersion Accelerates Language Learning');
    expect(parsed.paragraphs.length, 3);
    expect(
      parsed.content,
      contains('Reading authentic articles in context helps learners'),
    );
    expect(parsed.content, isNot(contains('console.log')));
    expect(parsed.content, isNot(contains('All rights reserved')));
    expect(parsed.content, isNot(contains('Advertisement')));
  });

  test('Universal CEFR Curriculum Blueprint, cache keys & offline fallback', () {
    // 6 CEFR levels x 7 sequential topics = 42 language-independent modules
    expect(UniversalCurriculumBlueprint.allNodes.length, 42);
    for (final level in CefrLevel.values) {
      final nodes = UniversalCurriculumBlueprint.nodesForLevel(level);
      expect(nodes.length, 7, reason: '${level.code} must have 7 modules');
    }

    final firstA1 = UniversalCurriculumBlueprint.nodesForLevel(CefrLevel.a1).first;
    expect(
      firstA1.cacheKey(targetLangCode: 'cs', nativeLangCode: 'uk'),
      'level_cs_uk_a1_a1_m1',
    );

    final fallback = UniversalCurriculumBlueprint.buildOfflineFallback(
      node: firstA1,
      targetLang: languageByCode('cs'),
      nativeLang: languageByCode('uk'),
    );
    expect(fallback.isValid, isTrue);
    expect(fallback.usedAi, isFalse);
    expect(fallback.examples.length, greaterThanOrEqualTo(3));
    expect(fallback.practiceExercises.length, 5);
    expect(fallback.finalTest.length, 5);

    // JSON round-trip for local SharedPreferences cache
    final restored = GeneratedLevelContent.fromJson(fallback.toJson());
    expect(restored.grammarRule, fallback.grammarRule);
    expect(restored.commonMistakes, fallback.commonMistakes);
    expect(restored.examples.length, fallback.examples.length);
    expect(restored.practiceExercises.length, 5);
    expect(restored.finalTest.length, 5);

    // Topic-aware cache key preserves neutral key and isolates domain-specific keys
    expect(
      firstA1.cacheKey(
        targetLangCode: 'cs',
        nativeLangCode: 'uk',
        topicId: 'neutral',
      ),
      'level_cs_uk_a1_a1_m1',
    );
    expect(
      firstA1.cacheKey(
        targetLangCode: 'cs',
        nativeLangCode: 'uk',
        topicId: 'travel',
      ),
      'level_cs_uk_a1_a1_m1_travel',
    );
  });

  test('LearningTopic domain options, prompt directives & localization keys', () {
    expect(LearningTopic.values.length, 6);
    expect(LearningTopic.fromId(null), LearningTopic.neutral);
    expect(LearningTopic.fromId('unknown_id'), LearningTopic.neutral);
    expect(LearningTopic.fromId('medicine_health'), LearningTopic.medicineHealth);

    const defaultSettings = AppSettings();
    expect(defaultSettings.learningTopic, LearningTopic.neutral);
    final travelSettings = defaultSettings.copyWith(
      learningTopicId: LearningTopic.travel.id,
    );
    expect(travelSettings.learningTopic, LearningTopic.travel);
    expect(travelSettings.learningTopic.aiPromptDirective, contains('Travel'));

    // Ensure previously missing/raw localization keys and new keys resolve properly
    for (final lang in ['uk', 'en', 'ur']) {
      final s = AppStrings(lang);
      for (final key in [
        'ok_btn',
        'retake_exam_btn',
        'level_locked_short',
        'learning_topic_section',
        'topic_neutral_title',
        'topic_daily_life_title',
        'topic_work_career_title',
        'topic_travel_title',
        'topic_medicine_health_title',
        'topic_friends_social_title',
        'rules_book_title',
        'rules_book_refresh_btn',
        'rules_book_sec_alphabet',
        'rules_book_sec_reading',
        'rules_book_sec_stress',
        'rules_book_sec_writing',
      ]) {
        final value = s.tr(key);
        expect(value, isNot(equals(key)),
            reason: 'Key "$key" must be localized for "$lang"');
        expect(value.trim(), isNotEmpty);
      }
    }
  });

  test('ReadingRulesBook validation, cache keys, offline fallback & JSON round-trip', () {
    final cacheKey = ReadingRulesBook.cacheKey(
      targetLangCode: 'de',
      nativeLangCode: 'uk',
    );
    expect(cacheKey, 'rules_book_de_uk');

    final emptyBook = const ReadingRulesBook(
      targetLanguageCode: 'de',
      nativeLanguageCode: 'uk',
      overview: 'short',
      alphabetAndDiacritics: [],
      readingRules: [],
      stressAndIntonation: [],
      writingRules: [],
    );
    expect(emptyBook.isValid, isFalse);

    final fallback = ReadingRulesBook.buildOfflineFallback(
      targetLang: languageByCode('de'),
      nativeLang: languageByCode('uk'),
    );
    expect(fallback.isValid, isTrue);
    expect(fallback.usedAi, isFalse);
    expect(fallback.alphabetAndDiacritics, isNotEmpty);
    expect(fallback.readingRules, isNotEmpty);
    expect(fallback.stressAndIntonation, isNotEmpty);
    expect(fallback.writingRules, isNotEmpty);

    final restored = ReadingRulesBook.fromJson(fallback.toJson());
    expect(restored.isValid, isTrue);
    expect(restored.targetLanguageCode, 'de');
    expect(restored.nativeLanguageCode, 'uk');
    expect(
      restored.alphabetAndDiacritics.length,
      fallback.alphabetAndDiacritics.length,
    );
    expect(restored.readingRules.length, fallback.readingRules.length);
    expect(
      restored.stressAndIntonation.length,
      fallback.stressAndIntonation.length,
    );
    expect(restored.writingRules.length, fallback.writingRules.length);
  });

  test('Gemini 429 marks model unavailable for session, skips Vertex on 429, and caches HTTP 200 model', () async {
    final requestedUrls = <String>[];
    final mockClient = MockClient((request) async {
      final url = request.url.toString();
      requestedUrls.add(url);

      if (request.method == 'GET' && url.contains('/v1beta/models?key=')) {
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-4-neon',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/gemini-3.8-flash',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/gemini-4-hydrogen',
                'supportedGenerationMethods': ['generateContent'],
              },
              {
                'name': 'models/gemini-3.5-flash-lite',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
          200,
        );
      }

      if (url.contains('aiplatform.googleapis.com')) {
        return http.Response('{"error":{"message":"Vertex disabled"}}', 403);
      }

      if (url.contains('/models/gemini-4-neon:generateContent')) {
        return http.Response(
          '{"error":{"code":429,"message":"Quota exceeded"}}',
          429,
        );
      }

      if (url.contains('/models/gemini-3.8-flash:generateContent')) {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'OK_FROM_FLASH'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
          200,
        );
      }

      return http.Response('{"error":{"message":"Unexpected"}}', 500);
    });

    final router = AiRouterClient(httpClient: mockClient);

    // 1st request: gemini-4-neon returns 429 ONCE (no retry), immediately moves to
    // gemini-3.8-flash (200), never hits Vertex AI, and caches gemini-3.8-flash.
    final firstRes = await router.generateTextSmart(
      prompt: 'Say OK',
      rawKeys: 'AIzaSyTestGeminiKey123456',
      fastTask: false,
    );
    expect(firstRes.text, 'OK_FROM_FLASH');
    expect(firstRes.provider, 'Gemini (gemini-3.8-flash)');
    expect(
      requestedUrls.where((u) => u.contains('gemini-4-neon')).length,
      1,
      reason: '429 model must not be retried on the same request',
    );
    expect(
      requestedUrls.any((u) => u.contains('aiplatform.googleapis.com')),
      isFalse,
      reason: 'Must never fall back to Vertex AI for AI Studio key',
    );

    // 2nd request: goes directly to cached gemini-3.8-flash with zero 429 calls
    requestedUrls.clear();
    final secondRes = await router.generateTextSmart(
      prompt: 'Say OK again',
      rawKeys: 'AIzaSyTestGeminiKey123456',
      fastTask: false,
    );
    expect(secondRes.text, 'OK_FROM_FLASH');
    expect(requestedUrls.length, 1);
    expect(requestedUrls.single, contains('gemini-3.8-flash'));
  });

  test('9-Chapter Grammar Handbook blueprint, cache keys, tables & AI Q&A history', () async {
    expect(GrammarBookBlueprint.chapters.length, 9);

    for (var i = 0; i < GrammarBookBlueprint.chapters.length; i++) {
      final ch = GrammarBookBlueprint.chapters[i];
      expect(ch.number, i + 1);
      expect(
        ch.cacheKey(targetLangCode: 'cs', nativeLangCode: 'uk'),
        'grammar_book_cs_uk_${ch.id}',
      );
      for (final lang in ['uk', 'en', 'ur']) {
        final s = AppStrings(lang);
        expect(s.tr(ch.titleKey), isNot(equals(ch.titleKey)));
        expect(s.tr(ch.subtitleKey), isNot(equals(ch.subtitleKey)));
      }
    }

    // Exact Q&A storage key
    expect(
      GrammarQaEntry.storageKey(targetLangCode: 'de', nativeLangCode: 'uk'),
      'grammar_qa_de_uk',
    );

    // Chapter content + table JSON round-trip
    final chapter = GrammarChapterContent(
      chapterId: 'ch2_nouns',
      targetLanguageCode: 'de',
      nativeLanguageCode: 'uk',
      summary: 'У німецькій мові є 3 роди та 4 відмінки.',
      tables: const [
        GrammarTable(
          title: 'Означені артиклі за відмінками',
          headers: ['Відмінок', 'Чол.', 'Жін.', 'Сер.', 'Мн.'],
          rows: [
            ['Nominativ', 'der', 'die', 'das', 'die'],
            ['Akkusativ', 'den', 'die', 'das', 'die'],
          ],
          note: 'У Akkusativ змінюється лише чоловічий рід.',
        ),
      ],
      sections: const [
        GrammarRuleSection(
          title: 'Чоловічий рід',
          explanation: 'Слова на -er, -en, дні тижня та пори року.',
          exceptions: ['das Fenster — середній рід'],
          examples: [
            ReadingRuleExample(
              text: 'Der Lehrer spricht klar.',
              pronunciation: '[дер лерер шпріхт клар]',
              translation: 'Вчитель говорить чітко.',
            ),
          ],
        ),
        GrammarRuleSection(
          title: 'Множина іменників',
          explanation: 'У множині завжди вживається артикль die.',
          examples: [
            ReadingRuleExample(
              text: 'Die Bücher liegen auf dem Tisch.',
              pronunciation: '',
              translation: 'Книги лежать на столі.',
            ),
          ],
        ),
      ],
      keyExceptions: const ['das Mädchen — середній рід через суфікс -chen'],
      commonMistakes: const ['Плутання der/den у знахідному відмінку'],
      usedAi: true,
      providerName: 'Gemini (gemini-3.8-flash)',
    );
    expect(chapter.isValid, isTrue);
    final restoredChapter = GrammarChapterContent.fromJson(chapter.toJson());
    expect(restoredChapter.isValid, isTrue);
    expect(restoredChapter.tables.length, 1);
    expect(restoredChapter.tables.first.rows.length, 2);
    expect(restoredChapter.sections.length, 2);
    expect(restoredChapter.keyExceptions.length, 1);

    // Ask AI grammar question end-to-end with MockClient
    final mockClient = MockClient((request) async {
      final url = request.url.toString();
      if (request.method == 'GET' && url.contains('/v1beta/models?key=')) {
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-3.8-flash',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
          200,
        );
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'answer':
                            'Після прийменника mit завжди вживається Dativ.',
                        'tables': [
                          {
                            'title': 'Артиклі в Dativ',
                            'headers': ['Рід', 'Артикль'],
                            'rows': [
                              ['Чол./Сер.', 'dem'],
                              ['Жін.', 'der'],
                            ],
                          },
                        ],
                        'examples': [
                          {
                            'text': 'Ich fahre mit dem Zug.',
                            'pronunciation': '[іх фаре міт дем цуґ]',
                            'translation': 'Я їду поїздом.',
                          },
                        ],
                        'exceptionsAndMistakes': [
                          'Не кажіть "mit den Zug" — після mit потрібен Dativ.',
                        ],
                      }),
                    },
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final curriculum = AiCurriculumService(AiRouterClient(httpClient: mockClient));
    final qaRes = await curriculum.askGrammarQuestion(
      question: 'Коли вживається Dativ після mit?',
      targetLang: languageByCode('de'),
      nativeLang: languageByCode('uk'),
      settings: const AppSettings(
        targetLanguageCode: 'de',
        nativeLanguageCode: 'uk',
        geminiApiKey: 'AIzaSyMockQaTestKey123',
        learningTopicId: 'travel',
      ),
    );
    expect(qaRes.errorDetail, isNull);
    expect(qaRes.entry, isNotNull);
    expect(qaRes.entry!.isValid, isTrue);
    expect(qaRes.entry!.examples.first.text, 'Ich fahre mit dem Zug.');
    expect(qaRes.entry!.tables.length, 1);

    final restoredQa = GrammarQaEntry.fromJson(qaRes.entry!.toJson());
    expect(restoredQa.question, 'Коли вживається Dativ після mit?');
    expect(restoredQa.exceptionsAndMistakes.length, 1);
  });

  test('AI vocabulary autofill parses structured JSON, respects topic & caches locally', () async {
    SharedPreferences.setMockInitialValues({});

    String? capturedPrompt;
    var apiCalls = 0;
    final mockClient = MockClient((request) async {
      final url = request.url.toString();
      if (request.method == 'GET' && url.contains('/v1beta/models?key=')) {
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-3.5-flash-lite',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
          200,
        );
      }
      apiCalls++;
      capturedPrompt = request.body;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'translation': 'квиток на поїзд',
                        'example': 'Ich habe eine Fahrkarte nach Wien gekauft.',
                        'exampleTranslation': 'Я купив квиток до Відня.',
                        'partOfSpeech': 'іменник',
                      }),
                    },
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final router = AiRouterClient(httpClient: mockClient);
    final translationService = AiTranslationService(router);
    const settings = AppSettings(
      targetLanguageCode: 'de',
      nativeLanguageCode: 'uk',
      geminiApiKey: 'AIzaSyMockAutofillKey12345',
      learningTopicId: 'travel',
    );

    final result = await translationService.autofillVocabularyWord(
      word: 'die Fahrkarte',
      settings: settings,
    );
    expect(apiCalls, 1);
    expect(capturedPrompt, contains('Travel'));
    expect(result.hasTranslation, isTrue);
    expect(result.usedAi, isTrue);
    expect(result.translation, 'квиток на поїзд');
    expect(result.example, 'Ich habe eine Fahrkarte nach Wien gekauft.');
    expect(result.exampleTranslation, 'Я купив квиток до Відня.');
    expect(result.partOfSpeech, 'іменник');

    // Local cache round-trip in StorageService
    final storage = StorageService();
    await storage.saveVocabAutofillCache(
      result: result,
      targetLangCode: 'de',
      nativeLangCode: 'uk',
      topicId: 'travel',
    );
    final cached = await storage.loadVocabAutofillCache(
      word: '  DIE   fahrkarte ',
      targetLangCode: 'de',
      nativeLangCode: 'uk',
      topicId: 'travel',
    );
    expect(cached, isNotNull);
    expect(cached!.fromCache, isTrue);
    expect(cached.translation, 'квиток на поїзд');
    expect(cached.exampleTranslation, 'Я купив квиток до Відня.');

    // VocabWord JSON round-trip preserves exampleTranslation
    final now = DateTime.now();
    final vocabWord = VocabWord(
      id: 'w1',
      word: 'die Fahrkarte',
      translation: cached.translation,
      exampleSentence: cached.example,
      exampleTranslation: cached.exampleTranslation,
      partOfSpeech: cached.partOfSpeech,
      createdAt: now,
      nextReviewAt: now,
    );
    final restoredWord = VocabWord.fromJson(vocabWord.toJson());
    expect(restoredWord.exampleTranslation, 'Я купив квиток до Відня.');

    // Verify new Add Word localization keys
    for (final lang in ['uk', 'en', 'ur']) {
      final s = AppStrings(lang);
      for (final key in [
        'word_in_target_lang_label',
        'ai_autofill_btn',
        'ai_autofill_loading',
        'ai_autofill_offline_hint',
        'example_usage_label',
        'example_translation_label',
        'speak_word_tooltip',
        'speak_example_tooltip',
        'vocab_script_mismatch_warning',
        'vocab_lang_mismatch_warning',
        'vocab_replace_word_btn',
        'vocab_save_mismatch_title',
        'vocab_save_anyway_btn',
      ]) {
        expect(s.tr(key), isNot(equals(key)));
      }
    }
  });

  test('WordScriptValidator catches script mismatches locally without API calls', () async {
    // Cyrillic entered for Latin target (German / English / Czech)
    final cyrillicInGerman = WordScriptValidator.validate(
      text: 'яблуко',
      targetLangCode: 'de',
    );
    expect(cyrillicInGerman.isCompatible, isFalse);
    expect(cyrillicInGerman.detectedUnexpectedScript, WritingScript.cyrillic);

    // Latin entered for Cyrillic target (Ukrainian)
    final latinInUk = WordScriptValidator.validate(
      text: 'apple',
      targetLangCode: 'uk',
    );
    expect(latinInUk.isCompatible, isFalse);
    expect(latinInUk.detectedUnexpectedScript, WritingScript.latin);

    // Mixed lookalike Cyrillic letter inside a Latin word ('c' + Cyrillic 'а' + 't')
    final mixedToken = WordScriptValidator.validate(
      text: 'c\u0430t',
      targetLangCode: 'en',
    );
    expect(mixedToken.isCompatible, isFalse);
    expect(mixedToken.isMixedToken, isTrue);

    // Valid diacritics for German / Czech / Polish
    expect(
      WordScriptValidator.validate(text: 'Straße & Grüße', targetLangCode: 'de')
          .isCompatible,
      isTrue,
    );
    expect(
      WordScriptValidator.validate(text: 'příliš žluťoučký', targetLangCode: 'cs')
          .isCompatible,
      isTrue,
    );

    // Dual-script Serbian accepts both Cyrillic and Latin
    expect(
      WordScriptValidator.validate(text: 'здраво', targetLangCode: 'sr')
          .isCompatible,
      isTrue,
    );
    expect(
      WordScriptValidator.validate(text: 'zdravo', targetLangCode: 'sr')
          .isCompatible,
      isTrue,
    );

    // Numbers & punctuation only are neutral
    expect(
      WordScriptValidator.validate(text: '2026!', targetLangCode: 'de')
          .isCompatible,
      isTrue,
    );

    // AppController.autofillVocabWord skips AI call completely on script mismatch
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    var apiCalls = 0;
    final mockClient = MockClient((request) async {
      apiCalls++;
      return http.Response('{"error":"should not be called"}', 500);
    });
    final controller = AppController(
      geminiService: GeminiService(
        routerClient: AiRouterClient(httpClient: mockClient),
      ),
    );
    await controller.updateSettings(
      const AppSettings(
        targetLanguageCode: 'de',
        nativeLanguageCode: 'uk',
        geminiApiKey: 'AIzaSyTestZeroQuotaGuard123',
      ),
    );
    final blocked = await controller.autofillVocabWord('привіт');
    expect(apiCalls, 0);
    expect(blocked.isTargetLanguage, isFalse);
    expect(blocked.errorDetail, 'script_mismatch');
  });

  test('AI autofill detects wrong language with same script and returns replacement', () async {
    final mockClient = MockClient((request) async {
      final url = request.url.toString();
      if (request.method == 'GET' && url.contains('/v1beta/models?key=')) {
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-3.5-flash-lite',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
          200,
        );
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'isTargetLanguage': false,
                        'detectedLanguage': 'Англійська',
                        'suggestedTargetWord': 'der Apfel',
                        'translation': 'яблуко',
                        'example': 'Ich esse jeden Morgen einen Apfel.',
                        'exampleTranslation': 'Я їм яблуко щоранку.',
                        'partOfSpeech': 'іменник',
                      }),
                    },
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = AiTranslationService(AiRouterClient(httpClient: mockClient));
    final res = await service.autofillVocabularyWord(
      word: 'apple',
      settings: const AppSettings(
        targetLanguageCode: 'de',
        nativeLanguageCode: 'uk',
        geminiApiKey: 'AIzaSyMockLangCheckKey123',
      ),
    );

    expect(res.usedAi, isTrue);
    expect(res.isTargetLanguage, isFalse);
    expect(res.hasLanguageMismatch, isTrue);
    expect(res.detectedLanguage, 'Англійська');
    expect(res.suggestedTargetWord, 'der Apfel');
    expect(res.translation, 'яблуко');
    expect(res.example, 'Ich esse jeden Morgen einen Apfel.');
    expect(res.exampleTranslation, 'Я їм яблуко щоранку.');

    // Serialization round-trip keeps mismatch fields
    final restored = WordAutofillResult.fromJson(res.toJson(), fromCache: true);
    expect(restored.isTargetLanguage, isFalse);
    expect(restored.detectedLanguage, 'Англійська');
    expect(restored.suggestedTargetWord, 'der Apfel');
  });

  test('Universal word origin detection works across any language pair', () async {
    // 1. Universal language-name & ISO code matcher
    expect(
      WordScriptValidator.doesDetectedLanguageMatchTarget(
        detectedLanguage: 'Словацька мова',
        targetLang: languageByCode('cs'),
      ),
      isFalse,
    );
    expect(
      WordScriptValidator.doesDetectedLanguageMatchTarget(
        detectedLanguage: 'Чеська мова',
        targetLang: languageByCode('cs'),
      ),
      isTrue,
    );
    expect(
      WordScriptValidator.doesDetectedLanguageMatchTarget(
        detectedLanguage: 'Німецька (Австрія)',
        detectedLanguageCode: 'de-AT',
        targetLang: languageByCode('de'),
      ),
      isTrue,
    );
    expect(
      WordScriptValidator.doesDetectedLanguageMatchTarget(
        detectedLanguage: 'Російська мова',
        targetLang: languageByCode('uk'),
      ),
      isFalse,
    );
    // Guard against prefix collisions (Malay vs Malayalam, Slovak vs Slovenian, Latin vs Latvian)
    expect(
      WordScriptValidator.doesDetectedLanguageMatchTarget(
        detectedLanguage: 'Malayalam',
        targetLang: languageByCode('ms'),
      ),
      isFalse,
    );
    expect(
      WordScriptValidator.doesDetectedLanguageMatchTarget(
        detectedLanguage: 'Slovenian',
        targetLang: languageByCode('sk'),
      ),
      isFalse,
    );
    expect(
      WordScriptValidator.doesDetectedLanguageMatchTarget(
        detectedLanguage: 'Latvian',
        targetLang: languageByCode('la'),
      ),
      isFalse,
    );

    // 2. Preserves detectedLanguage when word matches target language,
    //    AND flags mismatch if detectedLanguage contradicts targetLanguage
    var callIndex = 0;
    final mockClient = MockClient((request) async {
      final url = request.url.toString();
      if (request.method == 'GET' && url.contains('/v1beta/models?key=')) {
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-3.5-flash-lite',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
          200,
        );
      }
      callIndex++;
      final payload = callIndex == 1
          ? {
              'detectedLanguage': 'Німецька мова',
              'detectedLanguageCode': 'de',
              'isTargetLanguage': true,
              'suggestedTargetWord': '',
              'translation': 'книга',
              'example': 'Das Buch liegt auf dem Tisch.',
              'exampleTranslation': 'Книга лежить на столі.',
              'partOfSpeech': 'іменник',
            }
          : {
              // Even if LLM mistakenly sets isTargetLanguage=true while reporting Slovak for Czech
              'detectedLanguage': 'Словацька мова',
              'detectedLanguageCode': 'sk',
              'isTargetLanguage': true,
              'suggestedTargetWord': 'děkuji',
              'translation': 'дякую',
              'example': 'Děkuji za vaši pomoc.',
              'exampleTranslation': 'Дякую за вашу допомогу.',
              'partOfSpeech': 'вигук',
            };
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': jsonEncode(payload)},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = AiTranslationService(AiRouterClient(httpClient: mockClient));

    // Matched German word retains detectedLanguage
    final matched = await service.autofillVocabularyWord(
      word: 'das Buch',
      settings: const AppSettings(
        targetLanguageCode: 'de',
        nativeLanguageCode: 'uk',
        geminiApiKey: 'AIzaSyUniversalOriginKey123',
      ),
    );
    expect(matched.isTargetLanguage, isTrue);
    expect(matched.detectedLanguage, 'Німецька мова');
    expect(matched.detectedLanguageCode, 'de');
    expect(matched.suggestedTargetWord, isEmpty);

    // Slovak word entered for Czech target is universally flagged as mismatch
    final mismatched = await service.autofillVocabularyWord(
      word: 'ďakujem',
      settings: const AppSettings(
        targetLanguageCode: 'cs',
        nativeLanguageCode: 'uk',
        geminiApiKey: 'AIzaSyUniversalOriginKey123',
      ),
    );
    expect(mismatched.isTargetLanguage, isFalse);
    expect(mismatched.detectedLanguage, 'Словацька мова');
    expect(mismatched.detectedLanguageCode, 'sk');
    expect(mismatched.suggestedTargetWord, 'děkuji');

    // Verify localized warning format & origin label
    final ukStrings = AppStrings('uk');
    expect(
      ukStrings
          .tr('vocab_lang_mismatch_warning')
          .replaceAll('{detected}', 'Словацька мова')
          .replaceAll('{target}', ukStrings.shortLangName(languageByCode('cs'))),
      'Слово визначено як: Словацька мова (обрана мова вивчення: Чеська)',
    );
    expect(
      ukStrings
          .tr('vocab_detected_origin_label')
          .replaceAll('{detected}', 'Німецька мова'),
      'Мова слова: Німецька мова',
    );
  });
}
