int? _parseFlexibleInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  final str = raw.toString().trim();
  if (str.isEmpty) return null;
  final direct = int.tryParse(str);
  if (direct != null) return direct;
  final match = RegExp(r'-?\d+').firstMatch(str);
  return match != null ? int.tryParse(match.group(0)!) : null;
}

String _parseFlexibleString(dynamic raw) {
  if (raw == null) return '';
  if (raw is String) return raw.trim();
  if (raw is List) {
    return raw
        .map((e) => _parseFlexibleString(e))
        .where((s) => s.isNotEmpty)
        .join('\n')
        .trim();
  }
  if (raw is Map) {
    return raw.entries
        .map((e) => '${e.key}: ${_parseFlexibleString(e.value)}')
        .where((s) => s.trim().isNotEmpty)
        .join('\n')
        .trim();
  }
  return raw.toString().trim();
}

Map<String, dynamic>? _asStringKeyedMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}

List<String> _parseFlexibleOptions(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => _parseFlexibleString(e))
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (raw is Map) {
    final out = <String>[];
    raw.forEach((key, value) {
      final k = key.toString().trim();
      final v = _parseFlexibleString(value);
      if (v.isEmpty) return;
      final alreadyPrefixed =
          RegExp(r'^[A-Fa-f][\)\.\:\-]\s*').hasMatch(v);
      out.add(alreadyPrefixed || k.isEmpty ? v : '$k) $v');
    });
    return out;
  }
  return const [];
}

enum CefrLevel {
  a1('A1', 'Початковий'),
  a2('A2', 'Елементарний'),
  b1('B1', 'Середній'),
  b2('B2', 'Вище середнього'),
  c1('C1', 'Просунутий'),
  c2('C2', 'Вільне володіння');

  const CefrLevel(this.code, this.labelUk);
  final String code;
  final String labelUk;
}

/// Official CEFR certification subtests (ALTE, CCE, Goethe, Cambridge, DELF).
enum ExamSubtest {
  reading('Reading'),
  listening('Listening'),
  writing('Writing'),
  speaking('Speaking');

  const ExamSubtest(this.apiName);
  final String apiName;

  static ExamSubtest fromApiName(String raw) {
    final norm = raw.trim().toLowerCase();
    if (norm.contains('listen') || norm.contains('audio') || norm.contains('hör')) {
      return ExamSubtest.listening;
    }
    if (norm.contains('writ') || norm.contains('schreib') || norm.contains('écri')) {
      return ExamSubtest.writing;
    }
    if (norm.contains('speak') || norm.contains('oral') || norm.contains('sprech')) {
      return ExamSubtest.speaking;
    }
    return ExamSubtest.reading;
  }
}

/// Official task types returned by the certification exam engine JSON schema.
enum OfficialTaskType {
  multipleChoice('multiple_choice'),
  shortAnswer('short_answer'),
  matching('matching'),
  openWriting('open_writing'),
  speakingRoleplay('speaking_roleplay');

  const OfficialTaskType(this.apiValue);
  final String apiValue;

  static OfficialTaskType fromString(
    String raw, {
    ExamSubtest? subtestHint,
    bool hasOptions = false,
  }) {
    final norm = raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (norm.contains('short') ||
        norm.contains('gap') ||
        norm.contains('cloze') ||
        norm.contains('fill') ||
        norm.contains('completion')) {
      return OfficialTaskType.shortAnswer;
    }
    if (norm.contains('match') || norm.contains('heading')) {
      return OfficialTaskType.matching;
    }
    if (norm.contains('writ') ||
        norm.contains('essay') ||
        norm.contains('email') ||
        norm.contains('letter') ||
        norm.contains('report') ||
        norm.contains('article') ||
        norm.contains('composition')) {
      return OfficialTaskType.openWriting;
    }
    if (norm.contains('speak') ||
        norm.contains('roleplay') ||
        norm.contains('role_play') ||
        norm.contains('oral') ||
        norm.contains('monologue') ||
        norm.contains('interview') ||
        norm.contains('discussion')) {
      return OfficialTaskType.speakingRoleplay;
    }
    if (norm.contains('choice') ||
        norm.contains('mcq') ||
        norm.contains('true_false') ||
        norm.contains('boolean')) {
      return OfficialTaskType.multipleChoice;
    }
    if (!hasOptions) {
      if (subtestHint == ExamSubtest.writing) {
        return OfficialTaskType.openWriting;
      }
      if (subtestHint == ExamSubtest.speaking) {
        return OfficialTaskType.speakingRoleplay;
      }
    }
    return OfficialTaskType.multipleChoice;
  }
}

