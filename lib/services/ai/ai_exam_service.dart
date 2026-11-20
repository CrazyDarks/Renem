import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/app_settings.dart';
import '../../models/exam_models.dart';
import '../cefr_exam_blueprints.dart';
import 'ai_router_client.dart';
import 'ai_translation_service.dart';

/// Generates and evaluates official CEFR certification subtests (Reading,
/// Listening, Writing, Speaking), incorporating the user's [LearningTopic].
class AiExamService {
  AiExamService(this._router, this._translation);

  final AiRouterClient _router;
  final AiTranslationService _translation;

  Future<OfficialExamSubtestPaper> generateOfficialSubtest({
    required CefrLevel level,
    required ExamSubtest subtest,
    required AppSettings settings,
    List<String> recentWords = const [],
    void Function(int percent, String stageKey)? onProgress,
  }) async {
    final targetLang = settings.targetLanguage;
    final nativeLang = settings.nativeLanguage;
    final defaultMinutes =
        CefrExamBlueprints.defaultTimeLimitMinutes(level, subtest);
    final blueprintJson = CefrExamBlueprints.getBlueprintJson(level, subtest);
    final topicDirective = settings.learningTopic.aiPromptDirective;

    onProgress?.call(10, 'exam_stage_prepare');

    final vocabHint = recentWords.isEmpty
        ? ''
        : '\nДодатково (якщо доречно контексту): природно інтегруй 1–3 слова зі словника студента: ${recentWords.take(8).join(', ')}.';

    final prompt = '''
Ти — професійний розробник офіційних сертифікаційних іспитів з іноземних мов (за стандартами ALTE, CEFR/SERRJ, CCE, Goethe, Cambridge, DELF).

Твоє завдання — згенерувати повноцінний екзаменаційний тест (субтест) на основі переданих параметрів та офіційної специфікації (Blueprint).

ВХІДНІ ПАРАМЕТРИ:
- Мова іспиту (цільова мова): ${targetLang.englishName} (${targetLang.code})
- Мова інтерфейсу користувача (для інструкцій і пояснень): ${nativeLang.englishName} (${nativeLang.code})
- Рівень CEFR: ${level.code}
- Субтест: ${subtest.apiName}
- Тематична сфера навчання: $topicDirective
- Офіційна структура субтесту (Blueprint):
$blueprintJson$vocabHint

СУВОРІ ПРАВИЛА ГЕНЕРАЦІЇ:
1. УСІ тексти завдань, запитання, варіанти відповідей, аудіоскрипти, приклади та інструкції іспиту ("instruction_target", "stimulus.text_or_transcript", "questions[].question_text", "questions[].options", "questions[].correct_answer") ПОВИННІ бути написані виключно цільовою мовою (${targetLang.englishName}) з природною автентичною лексикою.
2. Поля "instruction_ui", "stimulus.visual_prompt_description", "questions[].explanation" та "evaluation_criteria.rubric" ПОВИННІ бути написані мовою інтерфейсу (${nativeLang.englishName}).
3. Суворо дотримуйся граматичних, лексичних та обсягових обмежень рівня ${level.code} за стандартом CEFR Companion Volume (2020) та специфікацією Blueprint вище, враховуючи обрану тематичну сферу навчання.
4. Для кожного запитання з варіантами відповідей ("multiple_choice" або "matching"):
   - Має бути рівно одна беззаперечно правильна відповідь.
   - У "options" використовуй формат ["A) ...", "B) ...", "C) ..."] (або до D) / E) згідно з Blueprint), а в "correct_answer" вкажи літеру (напр. "A").
5. ДЛЯ ПОВНОЦІННОГО ІСПИТУ ЗАБОРОНЕНО ПИСАТИ КОРОТКІ УРИВКИ ПО 2–3 РЕЧЕННЯ!
   - Для Reading: кожен текст у "stimulus.text_or_transcript" МАЄ бути повноцінним розгорнутим текстом ТОЧНО в межах "stimulus_word_range" з Blueprint (мінімум 150–450 слів залежно від рівня ${level.code})!
   - Для Listening: кожен аудіоскрипт у "stimulus.text_or_transcript" МАЄ бути повноцінним тривалим природним діалогом або радіосюжетом ТОЧНО в межах "stimulus_word_range" (мінімум 150–450 слів!), готовим до озвучення через TTS без сценічних ремарок у дужках!
   - Кількість завдань ("tasks") та запитань у кожному завданні ("questions") МАЄ точно відповідати "tasks_count" та "questions_count" у Blueprint.
6. Для завдань Writing ("open_writing") та Speaking ("speaking_roleplay"): обов'язково вказуй реалістичний розгорнутий комунікативний стимул (80–150 слів), 3–4 чіткі пункти плану в "questions", "min_words", "max_points" і критерії оцінювання ("rubric").
7. Якщо завдання передбачає візуальний контекст, опиши його в "visual_prompt_description" мовою ${nativeLang.englishName}; інакше передай null.
8. КОМПАКТНІСТЬ ПОЯСНЕНЬ: поле "explanation" — РІВНО 1 коротке речення (до 12–15 слів), поле "rubric" — 1 стисле речення (до 18 слів).
9. ВІДПОВІДАЙ ВИКЛЮЧНО У ФОРМАТІ ВАЛІДНОГО JSON без жодного тексту до чи після JSON і без markdown-блоків ```.

ФОРМАТ ВІДПОВІДІ (JSON):
{
  "exam_meta": {
    "language": "${targetLang.englishName}",
    "level": "${level.code}",
    "subtest": "${subtest.apiName}",
    "time_limit_minutes": $defaultMinutes,
    "pass_threshold_percent": 60
  },
  "tasks": [
    {
      "task_number": 1,
      "task_type": "multiple_choice | short_answer | matching | open_writing | speaking_roleplay",
      "instruction_ui": "Інструкція мовою інтерфейсу (${nativeLang.englishName})",
      "instruction_target": "Інструкція мовою іспиту (${targetLang.englishName})",
      "stimulus": {
        "text_or_transcript": "Повноцінний розгорнутий текст для читання, детальний лист-стимул або тривалий аудіоскрипт для TTS",
        "visual_prompt_description": null
      },
      "questions": [
        {
          "id": 1,
          "question_text": "Текст запитання",
          "options": ["A) ...", "B) ...", "C) ..."],
          "correct_answer": "A",
          "explanation": "1 коротке речення (до 12 слів) мовою ${nativeLang.englishName}"
        }
      ],
      "evaluation_criteria": {
        "min_words": 0,
        "max_points": 10,
        "rubric": "1 коротке речення критеріїв мовою ${nativeLang.englishName}"
      }
    }
  ]
}
''';

    onProgress?.call(22, 'exam_stage_ai');

    String? failureReason;
    String? userKeyFailure;

    try {
      final aiRes = await _router.generateTextSmart(
        prompt: prompt,
        rawKeys: settings.geminiApiKey,
        timeout: const Duration(seconds: 14),
        expectJson: true,
        maxTokens: 16384,
      );
      userKeyFailure = aiRes.userKeyErrorSummary;

      if (aiRes.text.isEmpty) {
        failureReason = userKeyFailure ??
            aiRes.errorSummary ??
            'All AI providers returned empty response';
      } else {
        final map = _router.extractJsonObject(aiRes.text);
        if (map != null) {
          final paper = OfficialExamSubtestPaper.fromJson(
            map,
            fallbackLanguage: targetLang.englishName,
            fallbackLevel: level.code,
            fallbackSubtest: subtest,
            fallbackTimeMinutes: defaultMinutes,
            usedAi: true,
            providerUsed: aiRes.provider,
          );
          if (paper.tasks.isNotEmpty) {
            onProgress?.call(100, 'exam_stage_ready');
            return paper;
          }
          final parseErr =
              '${aiRes.provider}: JSON parsed 0 tasks (keys: ${map.keys.join(", ")})';
          failureReason = userKeyFailure != null
              ? '$userKeyFailure | $parseErr'
              : parseErr;
          debugPrint('[Reman AI] $failureReason');
        } else {
          final wasTruncated = aiRes.finishReason == 'length';
          final parseErr = wasTruncated
              ? '${aiRes.provider}: JSON truncated (max_tokens reached, ${aiRes.text.length} chars)'
              : '${aiRes.provider}: Invalid JSON (${aiRes.text.length} chars)';
          failureReason = userKeyFailure != null
              ? '$userKeyFailure | $parseErr'
              : parseErr;
          debugPrint('[Reman AI] $failureReason');

          final plannedCount = CefrExamBlueprints.plannedTaskCount(subtest);
          if (plannedCount >= 2) {
            onProgress?.call(48, 'exam_stage_chunk_retry');
            final splitPaper = await _generateSubtestInTwoChunks(
              level: level,
              subtest: subtest,
              settings: settings,
              blueprintJson: blueprintJson,
              totalTasks: plannedCount,
              defaultMinutes: defaultMinutes,
              vocabHint: vocabHint,
            );
            if (splitPaper != null && splitPaper.tasks.isNotEmpty) {
              onProgress?.call(100, 'exam_stage_ready');
              return splitPaper;
            }
          }
        }
      }
    } catch (e) {
      final errStr = _router.shortError(e);
      failureReason =
          userKeyFailure != null ? '$userKeyFailure | $errStr' : errStr;
      debugPrint(
        '[Reman AI] Official CEFR subtest error (${subtest.apiName}): $e',
      );
    }

    onProgress?.call(65, 'exam_stage_target_lang');
    final englishFallback = CefrExamBlueprints.buildEnglishFallbackPaper(
      level: level,
      subtest: subtest,
      targetLanguage: targetLang,
    );
    final localized = await _localizeOfficialFallbackPaper(
      englishFallback,
      targetLang: targetLang,
      nativeLang: nativeLang,
      fallbackReason: failureReason,
    );
    onProgress?.call(100, 'exam_stage_ready');
    return localized;
  }

