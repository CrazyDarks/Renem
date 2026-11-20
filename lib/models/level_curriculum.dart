import 'app_settings.dart';
import 'exam_models.dart';
import 'vocab_word.dart';

/// Language-independent blueprint node for the CEFR Level Path (A1–C2).
class CurriculumModuleNode {
  const CurriculumModuleNode({
    required this.id,
    required this.cefr,
    required this.stepNumber,
    required this.titleUk,
    required this.titleEn,
    required this.subtitleUk,
    required this.subtitleEn,
    required this.aiTopicPrompt,
    required this.offlineRuleUk,
    required this.offlineRuleEn,
    required this.offlineMistakesUk,
    required this.offlineMistakesEn,
    required this.offlineTipUk,
    required this.offlineTipEn,
  });

  final String id;
  final CefrLevel cefr;
  final int stepNumber;
  final String titleUk;
  final String titleEn;
  final String subtitleUk;
  final String subtitleEn;

  /// Precise pedagogical description sent to the AI so it adapts the lesson
  /// accurately to any of the 92 supported target languages.
  final String aiTopicPrompt;

  final String offlineRuleUk;
  final String offlineRuleEn;
  final String offlineMistakesUk;
  final String offlineMistakesEn;
  final String offlineTipUk;
  final String offlineTipEn;

  String progressKey(String targetLangCode) =>
      '$targetLangCode:${cefr.code}:$stepNumber';

  String cacheKey({
    required String targetLangCode,
    required String nativeLangCode,
    String topicId = 'neutral',
  }) {
    final base =
        'level_${targetLangCode}_${nativeLangCode}_${cefr.code.toLowerCase()}_$id';
    final cleanTopic = topicId.trim().toLowerCase();
    if (cleanTopic.isEmpty || cleanTopic == 'neutral') return base;
    return '${base}_$cleanTopic';
  }

  String title(String uiLang) => uiLang == 'uk' ? titleUk : titleEn;
  String subtitle(String uiLang) => uiLang == 'uk' ? subtitleUk : subtitleEn;
  String offlineRule(String uiLang) =>
      uiLang == 'uk' ? offlineRuleUk : offlineRuleEn;
  String offlineMistakes(String uiLang) =>
      uiLang == 'uk' ? offlineMistakesUk : offlineMistakesEn;
  String offlineTip(String uiLang) =>
      uiLang == 'uk' ? offlineTipUk : offlineTipEn;
}

class LevelExampleItem {
  const LevelExampleItem({
    required this.target,
    required this.native,
  });

  final String target;
  final String native;

  Map<String, dynamic> toJson() => {
        'target': target,
        'native': native,
      };

  factory LevelExampleItem.fromJson(Map<String, dynamic> json) {
    return LevelExampleItem(
      target: (json['target'] ?? '').toString().trim(),
      native: (json['native'] ?? '').toString().trim(),
    );
  }
}

class LevelQuizItem {
  const LevelQuizItem({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };

  factory LevelQuizItem.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as List? ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final rawIndex = (json['correctIndex'] as num?)?.toInt() ?? 0;
    final safeIndex =
        rawOptions.isEmpty ? 0 : rawIndex.clamp(0, rawOptions.length - 1);
    return LevelQuizItem(
      question: (json['question'] ?? '').toString().trim(),
      options: rawOptions,
      correctIndex: safeIndex,
      explanation: (json['explanation'] ?? '').toString().trim(),
    );
  }
}

/// Complete generated (or cached / offline) lesson payload for one level node.
class GeneratedLevelContent {
  const GeneratedLevelContent({
    required this.grammarRule,
    required this.commonMistakes,
    required this.keyTip,
    required this.examples,
    required this.practiceExercises,
    required this.finalTest,
    required this.usedAi,
    this.providerName = '',
  });

  final String grammarRule;
  final String commonMistakes;
  final String keyTip;
  final List<LevelExampleItem> examples;
  final List<LevelQuizItem> practiceExercises;
  final List<LevelQuizItem> finalTest;
  final bool usedAi;
  final String providerName;