class ExamMeta {
  const ExamMeta({
    required this.language,
    required this.level,
    required this.subtest,
    required this.timeLimitMinutes,
    this.passThresholdPercent = 60,
  });

  final String language;
  final String level;
  final ExamSubtest subtest;
  final int timeLimitMinutes;
  final int passThresholdPercent;

  factory ExamMeta.fromJson(
    Map<String, dynamic> json, {
    required String fallbackLanguage,
    required String fallbackLevel,
    required ExamSubtest fallbackSubtest,
    required int fallbackTimeMinutes,
  }) {
    final rawSub = _parseFlexibleString(json['subtest']);
    final rawTime = _parseFlexibleInt(
      json['time_limit_minutes'] ?? json['timeLimitMinutes'] ?? json['duration'],
    );
    final rawPass = _parseFlexibleInt(
      json['pass_threshold_percent'] ?? json['passThresholdPercent'],
    );
    final langStr = _parseFlexibleString(json['language']);
    final lvlStr = _parseFlexibleString(json['level']);

    return ExamMeta(
      language: langStr.isNotEmpty ? langStr : fallbackLanguage,
      level: lvlStr.isNotEmpty ? lvlStr : fallbackLevel,
      subtest: rawSub.isNotEmpty
          ? ExamSubtest.fromApiName(rawSub)
          : fallbackSubtest,
      timeLimitMinutes: (rawTime != null && rawTime > 0)
          ? rawTime
          : fallbackTimeMinutes,
      passThresholdPercent: (rawPass != null && rawPass > 0 && rawPass <= 100)
          ? rawPass
          : 60,
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'level': level,
        'subtest': subtest.apiName,
        'time_limit_minutes': timeLimitMinutes,
        'pass_threshold_percent': passThresholdPercent,
      };
}

class ExamStimulus {
  const ExamStimulus({
    required this.textOrTranscript,
    this.visualPromptDescription,
  });

  final String textOrTranscript;
  final String? visualPromptDescription;

  bool get hasVisualPrompt =>
      visualPromptDescription != null &&
      visualPromptDescription!.trim().isNotEmpty &&
      visualPromptDescription!.trim().toLowerCase() != 'null';

  ExamStimulus copyWith({
    String? textOrTranscript,
    String? visualPromptDescription,
  }) {
    return ExamStimulus(
      textOrTranscript: textOrTranscript ?? this.textOrTranscript,
      visualPromptDescription:
          visualPromptDescription ?? this.visualPromptDescription,
    );
  }

  factory ExamStimulus.fromJson(dynamic raw) {
    final map = _asStringKeyedMap(raw);
    if (map != null) {
      final text = _parseFlexibleString(
        map['text_or_transcript'] ??
            map['textOrTranscript'] ??
            map['transcript'] ??
            map['audio_script'] ??
            map['passage'] ??
            map['content'] ??
            map['text'],
      );
      final visRaw = map['visual_prompt_description'] ??
          map['visualPromptDescription'] ??
          map['visual_prompt'];
      final vis = _parseFlexibleString(visRaw);
      return ExamStimulus(
        textOrTranscript: text,
        visualPromptDescription:
            (vis.isEmpty || vis.toLowerCase() == 'null') ? null : vis,
      );
    }
    final plain = _parseFlexibleString(raw);
    return ExamStimulus(textOrTranscript: plain);
  }

  Map<String, dynamic> toJson() => {
        'text_or_transcript': textOrTranscript,
        'visual_prompt_description': visualPromptDescription,
      };
}

class OfficialExamQuestionItem {
  const OfficialExamQuestionItem({
    required this.id,
    required this.questionText,
    this.options = const [],
    this.correctAnswer = '',
    this.explanation = '',
  });

