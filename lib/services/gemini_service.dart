import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../models/exam_models.dart';
import '../models/grammar_book_models.dart';
import '../models/level_curriculum.dart';
import '../models/reading_rules_book.dart';
import 'ai/ai_curriculum_service.dart';
import 'ai/ai_exam_service.dart';
import 'ai/ai_router_client.dart';
import 'ai/ai_translation_service.dart';

/// Unified Multi-AI service facade that delegates to modular specialized services:
/// - [AiRouterClient]: Multi-provider routing, discovery, smart caching & fallback.
/// - [AiTranslationService]: Contextual dictionary lookup, batch translation & OCR.
/// - [AiExamService]: Official CEFR certification generation & AI evaluation.
/// - [AiCurriculumService]: CEFR Level Path lessons & Reading/Writing Rules Book.
class GeminiService {
  GeminiService({AiRouterClient? routerClient})
      : _router = routerClient ?? AiRouterClient() {
    _translation = AiTranslationService(_router);
    _exam = AiExamService(_router, _translation);
    _curriculum = AiCurriculumService(_router);
  }

  final AiRouterClient _router;
  late final AiTranslationService _translation;
  late final AiExamService _exam;
  late final AiCurriculumService _curriculum;

  AiRouterClient get router => _router;

  static List<String> prioritizeKeys(List<String> keys) =>
      AiRouterClient.prioritizeKeys(keys);

  // --- Testing hooks (preserved for existing unit tests) ---

  @visibleForTesting
  Map<String, String> get workingModelCache => _router.workingModelCache;

  @visibleForTesting
  void recordModelSuccessForTest(String cacheKey, String model) {
    _router.recordModelSuccess(cacheKey, model);
  }

  @visibleForTesting
  void handleModelStatusForTest(
    String cacheKey,
    String exhaustedKey,
    String model,
    int statusCode,
  ) {
    _router.handleFailedModelStatus(
      cacheKey: cacheKey,
      exhaustedKey: exhaustedKey,
      model: model,
      statusCode: statusCode,
    );
  }

  @visibleForTesting
  List<String> buildOrderedCandidatesForTest(
    String cacheKey,
    String exhaustedKey,
    List<String> discovered,
  ) {
    return _router.buildOrderedCandidates(cacheKey, exhaustedKey, discovered);
  }

  // --- Static provider & discovery helpers ---

  static String detectProviderName(String rawKeys) =>
      AiRouterClient.detectProviderName(rawKeys);

  static List<String> filterGeminiModelEntries(List<dynamic> rawModels) =>
      AiRouterClient.filterGeminiModelEntries(rawModels);

  static List<String> sortGeminiModels(
    List<String> modelIds, {
    required bool fastTask,
  }) =>
      AiRouterClient.sortGeminiModels(modelIds, fastTask: fastTask);

  static bool isSupportedOpenAiChatModel(String id) =>
      AiRouterClient.isSupportedOpenAiChatModel(id);

  static List<String> prioritizeOpenAiModels(
    List<String> discovered, {
    required List<String> priorityModels,
    bool onlyFree = false,
  }) =>
      AiRouterClient.prioritizeOpenAiModels(
        discovered,
        priorityModels: priorityModels,
        onlyFree: onlyFree,
      );

  // --- Router & diagnostics ---

  String describeActiveProvider(String rawKeys) =>
      _router.describeActiveProvider(rawKeys);

  Future<({bool ok, String providerUsed, String? errorDetail})> testAiConnection(
    String rawApiKey,
  ) =>
      _router.testAiConnection(rawApiKey);

  Future<bool> testApiKey(String apiKey) async {
    final res = await testAiConnection(apiKey);
    return res.ok;
  }

  // --- Translation, dictionary & OCR ---

  Future<WordLookupResult> lookupWordInContext({
    required String word,
    required String contextSentence,
    required AppSettings settings,
  }) =>
      _translation.lookupWordInContext(
        word: word,
        contextSentence: contextSentence,
        settings: settings,
      );

