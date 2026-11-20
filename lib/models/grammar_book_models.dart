import 'package:flutter/material.dart';

import 'reading_rules_book.dart';
import 'supported_languages.dart';

/// Metadata and AI generation blueprint for a single chapter of the
/// language-independent 9-chapter Grammar & Rules Handbook.
class GrammarChapterSpec {
  const GrammarChapterSpec({
    required this.id,
    required this.number,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.accentColor,
    required this.aiPromptScope,
  });

  final String id;
  final int number;
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final Color accentColor;
  final String aiPromptScope;

  /// Exact SharedPreferences key:
  /// `grammar_book_{targetLang}_{nativeLang}_{chapterId}`
  String cacheKey({
    required String targetLangCode,
    required String nativeLangCode,
  }) =>
      'grammar_book_${targetLangCode}_${nativeLangCode}_$id';
}

/// Universal 9-chapter grammar handbook blueprint covering every core area of
/// any of the 92 supported target languages.
class GrammarBookBlueprint {
  static const List<GrammarChapterSpec> chapters = [
    GrammarChapterSpec(
      id: 'ch1_phonetics',
      number: 1,
      titleKey: 'grammar_ch1_title',
      subtitleKey: 'grammar_ch1_sub',
      icon: Icons.abc_rounded,
      accentColor: Colors.indigo,
      aiPromptScope:
          'Complete alphabet and script overview, all special letters and diacritics, full reading rules (digraphs, consonant clusters, palatalization/softening, devoicing, silent letters), vowel length/shifts, word stress patterns, sentence intonation, and spelling-to-sound exceptions.',
    ),
    GrammarChapterSpec(
      id: 'ch2_nouns',
      number: 2,
      titleKey: 'grammar_ch2_title',
      subtitleKey: 'grammar_ch2_sub',
      icon: Icons.table_chart_rounded,
      accentColor: Colors.teal,
      aiPromptScope:
          'Nouns: grammatical genders and how to identify them, articles/determiners (if applicable), plural formation patterns and irregular plurals, ALL grammatical cases (full declension ending tables across genders/singular/plural, or prepositional equivalents if the language has no morphological cases), animate/inanimate distinctions, and major noun exceptions.',
    ),
    GrammarChapterSpec(
      id: 'ch3_adjectives',
      number: 3,
      titleKey: 'grammar_ch3_title',
      subtitleKey: 'grammar_ch3_sub',
      icon: Icons.tune_rounded,
      accentColor: Colors.purple,
      aiPromptScope:
          'Adjectives and adverbs: agreement with nouns (gender, number, case) and adjective declension tables, position in sentences, formation of adverbs from adjectives, comparative and superlative degrees (regular rules + complete table of irregular comparatives/superlatives), and common exceptions.',
    ),
    GrammarChapterSpec(
      id: 'ch4_pronouns',
      number: 4,
      titleKey: 'grammar_ch4_title',
      subtitleKey: 'grammar_ch4_sub',
      icon: Icons.groups_rounded,
      accentColor: Colors.blue,
      aiPromptScope:
          'ALL types of pronouns with full declension/form tables: personal (subject, object, clitic/stressed forms), possessive, reflexive, demonstrative, interrogative, relative, indefinite, and negative pronouns, plus formal vs informal address rules and pronoun placement.',
    ),
    GrammarChapterSpec(
      id: 'ch5_verbs_present',
      number: 5,
      titleKey: 'grammar_ch5_title',
      subtitleKey: 'grammar_ch5_sub',
      icon: Icons.bolt_rounded,
      accentColor: Colors.orange,
      aiPromptScope:
          'Verbs in the present tense: infinitive patterns, ALL conjugation classes/groups with complete ending tables for all persons (singular & plural), stem changes and orthographic shifts, reflexive verbs, negation, and a comprehensive table of essential irregular verbs (to be, to have, to go, to do, to know, etc.).',
    ),
    GrammarChapterSpec(
      id: 'ch6_verbs_past_future',
      number: 6,
      titleKey: 'grammar_ch6_title',
      subtitleKey: 'grammar_ch6_sub',
      icon: Icons.history_toggle_off_rounded,
      accentColor: Colors.deepOrange,
      aiPromptScope:
          'Past and future tenses, verbal aspect (perfective vs imperfective or simple vs continuous/perfect as appropriate for the language): formation rules, auxiliary verbs, participle/past-stem tables, sequence of tenses, time markers, and key irregular past/future verb exceptions.',
    ),
    GrammarChapterSpec(
      id: 'ch7_modals_moods',
      number: 7,
      titleKey: 'grammar_ch7_title',
      subtitleKey: 'grammar_ch7_sub',
      icon: Icons.psychology_alt_rounded,
      accentColor: Colors.pink,
      aiPromptScope:
          'Modal verbs (can, must, may, want, should, etc.) with full conjugation tables and nuance differences, imperative mood (affirmative & negative commands, singular/plural/polite, irregular imperatives), conditional/subjunctive moods (hypotheticals, polite requests, wishes), and passive voice basics.',
    ),
    GrammarChapterSpec(
      id: 'ch8_prepositions_syntax',
      number: 8,
      titleKey: 'grammar_ch8_title',
      subtitleKey: 'grammar_ch8_sub',
      icon: Icons.account_tree_rounded,
      accentColor: Colors.cyan,
      aiPromptScope:
          'Prepositions (complete table grouped by required grammatical case or spatial/temporal usage, plus contractions), coordinating and subordinating conjunctions, cardinal & ordinal numerals (and noun agreement after numbers), and sentence word order rules (statements, questions, negation, subordinate clauses, clitic placement).',
    ),
    GrammarChapterSpec(
      id: 'ch9_exceptions_master',
      number: 9,
      titleKey: 'grammar_ch9_title',
      subtitleKey: 'grammar_ch9_sub',
      icon: Icons.warning_amber_rounded,
      accentColor: Colors.amber,
      aiPromptScope:
          'Master reference compendium of the most important language exceptions and tricky edge cases: irregular nouns, irregular verbs, irregular adjectives/adverbs, spelling & diacritic traps, false friends, frequently confused pairs, and high-frequency idioms/structures that break standard rules.',
    ),
  ];