  final int id;
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  /// Resolves the 0-based index of [correctAnswer] inside [options], supporting
  /// letter prefixes ("A", "B)", "C) ...") as well as exact option text matching.
  int resolveCorrectOptionIndex() {
    if (options.isEmpty) return -1;
    final cleanAns = correctAnswer.trim();
    if (cleanAns.isEmpty) return 0;

    // 1. Direct letter check ("A", "B", "C", "D", "A)", "A.")
    final letterMatch =
        RegExp(r'^([A-Fa-f])(?:[\)\.\:\s]|$)').firstMatch(cleanAns);
    if (letterMatch != null) {
      final idx = letterMatch.group(1)!.toUpperCase().codeUnitAt(0) - 65;
      if (idx >= 0 && idx < options.length) {
        return idx;
      }
    }

    // 2. Exact or stripped match against options
    final normAns = _stripOptionPrefix(cleanAns).toLowerCase();
    for (var i = 0; i < options.length; i++) {
      final optNorm = _stripOptionPrefix(options[i]).toLowerCase();
      if (optNorm == normAns ||
          options[i].trim().toLowerCase() == cleanAns.toLowerCase()) {
        return i;
      }
    }

    // 3. Contains fallback
    for (var i = 0; i < options.length; i++) {
      if (options[i].toLowerCase().contains(normAns) && normAns.length >= 2) {
        return i;
      }
    }

    return 0;
  }

  String get displayCorrectAnswerText {
    if (options.isEmpty) return correctAnswer;
    final idx = resolveCorrectOptionIndex();
    if (idx >= 0 && idx < options.length) {
      return options[idx];
    }
    return correctAnswer;
  }

  static String _stripOptionPrefix(String raw) {
    return raw.replaceFirst(RegExp(r'^[A-Fa-f][\)\.\:\-]\s*'), '').trim();
  }

  OfficialExamQuestionItem copyWith({
    int? id,
    String? questionText,
    List<String>? options,
    String? correctAnswer,
    String? explanation,
  }) {
    return OfficialExamQuestionItem(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
    );
  }

  factory OfficialExamQuestionItem.fromJson(
    Map<String, dynamic> json, {
    int fallbackId = 1,
  }) {
    final opts = _parseFlexibleOptions(
      json['options'] ?? json['choices'] ?? json['answers'],
    );
    final qText = _parseFlexibleString(
      json['question_text'] ??
          json['questionText'] ??
          json['question'] ??
          json['prompt'] ??
          json['statement'] ??
          json['text'],
    );
    final corr = _parseFlexibleString(
      json['correct_answer'] ??
          json['correctAnswer'] ??
          json['answer'] ??
          json['key'],
    );
    final expl = _parseFlexibleString(
      json['explanation'] ?? json['rationale'] ?? json['reason'],
    );
    return OfficialExamQuestionItem(
      id: _parseFlexibleInt(json['id'] ?? json['number']) ?? fallbackId,
      questionText: qText,
      options: opts,
      correctAnswer: corr,
      explanation: expl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question_text': questionText,
        'options': options,
        'correct_answer': correctAnswer,
        'explanation': explanation,
      };
}

class ExamEvaluationCriteria {
  const ExamEvaluationCriteria({
    this.minWords = 0,
    this.maxPoints = 5,
    this.rubric = '',
  });

  final int minWords;
  final int maxPoints;
  final String rubric;

  ExamEvaluationCriteria copyWith({
    int? minWords,
    int? maxPoints,
    String? rubric,
  }) {
    return ExamEvaluationCriteria(
      minWords: minWords ?? this.minWords,
      maxPoints: maxPoints ?? this.maxPoints,
      rubric: rubric ?? this.rubric,
    );
  }

  factory ExamEvaluationCriteria.fromJson(dynamic raw) {
    final map = _asStringKeyedMap(raw);
    if (map != null) {
      final minW =
          _parseFlexibleInt(map['min_words'] ?? map['minWords']) ?? 0;
      final maxP =
          _parseFlexibleInt(map['max_points'] ?? map['maxPoints'] ?? map['points']) ??
              5;
      return ExamEvaluationCriteria(
        minWords: minW < 0 ? 0 : minW,
        maxPoints: maxP <= 0 ? 5 : maxP,
        rubric: _parseFlexibleString(map['rubric'] ?? map['criteria']),
      );
    }
    return const ExamEvaluationCriteria();
  }

