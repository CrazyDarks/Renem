import 'supported_languages.dart';

/// Single letter, special character, or diacritic entry in the Reading Rules Book.
class AlphabetEntry {
  const AlphabetEntry({
    required this.symbol,
    required this.pronunciation,
    required this.exampleWord,
    required this.exampleTranslation,
    this.note = '',
  });

  final String symbol;
  final String pronunciation;
  final String exampleWord;
  final String exampleTranslation;
  final String note;

  bool get isValid => symbol.trim().isNotEmpty && pronunciation.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'pronunciation': pronunciation,
        'exampleWord': exampleWord,
        'exampleTranslation': exampleTranslation,
        'note': note,
      };

  factory AlphabetEntry.fromJson(Map<String, dynamic> json) {
    return AlphabetEntry(
      symbol: (json['symbol'] ?? json['letter'] ?? '').toString().trim(),
      pronunciation: (json['pronunciation'] ?? json['sound'] ?? '')
          .toString()
          .trim(),
      exampleWord: (json['exampleWord'] ?? json['example'] ?? '')
          .toString()
          .trim(),
      exampleTranslation:
          (json['exampleTranslation'] ?? json['translation'] ?? '')
              .toString()
              .trim(),
      note: (json['note'] ?? '').toString().trim(),
    );
  }
}

/// Speakable example word or phrase inside a reading/writing rule card.
class ReadingRuleExample {
  const ReadingRuleExample({
    required this.text,
    required this.pronunciation,
    required this.translation,
  });

  final String text;
  final String pronunciation;
  final String translation;

  bool get isValid => text.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'text': text,
        'pronunciation': pronunciation,
        'translation': translation,
      };

  factory ReadingRuleExample.fromJson(Map<String, dynamic> json) {
    return ReadingRuleExample(
      text: (json['text'] ?? json['word'] ?? json['target'] ?? '')
          .toString()
          .trim(),
      pronunciation:
          (json['pronunciation'] ?? json['transcription'] ?? json['sound'] ?? '')
              .toString()
              .trim(),
      translation: (json['translation'] ?? json['native'] ?? '')
          .toString()
          .trim(),
    );
  }
}

/// A structured rule block with explanation and speakable examples.
class ReadingRuleItem {
  const ReadingRuleItem({
    required this.title,
    required this.explanation,
    required this.examples,
  });

  final String title;
  final String explanation;
  final List<ReadingRuleExample> examples;

  bool get isValid => title.trim().isNotEmpty && explanation.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'title': title,
        'explanation': explanation,
        'examples': examples.map((e) => e.toJson()).toList(),
      };

  factory ReadingRuleItem.fromJson(Map<String, dynamic> json) {
    final rawExamples = json['examples'] as List<dynamic>? ?? const [];
    final examples = rawExamples
        .whereType<Map<String, dynamic>>()
        .map(ReadingRuleExample.fromJson)
        .where((e) => e.isValid)
        .toList();
    return ReadingRuleItem(
      title: (json['title'] ?? '').toString().trim(),
      explanation: (json['explanation'] ?? json['rule'] ?? '')
          .toString()
          .trim(),
      examples: examples,
    );
  }
}

/// Complete structured "Книжечка з правилами" (Reading & Writing Rules Handbook)
/// generated via Multi-AI and cached locally for offline study.
class ReadingRulesBook {
  const ReadingRulesBook({
    required this.targetLanguageCode,
    required this.nativeLanguageCode,
    required this.overview,
    required this.alphabetAndDiacritics,
    required this.readingRules,
    required this.stressAndIntonation,
    required this.writingRules,
    this.usedAi = false,
    this.providerName = '',
    this.generatedAtIso = '',
  });

  final String targetLanguageCode;
  final String nativeLanguageCode;
  final String overview;
  final List<AlphabetEntry> alphabetAndDiacritics;
  final List<ReadingRuleItem> readingRules;
  final List<ReadingRuleItem> stressAndIntonation;
  final List<ReadingRuleItem> writingRules;
  final bool usedAi;
  final String providerName;
  final String generatedAtIso;