  static GrammarChapterSpec byId(String id) {
    return chapters.firstWhere(
      (c) => c.id == id,
      orElse: () => chapters.first,
    );
  }
}

/// Structured comparison, declension, conjugation, or endings table.
class GrammarTable {
  const GrammarTable({
    required this.title,
    required this.headers,
    required this.rows,
    this.note = '',
  });

  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final String note;

  bool get isValid => headers.isNotEmpty && rows.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'title': title,
        'headers': headers,
        'rows': rows,
        'note': note,
      };

  factory GrammarTable.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'] as List<dynamic>? ?? const [];
    final headers = rawHeaders
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final rawRows = json['rows'] as List<dynamic>? ?? const [];
    final rows = <List<String>>[];
    for (final row in rawRows) {
      if (row is List) {
        final cells = row.map((c) => c.toString().trim()).toList();
        if (cells.any((c) => c.isNotEmpty)) {
          rows.add(cells);
        }
      }
    }

    return GrammarTable(
      title: (json['title'] ?? '').toString().trim(),
      headers: headers,
      rows: rows,
      note: (json['note'] ?? '').toString().trim(),
    );
  }
}

/// Deep grammar rule block inside a chapter, with explanation, exceptions,
/// and TTS-ready examples.
class GrammarRuleSection {
  const GrammarRuleSection({
    required this.title,
    required this.explanation,
    this.exceptions = const [],
    this.examples = const [],
  });

  final String title;
  final String explanation;
  final List<String> exceptions;
  final List<ReadingRuleExample> examples;

  bool get isValid => title.trim().isNotEmpty && explanation.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'title': title,
        'explanation': explanation,
        'exceptions': exceptions,
        'examples': examples.map((e) => e.toJson()).toList(),
      };

  factory GrammarRuleSection.fromJson(Map<String, dynamic> json) {
    final rawEx = json['examples'] as List<dynamic>? ?? const [];
    final examples = rawEx
        .whereType<Map<String, dynamic>>()
        .map(ReadingRuleExample.fromJson)
        .where((e) => e.isValid)
        .toList();

    final rawExceptions = json['exceptions'] as List<dynamic>? ?? const [];
    final exceptions = rawExceptions
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return GrammarRuleSection(
      title: (json['title'] ?? '').toString().trim(),
      explanation: (json['explanation'] ?? json['rule'] ?? '')
          .toString()
          .trim(),
      exceptions: exceptions,
      examples: examples,
    );
  }
}