  Map<String, dynamic> toJson() => {
        'min_words': minWords,
        'max_points': maxPoints,
        'rubric': rubric,
      };
}

class OfficialExamTask {
  const OfficialExamTask({
    required this.taskNumber,
    required this.taskType,
    required this.instructionUi,
    required this.instructionTarget,
    required this.stimulus,
    required this.questions,
    required this.evaluationCriteria,
  });

  final int taskNumber;
  final OfficialTaskType taskType;
  final String instructionUi;
  final String instructionTarget;
  final ExamStimulus stimulus;
  final List<OfficialExamQuestionItem> questions;
  final ExamEvaluationCriteria evaluationCriteria;

  OfficialExamTask copyWith({
    int? taskNumber,
    OfficialTaskType? taskType,
    String? instructionUi,
    String? instructionTarget,
    ExamStimulus? stimulus,
    List<OfficialExamQuestionItem>? questions,
    ExamEvaluationCriteria? evaluationCriteria,
  }) {
    return OfficialExamTask(
      taskNumber: taskNumber ?? this.taskNumber,
      taskType: taskType ?? this.taskType,
      instructionUi: instructionUi ?? this.instructionUi,
      instructionTarget: instructionTarget ?? this.instructionTarget,
      stimulus: stimulus ?? this.stimulus,
      questions: questions ?? this.questions,
      evaluationCriteria: evaluationCriteria ?? this.evaluationCriteria,
    );
  }

