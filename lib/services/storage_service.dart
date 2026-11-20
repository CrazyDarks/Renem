import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/study_material.dart';
import '../models/user_progress.dart';
import '../models/vocab_word.dart';

class StorageService {
  static const _keyTargetLang = 'lm_target_lang';
  static const _keyNativeLang = 'lm_native_lang';
  static const _keyThemeMode = 'lm_theme_mode';
  static const _keyGeminiApiKey = 'lm_gemini_api_key';
  static const _keyUseInternationalIpa = 'lm_use_international_ipa';
  static const _keyVoicePreset = 'lm_voice_preset';
  static const _keyPreferredVoiceName = 'lm_preferred_voice_name';
  static const _keySpeechRate = 'lm_speech_rate';
  static const _keyUseCustomAiVoice = 'lm_use_custom_ai_voice';
  static const _keyCustomAiVoiceApiKey = 'lm_custom_ai_voice_api_key';
  static const _keyCustomAiVoiceEndpoint = 'lm_custom_ai_voice_endpoint';
  static const _keyCustomAiVoiceModel = 'lm_custom_ai_voice_model';
  static const _keyLearningTopic = 'lm_learning_topic';
  static const _keyUiL10nPrefix = 'lm_ui_l10n_v3_';
  static const _keyAiRuleCachePrefix = 'lm_ai_rule_v1_';
  static const _keyVocabulary = 'lm_vocabulary_v2';
  static const _keyMaterials = 'lm_materials_v2';
  static const _keyUserProgress = 'lm_user_progress_v2';
  static const _keySeeded = 'lm_seeded_v2';
  static const _keyTutorialCompleted = 'tutorial_completed';

