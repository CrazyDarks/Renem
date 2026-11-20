import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/app_settings.dart';
import '../models/study_material.dart';
import '../models/user_progress.dart';
import '../models/vocab_word.dart';
import '../services/csv_service.dart';
import '../services/gemini_service.dart';
import '../services/google_account_service.dart';
import '../services/permission_service.dart';
import '../services/pronunciation_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../services/web_article_service.dart';
import '../services/youtube_subtitle_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    StorageService? storageService,
    GeminiService? geminiService,
    YoutubeSubtitleService? youtubeService,
    WebArticleService? webArticleService,
    CsvService? csvService,
    TtsService? ttsService,
    PronunciationService? pronunciationService,
    PermissionService? permissionService,
    GoogleAccountService? googleAccountService,
  })  : storage = storageService ?? StorageService(),
        gemini = geminiService ?? GeminiService(),
        youtube = youtubeService ?? YoutubeSubtitleService(),
        webArticle = webArticleService ?? WebArticleService(),
        csv = csvService ?? CsvService(),
        tts = ttsService ?? TtsService(),
        pronunciation = pronunciationService ?? PronunciationService(),
        permissions = permissionService ?? PermissionService(),
        googleAccount = googleAccountService ?? GoogleAccountService();

  final StorageService storage;
  final GeminiService gemini;
  final YoutubeSubtitleService youtube;
  final WebArticleService webArticle;
  final CsvService csv;
  final TtsService tts;
  final PronunciationService pronunciation;
  final PermissionService permissions;
  final GoogleAccountService googleAccount;

  AppSettings _settings = const AppSettings();
  UserProgress _progress = const UserProgress();
  List<VocabWord> _allVocabulary = [];
  List<StudyMaterial> _allMaterials = [];
  bool _initialized = false;
  bool _translatingUi = false;
  int _currentTabIndex = 0;
  int _trainingModeIndex = 0;
  bool _tutorialCompleted = true;
  bool _showTutorialOverlay = false;
  int _tutorialStepIndex = 0;

  AppSettings get settings => _settings;
  UserProgress get progress => _progress;
  bool get initialized => _initialized;
  bool get translatingUi => _translatingUi;
  int get currentTabIndex => _currentTabIndex;
  int get trainingModeIndex => _trainingModeIndex;
  bool get tutorialCompleted => _tutorialCompleted;
  bool get showTutorialOverlay => _showTutorialOverlay;
  int get tutorialStepIndex => _tutorialStepIndex;

  void navigateToTab(int tabIndex, {int? trainingSubMode}) {
    _currentTabIndex = tabIndex.clamp(0, 2);
    if (trainingSubMode != null) {
      _trainingModeIndex = trainingSubMode.clamp(0, 4);
    }
    notifyListeners();
  }

  void setTutorialStep(int step) {
    _tutorialStepIndex = step.clamp(0, 4);
    // Step 0 is the Learning Topic onboarding selector; steps 1..3 preview app tabs.
    if (_tutorialStepIndex == 1) {
      _currentTabIndex = 0;
    } else if (_tutorialStepIndex == 2) {
      _currentTabIndex = 1;
    } else if (_tutorialStepIndex == 3) {
      _currentTabIndex = 2;
    }
    notifyListeners();
  }

  Future<void> completeTutorial() async {
    _tutorialCompleted = true;
    _showTutorialOverlay = false;
    notifyListeners();
    await storage.saveTutorialCompleted(true);
  }

  Future<void> restartTutorial() async {
    _tutorialCompleted = false;
    _tutorialStepIndex = 0;
    _currentTabIndex = 0;
    _showTutorialOverlay = true;
    notifyListeners();
    await storage.saveTutorialCompleted(false);
  }

  /// Only returns vocabulary for the currently active target language.
  List<VocabWord> get vocabulary => List.unmodifiable(
        _allVocabulary.where(
          (w) => w.languageCode == _settings.targetLanguageCode,
        ),
      );

  /// Only returns study materials for the currently active target language.
  List<StudyMaterial> get materials => List.unmodifiable(
        _allMaterials.where(
          (m) => m.languageCode == _settings.targetLanguageCode,
        ),
      );

  Set<String> get savedWordsNormalized =>
      vocabulary.map((w) => w.word.trim().toLowerCase()).toSet();

  List<VocabWord> get dueWords =>
      vocabulary.where((w) => w.isDue).toList()
        ..sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));

  Future<void> initialize() async {
    final loadedSettings = await storage.loadSettings();
    final loadedVocab = await storage.loadVocabulary();
    final loadedMaterials = await storage.loadMaterials();
    final loadedProgress = await storage.loadUserProgress();
    final loadedTutorialDone = await storage.loadTutorialCompleted();

    _settings = loadedSettings;
    _applyTtsConfig(_settings);
    _allVocabulary = loadedVocab;
    _allMaterials = loadedMaterials;
    await _ensureStarterMaterialsForLanguage(_settings.targetLanguageCode);
    _progress = _reconcileDailyStreak(loadedProgress);
    _tutorialCompleted = loadedTutorialDone;
    _showTutorialOverlay = !loadedTutorialDone;
    _tutorialStepIndex = 0;

    // Immediately restore cached dynamic UI translations (e.g. Urdu, Turkish, Arabic...) before first build
    final cachedUi =
        await storage.loadUiTranslationsCache(_settings.nativeLanguageCode);
    if (cachedUi != null && cachedUi.isNotEmpty) {
      AppStrings.setDynamicTranslations(_settings.nativeLanguageCode, cachedUi);
    }

    _initialized = true;
    notifyListeners();
    await _ensureNativeUiTranslations(_settings.nativeLanguageCode);
    await _evaluateAchievements();
  }

  void _applyTtsConfig(AppSettings s) {
    tts.configure(
      voicePreset: s.voicePreset,
      preferredVoiceName: s.preferredVoiceName,
      speechRate: s.speechRate,
      useCustomAiVoice: s.useCustomAiVoice,
      customAiVoiceApiKey: s.customAiVoiceApiKey,
      customAiVoiceEndpoint: s.customAiVoiceEndpoint,
      customAiVoiceModel: s.customAiVoiceModel,
    );
  }

  Future<void> _ensureNativeUiTranslations(String langCode) async {
    if (AppStrings.hasFullCoverage(langCode)) return;

    // 1. Check persistent local cache first
    final cached = await storage.loadUiTranslationsCache(langCode);
    if (cached != null && cached.isNotEmpty) {
      AppStrings.setDynamicTranslations(langCode, cached);
      if (AppStrings.hasFullCoverage(langCode)) {
        notifyListeners();
        return;
      }
    }

    // 2. Translate all missing keys in parallel chunks from English into langCode
    final missingMap = AppStrings.missingEnglishSourceStrings(langCode);
    if (missingMap.isEmpty) return;

    _translatingUi = true;
    notifyListeners();
    try {
      final keys = missingMap.keys.toList();
      final englishValues = keys.map((k) => missingMap[k]!).toList();
      final translated = await gemini.batchTranslateTexts(
        texts: englishValues,
        sourceLangCode: 'en',
        targetLangCode: langCode,
      );
      if (translated.length == keys.length) {
        final mapped = <String, String>{
          ...(cached ?? const {}),
        };
        for (var i = 0; i < keys.length; i++) {
          if (translated[i].trim().isNotEmpty) {
            mapped[keys[i]] = translated[i].trim();
          }
        }
        AppStrings.setDynamicTranslations(langCode, mapped);
        await storage.saveUiTranslationsCache(langCode, mapped);
      }
    } catch (_) {
    } finally {
      _translatingUi = false;
      notifyListeners();
    }
  }

  UserProgress _reconcileDailyStreak(UserProgress current) {
    final now = DateTime.now();
    final todayStr = UserProgress.todayKey(now);
    if (current.lastActiveDate == todayStr) {
      return current;
    }

    final lastDate = DateTime.tryParse(current.lastActiveDate);
    var streak = current.currentStreak;
    var freezes = current.streakFreezes;

    if (lastDate != null) {
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final lastMidnight =
          DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diffDays = todayMidnight.difference(lastMidnight).inDays;

      if (diffDays == 1) {
        streak = current.currentStreak + 1;
      } else if (diffDays == 2 && freezes > 0) {
        freezes -= 1;
        streak = current.currentStreak + 1;
      } else if (diffDays > 1) {
        streak = 1;
      }
    } else {
      streak = 1;
    }

    final longest =
        streak > current.longestStreak ? streak : current.longestStreak;
    final dates = <String>{...current.activeDates, todayStr}.toList()..sort();

    return current.copyWith(
      currentStreak: streak,
      longestStreak: longest,
      streakFreezes: freezes,
      todayXp: 0,
      lastActiveDate: todayStr,
      activeDates: dates.length > 30 ? dates.sublist(dates.length - 30) : dates,
    );
  }

  Future<void> _ensureStarterMaterialsForLanguage(String langCode) async {
    final hasAnyForLang =
        _allMaterials.any((m) => m.languageCode == langCode);
    if (hasAnyForLang) return;
    final starters = StorageService.buildStarterMaterialsForLanguage(langCode);
    _allMaterials = [...starters, ..._allMaterials];
    await storage.saveMaterials(_allMaterials);
  }

  Future<void> awardXp(int amount) async {
    if (amount <= 0) return;
    final reconciled = _reconcileDailyStreak(_progress);
    final wasBelowGoal = reconciled.todayXp < reconciled.dailyGoalXp;
    final nextTodayXp = reconciled.todayXp + amount;
    final reachedGoalNow = wasBelowGoal && nextTodayXp >= reconciled.dailyGoalXp;

    _progress = reconciled.copyWith(
      xp: reconciled.xp + amount,
      todayXp: nextTodayXp,
    );
    if (reachedGoalNow) {
      HapticFeedback.heavyImpact();
    }
    notifyListeners();
    await storage.saveUserProgress(_progress);
    await _evaluateAchievements();
  }

  Future<void> _evaluateAchievements() async {
    final unlocked = Set<String>.from(_progress.unlockedAchievements);
    var bonusXp = 0;

    void tryUnlock(String id) {
      if (!unlocked.contains(id)) {
        unlocked.add(id);
        final def = allAchievements.firstWhere(
          (a) => a.id == id,
          orElse: () => allAchievements.first,
        );
        bonusXp += def.xpReward;
      }
    }

    if (_allVocabulary.isNotEmpty) tryUnlock('first_word');
    if (_allVocabulary.length >= 15) tryUnlock('vocab_15');
    if (_allVocabulary.length >= 50) tryUnlock('vocab_50');
    if (_progress.currentStreak >= 3) tryUnlock('streak_3');
    if (_progress.currentStreak >= 7) tryUnlock('streak_7');
    if (_progress.totalSrsReviews >= 20) tryUnlock('srs_20');
    if (_progress.pronunciationHighScores >= 5) {
      tryUnlock('pronunciation_star');
    }
    if (_progress.youtubeVideosAdded >= 1 ||
        _allMaterials.any((m) => m.sourceType == MaterialSourceType.youtube)) {
      tryUnlock('youtube_learner');
    }
    if (_progress.bestExamPercentage >= 80) {
      tryUnlock('exam_master');
    }

    if (unlocked.length != _progress.unlockedAchievements.length ||
        bonusXp > 0) {
      _progress = _progress.copyWith(
        unlockedAchievements: unlocked.toList(),
        xp: _progress.xp + bonusXp,
        todayXp: _progress.todayXp + bonusXp,
      );
      notifyListeners();
      await storage.saveUserProgress(_progress);
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? email,
    String? googleId,
    String? googlePhotoUrl,
    String? avatarBase64,
    int? dailyGoalXp,
  }) async {
    _progress = _progress.copyWith(
      displayName: displayName,
      email: email,
      googleId: googleId,
      googlePhotoUrl: googlePhotoUrl,
      avatarBase64: avatarBase64,
      dailyGoalXp: dailyGoalXp,
    );
    notifyListeners();
    await storage.saveUserProgress(_progress);
  }

  Future<bool> addFriend({
    required String nameOrCode,
    String? targetLanguageCode,
  }) async {
    final cleaned = nameOrCode.trim();
    if (cleaned.isEmpty) return false;

    final upper = cleaned.toUpperCase();
    final isCode = upper.startsWith('REMAN-') && upper.length >= 8;
    final hash = cleaned.codeUnits.fold<int>(
      0,
      (acc, c) => (acc * 37 + c) & 0xFFFF,
    );
    final generatedCode = isCode ? upper : 'REMAN-${1000 + (hash % 8999)}';
    final displayName = isCode ? 'Reman Друг (${upper.substring(6)})' : cleaned;

    final alreadyExists = _progress.friends.any(
      (f) =>
          f.friendCode.toUpperCase() == generatedCode ||
          f.name.toLowerCase() == displayName.toLowerCase(),
    );
    if (alreadyExists) return false;

    final friend = FriendProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: displayName,
      friendCode: generatedCode,
      xp: 120 + (hash % 480),
      streak: 1 + (hash % 14),
      targetLanguageCode: targetLanguageCode ?? _settings.targetLanguageCode,
    );

    _progress = _progress.copyWith(
      friends: [..._progress.friends, friend],
    );
    notifyListeners();
    await storage.saveUserProgress(_progress);
    await awardXp(10);
    return true;
  }

  Future<void> removeFriend(String friendId) async {
    _progress = _progress.copyWith(
      friends: _progress.friends.where((f) => f.id != friendId).toList(),
    );
    notifyListeners();
    await storage.saveUserProgress(_progress);
  }

  Future<void> cheerFriend(String friendId) async {
    var cheered = false;
    final updated = _progress.friends.map((f) {
      if (f.id == friendId && !f.cheeredToday) {
        cheered = true;
        return f.copyWith(
          xp: f.xp + 10,
          cheeredToday: true,
        );
      }
      return f;
    }).toList();
    if (!cheered) return;
    _progress = _progress.copyWith(friends: updated);
    notifyListeners();
    await storage.saveUserProgress(_progress);
    await awardXp(5);
  }

  Future<void> recordPronunciationScore(int scorePercent) async {
    final isHigh = scorePercent >= 85;
    if (scorePercent >= 70) {
      HapticFeedback.mediumImpact();
    }
    _progress = _progress.copyWith(
      pronunciationHighScores:
          _progress.pronunciationHighScores + (isHigh ? 1 : 0),
    );
    await awardXp(isHigh ? 15 : 5);
  }

  Future<void> recordExamCompleted(int score, int total) async {
    final pct = total <= 0 ? 0 : ((score / total) * 100).round();
    final best =
        pct > _progress.bestExamPercentage ? pct : _progress.bestExamPercentage;
    _progress = _progress.copyWith(
      examsPassed: _progress.examsPassed + 1,
      bestExamPercentage: best,
    );
    await awardXp(30 + (score * 2));
  }

  Future<void> completeLevelPathNode(String nodeKey) async {
    HapticFeedback.heavyImpact();
    final current = List<String>.from(_progress.completedPathNodes);
    final isFirstTime = !current.contains(nodeKey);
    if (isFirstTime) {
      current.add(nodeKey);
      _progress = _progress.copyWith(completedPathNodes: current);
      notifyListeners();
      await storage.saveUserProgress(_progress);
    }
    await awardXp(isFirstTime ? 25 : 10);
  }

  Future<void> recordDuelResult({
    required int myScore,
    required int correctAnswers,
    required int maxCombo,
    String? friendName,
    int? friendScore,
  }) async {
    HapticFeedback.mediumImpact();
    final record = DuelRecord(
      id: 'duel_${DateTime.now().microsecondsSinceEpoch}',
      myScore: myScore,
      correctAnswers: correctAnswers,
      maxCombo: maxCombo,
      friendName: friendName,
      friendScore: friendScore,
      languageCode: _settings.targetLanguageCode,
      playedAt: DateTime.now(),
    );
    final nextBestScore =
        myScore > _progress.bestDuelScore ? myScore : _progress.bestDuelScore;
    final nextBestCombo =
        maxCombo > _progress.bestDuelCombo ? maxCombo : _progress.bestDuelCombo;
    final updatedHistory = [record, ..._progress.duelHistory];
    _progress = _progress.copyWith(
      bestDuelScore: nextBestScore,
      bestDuelCombo: nextBestCombo,
      duelHistory: updatedHistory.length > 15
          ? updatedHistory.sublist(0, 15)
          : updatedHistory,
    );
    notifyListeners();
    await storage.saveUserProgress(_progress);
    await awardXp(15 + (correctAnswers * 2));
  }

  Map<String, dynamic> buildFullBackupPayload() {
    return {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {
        'targetLanguageCode': _settings.targetLanguageCode,
        'nativeLanguageCode': _settings.nativeLanguageCode,
        'themeMode': AppSettings.themeModeToString(_settings.themeMode),
        'learningTopicId': _settings.learningTopicId,
      },
      'progress': _progress.toJson(),
      'vocabulary': _allVocabulary.map((w) => w.toJson()).toList(),
      'materials': _allMaterials.map((m) => m.toJson()).toList(),
    };
  }

  Future<void> restoreFromBackupPayload(Map<String, dynamic> payload) async {
    final rawSettings = payload['settings'] as Map<String, dynamic>?;
    if (rawSettings != null) {
      final restoredTopicId = rawSettings['learningTopicId'] as String?;
      if (restoredTopicId != null && restoredTopicId.trim().isNotEmpty) {
        _settings = _settings.copyWith(
          learningTopicId: LearningTopic.fromId(restoredTopicId).id,
        );
        await storage.saveSettings(_settings);
      }
    }

    final rawProgress = payload['progress'] as Map<String, dynamic>?;
    if (rawProgress != null) {
      _progress = UserProgress.fromJson(rawProgress);
      await storage.saveUserProgress(_progress);
    }

    final rawVocab = payload['vocabulary'] as List<dynamic>?;
    if (rawVocab != null) {
      final restoredWords = rawVocab
          .whereType<Map<String, dynamic>>()
          .map(VocabWord.fromJson)
          .toList();
      await importWords(restoredWords);
    }

    final rawMaterials = payload['materials'] as List<dynamic>?;
    if (rawMaterials != null) {
      final restoredMats = rawMaterials
          .whereType<Map<String, dynamic>>()
          .map(StudyMaterial.fromJson)
          .toList();
      for (final m in restoredMats) {
        if (!_allMaterials.any((existing) => existing.id == m.id)) {
          _allMaterials = [m, ..._allMaterials];
        }
      }
      await storage.saveMaterials(_allMaterials);
    }

    notifyListeners();
    await _evaluateAchievements();
  }

  Future<void> updateSettings(AppSettings next) async {
    final prevNative = _settings.nativeLanguageCode;
    final prevTarget = _settings.targetLanguageCode;
    _settings = next;
    _applyTtsConfig(next);
    if (next.targetLanguageCode != prevTarget) {
      await _ensureStarterMaterialsForLanguage(next.targetLanguageCode);
    }
    notifyListeners();
    await storage.saveSettings(next);
    if (next.nativeLanguageCode != prevNative) {
      await _ensureNativeUiTranslations(next.nativeLanguageCode);
    }
  }

  bool hasWord(String word) {
    final key = word.trim().toLowerCase();
    final lang = _settings.targetLanguageCode;
    return _allVocabulary.any(
      (w) =>
          w.languageCode == lang && w.word.trim().toLowerCase() == key,
    );
  }

  Future<bool> addWord(VocabWord word) async {
    final key = word.word.trim().toLowerCase();
    if (key.isEmpty) return false;
    final lang = _settings.targetLanguageCode;
    final exists = _allVocabulary.any(
      (w) => w.languageCode == lang && w.word.trim().toLowerCase() == key,
    );
    if (exists) return false;

    final tagged = word.copyWith(languageCode: lang);
    _allVocabulary = [tagged, ..._allVocabulary];
    notifyListeners();
    await storage.saveVocabulary(_allVocabulary);
    await awardXp(10);
    return true;
  }

  Future<void> updateWord(VocabWord updated) async {
    _allVocabulary = _allVocabulary
        .map((w) => w.id == updated.id ? updated : w)
        .toList();
    notifyListeners();
    await storage.saveVocabulary(_allVocabulary);
  }

  Future<void> deleteWord(String id) async {
    _allVocabulary = _allVocabulary.where((w) => w.id != id).toList();
    notifyListeners();
    await storage.saveVocabulary(_allVocabulary);
  }

  Future<void> reviewWord(String id, SrsRating rating) async {
    if (rating == SrsRating.good || rating == SrsRating.easy) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    _allVocabulary = _allVocabulary.map((w) {
      if (w.id != id) return w;
      return w.applySrsRating(rating);
    }).toList();
    _progress = _progress.copyWith(
      totalSrsReviews: _progress.totalSrsReviews + 1,
    );
    notifyListeners();
    await storage.saveVocabulary(_allVocabulary);
    await awardXp(6);
  }

  Future<int> importWords(List<VocabWord> words) async {
    final lang = _settings.targetLanguageCode;
    final existingKeys = savedWordsNormalized;
    final toAdd = <VocabWord>[];
    for (final w in words) {
      final key = w.word.trim().toLowerCase();
      if (key.isNotEmpty && !existingKeys.contains(key)) {
        existingKeys.add(key);
        toAdd.add(w.copyWith(languageCode: lang));
      }
    }
    if (toAdd.isEmpty) return 0;
    _allVocabulary = [...toAdd, ..._allVocabulary];
    notifyListeners();
    await storage.saveVocabulary(_allVocabulary);
    await awardXp(toAdd.length * 2);
    return toAdd.length;
  }

  Future<void> addMaterial(StudyMaterial material) async {
    final lang = _settings.targetLanguageCode;
    final tagged = material.copyWith(languageCode: lang);
    final index = _allMaterials.indexWhere((m) => m.id == tagged.id);
    final isNew = index == -1;
    if (!isNew) {
      _allMaterials[index] = tagged;
    } else {
      _allMaterials = [tagged, ..._allMaterials];
      if (tagged.sourceType == MaterialSourceType.youtube) {
        _progress = _progress.copyWith(
          youtubeVideosAdded: _progress.youtubeVideosAdded + 1,
        );
      }
    }
    notifyListeners();
    await storage.saveMaterials(_allMaterials);
    if (isNew) {
      await awardXp(20);
    }
  }

  Future<void> deleteMaterial(String id) async {
    _allMaterials = _allMaterials.where((m) => m.id != id).toList();
    notifyListeners();
    await storage.saveMaterials(_allMaterials);
  }

  Future<void> speakTarget(
    String text, {
    double? overrideRate,
    String? trackId,
  }) {
    return tts.speak(
      text,
      locale: _settings.targetLanguage.ttsLocale,
      overrideRate: overrideRate,
      trackId: trackId,
    );
  }

  Future<void> speakNative(
    String text, {
    double? overrideRate,
    String? trackId,
  }) {
    return tts.speak(
      text,
      locale: _settings.nativeLanguage.ttsLocale,
      overrideRate: overrideRate,
      trackId: trackId,
    );
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in widget tree');
    return scope!.notifier!;
  }
}