/// Complete cached content for a single chapter of the Grammar Handbook.
class GrammarChapterContent {
  const GrammarChapterContent({
    required this.chapterId,
    required this.targetLanguageCode,
    required this.nativeLanguageCode,
    required this.summary,
    required this.sections,
    this.tables = const [],
    this.keyExceptions = const [],
    this.commonMistakes = const [],
    this.usedAi = false,
    this.providerName = '',
    this.generatedAtIso = '',
    this.errorDetail,
  });

  final String chapterId;
  final String targetLanguageCode;
  final String nativeLanguageCode;
  final String summary;
  final List<GrammarRuleSection> sections;
  final List<GrammarTable> tables;
  final List<String> keyExceptions;
  final List<String> commonMistakes;
  final bool usedAi;
  final String providerName;
  final String generatedAtIso;
  final String? errorDetail;

  bool get isValid => summary.trim().isNotEmpty && sections.length >= 2;

  Map<String, dynamic> toJson() => {
        'chapterId': chapterId,
        'targetLanguageCode': targetLanguageCode,
        'nativeLanguageCode': nativeLanguageCode,
        'summary': summary,
        'sections': sections.map((s) => s.toJson()).toList(),
        'tables': tables.map((t) => t.toJson()).toList(),
        'keyExceptions': keyExceptions,
        'commonMistakes': commonMistakes,
        'usedAi': usedAi,
        'providerName': providerName,
        'generatedAtIso': generatedAtIso,
      };

  factory GrammarChapterContent.fromJson(
    Map<String, dynamic> json, {
    String fallbackChapterId = 'ch1_phonetics',
    String fallbackTargetCode = 'en',
    String fallbackNativeCode = 'uk',
  }) {
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    final sections = rawSections
        .whereType<Map<String, dynamic>>()
        .map(GrammarRuleSection.fromJson)
        .where((s) => s.isValid)
        .toList();

    final rawTables = json['tables'] as List<dynamic>? ?? const [];
    final tables = rawTables
        .whereType<Map<String, dynamic>>()
        .map(GrammarTable.fromJson)
        .where((t) => t.isValid)
        .toList();

    List<String> parseStrings(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return GrammarChapterContent(
      chapterId: (json['chapterId'] ?? fallbackChapterId).toString().trim(),
      targetLanguageCode:
          (json['targetLanguageCode'] ?? fallbackTargetCode).toString().trim(),
      nativeLanguageCode:
          (json['nativeLanguageCode'] ?? fallbackNativeCode).toString().trim(),
      summary: (json['summary'] ?? json['overview'] ?? '').toString().trim(),
      sections: sections,
      tables: tables,
      keyExceptions: parseStrings(json['keyExceptions']),
      commonMistakes: parseStrings(json['commonMistakes']),
      usedAi: json['usedAi'] == true,
      providerName: (json['providerName'] ?? '').toString().trim(),
      generatedAtIso: (json['generatedAtIso'] ?? '').toString().trim(),
    );
  }

  /// Offline fallback placeholder so any chapter opens cleanly even without network.
  static GrammarChapterContent buildOfflineFallback({
    required GrammarChapterSpec spec,
    required LanguageOption targetLang,
    required LanguageOption nativeLang,
    String? errorDetail,
  }) {
    final isUk = nativeLang.code == 'uk';
    final langLabel = isUk ? targetLang.nameUk : targetLang.englishName;

    return GrammarChapterContent(
      chapterId: spec.id,
      targetLanguageCode: targetLang.code,
      nativeLanguageCode: nativeLang.code,
      summary: isUk
          ? 'Розділ ${spec.number} для мови «$langLabel (${targetLang.displayNativeName})» ще не завантажено через ШІ. Підключіться до інтернету й натисніть «Оновити розділ», щоб отримати повний академічний розбір із таблицями закінчень, винятками та прикладами з озвучкою.'
          : 'Chapter ${spec.number} for $langLabel (${targetLang.displayNativeName}) has not been generated via AI yet. Connect to the internet and tap "Refresh Chapter" to build the full reference with tables, exceptions, and speakable examples.',
      sections: [
        GrammarRuleSection(
          title: isUk
              ? 'Що входить до цього розділу'
              : 'What this chapter covers',
          explanation: isUk
              ? 'ШІ згенерує для мови $langLabel структуровані правила, таблиці відмінювання/дієвідмінювання, ключові винятки та 2–3 живі приклади з озвучкою до кожного правила. Після першого завантаження розділ працюватиме повністю офлайн.'
              : 'AI will generate structured rules, complete ending/conjugation tables, key exceptions, and 2–3 speakable examples per rule for $langLabel. Once generated, the chapter is cached for full offline access.',
          examples: [
            ReadingRuleExample(
              text: targetLang.displayNativeName,
              pronunciation: '',
              translation: langLabel,
            ),
          ],
        ),
        GrammarRuleSection(
          title: isUk
              ? 'Порада для вивчення'
              : 'Study tip',
          explanation: isUk
              ? 'Прослуховуйте кожен приклад уголос і порівнюйте стандартні моделі з винятками. Якщо виникло конкретне питання, скористайтеся блоком «Запитати ШІ» на головному екрані книжечки.'
              : 'Listen to every example aloud and compare regular patterns against exceptions. For specific edge cases, use the "Ask AI" bar on the main handbook screen.',
        ),
      ],
      tables: const [],
      keyExceptions: [
        isUk
            ? 'Натисніть «Оновити розділ», щоб завантажити повний список винятків для мови $langLabel.'
            : 'Tap "Refresh Chapter" to load the full exceptions list for $langLabel.',
      ],
      commonMistakes: [
        isUk
            ? 'Переконайтеся, що в Налаштуваннях додано робочий ШІ-ключ або є доступ до мережі.'
            : 'Make sure you have internet access or an active AI key configured in Settings.',
      ],
      usedAi: false,
      errorDetail: errorDetail,
    );
  }
}

/// Saved user grammar question + AI explanation inside "Мої запитання".
class GrammarQaEntry {
  const GrammarQaEntry({
    required this.id,
    required this.question,
    required this.answer,
    this.examples = const [],
    this.exceptionsAndMistakes = const [],
    this.tables = const [],
    this.providerName = '',
    this.createdAtIso = '',
    this.usedAi = true,
  });