  /// Strict validation to ensure AI output is complete and non-corrupted
  /// before accepting and persisting to local offline cache.
  bool get isValid =>
      overview.trim().isNotEmpty &&
      alphabetAndDiacritics.length >= 3 &&
      readingRules.length >= 2 &&
      stressAndIntonation.isNotEmpty &&
      writingRules.length >= 2;

  static String cacheKey({
    required String targetLangCode,
    required String nativeLangCode,
  }) =>
      'rules_book_${targetLangCode}_$nativeLangCode';

  Map<String, dynamic> toJson() => {
        'targetLanguageCode': targetLanguageCode,
        'nativeLanguageCode': nativeLanguageCode,
        'overview': overview,
        'alphabetAndDiacritics':
            alphabetAndDiacritics.map((e) => e.toJson()).toList(),
        'readingRules': readingRules.map((e) => e.toJson()).toList(),
        'stressAndIntonation':
            stressAndIntonation.map((e) => e.toJson()).toList(),
        'writingRules': writingRules.map((e) => e.toJson()).toList(),
        'usedAi': usedAi,
        'providerName': providerName,
        'generatedAtIso': generatedAtIso,
      };

  factory ReadingRulesBook.fromJson(
    Map<String, dynamic> json, {
    String fallbackTargetCode = 'en',
    String fallbackNativeCode = 'uk',
  }) {
    List<ReadingRuleItem> parseRuleList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ReadingRuleItem.fromJson)
          .where((item) => item.isValid)
          .toList();
    }

    final rawAlphabet =
        json['alphabetAndDiacritics'] as List<dynamic>? ?? const [];
    final alphabet = rawAlphabet
        .whereType<Map<String, dynamic>>()
        .map(AlphabetEntry.fromJson)
        .where((e) => e.isValid)
        .toList();

    return ReadingRulesBook(
      targetLanguageCode:
          (json['targetLanguageCode'] ?? fallbackTargetCode).toString().trim(),
      nativeLanguageCode:
          (json['nativeLanguageCode'] ?? fallbackNativeCode).toString().trim(),
      overview: (json['overview'] ?? '').toString().trim(),
      alphabetAndDiacritics: alphabet,
      readingRules: parseRuleList(json['readingRules']),
      stressAndIntonation: parseRuleList(json['stressAndIntonation']),
      writingRules: parseRuleList(json['writingRules']),
      usedAi: json['usedAi'] == true,
      providerName: (json['providerName'] ?? '').toString().trim(),
      generatedAtIso: (json['generatedAtIso'] ?? '').toString().trim(),
    );
  }

  /// Structured offline starter handbook so the screen always works cleanly
  /// even before the first online AI generation.
  static ReadingRulesBook buildOfflineFallback({
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
  }) {
    final isUk = nativeLang.code == 'uk';
    final langLabel = isUk ? targetLang.nameUk : targetLang.englishName;

    if (targetLang.code == 'en') {
      return ReadingRulesBook(
        targetLanguageCode: targetLang.code,
        nativeLanguageCode: nativeLang.code,
        overview: isUk
            ? 'Англійська використовує латинський алфавіт (26 літер). Вимова часто залежить від типу складу та буквосполучень, тому слухайте кожен приклад.'
            : 'English uses the 26-letter Latin alphabet. Pronunciation depends heavily on syllable type and letter combinations.',
        alphabetAndDiacritics: [
          AlphabetEntry(
            symbol: 'Aa',
            pronunciation: isUk ? '[ей] у відкритому, [е] у закритому' : '[eɪ] / [æ]',
            exampleWord: 'name / cat',
            exampleTranslation: isUk ? 'ім’я / кіт' : 'name / cat',
          ),
          AlphabetEntry(
            symbol: 'Ee',
            pronunciation: isUk ? '[і:] у відкритому, [е] у закритому' : '[iː] / [e]',
            exampleWord: 'see / pen',
            exampleTranslation: isUk ? 'бачити / ручка' : 'see / pen',
          ),
          AlphabetEntry(
            symbol: 'Ii / Yy',
            pronunciation: isUk ? '[ай] або коротке [и/і]' : '[aɪ] / [ɪ]',
            exampleWord: 'time / city',
            exampleTranslation: isUk ? 'час / місто' : 'time / city',
          ),
          AlphabetEntry(
            symbol: 'Ww',
            pronunciation: isUk ? 'губне [в] (губи трубочкою)' : 'rounded [w]',
            exampleWord: 'water',
            exampleTranslation: isUk ? 'вода' : 'water',
          ),
        ],
        readingRules: [
          ReadingRuleItem(
            title: isUk ? 'Буквосполучення TH' : 'TH digraph',
            explanation: isUk
                ? 'Кінчик язика між зубами: дзвінке [ð] у службових словах (the, this) та глухе [θ] у значущих (think, thank).'
                : 'Place tongue tip gently between teeth: voiced [ð] (this) vs voiceless [θ] (think).',
            examples: [
              ReadingRuleExample(
                text: 'think',
                pronunciation: '[θɪŋk]',
                translation: isUk ? 'думати' : 'think',
              ),
              ReadingRuleExample(
                text: 'this',
                pronunciation: '[ðɪs]',
                translation: isUk ? 'цей' : 'this',
              ),
            ],
          ),
          ReadingRuleItem(
            title: isUk ? 'Німа літера E в кінці слова' : 'Silent final E',
            explanation: isUk
                ? 'Кінцева «e» зазвичай не читається, але робить попередню голосну довгою (як в алфавіті).'
                : 'Final silent "e" usually lengthens the preceding vowel to its alphabet name.',
            examples: [
              ReadingRuleExample(
                text: 'make',
                pronunciation: '[meɪk]',
                translation: isUk ? 'робити' : 'make',
              ),
              ReadingRuleExample(
                text: 'home',
                pronunciation: '[hoʊm]',
                translation: isUk ? 'дім' : 'home',
              ),
            ],
          ),
        ],
        stressAndIntonation: [
          ReadingRuleItem(
            title: isUk ? 'Наголос у двоскладових словах' : 'Two-syllable stress',
            explanation: isUk
                ? 'Іменники та прикметники частіше мають наголос на 1-му складі (TAble), а дієслова — на 2-му (beGIN). Питання без питального слова мають висхідну інтонацію.'
                : 'Nouns/adjectives often stress the 1st syllable; verbs often stress the 2nd. Yes/no questions rise at the end.',
            examples: [
              ReadingRuleExample(
                text: 'Are you ready?',
                pronunciation: '↗ rising',
                translation: isUk ? 'Ти готовий?' : 'Are you ready?',
              ),
            ],
          ),
        ],
        writingRules: [
          ReadingRuleItem(
            title: isUk ? 'Велика літера' : 'Capitalization',
            explanation: isUk
                ? 'З великої літери завжди пишуться займенник «I» (я), дні тижня (Monday), місяці (May) та назви мов (English).'
                : 'Always capitalize the pronoun "I", days of the week, months, and languages.',
            examples: [
              ReadingRuleExample(
                text: 'I study English on Monday.',
                pronunciation: '',
                translation: isUk ? 'Я вчу англійську в понеділок.' : 'I study English on Monday.',
              ),
            ],
          ),
          ReadingRuleItem(
            title: isUk ? 'Типова пастка: подвоєння та апостроф' : 'Common pitfall: apostrophes',
            explanation: isUk
                ? 'Не плутайте it’s (= it is) та its (його/її). Апостроф позначає скорочення або присвійність.'
                : 'Do not confuse "it’s" (it is) with possessive "its".',
            examples: [
              ReadingRuleExample(
                text: "It's a good day.",
                pronunciation: '',
                translation: isUk ? 'Це гарний день.' : 'It is a good day.',
              ),
            ],
          ),
        ],
        usedAi: false,
      );
    }

    return ReadingRulesBook(
      targetLanguageCode: targetLang.code,
      nativeLanguageCode: nativeLang.code,
      overview: isUk
          ? 'Базовий офлайн-довідник для мови «$langLabel (${targetLang.displayNativeName})». Натисніть «Оновити довідник», щоб ШІ створив повний розбір алфавіту, діакритики, правил читання та правопису.'
          : 'Starter offline handbook for $langLabel (${targetLang.displayNativeName}). Tap "Refresh Handbook" so AI generates the complete alphabet, reading, stress, and writing rules.',
      alphabetAndDiacritics: [
        AlphabetEntry(
          symbol: targetLang.displayNativeName,
          pronunciation: isUk
              ? 'Натисніть «Оновити довідник» для повного списку літер і діакритики'
              : 'Tap Refresh Handbook for full alphabet & diacritics',
          exampleWord: targetLang.displayNativeName,
          exampleTranslation: langLabel,
        ),
        AlphabetEntry(
          symbol: 'A / E / I / O / U',
          pronunciation: isUk
              ? 'Голосні звуки формують ритм і відкритість складів'
              : 'Vowels shape syllable rhythm and clarity',
          exampleWord: 'A, E, I, O, U',
          exampleTranslation: isUk ? 'Голосні' : 'Vowels',
        ),
        AlphabetEntry(
          symbol: '´ ` ^ ¨ ~',
          pronunciation: isUk
              ? 'Діакритичні знаки змінюють звучання, довготу або наголос'
              : 'Diacritics alter vowel quality, length, or stress',
          exampleWord: targetLang.displayNativeName,
          exampleTranslation: isUk ? 'Особливі знаки' : 'Special marks',
        ),
      ],
      readingRules: [
        ReadingRuleItem(
          title: isUk ? 'Буквосполучення та приголосні' : 'Letter combinations & consonants',
          explanation: isUk
              ? 'Звертайте увагу на сполучення двох літер, які дають один звук, а також на пом’якшення чи оглушення приголосних наприкінці слова.'
              : 'Watch for digraphs representing a single sound and consonant softening or final devoicing.',
          examples: [
            ReadingRuleExample(
              text: targetLang.displayNativeName,
              pronunciation: '',
              translation: langLabel,
            ),
          ],
        ),
        ReadingRuleItem(
          title: isUk ? 'Винятки та запозичення' : 'Exceptions & loanwords',
          explanation: isUk
              ? 'Частовживані короткі слова та інтернаціоналізми іноді читаються не за стандартним правилом — завжди прослуховуйте озвучку.'
              : 'Frequent short words and loanwords may deviate from standard spelling-to-sound rules.',
          examples: const [],
        ),
      ],
      stressAndIntonation: [
        ReadingRuleItem(
          title: isUk ? 'Наголос та питальна інтонація' : 'Word stress & question intonation',
          explanation: isUk
              ? 'У розповідних реченнях голос плавно спадає в кінці, а в загальних питаннях піднімається на ключовому слові.'
              : 'Statements usually end with falling pitch while yes/no questions rise near the end.',
          examples: const [],
        ),
      ],
      writingRules: [
        ReadingRuleItem(
          title: isUk ? 'Велика літера та пунктуація' : 'Capitalization & punctuation',
          explanation: isUk
              ? 'Починайте речення та власні назви з великої літери. Перевіряйте правила великої літери для днів тижня, мов і звертань у мові $langLabel.'
              : 'Capitalize sentence starts and proper nouns, and check language-specific rules for days, languages, and polite forms.',
          examples: const [],
        ),
        ReadingRuleItem(
          title: isUk ? 'Типові пастки для початківців' : 'Beginner pitfalls',
          explanation: isUk
              ? 'Не пропускайте діакритичні знаки та стежте за базовими закінченнями роду й числа — оновіть довідник через ШІ для конкретних прикладів.'
              : 'Do not omit diacritics and pay attention to gender/number endings — refresh via AI for tailored examples.',
          examples: const [],
        ),
      ],
      usedAi: false,
    );
  }
}