  bool get isValid =>
      grammarRule.isNotEmpty &&
      examples.isNotEmpty &&
      practiceExercises.isNotEmpty &&
      finalTest.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'grammarRule': grammarRule,
        'commonMistakes': commonMistakes,
        'keyTip': keyTip,
        'examples': examples.map((e) => e.toJson()).toList(),
        'practiceExercises': practiceExercises.map((e) => e.toJson()).toList(),
        'finalTest': finalTest.map((e) => e.toJson()).toList(),
        'usedAi': usedAi,
        'providerName': providerName,
      };

  factory GeneratedLevelContent.fromJson(Map<String, dynamic> json) {
    final examples = (json['examples'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => LevelExampleItem.fromJson(Map<String, dynamic>.from(m)))
        .where((e) => e.target.isNotEmpty)
        .toList();

    final practice = (json['practiceExercises'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => LevelQuizItem.fromJson(Map<String, dynamic>.from(m)))
        .where((q) => q.question.isNotEmpty && q.options.length >= 2)
        .toList();

    final test = (json['finalTest'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => LevelQuizItem.fromJson(Map<String, dynamic>.from(m)))
        .where((q) => q.question.isNotEmpty && q.options.length >= 2)
        .toList();

    return GeneratedLevelContent(
      grammarRule: (json['grammarRule'] ?? '').toString().trim(),
      commonMistakes: (json['commonMistakes'] ?? '').toString().trim(),
      keyTip: (json['keyTip'] ?? '').toString().trim(),
      examples: examples,
      practiceExercises: practice,
      finalTest: test,
      usedAi: json['usedAi'] == true,
      providerName: (json['providerName'] ?? '').toString().trim(),
    );
  }
}

/// Universal 42-module CEFR Curriculum Blueprint (7 sequential modules per level A1–C2).
/// Works automatically for all 92 supported target languages.
class UniversalCurriculumBlueprint {
  static const List<CurriculumModuleNode> allNodes = [
    // ================= A1 (7 modules) =================
    CurriculumModuleNode(
      id: 'a1_m1',
      cefr: CefrLevel.a1,
      stepNumber: 1,
      titleUk: 'Базові конструкції, привітання та знайомство',
      titleEn: 'Core Sentence Basics, Greetings & Introductions',
      subtitleUk: 'Базовий порядок слів, займенники та дієслово «бути»',
      subtitleEn: 'Basic word order, personal pronouns, and the verb "to be"',
      aiTopicPrompt:
          'Foundational sentence structure, personal pronouns, greetings, self-introduction, and the verb "to be" / basic identity statements.',
      offlineRuleUk:
          'На рівні A1 речення будуються за чіткою схемою: хто виконує дію (підмет) → основна дія або стан (дієслово) → уточнення (хто/що/де). Звертайте увагу на узгодження дієслова «бути» із займенниками.',
      offlineRuleEn:
          'At A1, build clear statements using the core pattern: Subject (who) → Verb (action/state) → Complement (what/where). Pay close attention to conjugating "to be" with each pronoun.',
      offlineMistakesUk:
          'Часта помилка — пропуск дієслова-зв’язки або пряме калькування порядку слів із рідної мови.',
      offlineMistakesEn:
          'Common mistake: omitting the linking verb or copying word order literally from your native language.',
      offlineTipUk: 'Формула знайомства: [Займенник] + [дієслово «бути»] + [ім’я / професія / країна].',
      offlineTipEn: 'Core pattern: [Pronoun] + [verb "to be"] + [name / role / origin].',
    ),
    CurriculumModuleNode(
      id: 'a1_m2',
      cefr: CefrLevel.a1,
      stepNumber: 2,
      titleUk: 'Теперішній час та щоденні дії',
      titleEn: 'Present Tense & Daily Routines',
      subtitleUk: 'Регулярні звички, розклад дня та закінчення дієслів',
      subtitleEn: 'Regular habits, daily schedules, and present verb endings',
      aiTopicPrompt:
          'Present tense conjugation for regular and top irregular verbs, talking about daily routines, habits, and frequency adverbs.',
      offlineRuleUk:
          'Теперішній час використовується для опису регулярних дій, звичок і загальних фактів. Вивчіть типові особові закінчення дієслів для кожної особи в обраній мові.',
      offlineRuleEn:
          'Use the present tense for daily routines, habits, and general facts. Focus on how verb endings change by person and number in your target language.',
      offlineMistakesUk:
          'Типова помилка — вживання початкової форми (інфінітива) замість провідміняного дієслова.',
      offlineMistakesEn:
          'Common mistake: leaving the verb in its infinitive form instead of conjugating it for the subject.',
      offlineTipUk: 'Маркери регулярності: щодня, зазвичай, часто, вранці.',
      offlineTipEn: 'Frequency markers: every day, usually, often, in the morning.',
    ),
    CurriculumModuleNode(
      id: 'a1_m3',
      cefr: CefrLevel.a1,
      stepNumber: 3,
      titleUk: 'Питання та заперечення',
      titleEn: 'Questions & Negations',
      subtitleUk: 'Загальні й спеціальні питання (хто, де, коли) та частка «не»',
      subtitleEn: 'Yes/No questions, Wh-question words, and negative statements',
      aiTopicPrompt:
          'Forming yes/no questions, question words (who, what, where, when, why, how), and negative sentences in the present tense.',
      offlineRuleUk:
          'Щоб поставити питання, використовуйте питальні слова на початку речення, інтонацію або спеціальне допоміжне дієслово (залежно від граматики мови). Для заперечення додавайте заперечну частку перед дієсловом.',
      offlineRuleEn:
          'Form questions using question words at the start, rising intonation, or auxiliary verbs depending on the language. Form negations by placing the negative particle in the required position.',
      offlineMistakesUk:
          'Типова помилка — подвійне маркування (наприклад, зайве закінчення у дієслова після допоміжного слова) або неправильне місце частки заперечення.',
      offlineMistakesEn:
          'Common mistake: placing the negation marker in the wrong position or misordering subject and auxiliary.',
      offlineTipUk: 'Опануйте 6 базових питальних слів: Хто? Що? Де? Коли? Чому? Як?',
      offlineTipEn: 'Master the 6 core question words: Who? What? Where? When? Why? How?',
    ),
    CurriculumModuleNode(
      id: 'a1_m4',
      cefr: CefrLevel.a1,
      stepNumber: 4,
      titleUk: 'Іменники, рід, артиклі та множина',
      titleEn: 'Nouns, Gender, Articles & Plurals',
      subtitleUk: 'Означеність/неозначеність, числа та узгодження прикметників',
      subtitleEn: 'Definite/indefinite markers, numbers, and plural forms',
      aiTopicPrompt:
          'Nouns, grammatical gender or classifiers (if applicable to the target language), articles/determiners, plural formation, and basic noun-adjective agreement.',
      offlineRuleUk:
          'У багатьох мовах іменники мають рід, число або вимагають артикля (означеного для відомих предметів і неозначеного для першої згадки). Завжди запам’ятовуйте нові іменники разом із їхнім родом або артиклем.',
      offlineRuleEn:
          'Nouns often carry grammatical gender, plural endings, or articles (indefinite for first mention, definite for specific known items). Always learn new nouns together with their article or gender.',
      offlineMistakesUk:
          'Типова помилка — вживання іменника без обов’язкового артикля або забування про зміну прикметника у множині.',
      offlineMistakesEn:
          'Common mistake: omitting required articles or forgetting plural agreement.',
      offlineTipUk: 'Нове слово = [Артикль / Рід] + [Іменник] + [Форма множини].',
      offlineTipEn: 'Learn as a chunk: [Article / Gender] + [Noun] + [Plural form].',
    ),
    CurriculumModuleNode(
      id: 'a1_m5',
      cefr: CefrLevel.a1,
      stepNumber: 5,
      titleUk: 'Прийменники місця, часу та орієнтування в місті',
      titleEn: 'Prepositions of Place, Time & Getting Around',
      subtitleUk: 'Де знаходиться об’єкт, котра година та маршрут по місту',
      subtitleEn: 'Locations, telling time, transport, and simple directions',
      aiTopicPrompt:
          'Prepositions of place (in, on, under, near, next to) and time (at, on, in), telling time, days of the week, and asking for directions.',
      offlineRuleUk:
          'Прийменники поєднують слова у просторі й часі. Розрізняйте статичне положення («де?») та напрямок руху («куди?»), оскільки в багатьох мовах вони вимагають різних прийменників або відмінків.',
      offlineRuleEn:
          'Prepositions anchor actions in space and time. Distinguish between static location ("where?") and movement ("where to?"), as many languages use different forms or cases.',
      offlineMistakesUk:
          'Типова помилка — дослівний переклад прийменників із рідної мови (наприклад, «на роботі» чи «в понеділок»).',
      offlineMistakesEn:
          'Common mistake: translating prepositions word-for-word from your native language.',
      offlineTipUk: 'Запам’ятовуйте прийменники цілими зв’язками (з днем тижня, з часом, з транспортом).',
      offlineTipEn: 'Memorize prepositions inside fixed time and place chunks.',
    ),
    CurriculumModuleNode(
      id: 'a1_m6',
      cefr: CefrLevel.a1,
      stepNumber: 6,
      titleUk: 'Базові модальні конструкції (хочу, можу, треба)',
      titleEn: 'Basic Modal Expressions (Can, Want, Need)',
      subtitleUk: 'Вираження бажань, можливостей та ввічливих прохань',
      subtitleEn: 'Expressing ability, desires, needs, and polite requests',
      aiTopicPrompt:
          'Core modal verbs and expressions for ability ("can"), desire ("want / would like"), and basic necessity ("need / must") combined with infinitives.',
      offlineRuleUk:
          'Модальні дієслова виражають ставлення до дії (можливість, бажання, необхідність). Після модального дієслова основна дія зазвичай стоїть у початковій формі (інфінітиві).',
      offlineRuleEn:
          'Modal verbs express ability, desire, or necessity. The main verb that follows a modal typically stays in its base/infinitive form.',
      offlineMistakesUk:
          'Типова помилка — відмінювання обох дієслів одночасно замість того, щоб відмінювати лише модальне.',
      offlineMistakesEn:
          'Common mistake: conjugating both the modal verb and the main verb at the same time.',
      offlineTipUk: 'Формула: [Модальне дієслово (змінюється)] + [Основне дієслово (інфінітив)].',
      offlineTipEn: 'Formula: [Conjugated modal] + [Main verb in infinitive].',
    ),
    CurriculumModuleNode(
      id: 'a1_m7',
      cefr: CefrLevel.a1,
      stepNumber: 7,
      titleUk: 'Повсякденні діалоги: кафе, магазин, покупки',
      titleEn: 'Everyday Dialogues: Café, Shopping & Polite Requests',
      subtitleUk: 'Замовлення їжі, ціни, ввічливі формули та короткі відповіді',
      subtitleEn: 'Ordering food, asking prices, polite formulas, and practical replies',
      aiTopicPrompt:
          'Practical A1 dialogues for cafés, restaurants, and shopping: polite requests ("I would like..."), asking prices, quantities, thanking, and paying.',
      offlineRuleUk:
          'У повсякденних діалогах важливу роль відіграють ввічливі кліше («Я б хотів/хотіла...», «Скільки це коштує?», «Будь ласка»). Вони звучать значно природніше, ніж прямі наказові форми.',
      offlineRuleEn:
          'Polite fixed expressions ("I would like...", "How much is this?", "Could I have...") sound far more natural in cafés and shops than direct commands.',
      offlineMistakesUk:
          'Типова помилка — використання занадто прямого «Дайте мені...» замість ввічливої формули замовлення.',
      offlineMistakesEn:
          'Common mistake: using overly direct imperatives instead of polite request forms.',
      offlineTipUk: 'Використовуйте пом’якшені формули ввічливості в кожному діалозі обслуговування.',
      offlineTipEn: 'Pair every request with polite softeners and greetings.',
    ),

    // ================= A2 (7 modules) =================
    CurriculumModuleNode(
      id: 'a2_m1',
      cefr: CefrLevel.a2,
      stepNumber: 1,
      titleUk: 'Минулий час: завершені події та розповідь',
      titleEn: 'Past Tense: Completed Events & Storytelling',
      subtitleUk: 'Як розповідати про вчорашній день, вихідні та подорожі',
      subtitleEn: 'Talking about yesterday, weekends, trips, and past sequences',
      aiTopicPrompt:
          'Main past tense for completed actions, regular vs key irregular past forms, and time expressions (yesterday, last week, two years ago).',
      offlineRuleUk:
          'Минулий час описує події, які відбулися й завершилися до моменту мовлення. Зверніть увагу на утворення правильних форм та список найуживаніших неправильних дієслів (бути, йти, робити, мати, бачити).',
      offlineRuleEn:
          'Use the past tense for actions completed before now. Practice regular past patterns alongside the highest-frequency irregular verbs (be, go, do, have, see).',
      offlineMistakesUk:
          'Типова помилка — застосування правила для правильних дієслів до неправильних або змішування теперішнього й минулого часів в одному реченні.',
      offlineMistakesEn:
          'Common mistake: applying regular endings to irregular verbs or slipping back into present tense mid-story.',
      offlineTipUk: 'Маркери минулого: вчора, минулого тижня, два дні тому.',
      offlineTipEn: 'Past time markers: yesterday, last week, two days ago.',
    ),
    CurriculumModuleNode(
      id: 'a2_m2',
      cefr: CefrLevel.a2,
      stepNumber: 2,
      titleUk: 'Майбутній час: плани, наміри та прогнози',
      titleEn: 'Future Tense: Plans, Intentions & Predictions',
      subtitleUk: 'Заплановані події vs спонтанні рішення та обіцянки',
      subtitleEn: 'Scheduled plans vs spontaneous decisions and future predictions',
      aiTopicPrompt:
          'Expressing the future: future tense forms, planned intentions ("going to" / present for arrangements), and spontaneous promises or predictions.',
      offlineRuleUk:
          'Для вираження майбутнього мови часто розрізняють заздалегідь сплановані наміри та спонтанні рішення або прогнози. Поєднуйте конструкції майбутнього з точними часовими орієнтирами.',
      offlineRuleEn:
          'Many languages distinguish between pre-decided plans and spontaneous future decisions or predictions. Pair future forms with clear time references.',
      offlineMistakesUk:
          'Типова помилка — використання теперішнього часу без часового маркера або неправильний вибір допоміжного дієслова майбутнього.',
      offlineMistakesEn:
          'Common mistake: dropping the future auxiliary or using present tense without a clear future time marker.',
      offlineTipUk: 'Чітко розмежовуйте: «Я вже запланував» vs «Я щойно вирішив / думаю, що...».',
      offlineTipEn: 'Distinguish planned intentions from spontaneous predictions.',
    ),
    CurriculumModuleNode(
      id: 'a2_m3',
      cefr: CefrLevel.a2,
      stepNumber: 3,
      titleUk: 'Ступені порівняння прикметників та прислівників',
      titleEn: 'Comparatives, Superlatives & Expressing Preferences',
      subtitleUk: 'Як порівнювати речі, міста, сервіси та оцінювати вибір',
      subtitleEn: 'Comparing options, places, prices, and expressing preferences',
      aiTopicPrompt:
          'Comparative and superlative adjectives and adverbs, equality comparisons ("as ... as"), and key irregular comparatives (good/better/best, bad/worse/worst).',
      offlineRuleUk:
          'Ступені порівняння допомагають зіставляти два об’єкти (вищий ступінь: «швидший за...») або виділяти один серед усіх (найвищий ступінь: «найкращий»). Окремо вивчіть винятки для «добрий» і «поганий».',
      offlineRuleEn:
          'Comparatives contrast two items ("faster than...") while superlatives single out the top extreme ("the best"). Memorize irregular pairs like good/better/best.',
      offlineMistakesUk:
          'Типова помилка — подвійне порівняння («більш кращий») або плутанина у сполучнику «ніж / за».',
      offlineMistakesEn:
          'Common mistake: double comparatives (e.g. "more better") or choosing the wrong comparison conjunction.',
      offlineTipUk: 'Вивчіть 3 шаблони: [більш ... ніж], [най...], [такий самий ..., як].',
      offlineTipEn: 'Master 3 patterns: [more ... than], [the most ...], [as ... as].',
    ),
    CurriculumModuleNode(
      id: 'a2_m4',
      cefr: CefrLevel.a2,
      stepNumber: 4,
      titleUk: 'Зворотні дієслова та опис самопочуття і рутини',
      titleEn: 'Reflexive Verbs, Health & Personal Routine',
      subtitleUk: 'Дії, спрямовані на себе, візит до лікаря та емоції',
      subtitleEn: 'Self-directed actions, daily self-care, feelings, and health',
      aiTopicPrompt:
          'Reflexive verbs/pronouns (or self-directed constructions), talking about morning routines, physical well-being, symptoms, and emotions.',
      offlineRuleUk:
          'Зворотні конструкції вказують, що дія спрямована на самого виконавця (вмиватися, готуватися, почуватися). Слідкуйте за місцем зворотної частки чи займенника в реченні.',
      offlineRuleEn:
          'Reflexive constructions show that the subject performs the action on themselves (wash oneself, feel, get ready). Pay attention to where the reflexive pronoun sits in the clause.',
      offlineMistakesUk:
          'Типова помилка — перенесення зворотних дієслів із рідної мови: дієслово, зворотне в українській, може не бути зворотним у мові вивчення (і навпаки).',
      offlineMistakesEn:
          'Common mistake: assuming a verb is reflexive just because its translation is reflexive in your native language.',
      offlineTipUk: 'Запам’ятовуйте топ-10 зворотних фраз для ранку та самопочуття як готові блоки.',
      offlineTipEn: 'Memorize everyday routine and health expressions as complete phrases.',
    ),
    CurriculumModuleNode(
      id: 'a2_m5',
      cefr: CefrLevel.a2,
      stepNumber: 5,
      titleUk: 'Модальні дієслова обов’язку, поради та дозволу',
      titleEn: 'Modals of Obligation, Advice & Permission',
      subtitleUk: 'Різниця між «повинен», «варто», «можна» та «заборонено»',
      subtitleEn: 'Distinguishing obligation, friendly advice, permission, and prohibition',
      aiTopicPrompt:
          'Modal verbs for obligation ("must / have to"), advice ("should"), permission ("may / can"), and prohibition ("must not / not allowed").',
      offlineRuleUk:
          'На рівні A2 важливо точно розрізняти м’яку пораду («тобі варто»), суворий обов’язок («ти мусиш») та відсутність необхідності («не обов’язково» vs «заборонено»).',
      offlineRuleEn:
          'Distinguish clearly between soft advice ("should"), strong obligation ("must/have to"), lack of necessity ("don\'t have to"), and strict prohibition ("must not").',
      offlineMistakesUk:
          'Типова помилка — плутанина між «не треба (необов’язково)» та «суворо заборонено».',
      offlineMistakesEn:
          'Common mistake: confusing "not necessary" with "strictly prohibited".',
      offlineTipUk: 'Порада = м’яко (should); Правило = суворо (must); Немає потреби ≠ Заборона.',
      offlineTipEn: 'Advice = soft; Rule = strong; No obligation ≠ Prohibition.',
    ),
    CurriculumModuleNode(
      id: 'a2_m6',
      cefr: CefrLevel.a2,
      stepNumber: 6,
      titleUk: 'Сполучники причини, наслідку та протиставлення',
      titleEn: 'Connectors of Cause, Contrast & Sequence',
      subtitleUk: 'Поєднання думок за допомогою «тому що», «але», «хоча», «отже»',
      subtitleEn: 'Linking ideas smoothly using because, but, although, and so',
      aiTopicPrompt:
          'Coordinating and basic subordinating conjunctions: cause (because), result (so/therefore), contrast (but/although), and sequence (first, then, finally).',
      offlineRuleUk:
          'Сполучники перетворюють окремі короткі фрази на зв’язну мову. Перевірте, чи змінюють підрядні сполучники порядок слів у другій частині речення у вашій мові вивчення.',
      offlineRuleEn:
          'Conjunctions turn choppy sentences into natural speech. Check whether subordinating conjunctions affect word order or verb position in your target language.',
      offlineMistakesUk:
          'Типова помилка — одночасне використання «хоча» та «але» в одному реченні.',
      offlineMistakesEn:
          'Common mistake: combining both "although" and "but" inside the same sentence.',
      offlineTipUk: 'Використовуйте ланцюжок: [Теза] + [тому що / але / тому] + [Аргумент].',
      offlineTipEn: 'Build linked thoughts: [Point] + [because / but / so] + [Reason].',
    ),
    CurriculumModuleNode(
      id: 'a2_m7',
      cefr: CefrLevel.a2,
      stepNumber: 7,
      titleUk: 'Подорожі, готель та вирішення побутових ситуацій',
      titleEn: 'Travel, Hotels & Solving Everyday Situations',
      subtitleUk: 'Бронювання, аеропорт, скарги та прохання про допомогу',
      subtitleEn: 'Bookings, check-in, asking for help, and handling minor issues',
      aiTopicPrompt:
          'Practical A2 travel and service dialogues: hotel check-in, transport delays, asking for clarification, and polite problem-solving.',
      offlineRuleUk:
          'У ситуаціях подорожі поєднуйте ввічливе звертання, чіткий опис проблеми в теперішньому або минулому часі та прохання про рішення.',
      offlineRuleEn:
          'In travel situations, combine a polite opening, a clear description of the issue, and a specific request for assistance.',
      offlineMistakesUk:
          'Типова помилка — надто довгі або непрямі фрази замість чіткої структури «Проблема + Прохання».',
      offlineMistakesEn:
          'Common mistake: vague phrasing instead of a polite, specific statement of the problem and request.',
      offlineTipUk: 'Шаблон: [Вибачте] + [що сталося] + [чи могли б ви допомогти з...].',
      offlineTipEn: 'Template: [Excuse me] + [what happened] + [could you help with...].',
    ),

    // ================= B1 (7 modules) =================
    CurriculumModuleNode(
      id: 'b1_m1',
      cefr: CefrLevel.b1,
      stepNumber: 1,
      titleUk: 'Досвід і результат vs завершений минулий час',
      titleEn: 'Life Experience & Present Results vs Finished Past',
      subtitleUk: 'Як виражати зв’язок минулої дії із теперішнім моментом',
      subtitleEn: 'Expressing ongoing relevance, life experience, and completed events',
      aiTopicPrompt:
          'Contrasting past actions with present relevance/experience (Present Perfect / perfective aspect) versus finished past events at a specific time.',
      offlineRuleUk:
          'На рівні B1 ключовим є розрізнення результату/досвіду, важливого зараз («я вже бачив це»), та завершеного факту в конкретний момент минулого («я бачив це вчора»).',
      offlineRuleEn:
          'At B1, distinguish between experience or results relevant right now versus completed actions tied to a specific past time.',
      offlineMistakesUk:
          'Типова помилка — поєднання форми досвіду/результату з маркерами завершеного часу («вчора», «у 2020 році»).',
      offlineMistakesEn:
          'Common mistake: pairing present-relevance forms with finished past time markers like "yesterday".',
      offlineTipUk: 'Важливий результат зараз = форма досвіду; Є точна дата = простий минулий.',
      offlineTipEn: 'Result now = experience/perfect form; Exact past date = simple past.',
    ),
    CurriculumModuleNode(
      id: 'b1_m2',
      cefr: CefrLevel.b1,
      stepNumber: 2,
      titleUk: 'Складні речення з відносними займенниками',
      titleEn: 'Complex Sentences & Relative Clauses',
      subtitleUk: 'Уточнення людей, предметів і місць («який», «де», «чий»)',
      subtitleEn: 'Defining people, objects, and places using relative pronouns',
      aiTopicPrompt:
          'Relative clauses (who, which, that, where, whose), connecting two clauses smoothly without repeating nouns, and punctuation rules.',
      offlineRuleUk:
          'Відносні підрядні речення дозволяють точно описати людину, предмет чи місце всередині одного складного речення без повторення іменника.',
      offlineRuleEn:
          'Relative clauses let you define a person, object, or place smoothly inside one sentence without repeating the noun.',
      offlineMistakesUk:
          'Типова помилка — дублювання займенника у підрядній частині («книга, яку я її читав»).',
      offlineMistakesEn:
          'Common mistake: repeating the object pronoun inside the relative clause.',
      offlineTipUk: 'Поєднуйте два коротких факти в один за допомогою відносного слова.',
      offlineTipEn: 'Merge two short sentences by replacing the repeated noun with a relative word.',
    ),
    CurriculumModuleNode(
      id: 'b1_m3',
      cefr: CefrLevel.b1,
      stepNumber: 3,
      titleUk: 'Умовні речення: реальні плани та уявні сценарії',
      titleEn: 'Conditionals: Real Outcomes & Hypothetical Scenarios',
      subtitleUk: 'Конструкції «Якщо..., то...» та «Якби..., я б...»',
      subtitleEn: 'First and second conditionals for real plans and imaginary situations',
      aiTopicPrompt:
          'Real future conditionals (First Conditional) and hypothetical present/future conditionals (Second Conditional / subjunctive/conditional mood).',
      offlineRuleUk:
          'Умовні речення поділяються на реальні умови (висока ймовірність у майбутньому) та гіпотетичні («якби я мав більше часу, я б...»). Уважно узгоджуйте час або спосіб дієслова в обох частинах.',
      offlineRuleEn:
          'Separate real likely conditions from hypothetical "if I had..., I would..." scenarios, keeping verb moods and tenses consistent across both clauses.',
      offlineMistakesUk:
          'Типова помилка — використання умовного способу або майбутнього часу не в тій частині речення.',
      offlineMistakesEn:
          'Common mistake: mixing real and hypothetical verb forms across the condition and result clauses.',
      offlineTipUk: 'Реальна умова → реальний наслідок; Уявна умова → умовний спосіб.',
      offlineTipEn: 'Real condition → likely outcome; Imaginary condition → conditional mood.',
    ),
    CurriculumModuleNode(
      id: 'b1_m4',
      cefr: CefrLevel.b1,
      stepNumber: 4,
      titleUk: 'Пасивний стан у новинах та інструкціях',
      titleEn: 'Passive Voice in News, Processes & Instructions',
      subtitleUk: 'Коли фокус на дії чи об’єкті, а не на виконавці',
      subtitleEn: 'Focusing on the action or result rather than who performed it',
      aiTopicPrompt:
          'Forming and using the passive voice across present, past, and future tenses in everyday news, signs, and process descriptions.',
      offlineRuleUk:
          'Пасивний стан переносить акцент із виконавця на сам результат або процес («Цей міст побудували у 1995 році»). Він незамінний у новинах, правилах та описах процесів.',
      offlineRuleEn:
          'The passive voice shifts focus from the doer to the action or object itself. It is essential in news, instructions, and process descriptions.',
      offlineMistakesUk:
          'Типова помилка — пропуск допоміжного дієслова або неправильна форма дієприкметника.',
      offlineMistakesEn:
          'Common mistake: omitting the auxiliary verb or using the wrong participle form.',
      offlineTipUk: 'Пасив відповідає на питання «Що зроблено / робиться з об’єктом?».',
      offlineTipEn: 'Use passive when the receiver of the action matters more than the actor.',
    ),
    CurriculumModuleNode(
      id: 'b1_m5',
      cefr: CefrLevel.b1,
      stepNumber: 5,
      titleUk: 'Непряма мова: переказ слів, питань і прохань',
      titleEn: 'Reported Speech: Statements, Questions & Requests',
      subtitleUk: 'Як переказувати почуте, змінюючи займенники та часи',
      subtitleEn: 'Reporting what someone said, asked, or requested accurately',
      aiTopicPrompt:
          'Indirect/reported speech for statements, yes/no questions, wh-questions, and requests, including pronoun and tense/time-marker shifts.',
      offlineRuleUk:
          'Переказуючи чиїсь слова, змінюйте займенники відповідно до контексту, прибирайте питальний порядок слів у непрямих питаннях та за потреби узгоджуйте часи.',
      offlineRuleEn:
          'When reporting speech, adjust pronouns and time references to your viewpoint and use statement word order in indirect questions.',
      offlineMistakesUk:
          'Типова помилка — збереження прямого питального порядку слів усередині непрямого питання.',
      offlineMistakesEn:
          'Common mistake: keeping direct-question word order inside an indirect question.',
      offlineTipUk: 'У непрямому питанні порядок слів такий самий, як у звичайному ствердженні.',
      offlineTipEn: 'Indirect questions follow normal statement word order.',
    ),
    CurriculumModuleNode(
      id: 'b1_m6',
      cefr: CefrLevel.b1,
      stepNumber: 6,
      titleUk: 'Дієслівне керування: інфінітив vs герундій / віддієслівні форми',
      titleEn: 'Verb Patterns: Infinitive vs Gerund / Verbal Nouns',
      subtitleUk: 'Яку форму обрати після дієслів бажання, звички чи закінчення дії',
      subtitleEn: 'Choosing the right verb complement after key everyday verbs',
      aiTopicPrompt:
          'Verb complement patterns (infinitive vs gerund/participle/subordinate clause depending on the target language) after verbs of preference, planning, stopping, and prepositions.',
      offlineRuleUk:
          'Одні дієслова вимагають після себе інфінітива (вирішити зробити), інші — герундія або підрядного речення. Деякі дієслова навіть змінюють значення залежно від наступної форми.',
      offlineRuleEn:
          'Certain verbs require an infinitive while others take a gerund, verbal noun, or clause. A few key verbs even change meaning depending on the pattern.',
      offlineMistakesUk:
          'Типова помилка — вибір форми за аналогією з рідною мовою без перевірки керування дієслова.',
      offlineMistakesEn:
          'Common mistake: guessing the verb pattern based on native-language translation.',
      offlineTipUk: 'Вчіть дієслово разом із його типовим продовженням (наприклад, «уникати + дія»).',
      offlineTipEn: 'Learn each verb together with its required complement structure.',
    ),
    CurriculumModuleNode(
      id: 'b1_m7',
      cefr: CefrLevel.b1,
      stepNumber: 7,
      titleUk: 'Аргументація власної думки та робочі діалоги',
      titleEn: 'Expressing Opinions, Agreement & Workplace Dialogues',
      subtitleUk: 'Структурування думки, ввічлива незгода та підбиття підсумків',
      subtitleEn: 'Giving balanced opinions, polite disagreement, and workplace communication',
      aiTopicPrompt:
          'B1 functional language for discussions and work: giving opinions, agreeing/disagreeing politely, weighing pros and cons, and summarizing.',
      offlineRuleUk:
          'Переконлива відповідь на рівні B1 складається з трьох кроків: позиція («На мою думку...»), аргумент («По-перше...») та приклад із власного досвіду.',
      offlineRuleEn:
          'A persuasive B1 response follows three steps: state your viewpoint, give a clear reason, and support it with a concrete example.',
      offlineMistakesUk:
          'Типова помилка — надто різке «Ти не правий» замість дипломатичної незгоди.',
      offlineMistakesEn:
          'Common mistake: sounding overly blunt when disagreeing instead of using diplomatic softeners.',
      offlineTipUk: 'Каркас дискусії: Позиція → Причина → Конкретний приклад.',
      offlineTipEn: 'Discussion frame: Viewpoint → Reason → Concrete example.',
    ),

    // ================= B2 (7 modules) =================
    CurriculumModuleNode(
      id: 'b2_m1',
      cefr: CefrLevel.b2,
      stepNumber: 1,
      titleUk: 'Узгодження часів та багатошарова розповідь про минуле',
      titleEn: 'Narrative Tenses & Past-Before-Past Precision',
      subtitleUk: 'Хронологія подій, передісторія та фонові процеси',
      subtitleEn: 'Sequencing background context, completed events, and earlier past actions',
      aiTopicPrompt:
          'Combining narrative past tenses (past simple, past continuous/imperfect, past perfect/pluperfect) to show clear chronology in stories and reports.',
      offlineRuleUk:
          'Для точного опису подій у минулому поєднуйте три шари: основна лінія подій, тривалий фон та дія, що відбулася ще раніше (передминулий час).',
      offlineRuleEn:
          'Layer past narratives clearly using three planes: main completed events, ongoing background actions, and earlier events that happened beforehand.',
      offlineMistakesUk:
          'Типова помилка — надмірне використання передминулого часу там, де порядок подій і так очевидний.',
      offlineMistakesEn:
          'Common mistake: overusing past-perfect forms when simple chronological order is already clear.',
      offlineTipUk: 'Використовуйте передминулий час саме тоді, коли повертаєтеся назад у часі.',
      offlineTipEn: 'Reach for past-before-past forms specifically when jumping backward in time.',
    ),
    CurriculumModuleNode(
      id: 'b2_m2',
      cefr: CefrLevel.b2,
      stepNumber: 2,
      titleUk: 'Модальні припущення про теперішнє й минуле',
      titleEn: 'Modal Deduction: Certainty, Possibility & Regret',
      subtitleUk: 'Логічні висновки («напевно», «не може бути», «варто було»)',
      subtitleEn: 'Expressing logical certainty, speculation, and past regrets',
      aiTopicPrompt:
          'Modals of deduction and speculation in present and past (must have, might have, can\'t have, should have) to evaluate evidence and express regret.',
      offlineRuleUk:
          'Модальні конструкції оцінки дозволяють показати ступінь упевненості мовця: від майже 100% впевненості («мабуть, це сталося») до сумніву чи жалю про минуле рішення («варто було перевірити»).',
      offlineRuleEn:
          'Speculative modal structures signal how certain you are based on evidence—from strong logical deduction to possibility or past regret.',
      offlineMistakesUk:
          'Типова помилка — використання форми «must not» для логічного заперечення замість «can\'t / cannot be».',
      offlineMistakesEn:
          'Common mistake: using prohibition forms instead of impossibility forms for negative deduction.',
      offlineTipUk: 'Оцінюйте силу доказу: 95% (must) • 50% (might/could) • 0% (can\'t).',
      offlineTipEn: 'Match certainty to evidence: ~95% certainty, ~50% possibility, ~0% impossibility.',
    ),
    CurriculumModuleNode(
      id: 'b2_m3',
      cefr: CefrLevel.b2,
      stepNumber: 3,
      titleUk: 'Складні й змішані умовні речення та конструкції жалю',
      titleEn: 'Third & Mixed Conditionals and Expressing Wishes',
      subtitleUk: 'Альтернативне минуле та його вплив на сьогодення',
      subtitleEn: 'Unfulfilled past scenarios, mixed time frames, and wish/regret clauses',
      aiTopicPrompt:
          'Third conditional (unreal past), mixed conditionals (past condition affecting present result), and wish / if-only constructions.',
      offlineRuleUk:
          'Умовні речення вищого рівня описують альтернативне минуле («Якби ми виїхали раніше, ми б не запізнилися») або пов’язують минуле рішення з теперішнім наслідком (змішаний тип).',
      offlineRuleEn:
          'Advanced conditionals explore alternate past outcomes or link a past decision directly to a present consequence (mixed conditionals).',
      offlineMistakesUk:
          'Типова помилка — змішування часу причини та часу наслідку без урахування часових маркерів («зараз» vs «тоді»).',
      offlineMistakesEn:
          'Common mistake: losing track of whether the result refers to "then" or "right now".',
      offlineTipUk: 'Перевіряйте два часових якорі: Коли була умова? Коли є результат?',
      offlineTipEn: 'Check both time anchors: When was the condition? When is the result?',
    ),
    CurriculumModuleNode(
      id: 'b2_m4',
      cefr: CefrLevel.b2,
      stepNumber: 4,
      titleUk: 'Безособовий пасив та академічна об’єктивність',
      titleEn: 'Impersonal Passive & Formal Reporting Structures',
      subtitleUk: '«Вважається, що...», «Очікується, що...» у статтях та звітах',
      subtitleEn: 'Distancing statements like "It is believed that..." in articles and reports',
      aiTopicPrompt:
          'Impersonal passive and reporting structures ("It is reported that...", "is expected to..."), causative structures ("have something done"), and formal register.',
      offlineRuleUk:
          'В аналітичних текстах і журналістиці часто уникають прямого «Я думаю» на користь об’єктивних безособових конструкцій («Зазначається, що...», «Очікується, що...»).',
      offlineRuleEn:
          'Analytical articles and journalism favor objective distancing patterns ("It is widely believed that...", "is projected to...") over personal claims.',
      offlineMistakesUk:
          'Типова помилка — порушення зв’язку між безособовим вступом та наступною формою дієслова.',
      offlineMistakesEn:
          'Common mistake: breaking agreement between the reporting passive and the infinitive/clause that follows.',
      offlineTipUk: 'Використовуйте безособовий пасив для нейтральної подачі фактів і досліджень.',
      offlineTipEn: 'Use impersonal reporting to present data and trends neutrally.',
    ),
    CurriculumModuleNode(
      id: 'b2_m5',
      cefr: CefrLevel.b2,
      stepNumber: 5,
      titleUk: 'Складні сполучники, поступка та дискурсивні маркери',
      titleEn: 'Advanced Linkers, Concession & Discourse Markers',
      subtitleUk: 'Різниця між «незважаючи на», «хоча», «проте», «водночас»',
      subtitleEn: 'Contrast, concession (despite vs although), and structured flow',
      aiTopicPrompt:
          'Advanced discourse markers and concession structures (despite/in spite of + noun vs although/even though + clause; however, nevertheless, whereas).',
      offlineRuleUk:
          'Звертайте увагу на синтаксис сполучників поступки: одні вимагають після себе іменника або іменної групи («незважаючи на дощ»), а інші — повного речення з підметом і присудком («хоча йшов дощ»).',
      offlineRuleEn:
          'Pay close attention to concession syntax: some linkers take a noun phrase ("despite the rain"), while others require a full subject + verb clause ("although it rained").',
      offlineMistakesUk:
          'Типова помилка — вживання повного речення після прийменникового сполучника («despite it rained»).',
      offlineMistakesEn:
          'Common mistake: putting a full clause directly after a prepositional linker.',
      offlineTipUk: 'Прийменник (despite) + іменник/фраза • Сполучник (although) + підмет і дієслово.',
      offlineTipEn: 'Preposition linker + noun phrase • Conjunction linker + full clause.',
    ),
    CurriculumModuleNode(
      id: 'b2_m6',
      cefr: CefrLevel.b2,
      stepNumber: 6,
      titleUk: 'Фразові дієслова, сталі колокації та точність лексики',
      titleEn: 'Multi-Word Verbs, Collocations & Lexical Precision',
      subtitleUk: 'Природні словосполучення замість дослівного перекладу',
      subtitleEn: 'Natural verb-noun collocations and idiomatic multi-word verbs',
      aiTopicPrompt:
          'High-frequency B2 collocations, multi-word/phrasal verbs or prefixed verbs typical of the target language, and avoiding false friends.',
      offlineRuleUk:
          'На рівні B2 природність мовлення визначається колокаціями — тим, які дієслова та прикметники традиційно поєднуються з конкретними іменниками саме в цій мові.',
      offlineRuleEn:
          'At B2, fluency depends heavily on natural collocations—the exact verb-noun and adverb-adjective pairings native speakers expect.',
      offlineMistakesUk:
          'Типова помилка — підстановка «універсальних» дієслів (робити/брати) замість точних колокацій.',
      offlineMistakesEn:
          'Common mistake: overusing generic verbs instead of precise collocations.',
      offlineTipUk: 'Записуйте в словник не лише окреме слово, а готову зв’язку «дієслово + іменник».',
      offlineTipEn: 'Store verb + noun partnerships rather than isolated words.',
    ),
    CurriculumModuleNode(
      id: 'b2_m7',
      cefr: CefrLevel.b2,
      stepNumber: 7,
      titleUk: 'Дебати, переговори та ділова переписка',
      titleEn: 'Negotiations, Debates & Professional Correspondence',
      subtitleUk: 'Офіційний vs напівофіційний регістр, контраргументи та компроміси',
      subtitleEn: 'Formal vs semi-formal tone, counterarguments, and proposing compromises',
      aiTopicPrompt:
          'B2 negotiation and professional writing structures: polite hedging, acknowledging counterarguments, proposing alternatives, and formal email conventions.',
      offlineRuleUk:
          'У діловому спілкуванні та дебатах спочатку визнайте аргумент опонента, а потім м’яко введіть контраргумент і запропонуйте конструктивну альтернативу.',
      offlineRuleEn:
          'In negotiations and formal writing, acknowledge the other perspective first, then introduce a measured counterpoint and concrete alternative.',
      offlineMistakesUk:
          'Типова помилка — змішування розмовного сленгу з офіційними кліше в одному листі.',
      offlineMistakesEn:
          'Common mistake: mixing casual slang and formal register in the same message.',
      offlineTipUk: 'Дипломатичний міст: «Я розумію вашу точку зору, однак варто врахувати...».',
      offlineTipEn: 'Diplomatic bridge: "I see your point; however, we should also consider...".',
    ),

    // ================= C1 (7 modules) =================
    CurriculumModuleNode(
      id: 'c1_m1',
      cefr: CefrLevel.c1,
      stepNumber: 1,
      titleUk: 'Стилістична інверсія та емфатичні конструкції',
      titleEn: 'Stylistic Inversion & Cleft Sentences for Emphasis',
      subtitleUk: 'Риторичне підсилення думки в есе, статтях і виступах',
      subtitleEn: 'Fronting negative adverbials and cleft structures for rhetorical impact',
      aiTopicPrompt:
          'Stylistic inversion after negative/restrictive adverbials, cleft sentences, and fronting techniques used for emphasis in C1 writing and speeches.',
      offlineRuleUk:
          'Винесення емоційно або логічно важливого елемента на початок речення (емфаза та інверсія) робить аргументацію в есе й виступах переконливішою та виразнішою.',
      offlineRuleEn:
          'Fronting key elements, using cleft structures, or applying stylistic inversion highlights crucial information in formal essays and speeches.',
      offlineMistakesUk:
          'Типова помилка — зловживання інверсією в побутовій розмові або пропуск зміни порядку слів після обмеження на початку.',
      offlineMistakesEn:
          'Common mistake: forgetting the required verb-subject adjustment or overusing inversion in casual chat.',
      offlineTipUk: 'Використовуйте інверсію дозовано — 1–2 рази на ключових тезах тексту.',
      offlineTipEn: 'Reserve stylistic inversion for high-impact key points.',
    ),
    CurriculumModuleNode(
      id: 'c1_m2',
      cefr: CefrLevel.c1,
      stepNumber: 2,
      titleUk: 'Дієприкметникові звороти та синтаксична стислість',
      titleEn: 'Participle Clauses & Syntactic Conciseness',
      subtitleUk: 'Скорочення громіздких підрядних речень без втрати змісту',
      subtitleEn: 'Compressing wordy subordinate clauses into sleek participle structures',
      aiTopicPrompt:
          'Present, past, and perfect participle clauses (or equivalent adverbial participles in the target language) for concise cause, time, and result expressions.',
      offlineRuleUk:
          'Дієприкметникові та дієприслівникові звороти дозволяють об’єднати причину, час і наслідок в одне елегантне речення. Підмет звороту обов’язково має збігатися з підметом головної частини.',
      offlineRuleEn:
          'Participle clauses condense time, cause, and condition into crisp sentences. Always ensure the implied subject of the participle matches the main clause subject.',
      offlineMistakesUk:
          'Типова помилка — «висячий» зворот, коли дія у звороті логічно не належить підмету головного речення.',
      offlineMistakesEn:
          'Common mistake: dangling participles where the main subject could not logically perform the participle action.',
      offlineTipUk: 'Тест на коректність: чи справді підмет головної частини виконує дію звороту?',
      offlineTipEn: 'Sanity check: does the main clause subject actually perform the participle action?',
    ),
    CurriculumModuleNode(
      id: 'c1_m3',
      cefr: CefrLevel.c1,
      stepNumber: 3,
      titleUk: 'Номіналізація та академічний стиль письма',
      titleEn: 'Nominalization & Academic Cohesion',
      subtitleUk: 'Перетворення дій на поняття для щільного аналітичного тексту',
      subtitleEn: 'Transforming verb phrases into abstract noun phrases for formal writing',
      aiTopicPrompt:
          'Nominalization, cohesive reference chains, formal lexical substitution, and maintaining impersonal academic flow in C1 essays and reports.',
      offlineRuleUk:
          'Номіналізація (заміна дієслівних фраз на іменникові поняття: «швидко зростає» → «стрімке зростання») підвищує щільність та офіційність академічних і бізнес-текстів.',
      offlineRuleEn:
          'Nominalization turns action clauses into compact noun concepts, elevating formality and cohesion in analytical reports and essays.',
      offlineMistakesUk:
          'Типова помилка — надмірне нагромадження абстрактних іменників, через яке текст стає важким для читання.',
      offlineMistakesEn:
          'Common mistake: stacking too many abstract nouns so the sentence loses clarity.',
      offlineTipUk: 'Чергуйте номіналізовані тези з чіткими активними дієсловами.',
      offlineTipEn: 'Balance nominalized concepts with strong, concrete main verbs.',
    ),
    CurriculumModuleNode(
      id: 'c1_m4',
      cefr: CefrLevel.c1,
      stepNumber: 4,
      titleUk: 'Тонкі відтінки умови, гіпотез та умовного способу',
      titleEn: 'Advanced Conditionals, Subjunctive & Alternatives to "If"',
      subtitleUk: 'Конструкції «за умови, що», «якби не», формальний Subjunctive',
      subtitleEn: 'Provided that, unless, inverted conditionals, and formal subjunctive',
      aiTopicPrompt:
          'Alternatives to "if" (provided that, on condition that, supposing, but for), inverted conditionals, and formal subjunctive/optative structures.',
      offlineRuleUk:
          'На рівні C1 замість одноманітного «якщо» використовують точніші маркери умови («за умови, що», «якби не», «на випадок, якщо») та формальний умовний спосіб у рекомендаціях і вимогах.',
      offlineRuleEn:
          'Replace repetitive "if" clauses with nuanced conditional markers ("provided that", "but for", "in the event that") and formal subjunctive patterns.',
      offlineMistakesUk:
          'Типова помилка — неточне узгодження способу дієслова після дієслів вимоги або рекомендації.',
      offlineMistakesEn:
          'Common mistake: slipping into indicative forms where formal subjunctive is expected.',
      offlineTipUk: 'Обирайте сполучник умови за відтінком: обмеження, виняток чи запобіжний захід.',
      offlineTipEn: 'Pick the conditional linker that matches the exact nuance: restriction, exception, or precaution.',
    ),
    CurriculumModuleNode(
      id: 'c1_m5',
      cefr: CefrLevel.c1,
      stepNumber: 5,
      titleUk: 'Еліпсис, заміщення та природна зв’язність мовлення',
      titleEn: 'Ellipsis, Substitution & Natural Text Economy',
      subtitleUk: 'Як уникати повторів слів так, як це роблять носії мови',
      subtitleEn: 'Avoiding awkward repetition using ellipsis and pro-forms naturally',
      aiTopicPrompt:
          'Ellipsis (omitting recoverable words) and substitution (so, not, one/ones, do so, demonstratives) to create smooth, native-like C1 cohesion.',
      offlineRuleUk:
          'Носії мови рідко повторюють однакові слова в сусідніх реченнях — вони опускають очевидні елементи (еліпсис) або замінюють їх короткими словами-заступниками.',
      offlineRuleEn:
          'Native speakers avoid repeating identical phrases by omitting predictable elements (ellipsis) or replacing them with concise substitutes.',
      offlineMistakesUk:
          'Типова помилка — пропуск слова, яке неможливо однозначно відновити з контексту.',
      offlineMistakesEn:
          'Common mistake: omitting an element that creates ambiguity for the reader.',
      offlineTipUk: 'Скорочуйте повтор лише тоді, коли зміст залишається на 100% прозорим.',
      offlineTipEn: 'Only omit repeated words when the meaning stays 100% unambiguous.',
    ),
    CurriculumModuleNode(
      id: 'c1_m6',
      cefr: CefrLevel.c1,
      stepNumber: 6,
      titleUk: 'Ідіоми, метафори та зміна регістру (формальний vs живий)',
      titleEn: 'Idiomatic Precision, Metaphors & Register Shifting',
      subtitleUk: 'Відчуття доречності, підтексту та відтінків значень синонімів',
      subtitleEn: 'Choosing between formal, neutral, and idiomatic equivalents accurately',
      aiTopicPrompt:
          'C1 idioms, figurative expressions, near-synonyms with distinct connotations, and shifting smoothly between formal and colloquial registers.',
      offlineRuleUk:
          'Слова-синоніми майже ніколи не є повністю взаємозамінними: вони відрізняються конотацією (позитивною, нейтральною чи критичною) та сферою вживання.',
      offlineRuleEn:
          'Near-synonyms rarely mean the exact same thing—they differ in emotional connotation, intensity, and formality level.',
      offlineMistakesUk:
          'Типова помилка — вживання яскравої розмовної ідіоми в офіційному документі або навпаки.',
      offlineMistakesEn:
          'Common mistake: inserting colloquial idioms into formal documents or overly stiff phrasing into casual speech.',
      offlineTipUk: 'Перед вибором синоніма перевірте два критерії: тон (позитив/негатив) і ситуація.',
      offlineTipEn: 'Check every synonym on two axes: connotation and register.',
    ),
    CurriculumModuleNode(
      id: 'c1_m7',
      cefr: CefrLevel.c1,
      stepNumber: 7,
      titleUk: 'Критичний аналіз, презентації та захист позиції',
      titleEn: 'Critical Analysis, Presentations & Defending Arguments',
      subtitleUk: 'Логіка переконання, оцінка джерел та відповіді на складні питання',
      subtitleEn: 'Structuring high-level talks, evaluating claims, and handling Q&A',
      aiTopicPrompt:
          'C1 presentation and argumentation discourse: signposting, evaluating evidence critically, reframing tough questions, and synthesizing conclusions.',
      offlineRuleUk:
          'У виступах високого рівня використовуйте вербальні дороговкази (signposting), щоб вести слухача від проблеми до доказів, ризиків і фінального висновку.',
      offlineRuleEn:
          'In C1 presentations and debates, use clear signposting to guide listeners through claims, counter-evidence, caveats, and final takeaways.',
      offlineMistakesUk:
          'Типова помилка — емоційне відхилення від теми під час незручного запитання замість спокійного переформулювання.',
      offlineMistakesEn:
          'Common mistake: getting defensive during tough questions instead of reframing calmly.',
      offlineTipUk: 'Відповідь на складне питання: Визнати нюанс → Навести факт → Повернутися до тези.',
      offlineTipEn: 'Tough Q&A pattern: Acknowledge nuance → Cite evidence → Return to core thesis.',
    ),

    // ================= C2 (7 modules) =================
    CurriculumModuleNode(
      id: 'c2_m1',
      cefr: CefrLevel.c2,
      stepNumber: 1,
      titleUk: 'Академічне хеджування, дипломатичність і тонкі модальні відтінки',
      titleEn: 'Academic Hedging, Diplomacy & Subtle Modality',
      subtitleUk: 'Точне калібрування категоричності, іронії та припущень',
      subtitleEn: 'Calibrating certainty, tactful critique, and nuanced modal perfects',
      aiTopicPrompt:
          'C2 academic hedging, diplomatic understatement, nuanced modal perfects (needn\'t have vs didn\'t need to, might well have), and avoiding overstatement.',
      offlineRuleUk:
          'Рівень C2 вирізняється здатністю точно дозувати категоричність (хеджування): замість абсолютних тверджень використовуються вивірені формулювання («дані свідчать про ймовірність...», «можна припустити...»).',
      offlineRuleEn:
          'C2 mastery shines through calibrated hedging—expressing claims with scholarly precision rather than sweeping generalizations.',
      offlineMistakesUk:
          'Типова помилка — надмірна категоричність у науковому чи дипломатичному дискурсі або, навпаки, розмитість основної тези.',
      offlineMistakesEn:
          'Common mistake: either overstating claims dogmatically or hedging so heavily that the point disappears.',
      offlineTipUk: 'Хеджування посилює довіру до аргументу, показуючи інтелектуальну чесність.',
      offlineTipEn: 'Strategic hedging builds credibility by matching claim strength to evidence.',
    ),
    CurriculumModuleNode(
      id: 'c2_m2',
      cefr: CefrLevel.c2,
      stepNumber: 2,
      titleUk: 'Архітектура складних синтаксичних періодів та ритм фрази',
      titleEn: 'Complex Syntactic Architecture & Rhetorical Rhythm',
      subtitleUk: 'Паралелізм, градація, вставні конструкції та баланс довгих речень',
      subtitleEn: 'Parallelism, balanced clauses, parentheticals, and prose rhythm',
      aiTopicPrompt:
          'C2 advanced syntax: rhetorical parallelism, tricolon, parenthetical insertions, appositives, and managing long multi-clause sentences cleanly.',
      offlineRuleUk:
          'Довге речення рівня C2 залишається легким для сприйняття завдяки синтаксичному паралелізму (однакова граматична форма однорідних частин) та чіткій ієрархії головної й додаткової інформації.',
      offlineRuleEn:
          'Long C2 sentences stay effortless to read when anchored by grammatical parallelism and clean hierarchy between main claims and parentheticals.',
      offlineMistakesUk:
          'Типова помилка — порушення паралелізму всередині переліку (змішування іменників, інфінітивів та підрядних речень).',
      offlineMistakesEn:
          'Common mistake: breaking parallel structure across items in a balanced list.',
      offlineTipUk: 'Перевіряйте симетрію: якщо перелік почався з іменника — кожен елемент має бути іменником.',
      offlineTipEn: 'Keep symmetry intact: match grammatical forms across parallel elements.',
    ),
    CurriculumModuleNode(
      id: 'c2_m3',
      cefr: CefrLevel.c2,
      stepNumber: 3,
      titleUk: 'Тонкощі синонімії, конотацій та культурних алюзій',
      titleEn: 'Nuanced Synonymy, Connotation & Cultural Allusions',
      subtitleUk: 'Мікровідтінки значень, підтекст, метафорика та точний добір слів',
      subtitleEn: 'Distinguishing subtle lexical shades, subtext, and cultural references',
      aiTopicPrompt:
          'C2 lexical precision: subtle differences among near-synonyms, cultural idioms/allusions specific to the target language, and connotative shifts.',
      offlineRuleUk:
          'Вільне володіння мовою означає відчуття культурного контексту та прихованого підтексту слів: одне слово може описувати ту саму рису як чесноту («наполегливий»), а інше — як ваду («впертий»).',
      offlineRuleEn:
          'Near-native command means sensing cultural resonance and subtext—how one word frames a trait positively while its near-synonym frames it critically.',
      offlineMistakesUk:
          'Типова помилка — використання рідкісного «книжного» слова без урахування його реального емоційного забарвлення.',
      offlineMistakesEn:
          'Common mistake: choosing rare literary words without checking their actual tone or usage context.',
      offlineTipUk: 'Оцінюйте кожне слово рівня C2 за трьома вимірами: значення, емоція, колокація.',
      offlineTipEn: 'Evaluate every C2 lexical choice by meaning, emotional charge, and collocation.',
    ),
    CurriculumModuleNode(
      id: 'c2_m4',
      cefr: CefrLevel.c2,
      stepNumber: 4,
      titleUk: 'Прагматика, іронія, недомовленість та непрямі мовленнєві акти',
      titleEn: 'Pragmatics, Irony, Understatement & Implicature',
      subtitleUk: 'Читання «між рядків» і ввічливі форми непрямої критики',
      subtitleEn: 'Reading between the lines, polite understatement, and indirect speech acts',
      aiTopicPrompt:
          'Pragmatic competence at C2: understatement, irony, indirect criticism, face-saving politeness strategies, and implied meaning in the target culture.',
      offlineRuleUk:
          'У живому та дипломатичному спілкуванні буквальне значення фрази часто відрізняється від її справжнього наміру. Звертайте увагу на пом’якшувачі, інтонацію та контекстні натяки.',
      offlineRuleEn:
          'In high-context and diplomatic communication, literal meaning often diverges from speaker intent. Watch for understatement, softeners, and contextual cues.',
      offlineMistakesUk:
          'Типова помилка — буквальне сприйняття ввічливого натяку або іронічної недомовленості.',
      offlineMistakesEn:
          'Common mistake: interpreting polite understatement or subtle irony purely literally.',
      offlineTipUk: 'Запитуйте себе не лише «що сказано?», а «чому це сформульовано саме так?».',
      offlineTipEn: 'Ask not only "what was said?" but "why was it phrased this way?".',
    ),
    CurriculumModuleNode(
      id: 'c2_m5',
      cefr: CefrLevel.c2,
      stepNumber: 5,
      titleUk: 'Дискурс медіа, публіцистики та юридично-ділових текстів',
      titleEn: 'Media, Editorial & Legal-Executive Discourse',
      subtitleUk: 'Стислі заголовки, аналітичні колонки та точні формулювання угод',
      subtitleEn: 'Editorial rhetoric, compressed headlines, and precise contractual language',
      aiTopicPrompt:
          'C2 specialized discourse: editorial persuasion, compressed journalistic syntax, and high-precision legal/executive terminology and clauses.',
      offlineRuleUk:
          'Публіцистика й ділові документи мають власні конвенції: від гранично стислих заголовків до однозначних формулювань умов і відповідальності, де кожне слово має юридичну вагу.',
      offlineRuleEn:
          'Editorials and executive/legal texts follow specialized conventions—from ultra-compressed headlines to unambiguous clauses where every qualifier carries weight.',
      offlineMistakesUk:
          'Типова помилка — неточне тлумачення обмежувальних застережень («якщо інше не передбачено...»).',
      offlineMistakesEn:
          'Common mistake: overlooking qualifying clauses that narrow or reverse a general rule.',
      offlineTipUk: 'Завжди виділяйте в складних документах слова-обмежувачі та винятки.',
      offlineTipEn: 'Always flag qualifying phrases, exceptions, and scope limiters first.',
    ),
    CurriculumModuleNode(
      id: 'c2_m6',
      cefr: CefrLevel.c2,
      stepNumber: 6,
      titleUk: 'Редагування, перефразування та стилістична трансформація',
      titleEn: 'Editing, Paraphrasing & Stylistic Transformation',
      subtitleUk: 'Передача однієї ідеї в різних стилях без втрати нюансів',
      subtitleEn: 'Recasting complex ideas across registers with zero loss of nuance',
      aiTopicPrompt:
          'C2 paraphrasing and stylistic editing: converting dense academic prose to crisp executive summaries and vice versa while preserving exact nuance.',
      offlineRuleUk:
          'Справжнє майстерство перефразування полягає в зміні самої синтаксичної структури речення (актив ↔ пасив, причина ↔ наслідок, іменник ↔ дієслово), а не в механічній заміні слів синонімами.',
      offlineRuleEn:
          'True C2 paraphrasing restructures the underlying grammar (cause ↔ effect, noun ↔ verb, clause ↔ participle) rather than merely swapping individual words.',
      offlineMistakesUk:
          'Типова помилка — заміна слів за словником синонімів, що руйнує природні колокації.',
      offlineMistakesEn:
          'Common mistake: thesaurus-swapping individual words in ways that break natural collocations.',
      offlineTipUk: 'Спочатку зрозумійте суть без опори на оригінал, потім сформулюйте її по-новому.',
      offlineTipEn: 'Grasp the core logic away from the original wording, then rebuild cleanly.',
    ),
    CurriculumModuleNode(
      id: 'c2_m7',
      cefr: CefrLevel.c2,
      stepNumber: 7,
      titleUk: 'Синтез: вільна риторика, полеміка та публічний виступ',
      titleEn: 'Synthesis: Rhetoric, Polemics & Keynote Mastery',
      subtitleUk: 'Бездоганна логіка, переконливі образи та керування увагою аудиторії',
      subtitleEn: 'Commanding rhetoric, nuanced rebuttal, and memorable closing statements',
      aiTopicPrompt:
          'C2 rhetorical mastery: crafting persuasive speeches, nuanced rebuttals, rhetorical contrasts, and synthesizing multi-angle arguments fluently.',
      offlineRuleUk:
          'Фінальний рівень C2 поєднує точність граматики, багатство лексики й риторичну стратегію: контрасти, риторичні питання та сильні підсумкові формули закріплюють головну ідею в пам’яті слухача.',
      offlineRuleEn:
          'C2 rhetorical synthesis unites grammatical precision, rich lexis, and strategic pacing—using contrast, framing, and crisp conclusions to persuade naturally.',
      offlineMistakesUk:
          'Типова помилка — перевантаження виступу складною термінологією на шкоду ясності й живого контакту.',
      offlineMistakesEn:
          'Common mistake: prioritizing ornate complexity over clarity and genuine audience connection.',
      offlineTipUk: 'Найвищий пілотаж — пояснити складну ідею точно, елегантно й зрозуміло.',
      offlineTipEn: 'Peak mastery is expressing complex ideas with effortless clarity and elegance.',
    ),
  ];

  static List<CurriculumModuleNode> nodesForLevel(CefrLevel level) =>
      allNodes.where((n) => n.cefr == level).toList();

  /// Builds a rich, usable offline fallback lesson tailored to the selected
  /// target/native languages (incorporating user's saved vocabulary when present)
  /// so the user can study and pass the level even without network or API key.
  static GeneratedLevelContent buildOfflineFallback({
    required CurriculumModuleNode node,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    List<VocabWord> userVocab = const [],
  }) {
    final isUk = nativeLang.code == 'uk';
    final langLabel = isUk ? targetLang.nameUk : targetLang.englishName;
    final topicTitle = node.title(nativeLang.code);

    // Build 3-4 contextual examples (leveraging user's saved words for this language if available)
    final examples = <LevelExampleItem>[];
    for (final w in userVocab.take(4)) {
      final sentence = w.exampleSentence.trim().isNotEmpty
          ? w.exampleSentence.trim()
          : (w.contextSentence.trim().isNotEmpty
              ? w.contextSentence.trim()
              : w.word.trim());
      if (sentence.isNotEmpty && w.translation.trim().isNotEmpty) {
        examples.add(
          LevelExampleItem(
            target: sentence,
            native: '${w.word} — ${w.translation}',
          ),
        );
      }
    }

    if (examples.length < 3) {
      examples.addAll([
        LevelExampleItem(
          target: isUk
              ? '[Офлайн-приклад 1 • ${targetLang.flag} $langLabel] $topicTitle'
              : '[Offline Example 1 • ${targetLang.flag} $langLabel] $topicTitle',
          native: isUk
              ? 'Підключіться до інтернету або натисніть «Оновити через ШІ», щоб згенерувати живі приклади мовою $langLabel.'
              : 'Connect to the internet or tap "Refresh with AI" to generate authentic $langLabel examples.',
        ),
        LevelExampleItem(
          target: node.offlineTip(nativeLang.code),
          native: isUk
              ? 'Опорна формула теми рівня ${node.cefr.code}'
              : 'Core pattern formula for ${node.cefr.code}',
        ),
        LevelExampleItem(
          target: node.subtitle(nativeLang.code),
          native: isUk
              ? 'Ключовий фокус модуля №${node.stepNumber}'
              : 'Key focus of Module #${node.stepNumber}',
        ),
      ]);
    }

    // Build 5 offline practice exercises (mixing saved-word checks + conceptual rule checks)
    final practice = <LevelQuizItem>[];
    if (userVocab.length >= 4) {
      for (var i = 0; i < 2 && i < userVocab.length; i++) {
        final target = userVocab[i];
        final distractors = userVocab
            .where((w) => w.id != target.id)
            .take(3)
            .map((w) => w.translation)
            .toList();
        if (distractors.length == 3) {
          final opts = [target.translation, ...distractors];
          practice.add(
            LevelQuizItem(
              question: isUk
                  ? 'Офлайн-практика (${targetLang.flag}): оберіть правильний переклад слова «${target.word}»:'
                  : 'Offline practice (${targetLang.flag}): choose the right translation of "${target.word}":',
              options: opts,
              correctIndex: 0,
              explanation: '${target.word} = ${target.translation}.',
            ),
          );
        }
      }
    }

    final conceptualPractice = <LevelQuizItem>[
      LevelQuizItem(
        question: isUk
            ? 'Яка головна мета модуля «$topicTitle» (${node.cefr.code})?'
            : 'What is the main focus of "$topicTitle" (${node.cefr.code})?',
        options: isUk
            ? [
                node.subtitleUk,
                'Лише механічне зазубрювання алфавіту без контексту',
                'Ігнорування порядку слів і структури речення',
                'Виключно дослівний переклад кожного слова окремо',
              ]
            : [
                node.subtitleEn,
                'Only memorizing letters without context',
                'Ignoring sentence structure and word order',
                'Translating every word literally without grammar',
              ],
        correctIndex: 0,
        explanation: node.offlineRule(nativeLang.code),
      ),
      LevelQuizItem(
        question: isUk
            ? 'Якої типової помилки слід уникати в цій темі?'
            : 'Which common mistake should you avoid in this topic?',
        options: isUk
            ? [
                node.offlineMistakesUk,
                'Регулярного повторення прикладів у контексті',
                'Прослуховування вимови носіїв мови',
                'Перевірки узгодження слів у реченні',
              ]
            : [
                node.offlineMistakesEn,
                'Practicing examples inside natural context',
                'Listening to native pronunciation',
                'Checking agreement and word order',
              ],
        correctIndex: 0,
        explanation: node.offlineMistakes(nativeLang.code),
      ),
      LevelQuizItem(
        question: isUk
            ? 'Яка опорна формула / порада найкраще допомагає застосувати правило?'
            : 'Which key tip best helps you apply this rule?',
        options: isUk
            ? [
                node.offlineTipUk,
                'Завжди залишати всі слова у словниковій формі',
                'Уникати будь-яких службових слів і маркерів',
                'Копіювати граматику рідної мови без адаптації',
              ]
            : [
                node.offlineTipEn,
                'Always keep every word in its dictionary form',
                'Avoid all linking words and markers',
                'Copy native grammar literally without adapting',
              ],
        correctIndex: 0,
        explanation: node.offlineTip(nativeLang.code),
      ),
      LevelQuizItem(
        question: isUk
            ? 'Як найефективніше закріпити граматику рівня ${node.cefr.code} для мови $langLabel?'
            : 'What is the best way to master ${node.cefr.code} grammar in $langLabel?',
        options: isUk
            ? [
                'Поєднувати правило з живими реченнями, озвученням і тестом',
                'Читати лише теорію без жодного прикладу',
                'Пропускати перевірку типових помилок',
                'Вчити окремі слова без граматичних зв’язків',
              ]
            : [
                'Combine the rule with live examples, audio, and testing',
                'Read abstract theory without any examples',
                'Skip reviewing common pitfalls',
                'Memorize isolated words without grammar',
              ],
        correctIndex: 0,
        explanation: isUk
            ? 'Контекстні приклади + активна перевірка закріплюють правило у довготривалій пам’яті.'
            : 'Contextual examples plus active recall lock grammar into long-term memory.',
      ),
      LevelQuizItem(
        question: isUk
            ? 'Що потрібно зробити після відновлення інтернету для максимальної користі від модуля?'
            : 'What should you do once back online to get full target-language drills?',
        options: isUk
            ? [
                'Натиснути «Оновити через ШІ» для генерації повного набору вправ мовою $langLabel',
                'Видалити весь прогрес і почати заново',
                'Вимкнути звук та приховати приклади',
                'Перемкнути рівень на випадковий',
              ]
            : [
                'Tap "Refresh with AI" to generate full $langLabel exercises and examples',
                'Delete all saved progress',
                'Mute audio and hide examples',
                'Switch randomly to another level',
              ],
        correctIndex: 0,
        explanation: isUk
            ? 'Після генерації через ШІ модуль автоматично кешується локально і працює миттєво навіть офлайн.'
            : 'Once generated by AI, the module is cached locally and loads instantly even offline.',
      ),
    ];

    for (final q in conceptualPractice) {
      if (practice.length >= 5) break;
      practice.add(q);
    }

    // Build 5 final test questions (offline mastery check so >=70% unlocks next node)
    final finalTest = <LevelQuizItem>[
      LevelQuizItem(
        question: isUk
            ? '1. Яке твердження найточніше описує правило модуля «$topicTitle»?'
            : '1. Which statement accurately summarizes the rule for "$topicTitle"?',
        options: isUk
            ? [
                node.offlineRuleUk,
                'У цій темі граматична форма слів ніколи не змінюється.',
                'Ця тема застосовується лише в художніх віршах і не потрібна в розмові.',
                'Достатньо переставити слова в довільному порядку.',
              ]
            : [
                node.offlineRuleEn,
                'Word forms never change in this topic.',
                'This rule is never used in everyday communication.',
                'Words can be placed in any random order.',
              ],
        correctIndex: 0,
        explanation: node.offlineRule(nativeLang.code),
      ),
      LevelQuizItem(
        question: isUk
            ? '2. На що насамперед слід звернути увагу, щоб уникнути типової помилки?'
            : '2. What should you watch out for to avoid the classic mistake here?',
        options: isUk
            ? [
                node.offlineMistakesUk,
                'Не використовувати розділові знаки в реченнях.',
                'Уникати будь-яких прикладів із діалогів.',
                'Повністю відмовитися від повторення.',
              ]
            : [
                node.offlineMistakesEn,
                'Never use punctuation in sentences.',
                'Avoid dialogue examples completely.',
                'Skip reviewing past mistakes.',
              ],
        correctIndex: 0,
        explanation: node.offlineMistakes(nativeLang.code),
      ),
      LevelQuizItem(
        question: isUk
            ? '3. Який шаблон/орієнтир відповідає темі «$topicTitle»?'
            : '3. Which pattern/formula corresponds to "$topicTitle"?',
        options: isUk
            ? [
                node.offlineTipUk,
                'Випадковий набір іменників без дієслова',
                'Пряме перенесення закінчень із рідної мови',
                'Використання лише інфінітива в усіх часах',
              ]
            : [
                node.offlineTipEn,
                'Random nouns without a verb',
                'Copying native-language endings directly',
                'Using only infinitives in every tense',
              ],
        correctIndex: 0,
        explanation: node.offlineTip(nativeLang.code),
      ),
      LevelQuizItem(
        question: isUk
            ? '4. Який піднапрям входить до цього модуля рівня ${node.cefr.code}?'
            : '4. Which skill focus belongs to this ${node.cefr.code} module?',
        options: isUk
            ? [
                node.subtitleUk,
                'Налаштування Wi-Fi роутера',
                'Лише цифрові коди без лексики',
                'Вивчення мови без практики речень',
              ]
            : [
                node.subtitleEn,
                'Unrelated technical jargon only',
                'Numeric codes without vocabulary',
                'Learning grammar without ever forming sentences',
              ],
        correctIndex: 0,
        explanation: node.subtitle(nativeLang.code),
      ),
      LevelQuizItem(
        question: isUk
            ? '5. Який мінімальний результат підсумкового тесту відкриває наступний модуль у гілці?'
            : '5. What minimum final test score unlocks the next module in the path?',
        options: isUk
            ? [
                'Щонайменше 70% правильних відповідей',
                'Рівно 10%',
                'Лише 100% без жодної помилки',
                'Тест не впливає на відкриття наступного рівня',
              ]
            : [
                'At least 70% correct answers',
                'Only 10%',
                'Strictly 100% with zero mistakes',
                'The test does not unlock the next level',
              ],
        correctIndex: 0,
        explanation: isUk
            ? 'Результат від 70% підтверджує засвоєння модуля і розблоковує наступний крок.'
            : 'Scoring 70% or higher confirms mastery and unlocks the next step.',
      ),
    ];

    return GeneratedLevelContent(
      grammarRule: node.offlineRule(nativeLang.code),
      commonMistakes: node.offlineMistakes(nativeLang.code),
      keyTip: node.offlineTip(nativeLang.code),
      examples: examples.take(4).toList(),
      practiceExercises: practice.take(5).toList(),
      finalTest: finalTest,
      usedAi: false,
      providerName: 'Offline',
    );
  }
}