  Future<bool> loadTutorialCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyTutorialCompleted) ?? false;
  }

  Future<void> saveTutorialCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTutorialCompleted, completed);
  }

  Future<Map<String, dynamic>?> loadAiRuleCache(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyAiRuleCachePrefix$cacheKey');
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAiRuleCache(
    String cacheKey,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyAiRuleCachePrefix$cacheKey', jsonEncode(data));
  }

  /// Loads cached AI-generated level module content using key format:
  /// `level_{targetLang}_{nativeLang}_{cefr}_{levelId}`
  Future<Map<String, dynamic>?> loadLevelContentCache(String exactKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(exactKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Persists AI-generated level module content under:
  /// `level_{targetLang}_{nativeLang}_{cefr}_{levelId}`
  Future<void> saveLevelContentCache(
    String exactKey,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(exactKey, jsonEncode(data));
  }

  /// Returns all cached level keys matching `level_*` for instant badge indicators.
  Future<Set<String>> loadCachedLevelKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().where((k) => k.startsWith('level_')).toSet();
  }

  /// Loads cached "Книжечка з правилами" JSON for `rules_book_{targetLang}_{nativeLang}`.
  Future<Map<String, dynamic>?> loadReadingRulesCache(String exactKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(exactKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Persists validated "Книжечка з правилами" JSON for offline access.
  Future<void> saveReadingRulesCache(
    String exactKey,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(exactKey, jsonEncode(data));
  }

  /// Loads cached grammar chapter JSON under:
  /// `grammar_book_{targetLang}_{nativeLang}_{chapterId}`
  Future<Map<String, dynamic>?> loadGrammarChapterCache(String exactKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(exactKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Persists validated grammar chapter JSON for offline access.
  Future<void> saveGrammarChapterCache(
    String exactKey,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(exactKey, jsonEncode(data));
  }

  /// Returns all cached grammar chapter keys for a language pair so the TOC
  /// can immediately display offline-ready badges.
  Future<Set<String>> loadCachedGrammarChapterKeys({
    required String targetLangCode,
    required String nativeLangCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'grammar_book_${targetLangCode}_${nativeLangCode}_';
    return prefs.getKeys().where((k) => k.startsWith(prefix)).toSet();
  }

  /// Loads saved Q&A history list under `grammar_qa_{targetLang}_{nativeLang}`.
  Future<List<Map<String, dynamic>>> loadGrammarQaHistory(
    String exactKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(exactKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Persists Q&A history list under `grammar_qa_{targetLang}_{nativeLang}`.
  Future<void> saveGrammarQaHistory(
    String exactKey,
    List<Map<String, dynamic>> items,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(exactKey, jsonEncode(items));
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      targetLanguageCode: prefs.getString(_keyTargetLang) ?? 'en',
      nativeLanguageCode: prefs.getString(_keyNativeLang) ?? 'uk',
      themeMode: AppSettings.themeModeFromString(prefs.getString(_keyThemeMode)),
      geminiApiKey: prefs.getString(_keyGeminiApiKey) ?? '',
      useInternationalIpa: prefs.getBool(_keyUseInternationalIpa) ?? false,
      voicePreset: prefs.getString(_keyVoicePreset) ?? 'neural_natural',
      preferredVoiceName: prefs.getString(_keyPreferredVoiceName) ?? '',
      speechRate: prefs.getDouble(_keySpeechRate) ?? 0.48,
      useCustomAiVoice: prefs.getBool(_keyUseCustomAiVoice) ?? false,
      customAiVoiceApiKey: prefs.getString(_keyCustomAiVoiceApiKey) ?? '',
      customAiVoiceEndpoint: prefs.getString(_keyCustomAiVoiceEndpoint) ?? '',
      customAiVoiceModel: prefs.getString(_keyCustomAiVoiceModel) ?? 'alloy',
      learningTopicId: prefs.getString(_keyLearningTopic) ?? 'neutral',
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyTargetLang, settings.targetLanguageCode),
      prefs.setString(_keyNativeLang, settings.nativeLanguageCode),
      prefs.setString(
        _keyThemeMode,
        AppSettings.themeModeToString(settings.themeMode),
      ),
      prefs.setString(_keyGeminiApiKey, settings.geminiApiKey.trim()),
      prefs.setBool(_keyUseInternationalIpa, settings.useInternationalIpa),
      prefs.setString(_keyVoicePreset, settings.voicePreset),
      prefs.setString(_keyPreferredVoiceName, settings.preferredVoiceName),
      prefs.setDouble(_keySpeechRate, settings.speechRate),
      prefs.setBool(_keyUseCustomAiVoice, settings.useCustomAiVoice),
      prefs.setString(
        _keyCustomAiVoiceApiKey,
        settings.customAiVoiceApiKey.trim(),
      ),
      prefs.setString(
        _keyCustomAiVoiceEndpoint,
        settings.customAiVoiceEndpoint.trim(),
      ),
      prefs.setString(
        _keyCustomAiVoiceModel,
        settings.customAiVoiceModel.trim(),
      ),
      prefs.setString(_keyLearningTopic, settings.learningTopicId),
    ]);
  }

  Future<Map<String, String>?> loadUiTranslationsCache(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_keyUiL10nPrefix$langCode');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUiTranslationsCache(
    String langCode,
    Map<String, String> values,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyUiL10nPrefix$langCode', jsonEncode(values));
  }

  Future<UserProgress> loadUserProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyUserProgress);
    final today = UserProgress.todayKey();
    if (raw == null || raw.isEmpty) {
      final initial = UserProgress(
        lastActiveDate: today,
        activeDates: [today],
      );
      await saveUserProgress(initial);
      return initial;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return UserProgress.fromJson(decoded);
    } catch (_) {
      return UserProgress(lastActiveDate: today, activeDates: [today]);
    }
  }

  Future<void> saveUserProgress(UserProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserProgress, jsonEncode(progress.toJson()));
  }

  Future<List<VocabWord>> loadVocabulary() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyVocabulary);
    if (raw == null || raw.isEmpty) {
      final isSeeded = prefs.getBool(_keySeeded) ?? false;
      if (!isSeeded) {
        final starter = _starterWords();
        await saveVocabulary(starter);
        return starter;
      }
      return [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(VocabWord.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveVocabulary(List<VocabWord> words) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(words.map((w) => w.toJson()).toList());
    await prefs.setString(_keyVocabulary, encoded);
    await prefs.setBool(_keySeeded, true);
  }

  Future<List<StudyMaterial>> loadMaterials() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyMaterials);
    if (raw == null || raw.isEmpty) {
      final isSeeded = prefs.getBool(_keySeeded) ?? false;
      if (!isSeeded) {
        final starter = _starterMaterials();
        await saveMaterials(starter);
        await prefs.setBool(_keySeeded, true);
        return starter;
      }
      return [];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(StudyMaterial.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMaterials(List<StudyMaterial> materials) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(materials.map((m) => m.toJson()).toList());
    await prefs.setString(_keyMaterials, encoded);
    await prefs.setBool(_keySeeded, true);
  }

  List<StudyMaterial> _starterMaterials() {
    return buildStarterMaterialsForLanguage('en');
  }

  /// Builds 2 engaging starter interactive texts/dialogues in [langCode]
  /// so new users can immediately start reading and tapping words.
  static List<StudyMaterial> buildStarterMaterialsForLanguage(String langCode) {
    final now = DateTime.now();
    switch (langCode) {
      case 'es':
        return [
          StudyMaterial(
            id: 'starter-es-1',
            title: 'El arte de aprender idiomas en contexto',
            languageCode: 'es',
            sourceType: MaterialSourceType.manual,
            createdAt: now,
            content:
                'Aprender un idioma nuevo se vuelve mucho más natural cuando lees historias reales en lugar de memorizar listas aburridas.\n\n'
                'Cada vez que encuentras una palabra desconocida dentro de una frase interesante, tu cerebro conecta el significado con la situación.\n\n'
                'Toca cualquier palabra de este texto para ver su traducción instantánea, escuchar la pronunciación y guardarla en tu vocabulario.',
          ),
          StudyMaterial(
            id: 'starter-es-2',
            title: 'Diálogo: Un café por la mañana en Madrid',
            languageCode: 'es',
            sourceType: MaterialSourceType.manual,
            createdAt: now.subtract(const Duration(minutes: 5)),
            content:
                '— ¡Buenos días! ¿Qué desea tomar hoy?\n\n'
                '— Hola, me gustaría un café con leche caliente y un cruasán recién horneado, por favor.\n\n'
                '— ¡Claro que sí! ¿Prefiere tomarlo aquí en la terraza o para llevar?\n\n'
                '— En la terraza está perfecto, hace un tiempo maravilloso esta mañana.',
          ),
        ];
      case 'de':
        return [
          StudyMaterial(
            id: 'starter-de-1',
            title: 'Sprachen natürlich im Kontext entdecken',
            languageCode: 'de',
            sourceType: MaterialSourceType.manual,
            createdAt: now,
            content:
                'Eine Fremdsprache zu lernen macht viel mehr Spaß, wenn man spannende Texte liest und echte Gespräche hört.\n\n'
                'Unser Gehirn merkt sich neue Wörter am besten, wenn sie in einer lebendigen Geschichte vorkommen.\n\n'
                'Tippe einfach auf ein beliebiges Wort in diesem Artikel, um die Übersetzung zu sehen und die Aussprache zu üben.',
          ),
          StudyMaterial(
            id: 'starter-de-2',
            title: 'Dialog: Im Berliner Straßencafé',
            languageCode: 'de',
            sourceType: MaterialSourceType.manual,
            createdAt: now.subtract(const Duration(minutes: 5)),
            content:
                '— Guten Morgen! Ist dieser Tisch am Fenster noch frei?\n\n'
                '— Ja, natürlich! Setzen Sie sich gerne. Was darf ich Ihnen bringen?\n\n'
                '— Ich hätte gern einen großen Cappuccino und ein Stück Apfelkuchen, bitte.\n\n'
                '— Sehr gern, ich bringe es Ihnen sofort.',
          ),
        ];
      case 'fr':
        return [
          StudyMaterial(
            id: 'starter-fr-1',
            title: 'Apprendre une langue grâce à l’immersion',
            languageCode: 'fr',
            sourceType: MaterialSourceType.manual,
            createdAt: now,
            content:
                'Plonger dans des textes authentiques est la méthode la plus efficace pour progresser rapidement dans une langue étrangère.\n\n'
                'En lisant quelques minutes chaque jour, vous découvrez naturellement le vocabulaire et la grammaire en action.\n\n'
                'Appuyez sur n’importe quel mot pour afficher sa traduction, écouter sa prononciation et l’ajouter à vos cartes de révision.',
          ),
          StudyMaterial(
            id: 'starter-fr-2',
            title: 'Dialogue : À la boulangerie parisienne',
            languageCode: 'fr',
            sourceType: MaterialSourceType.manual,
            createdAt: now.subtract(const Duration(minutes: 5)),
            content:
                '— Bonjour ! Qu’est-ce qui vous ferait plaisir ce matin ?\n\n'
                '— Bonjour, je voudrais une baguette croustillante et deux pains au chocolat, s’il vous plaît.\n\n'
                '— Voici pour vous. Désirez-vous autre chose avec ceci ?\n\n'
                '— Non, c’est tout pour aujourd’hui. Merci beaucoup et bonne journée !',
          ),
        ];
      case 'pl':
        return [
          StudyMaterial(
            id: 'starter-pl-1',
            title: 'Jak skutecznie uczyć się języków w kontekście',
            languageCode: 'pl',
            sourceType: MaterialSourceType.manual,
            createdAt: now,
            content:
                'Nauka języka obcego staje się przyjemnością, gdy codziennie czytasz krótkie, ciekawe artykuły oraz dialogi.\n\n'
                'Zamiast uczyć się pojedynczych słówek bez kontekstu, poznajesz całe zwroty gotowe do użycia w rozmowie.\n\n'
                'Kliknij dowolne słowo w tym tekście, aby sprawdzić tłumaczenie, odsłuchać wymowę i dodać je do powtórek.',
          ),
          StudyMaterial(
            id: 'starter-pl-2',
            title: 'Dialog: Spotkanie w kawiarni w Krakowie',
            languageCode: 'pl',
            sourceType: MaterialSourceType.manual,
            createdAt: now.subtract(const Duration(minutes: 5)),
            content:
                '— Dzień dobry! Co mogę dzisiaj dla państwa przygotować?\n\n'
                '— Poproszę czarną kawę oraz domową szarlotkę z cynamonem.\n\n'
                '— Doskonały wybór, nasza szarlotka jest dzisiaj wyjątkowo świeża.\n\n'
                '— Brzmi wspaniale, bardzo dziękuję!',
          ),
        ];
      case 'it':
        return [
          StudyMaterial(
            id: 'starter-it-1',
            title: 'Il segreto per imparare le lingue ogni giorno',
            languageCode: 'it',
            sourceType: MaterialSourceType.manual,
            createdAt: now,
            content:
                'Leggere racconti e dialoghi autentici aiuta la mente a ricordare i vocaboli senza alcuno sforzo.\n\n'
                'Bastano dieci minuti di lettura interattiva al giorno per costruire un vocabolario ricco e naturale.\n\n'
                'Tocca qualsiasi parola per scoprire il significato, ascoltare la pronuncia corretta e salvarla nel tuo dizionario.',
          ),
          StudyMaterial(
            id: 'starter-it-2',
            title: 'Dialogo: Colazione al bar a Roma',
            languageCode: 'it',
            sourceType: MaterialSourceType.manual,
            createdAt: now.subtract(const Duration(minutes: 5)),
            content:
                '— Buongiorno! Prende il solito caffè espresso al banco?\n\n'
                '— Oggi preferisco un cappuccino cremoso e un cornetto alla crema, grazie.\n\n'
                '— Arriva subito! Vuole anche un bicchiere d’acqua frizzante?\n\n'
                '— Sì, volentieri, è davvero una splendida giornata.',
          ),
        ];
      default:
        return [
          StudyMaterial(
            id: 'starter-$langCode-1',
            title: 'Learning Languages in Context (Interactive Story)',
            languageCode: langCode,
            sourceType: MaterialSourceType.manual,
            createdAt: now,
            content:
                'Learning a foreign language becomes effortless when you immerse yourself in authentic content every single day.\n\n'
                'Instead of memorizing isolated word lists, reading short stories and watching videos helps your brain recognize natural patterns.\n\n'
                'Tap any unfamiliar word in this article to inspect its instant translation, listen to native pronunciation, and save it to your spaced-repetition deck.',
          ),
          StudyMaterial(
            id: 'starter-$langCode-2',
            title: 'Dialogue: Morning Coffee & Travel Plans',
            languageCode: langCode,
            sourceType: MaterialSourceType.manual,
            createdAt: now.subtract(const Duration(minutes: 5)),
            content:
                '— Good morning! Welcome to our local café. What can I get started for you today?\n\n'
                '— Hi! Could I please get a freshly brewed coffee and a warm almond croissant?\n\n'
                '— Coming right up. Are you exploring the city for the weekend?\n\n'
                '— Yes, it is my first time visiting, and everyone has been remarkably welcoming so far!',
          ),
        ];
    }
  }

  List<VocabWord> _starterWords() {
    final now = DateTime.now();
    return [
      VocabWord(
        id: 'starter-word-1',
        word: 'immerse',
        translation: 'занурюватися',
        contextSentence:
            'Learning a foreign language becomes effortless when you immerse yourself in authentic content.',
        exampleSentence: 'She decided to immerse herself in Spanish cinema.',
        partOfSpeech: 'verb',
        sourceTitle: 'Learning Languages in Context',
        createdAt: now,
        nextReviewAt: now,
      ),
      VocabWord(
        id: 'starter-word-2',
        word: 'effortless',
        translation: 'невимушений, легкий',
        contextSentence:
            'Learning a foreign language becomes effortless when you immerse yourself in authentic content.',
        exampleSentence: 'With daily practice, speaking feels effortless.',
        partOfSpeech: 'adjective',
        sourceTitle: 'Learning Languages in Context',
        createdAt: now,
        nextReviewAt: now,
      ),
      VocabWord(
        id: 'starter-word-3',
        word: 'authentic',
        translation: 'автентичний, справжній',
        contextSentence:
            'Reading stories and watching videos helps you learn from authentic sources.',
        exampleSentence: 'We cooked an authentic Italian pasta dish.',
        partOfSpeech: 'adjective',
        sourceTitle: 'Learning Languages in Context',
        createdAt: now,
        nextReviewAt: now,
      ),
    ];
  }
}