  factory OfficialExamTask.fromJson(
    Map<String, dynamic> json, {
    int fallbackNumber = 1,
    ExamSubtest? subtestHint,
  }) {
    final rawQs = (json['questions'] ??
            json['items'] ??
            json['prompts'] ??
            json['bullet_points']) as List<dynamic>? ??
        const [];
    final parsedQs = <OfficialExamQuestionItem>[];
    for (var i = 0; i < rawQs.length; i++) {
      final item = rawQs[i];
      final itemMap = _asStringKeyedMap(item);
      if (itemMap != null) {
        parsedQs.add(
          OfficialExamQuestionItem.fromJson(itemMap, fallbackId: i + 1),
        );
      } else {
        final txt = _parseFlexibleString(item);
        if (txt.isNotEmpty) {
          parsedQs.add(
            OfficialExamQuestionItem(id: i + 1, questionText: txt),
          );
        }
      }
    }

    final hasOptions = parsedQs.any((q) => q.options.isNotEmpty);
    final rawType = _parseFlexibleString(
      json['task_type'] ?? json['taskType'] ?? json['type'],
    );
    final instrUi = _parseFlexibleString(
      json['instruction_ui'] ??
          json['instructionUi'] ??
          json['instruction'] ??
          json['instructions'],
    );
    final instrTarget = _parseFlexibleString(
      json['instruction_target'] ??
          json['instructionTarget'] ??
          json['target_instruction'],
    );

    final rawStimulus = json['stimulus'] ??
        json['text_or_transcript'] ??
        json['passage'] ??
        json['transcript'] ??
        json['prompt_text'];

    return OfficialExamTask(
      taskNumber:
          _parseFlexibleInt(json['task_number'] ?? json['taskNumber'] ?? json['number']) ??
              fallbackNumber,
      taskType: OfficialTaskType.fromString(
        rawType,
        subtestHint: subtestHint,
        hasOptions: hasOptions,
      ),
      instructionUi: instrUi,
      instructionTarget: instrTarget,
      stimulus: ExamStimulus.fromJson(rawStimulus),
      questions: parsedQs,
      evaluationCriteria: ExamEvaluationCriteria.fromJson(
        json['evaluation_criteria'] ??
            json['evaluationCriteria'] ??
            json['criteria'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'task_number': taskNumber,
        'task_type': taskType.apiValue,
        'instruction_ui': instructionUi,
        'instruction_target': instructionTarget,
        'stimulus': stimulus.toJson(),
        'questions': questions.map((q) => q.toJson()).toList(),
        'evaluation_criteria': evaluationCriteria.toJson(),
      };
}

/// Complete generated JSON paper for one certification subtest.
class OfficialExamSubtestPaper {
  const OfficialExamSubtestPaper({
    required this.examMeta,
    required this.tasks,
    this.usedAi = false,
    this.providerUsed = '',
    this.fallbackReason,
  });

  final ExamMeta examMeta;
  final List<OfficialExamTask> tasks;
  final bool usedAi;
  final String providerUsed;
  final String? fallbackReason;

  int get totalMaxPoints =>
      tasks.fold<int>(0, (sum, t) => sum + t.evaluationCriteria.maxPoints);

  factory OfficialExamSubtestPaper.fromJson(
    Map<String, dynamic> json, {
    required String fallbackLanguage,
    required String fallbackLevel,
    required ExamSubtest fallbackSubtest,
    required int fallbackTimeMinutes,
    bool usedAi = true,
    String providerUsed = '',
    String? fallbackReason,
  }) {
    // Unwrap nested {"exam": {...}} or {"subtest": {...}} wrapper if LLM added one
    Map<String, dynamic> root = json;
    for (final wrapperKey in const ['exam', 'subtest_paper', 'paper', 'data']) {
      final candidate = _asStringKeyedMap(root[wrapperKey]);
      if (candidate != null &&
          (candidate.containsKey('tasks') ||
              candidate.containsKey('sections') ||
              candidate.containsKey('parts'))) {
        root = candidate;
        break;
      }
    }

    final metaJson = _asStringKeyedMap(
          root['exam_meta'] ??
              root['examMeta'] ??
              root['meta'] ??
              root['metadata'],
        ) ??
        const <String, dynamic>{};

    final meta = ExamMeta.fromJson(
      metaJson,
      fallbackLanguage: fallbackLanguage,
      fallbackLevel: fallbackLevel,
      fallbackSubtest: fallbackSubtest,
      fallbackTimeMinutes: fallbackTimeMinutes,
    );

    final rawTasksDynamic = root['tasks'] ??
        root['sections'] ??
        root['parts'] ??
        root['exercises'];
    final rawTasks =
        rawTasksDynamic is List ? rawTasksDynamic : const <dynamic>[];
    final parsedTasks = <OfficialExamTask>[];
    for (var i = 0; i < rawTasks.length; i++) {
      final itemMap = _asStringKeyedMap(rawTasks[i]);
      if (itemMap != null) {
        parsedTasks.add(
          OfficialExamTask.fromJson(
            itemMap,
            fallbackNumber: i + 1,
            subtestHint: meta.subtest,
          ),
        );
      }
    }

    return OfficialExamSubtestPaper(
      examMeta: meta,
      tasks: parsedTasks,
      usedAi: usedAi,
      providerUsed: providerUsed,
      fallbackReason: fallbackReason,
    );
  }

  Map<String, dynamic> toJson() => {
        'exam_meta': examMeta.toJson(),
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };
}

/// A live exam session containing either 1 chosen subtest or all 4 CEFR subtests.
class OfficialExamSession {
  const OfficialExamSession({
    required this.level,
    required this.subtests,
  });

  final CefrLevel level;
  final List<OfficialExamSubtestPaper> subtests;

  int get totalTimeMinutes =>
      subtests.fold<int>(0, (sum, p) => sum + p.examMeta.timeLimitMinutes);

  int get totalMaxPoints =>
      subtests.fold<int>(0, (sum, p) => sum + p.totalMaxPoints);

  int get passThresholdPercent =>
      subtests.isEmpty ? 60 : subtests.first.examMeta.passThresholdPercent;

  bool get usedAi => subtests.any((p) => p.usedAi);

  bool get hasAnyFallback => subtests.any((p) => !p.usedAi);

  List<String> get aiFallbackReasons => subtests
      .where((p) => !p.usedAi && (p.fallbackReason?.trim().isNotEmpty ?? false))
      .map((p) => '${p.examMeta.subtest.apiName}: ${p.fallbackReason!.trim()}')
      .toList();

  String get providerLabel {
    final aiProviders = subtests
        .where((p) => p.usedAi && p.providerUsed.isNotEmpty)
        .map((p) => p.providerUsed)
        .toSet();
    if (aiProviders.isNotEmpty) return aiProviders.first;
    return 'CEFR Blueprint Bank';
  }
}

/// Per-task graded outcome inside [OfficialExamEvaluation].
class OfficialTaskEvaluation {
  const OfficialTaskEvaluation({
    required this.subtest,
    required this.taskNumber,
    required this.earnedPoints,
    required this.maxPoints,
    required this.feedback,
    this.questionCorrectMap = const {},
  });

  final ExamSubtest subtest;
  final int taskNumber;
  final double earnedPoints;
  final int maxPoints;
  final String feedback;

  /// Map of question.id -> bool (true if answered correctly) for objective questions.
  final Map<int, bool> questionCorrectMap;
}

class OfficialExamEvaluation {
  const OfficialExamEvaluation({
    required this.targetLevel,
    required this.earnedPoints,
    required this.maxPoints,
    required this.passThresholdPercent,
    required this.estimatedLevel,
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.taskEvaluations,
    required this.usedAi,
  });

  final CefrLevel targetLevel;
  final double earnedPoints;
  final int maxPoints;
  final int passThresholdPercent;
  final String estimatedLevel;
  final String summary;
  final List<String> strengths;
  final List<String> improvements;
  final List<OfficialTaskEvaluation> taskEvaluations;
  final bool usedAi;

  double get percentage =>
      maxPoints <= 0 ? 0.0 : ((earnedPoints / maxPoints) * 100.0).clamp(0, 100);

  bool get passed => percentage >= passThresholdPercent;
}

// ---------------------------------------------------------------------------
// Legacy / auxiliary models kept for compatibility with CefrQuestionBank & lookup
// ---------------------------------------------------------------------------

enum ExamTaskType {
  grammar('Читання та Граматика (Reading)'),
  listening('Аудіювання (Listening)'),
  writing('Письмо (Writing)'),
  speaking('Усне мовлення (Speaking)');

  const ExamTaskType(this.labelUk);
  final String labelUk;
}

class ExamQuestion {
  const ExamQuestion({
    required this.question,
    this.options = const [],
    this.correctIndex = 0,
    required this.explanation,
    this.topic = '',
    this.type = ExamTaskType.grammar,
    this.subType = '',
    this.instruction = '',
    this.stimulusText = '',
    this.audioScript = '',
    this.expectedAnswer = '',
    this.passingCriteria = '',
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String topic;
  final ExamTaskType type;
  final String subType;
  final String instruction;
  final String stimulusText;
  final String audioScript;
  final String expectedAnswer;
  final String passingCriteria;

  String get effectiveTargetText =>
      expectedAnswer.trim().isNotEmpty
          ? expectedAnswer.trim()
          : (options.isNotEmpty &&
                  correctIndex >= 0 &&
                  correctIndex < options.length)
              ? options[correctIndex]
              : question;

  String get effectiveAudioText =>
      audioScript.trim().isNotEmpty ? audioScript.trim() : effectiveTargetText;

  ExamQuestion copyWith({
    String? question,
    List<String>? options,
    int? correctIndex,
    String? explanation,
    String? topic,
    ExamTaskType? type,
    String? subType,
    String? instruction,
    String? stimulusText,
    String? audioScript,
    String? expectedAnswer,
    String? passingCriteria,
  }) {
    return ExamQuestion(
      question: question ?? this.question,
      options: options ?? this.options,
      correctIndex: correctIndex ?? this.correctIndex,
      explanation: explanation ?? this.explanation,
      topic: topic ?? this.topic,
      type: type ?? this.type,
      subType: subType ?? this.subType,
      instruction: instruction ?? this.instruction,
      stimulusText: stimulusText ?? this.stimulusText,
      audioScript: audioScript ?? this.audioScript,
      expectedAnswer: expectedAnswer ?? this.expectedAnswer,
      passingCriteria: passingCriteria ?? this.passingCriteria,
    );
  }
}

class WordLookupResult {
  const WordLookupResult({
    required this.word,
    required this.translation,
    required this.example,
    this.partOfSpeech = '',
    this.explanation = '',
    this.usedAi = false,
  });

  final String word;
  final String translation;
  final String example;
  final String partOfSpeech;
  final String explanation;
  final bool usedAi;
}