  Future<String> translateSentence({
    required String sentence,
    required String sourceLangCode,
    required String targetLangCode,
  }) =>
      _translation.translateSentence(
        sentence: sentence,
        sourceLangCode: sourceLangCode,
        targetLangCode: targetLangCode,
      );

  Future<List<String>> batchTranslateTexts({
    required List<String> texts,
    required String sourceLangCode,
    required String targetLangCode,
  }) =>
      _translation.batchTranslateTexts(
        texts: texts,
        sourceLangCode: sourceLangCode,
        targetLangCode: targetLangCode,
      );

  Future<List<String>> translateSubtitleCues({
    required List<String> texts,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
  }) =>
      _translation.translateSubtitleCues(
        texts: texts,
        targetLang: targetLang,
        nativeLang: nativeLang,
        settings: settings,
      );

  Future<String> extractTextFromImage({
    required Uint8List imageBytes,
    required String mimeType,
    required AppSettings settings,
  }) =>
      _translation.extractTextFromImage(
        imageBytes: imageBytes,
        mimeType: mimeType,
        settings: settings,
      );

  // --- Official CEFR Exams ---

  Future<OfficialExamSubtestPaper> generateOfficialSubtest({
    required CefrLevel level,
    required ExamSubtest subtest,
    required AppSettings settings,
    List<String> recentWords = const [],
    void Function(int percent, String stageKey)? onProgress,
  }) =>
      _exam.generateOfficialSubtest(
        level: level,
        subtest: subtest,
        settings: settings,
        recentWords: recentWords,
        onProgress: onProgress,
      );

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
  }) =>
      _exam.generateOfficialExamSession(
        level: level,
        subtests: subtests,
        settings: settings,
        recentWords: recentWords,
        onProgress: onProgress,
      );

  Future<OfficialExamEvaluation> evaluateOfficialExam({
    required OfficialExamSession session,
    required Map<String, int> choiceAnswers,
    required Map<String, String> textAnswers,
    required Map<String, String> speakingTranscripts,
    required Map<String, int> speakingPronScores,
    required AppSettings settings,
  }) =>
      _exam.evaluateOfficialExam(
        session: session,
        choiceAnswers: choiceAnswers,
        textAnswers: textAnswers,
        speakingTranscripts: speakingTranscripts,
        speakingPronScores: speakingPronScores,
        settings: settings,
      );

  // --- Level Path & Reading Rules Handbook ---

  Future<Map<String, dynamic>> generateLevelRuleExplanation({
    required String cefrCode,
    required String topicTitle,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
    required Map<String, dynamic> offlineFallback,
  }) =>
      _curriculum.generateLevelRuleExplanation(
        cefrCode: cefrCode,
        topicTitle: topicTitle,
        targetLang: targetLang,
        nativeLang: nativeLang,
        settings: settings,
        offlineFallback: offlineFallback,
      );

  Future<GeneratedLevelContent> generateLevelModuleContent({
    required CurriculumModuleNode node,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
    required GeneratedLevelContent offlineFallback,
  }) =>
      _curriculum.generateLevelModuleContent(
        node: node,
        targetLang: targetLang,
        nativeLang: nativeLang,
        settings: settings,
        offlineFallback: offlineFallback,
      );

  Future<ReadingRulesBook> generateReadingRulesBook({
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
    required ReadingRulesBook offlineFallback,
  }) =>
      _curriculum.generateReadingRulesBook(
        targetLang: targetLang,
        nativeLang: nativeLang,
        settings: settings,
        offlineFallback: offlineFallback,
      );

  Future<GrammarChapterContent> generateGrammarChapter({
    required GrammarChapterSpec chapter,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
    required GrammarChapterContent offlineFallback,
  }) =>
      _curriculum.generateGrammarChapter(
        chapter: chapter,
        targetLang: targetLang,
        nativeLang: nativeLang,
        settings: settings,
        offlineFallback: offlineFallback,
      );

  Future<({GrammarQaEntry? entry, String? errorDetail})> askGrammarQuestion({
    required String question,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    required AppSettings settings,
  }) =>
      _curriculum.askGrammarQuestion(
        question: question,
        targetLang: targetLang,
        nativeLang: nativeLang,
        settings: settings,
      );
}