  Future<OfficialExamSubtestPaper?> _generateSubtestInTwoChunks({
    required CefrLevel level,
    required ExamSubtest subtest,
    required AppSettings settings,
    required String blueprintJson,
    required int totalTasks,
    required int defaultMinutes,
    required String vocabHint,
  }) async {
    final targetLang = settings.targetLanguage;
    final nativeLang = settings.nativeLanguage;
    final topicDirective = settings.learningTopic.aiPromptDirective;
    final mid = (totalTasks / 2).ceil();
    final ranges = <(int, int)>[
      (1, mid),
      if (mid < totalTasks) (mid + 1, totalTasks),
    ];

    final mergedTasks = <OfficialExamTask>[];
    String usedProvider = '';

    for (final (fromNum, toNum) in ranges) {
      final chunkPrompt = '''
You are an official CEFR certification examiner (${level.code}, ${subtest.apiName}).
Target language: ${targetLang.englishName} (${targetLang.code})
UI/instruction language: ${nativeLang.englishName} (${nativeLang.code})
$topicDirective
Blueprint reference:
$blueprintJson$vocabHint

GENERATE ONLY tasks #$fromNum through #$toNum (inclusive) of this ${subtest.apiName} subtest so the JSON stays concise and complete.
- All exam texts/transcripts/questions/options/correct_answer MUST be in ${targetLang.englishName}.
- All instruction_ui, explanation, rubric, visual_prompt_description MUST be in ${nativeLang.englishName}.
- Keep every "explanation" strictly to 1 short sentence (max 12-15 words) and "rubric" to 1 short sentence (max 18 words) to stay compact.
- Respond ONLY with valid JSON (no markdown fences):
{
  "exam_meta": {
    "language": "${targetLang.englishName}",
    "level": "${level.code}",
    "subtest": "${subtest.apiName}",
    "time_limit_minutes": $defaultMinutes,
    "pass_threshold_percent": 60
  },
  "tasks": [
    {
      "task_number": $fromNum,
      "task_type": "multiple_choice | short_answer | matching | open_writing | speaking_roleplay",
      "instruction_ui": "...",
      "instruction_target": "...",
      "stimulus": {
        "text_or_transcript": "...",
        "visual_prompt_description": null
      },
      "questions": [
        {
          "id": 1,
          "question_text": "...",
          "options": ["A) ...", "B) ...", "C) ..."],
          "correct_answer": "A",
          "explanation": "1 short sentence"
        }
      ],
      "evaluation_criteria": {
        "min_words": 0,
        "max_points": 10,
        "rubric": "1 short sentence"
      }
    }
  ]
}
''';

      try {
        final chunkRes = await _router.generateTextSmart(
          prompt: chunkPrompt,
          rawKeys: settings.geminiApiKey,
          timeout: const Duration(seconds: 14),
          expectJson: true,
          maxTokens: 12288,
        );
        final map = _router.extractJsonObject(chunkRes.text);
        if (map != null) {
          final partPaper = OfficialExamSubtestPaper.fromJson(
            map,
            fallbackLanguage: targetLang.englishName,
            fallbackLevel: level.code,
            fallbackSubtest: subtest,
            fallbackTimeMinutes: defaultMinutes,
            usedAi: true,
            providerUsed: chunkRes.provider,
          );
          if (partPaper.tasks.isNotEmpty) {
            usedProvider = chunkRes.provider;
            for (final t in partPaper.tasks) {
              mergedTasks.add(
                t.copyWith(taskNumber: mergedTasks.length + 1),
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[Reman AI] Chunk ($fromNum-$toNum) error: $e');
      }

      if (ranges.length > 1) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }

    if (mergedTasks.isEmpty) return null;
    return OfficialExamSubtestPaper(
      examMeta: ExamMeta(
        language: targetLang.englishName,
        level: level.code,
        subtest: subtest,
        timeLimitMinutes: defaultMinutes,
        passThresholdPercent: 60,
      ),
      tasks: mergedTasks,
      usedAi: true,
      providerUsed: usedProvider.isNotEmpty ? usedProvider : 'AI (Split Mode)',
    );
  }

  Future<OfficialExamSession> generateOfficialExamSession({
    required CefrLevel level,
    required List<ExamSubtest> subtests,
    required AppSettings settings,
    List<String> recentWords = const [],
    void Function(
      int percent,
      String stageKey,
      Map<ExamSubtest, bool> completedSubtests,
    )? onProgress,
  }) async {
    final activeSubtests = subtests.isEmpty
        ? const [
            ExamSubtest.reading,
            ExamSubtest.listening,
            ExamSubtest.writing,
            ExamSubtest.speaking,
          ]
        : subtests;

    final completedMap = <ExamSubtest, bool>{
      for (final s in activeSubtests) s: false,
    };

    onProgress?.call(8, 'exam_stage_prepare', Map.of(completedMap));
    onProgress?.call(14, 'exam_stage_ai', Map.of(completedMap));

    final keyCount = _router.parseKeys(settings.geminiApiKey).length;
    final maxConcurrency = (activeSubtests.length > 1 && keyCount >= 2) ? 2 : 1;
    final papers = List<OfficialExamSubtestPaper?>.filled(
      activeSubtests.length,
      null,
    );
    var finishedCount = 0;

    if (maxConcurrency == 1) {
      for (var i = 0; i < activeSubtests.length; i++) {
        final sub = activeSubtests[i];
        final basePct = 14 + ((i / activeSubtests.length) * 80).round();
        final spanPct = (80 / activeSubtests.length).round();

        final paper = await generateOfficialSubtest(
          level: level,
          subtest: sub,
          settings: settings,
          recentWords: recentWords,
          onProgress: (pct, stage) {
            final scaled = basePct + ((pct / 100.0) * spanPct).round();
            onProgress?.call(
              scaled.clamp(10, 96),
              stage,
              Map.of(completedMap),
            );
          },
        );
        papers[i] = paper;
        finishedCount += 1;
        completedMap[sub] = true;
        final donePct =
            14 + ((finishedCount / activeSubtests.length) * 82).round();
        final stage = finishedCount < activeSubtests.length
            ? 'exam_stage_ai'
            : 'exam_stage_finalize';
        onProgress?.call(donePct.clamp(15, 96), stage, Map.of(completedMap));

        if (i < activeSubtests.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
    } else {
      var nextIndex = 0;
      Future<void> worker(int workerId) async {
        if (workerId > 0) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        while (true) {
          final i = nextIndex++;
          if (i >= activeSubtests.length) return;
          final sub = activeSubtests[i];
          final paper = await generateOfficialSubtest(
            level: level,
            subtest: sub,
            settings: settings,
            recentWords: recentWords,
          );
          papers[i] = paper;
          finishedCount += 1;
          completedMap[sub] = true;
          final donePct =
              14 + ((finishedCount / activeSubtests.length) * 82).round();
          final stage = finishedCount < activeSubtests.length
              ? 'exam_stage_ai'
              : 'exam_stage_finalize';
          onProgress?.call(donePct.clamp(15, 96), stage, Map.of(completedMap));
        }
      }

      await Future.wait([worker(0), worker(1)]);
    }

    onProgress?.call(100, 'exam_stage_ready', Map.of(completedMap));

    return OfficialExamSession(
      level: level,
      subtests: papers.whereType<OfficialExamSubtestPaper>().toList(),
    );
  }

  Future<OfficialExamSubtestPaper> _localizeOfficialFallbackPaper(
    OfficialExamSubtestPaper paper, {
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    String? fallbackReason,
  }) async {
    final targetTexts = <String>[];
    final uiTexts = <String>[];

    for (final t in paper.tasks) {
      targetTexts.add(t.instructionTarget);
      targetTexts.add(t.stimulus.textOrTranscript);
      for (final q in t.questions) {
        targetTexts.add(q.questionText);
        targetTexts.addAll(q.options);
        if (t.taskType == OfficialTaskType.shortAnswer) {
          targetTexts.add(q.correctAnswer);
        }
      }

      uiTexts.add(t.instructionUi);
      uiTexts.add(t.stimulus.visualPromptDescription ?? '');
      uiTexts.add(t.evaluationCriteria.rubric);
      for (final q in t.questions) {
        uiTexts.add(q.explanation);
      }
    }

    final results = await Future.wait([
      targetLang.code == 'en'
          ? Future.value(targetTexts)
          : _translation.batchTranslateTexts(
              texts: targetTexts,
              sourceLangCode: 'en',
              targetLangCode: targetLang.code,
            ),
      nativeLang.code == 'en'
          ? Future.value(uiTexts)
          : _translation.batchTranslateTexts(
              texts: uiTexts,
              sourceLangCode: 'en',
              targetLangCode: nativeLang.code,
            ),
    ]);

    final tTarget = results[0];
    final tUi = results[1];
    var tc = 0;
    var uc = 0;

    String nextTarget(String fallback) =>
        tc < tTarget.length ? tTarget[tc++] : fallback;
    String nextUi(String fallback) => uc < tUi.length ? tUi[uc++] : fallback;

    final updatedTasks = <OfficialExamTask>[];
    for (final t in paper.tasks) {
      final instrTarget = nextTarget(t.instructionTarget);
      final stimText = nextTarget(t.stimulus.textOrTranscript);

      final instrUi = nextUi(t.instructionUi);
      final rawVis = nextUi(t.stimulus.visualPromptDescription ?? '');
      final rubric = nextUi(t.evaluationCriteria.rubric);

      final updatedQs = <OfficialExamQuestionItem>[];
      for (final q in t.questions) {
        final qText = nextTarget(q.questionText);
        final opts = <String>[];
        for (final o in q.options) {
          opts.add(nextTarget(o));
        }
        final corrAns = t.taskType == OfficialTaskType.shortAnswer
            ? nextTarget(q.correctAnswer)
            : q.correctAnswer;
        final expl = nextUi(q.explanation);

        updatedQs.add(
          q.copyWith(
            questionText: qText,
            options: opts,
            correctAnswer: corrAns,
            explanation: expl,
          ),
        );
      }

      updatedTasks.add(
        t.copyWith(
          instructionUi: instrUi,
          instructionTarget: instrTarget,
          stimulus: ExamStimulus(
            textOrTranscript: stimText,
            visualPromptDescription:
                t.stimulus.hasVisualPrompt && rawVis.trim().isNotEmpty
                    ? rawVis
                    : null,
          ),
          questions: updatedQs,
          evaluationCriteria: t.evaluationCriteria.copyWith(rubric: rubric),
        ),
      );
    }

    return OfficialExamSubtestPaper(
      examMeta: paper.examMeta,
      tasks: updatedTasks,
      usedAi: false,
      providerUsed: 'CEFR Blueprint Bank',
      fallbackReason: fallbackReason,
    );
  }

  Future<OfficialExamEvaluation> evaluateOfficialExam({
    required OfficialExamSession session,
    required Map<String, int> choiceAnswers,
    required Map<String, String> textAnswers,
    required Map<String, String> speakingTranscripts,
    required Map<String, int> speakingPronScores,
    required AppSettings settings,
  }) async {
    final taskEvals = <OfficialTaskEvaluation>[];
    final openTaskPayloads = <Map<String, dynamic>>[];

    for (final paper in session.subtests) {
      final sub = paper.examMeta.subtest;
      for (final task in paper.tasks) {
        final maxPts = task.evaluationCriteria.maxPoints;
        if (task.taskType == OfficialTaskType.multipleChoice ||
            task.taskType == OfficialTaskType.matching ||
            task.taskType == OfficialTaskType.shortAnswer) {
          final qMap = <int, bool>{};
          var correctCount = 0;

          for (final q in task.questions) {
            final qKey = '${sub.apiName}_${task.taskNumber}_${q.id}';
            bool isOk = false;
            if (task.taskType == OfficialTaskType.shortAnswer) {
              final userTxt = (textAnswers[qKey] ?? '').trim();
              isOk = _matchesShortAnswer(userTxt, q.correctAnswer);
            } else {
              final picked = choiceAnswers[qKey];
              if (picked != null && picked == q.resolveCorrectOptionIndex()) {
                isOk = true;
              }
            }
            qMap[q.id] = isOk;
            if (isOk) correctCount++;
          }

          final totalQs = task.questions.length;
          final earned = totalQs == 0
              ? 0.0
              : ((correctCount / totalQs) * maxPts * 10).round() / 10.0;

          taskEvals.add(
            OfficialTaskEvaluation(
              subtest: sub,
              taskNumber: task.taskNumber,
              earnedPoints: earned,
              maxPoints: maxPts,
              feedback: '$correctCount / $totalQs',
              questionCorrectMap: qMap,
            ),
          );
        } else {
          final tKey = '${sub.apiName}_${task.taskNumber}';
          final responseText = task.taskType == OfficialTaskType.openWriting
              ? (textAnswers[tKey] ?? '').trim()
              : (speakingTranscripts[tKey] ?? '').trim();
          final pronScore = speakingPronScores[tKey] ?? 0;

          openTaskPayloads.add({
            'task_key': tKey,
            'subtest': sub.apiName,
            'task_number': task.taskNumber,
            'task_type': task.taskType.apiValue,
            'instruction': task.instructionTarget.isNotEmpty
                ? task.instructionTarget
                : task.instructionUi,
            'stimulus': task.stimulus.textOrTranscript,
            'min_words': task.evaluationCriteria.minWords,
            'max_points': maxPts,
            'rubric': task.evaluationCriteria.rubric,
            'candidate_response': responseText,
            if (task.taskType == OfficialTaskType.speakingRoleplay)
              'speech_recognition_accuracy_percent': pronScore,
          });
        }
      }
    }

    Map<String, dynamic>? aiEvalMap;
    try {
      final objectiveEarned =
          taskEvals.fold<double>(0, (s, e) => s + e.earnedPoints);
      final objectiveMax = taskEvals.fold<int>(0, (s, e) => s + e.maxPoints);
      final topicDirective = settings.learningTopic.aiPromptDirective;

      final prompt = '''
You are an official certified CEFR examiner (${session.level.code}).
Target exam language: ${settings.targetLanguage.englishName}
Feedback / UI language: ${settings.nativeLanguage.englishName}
$topicDirective
Pass threshold: ${session.passThresholdPercent}%
Objective tasks score so far: $objectiveEarned / $objectiveMax points.

Productive tasks (Writing / Speaking) submitted by the candidate:
${jsonEncode(openTaskPayloads)}

Grade every productive task strictly according to its CEFR level (${session.level.code}), "min_words", "max_points", and "rubric". If "candidate_response" is empty, award 0 points.
Also write an encouraging, concrete overall assessment in ${settings.nativeLanguage.englishName}.

Respond ONLY with valid JSON (no markdown fences):
{
  "open_task_scores": [
    {
      "task_key": "Writing_1",
      "earned_points": 4.5,
      "feedback": "Detailed feedback in ${settings.nativeLanguage.englishName}"
    }
  ],
  "estimated_level": "${session.level.code}",
  "summary": "2-3 sentences overall official examiner assessment in ${settings.nativeLanguage.englishName}",
  "strengths": ["strength 1 in ${settings.nativeLanguage.englishName}", "strength 2"],
  "improvements": ["actionable tip 1 in ${settings.nativeLanguage.englishName}", "tip 2"]
}
''';

      final aiRes = await _router.generateTextSmart(
        prompt: prompt,
        rawKeys: settings.geminiApiKey,
        timeout: const Duration(seconds: 14),
        expectJson: true,
      );
      aiEvalMap = _router.extractJsonObject(aiRes.text);
    } catch (e) {
      debugPrint('AI official exam evaluation error: $e');
    }

    final aiTaskScores = <String, ({double pts, String feedback})>{};
    if (aiEvalMap != null) {
      final rawOpen =
          aiEvalMap['open_task_scores'] as List<dynamic>? ?? const [];
      for (final item in rawOpen.whereType<Map<String, dynamic>>()) {
        final key = (item['task_key'] as String? ?? '').trim();
        final pts = (item['earned_points'] as num?)?.toDouble();
        final fb = (item['feedback'] as String? ?? '').trim();
        if (key.isNotEmpty && pts != null) {
          aiTaskScores[key] = (pts: pts, feedback: fb);
        }
      }
    }

    for (final payload in openTaskPayloads) {
      final tKey = payload['task_key'] as String;
      final sub = ExamSubtest.fromApiName(payload['subtest'] as String);
      final taskNum = payload['task_number'] as int;
      final maxPts = payload['max_points'] as int;
      final minWords = payload['min_words'] as int;
      final respTxt = (payload['candidate_response'] as String).trim();
      final isSpeaking =
          payload['task_type'] == OfficialTaskType.speakingRoleplay.apiValue;
      final pronScore =
          (payload['speech_recognition_accuracy_percent'] as int?) ?? 0;

      if (aiTaskScores.containsKey(tKey)) {
        final graded = aiTaskScores[tKey]!;
        taskEvals.add(
          OfficialTaskEvaluation(
            subtest: sub,
            taskNumber: taskNum,
            earnedPoints: graded.pts.clamp(0, maxPts.toDouble()),
            maxPoints: maxPts,
            feedback: graded.feedback,
          ),
        );
      } else {
        final words = _countWords(respTxt);
        double ratio;
        if (respTxt.isEmpty) {
          ratio = 0.0;
        } else if (isSpeaking) {
          final wordRatio = minWords > 0
              ? (words / minWords).clamp(0.0, 1.0)
              : (words >= 4 ? 0.85 : 0.45);
          ratio = ((pronScore / 100.0) * 0.65 + wordRatio * 0.35).clamp(0.0, 1.0);
        } else {
          ratio = minWords > 0
              ? (words / minWords).clamp(0.0, 1.0) * 0.85
              : (words >= 8 ? 0.8 : 0.45);
        }
        final earned = ((ratio * maxPts) * 10).round() / 10.0;
        taskEvals.add(
          OfficialTaskEvaluation(
            subtest: sub,
            taskNumber: taskNum,
            earnedPoints: earned,
            maxPoints: maxPts,
            feedback: respTxt.isEmpty
                ? 'No response submitted.'
                : 'Recorded $words words${isSpeaking ? ' (speech accuracy $pronScore%)' : ''}.',
          ),
        );
      }
    }

    final totalEarned =
        (taskEvals.fold<double>(0, (s, e) => s + e.earnedPoints) * 10).round() /
            10.0;
    final totalMax = session.totalMaxPoints;
    final passThreshold = session.passThresholdPercent;

    if (aiEvalMap != null &&
        (aiEvalMap['summary'] as String? ?? '').trim().isNotEmpty) {
      return OfficialExamEvaluation(
        targetLevel: session.level,
        earnedPoints: totalEarned,
        maxPoints: totalMax,
        passThresholdPercent: passThreshold,
        estimatedLevel:
            (aiEvalMap['estimated_level'] as String? ?? session.level.code)
                .trim(),
        summary: (aiEvalMap['summary'] as String).trim(),
        strengths: (aiEvalMap['strengths'] as List<dynamic>? ?? const [])
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        improvements: (aiEvalMap['improvements'] as List<dynamic>? ?? const [])
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        taskEvaluations: taskEvals,
        usedAi: true,
      );
    }

    return _buildFallbackOfficialEvaluation(
      session: session,
      totalEarned: totalEarned,
      totalMax: totalMax,
      passThreshold: passThreshold,
      taskEvals: taskEvals,
      nativeLangCode: settings.nativeLanguageCode,
    );
  }

  Future<OfficialExamEvaluation> _buildFallbackOfficialEvaluation({
    required OfficialExamSession session,
    required double totalEarned,
    required int totalMax,
    required int passThreshold,
    required List<OfficialTaskEvaluation> taskEvals,
    required String nativeLangCode,
  }) async {
    final pct = totalMax <= 0 ? 0.0 : (totalEarned / totalMax) * 100.0;
    final passed = pct >= passThreshold;
    final levels = CefrLevel.values;
    final idx = levels.indexOf(session.level);

    var estimated = passed
        ? (pct >= 85 && idx < levels.length - 1
            ? '${session.level.code}+ (${levels[idx + 1].code} ready)'
            : session.level.code)
        : (idx > 0 ? levels[idx - 1].code : 'A1');

    var summary = passed
        ? 'Congratulations! You passed the ${session.level.code} certification exam with ${pct.round()}% (${totalEarned.toStringAsFixed(1)} / $totalMax pts, pass threshold $passThreshold%).'
        : 'You scored ${pct.round()}% (${totalEarned.toStringAsFixed(1)} / $totalMax pts). The official pass threshold is $passThreshold%. Review the explanations below and try again.';

    final weakSubtests = taskEvals
        .where((e) => e.maxPoints > 0 && (e.earnedPoints / e.maxPoints) < 0.6)
        .map((e) => e.subtest.apiName)
        .toSet()
        .toList();

    var strengths = <String>[
      'Completed official ${session.level.code} CEFR certification tasks.',
      if (passed) 'Met the official $passThreshold% certification pass threshold.',
    ];
    var improvements = <String>[
      if (weakSubtests.isNotEmpty)
        'Focus extra practice on: ${weakSubtests.join(', ')}.',
      'Review task explanations and practice vocabulary in SRS flashcards.',
    ];

    if (nativeLangCode != 'en') {
      final allLines = <String>[
        estimated,
        summary,
        ...strengths,
        ...improvements,
      ];
      final translated = await _translation.batchTranslateTexts(
        texts: allLines,
        sourceLangCode: 'en',
        targetLangCode: nativeLangCode,
      );
      if (translated.length == allLines.length) {
        estimated = translated[0];
        summary = translated[1];
        strengths = translated.sublist(2, 2 + strengths.length);
        improvements = translated.sublist(2 + strengths.length);
      }
    }

    return OfficialExamEvaluation(
      targetLevel: session.level,
      earnedPoints: totalEarned,
      maxPoints: totalMax,
      passThresholdPercent: passThreshold,
      estimatedLevel: estimated,
      summary: summary,
      strengths: strengths,
      improvements: improvements,
      taskEvaluations: taskEvals,
      usedAi: false,
    );
  }

  bool _matchesShortAnswer(String userRaw, String expectedRaw) {
    final user = _normAnswer(userRaw);
    if (user.isEmpty) return false;
    final candidates = expectedRaw
        .split(RegExp(r'[/|;]'))
        .map(_normAnswer)
        .where((s) => s.isNotEmpty)
        .toList();
    if (candidates.isEmpty) return false;
    for (final c in candidates) {
      if (user == c ||
          user.contains(c) ||
          (c.contains(user) && user.length >= 2)) {
        return true;
      }
      if (_similarityRatio(user, c) >= 0.78) return true;
    }
    return false;
  }

  String _normAnswer(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}\p{N}:.\s]", unicode: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _countWords(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  double _similarityRatio(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final m = a.length;
    final n = b.length;
    final prev = List<int>.generate(n + 1, (j) => j);
    final curr = List<int>.filled(n + 1, 0);
    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        var best = del < ins ? del : ins;
        if (sub < best) best = sub;
        curr[j] = best;
      }
      for (var j = 0; j <= n; j++) {
        prev[j] = curr[j];
      }
    }
    final dist = prev[n];
    final maxLen = m > n ? m : n;
    return maxLen == 0 ? 1.0 : (1.0 - dist / maxLen).clamp(0.0, 1.0);
  }
}