  final String id;
  final String question;
  final String answer;
  final List<ReadingRuleExample> examples;
  final List<String> exceptionsAndMistakes;
  final List<GrammarTable> tables;
  final String providerName;
  final String createdAtIso;
  final bool usedAi;

  bool get isValid =>
      question.trim().isNotEmpty && answer.trim().isNotEmpty;

  /// Exact SharedPreferences key: `grammar_qa_{targetLang}_{nativeLang}`
  static String storageKey({
    required String targetLangCode,
    required String nativeLangCode,
  }) =>
      'grammar_qa_${targetLangCode}_$nativeLangCode';

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'answer': answer,
        'examples': examples.map((e) => e.toJson()).toList(),
        'exceptionsAndMistakes': exceptionsAndMistakes,
        'tables': tables.map((t) => t.toJson()).toList(),
        'providerName': providerName,
        'createdAtIso': createdAtIso,
        'usedAi': usedAi,
      };

  factory GrammarQaEntry.fromJson(Map<String, dynamic> json) {
    final rawEx = json['examples'] as List<dynamic>? ?? const [];
    final examples = rawEx
        .whereType<Map<String, dynamic>>()
        .map(ReadingRuleExample.fromJson)
        .where((e) => e.isValid)
        .toList();

    final rawExceptions =
        json['exceptionsAndMistakes'] as List<dynamic>? ?? const [];
    final exceptions = rawExceptions
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final rawTables = json['tables'] as List<dynamic>? ?? const [];
    final tables = rawTables
        .whereType<Map<String, dynamic>>()
        .map(GrammarTable.fromJson)
        .where((t) => t.isValid)
        .toList();

    return GrammarQaEntry(
      id: (json['id'] ?? '').toString().trim().isNotEmpty
          ? json['id'].toString().trim()
          : DateTime.now().microsecondsSinceEpoch.toString(),
      question: (json['question'] ?? '').toString().trim(),
      answer: (json['answer'] ?? json['explanation'] ?? '').toString().trim(),
      examples: examples,
      exceptionsAndMistakes: exceptions,
      tables: tables,
      providerName: (json['providerName'] ?? '').toString().trim(),
      createdAtIso: (json['createdAtIso'] ?? '').toString().trim(),
      usedAi: json['usedAi'] != false,
    );
  }
}
