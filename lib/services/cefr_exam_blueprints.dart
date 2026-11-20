import 'dart:convert';

import '../models/app_settings.dart';
import '../models/exam_models.dart';

/// Official CEFR Companion Volume (Council of Europe, 2020) certification blueprints
/// aligned with ALTE, CCE, Goethe-Zertifikat, Cambridge English, and DELF/DALF standards.
///
/// Includes full-length exam specifications (4 Reading tasks, 4 Listening audio tracks,
/// 3 Writing tasks, 3 Speaking parts) AND comprehensive, level-differentiated
/// full-length demo/fallback papers so even offline or demo exams feel authentic.
class CefrExamBlueprints {
  static int defaultTimeLimitMinutes(CefrLevel level, ExamSubtest subtest) {
    return switch (subtest) {
      ExamSubtest.reading => switch (level) {
          CefrLevel.a1 => 30,
          CefrLevel.a2 => 35,
          CefrLevel.b1 => 45,
          CefrLevel.b2 => 55,
          CefrLevel.c1 => 65,
          CefrLevel.c2 => 75,
        },
      ExamSubtest.listening => switch (level) {
          CefrLevel.a1 => 25,
          CefrLevel.a2 => 30,
          CefrLevel.b1 => 35,
          CefrLevel.b2 => 40,
          CefrLevel.c1 => 45,
          CefrLevel.c2 => 45,
        },
      ExamSubtest.writing => switch (level) {
          CefrLevel.a1 => 25,
          CefrLevel.a2 => 35,
          CefrLevel.b1 => 45,
          CefrLevel.b2 => 60,
          CefrLevel.c1 => 75,
          CefrLevel.c2 => 80,
        },
      ExamSubtest.speaking => switch (level) {
          CefrLevel.a1 => 15,
          CefrLevel.a2 => 18,
          CefrLevel.b1 => 20,
          CefrLevel.b2 => 22,
          CefrLevel.c1 => 25,
          CefrLevel.c2 => 25,
        },
    };
  }

  /// Returns expected number of tasks per subtest for UI preview cards.
  static int plannedTaskCount(ExamSubtest subtest) {
    return switch (subtest) {
      ExamSubtest.reading => 4,
      ExamSubtest.listening => 4,
      ExamSubtest.writing => 3,
      ExamSubtest.speaking => 3,
    };
  }

  /// Returns a strict JSON Blueprint matching the CEFR Companion Volume (2020)
  /// descriptors for [level] and [subtest] to inject into `{{exam_blueprint_json}}`.
  static String getBlueprintJson(CefrLevel level, ExamSubtest subtest) {
    final map = buildBlueprintMap(level, subtest);
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static Map<String, dynamic> buildBlueprintMap(
    CefrLevel level,
    ExamSubtest subtest,
  ) {
    final timeLimit = defaultTimeLimitMinutes(level, subtest);

    return switch (subtest) {
      ExamSubtest.reading => {
          'standard':
              'CEFR Companion Volume (2020) / ALTE / Goethe / Cambridge / DELF',
          'subtest': 'Reading',
          'level': level.code,
          'time_limit_minutes': timeLimit,
          'pass_threshold_percent': 60,
          'cefr_companion_descriptor': _readingDescriptor(level),
          'tasks_count': 4,
          'tasks_spec': [
            {
              'task_number': 1,
              'task_type': 'multiple_choice',
              'format': _readingTask1Format(level),
              'stimulus_word_range': _readingWordRange(level, part: 1),
              'questions_count': 5,
              'options_per_question': 3,
              'max_points': 10,
              'rubric':
                  '2 points per correct answer. Full multi-paragraph text testing global comprehension, main ideas, and concrete details.',
            },
            {
              'task_number': 2,
              'task_type': 'matching',
              'format': _readingTask2Format(level),
              'stimulus_word_range': _readingWordRange(level, part: 2),
              'questions_count': 4,
              'options_per_question': 5,
              'max_points': 8,
              'rubric':
                  '2 points per correct match. 5 detailed texts/notices (A–E) matched to 4 people/situations.',
            },
            {
              'task_number': 3,
              'task_type': 'multiple_choice',
              'format': _readingTask3Format(level),
              'stimulus_word_range': _readingWordRange(level, part: 3),
              'questions_count': 4,
              'options_per_question': 3,
              'max_points': 8,
              'rubric':
                  '2 points per correct answer. Detailed practical correspondence, report, or commentary with inference and writer attitude.',
            },
            {
              'task_number': 4,
              'task_type': 'short_answer',
              'format': _readingTask4Format(level),
              'stimulus_word_range': _readingWordRange(level, part: 4),
              'questions_count': 3,
              'options_per_question': 0,
              'max_points': 6,
              'rubric':
                  '2 points per exact factual answer (1–4 words or number extracted from the detailed document).',
            },
          ],
        },
      ExamSubtest.listening => {
          'standard':
              'CEFR Companion Volume (2020) / ALTE / Goethe / Cambridge / DELF',
          'subtest': 'Listening',
          'level': level.code,
          'time_limit_minutes': timeLimit,
          'pass_threshold_percent': 60,
          'cefr_companion_descriptor': _listeningDescriptor(level),
          'tasks_count': 4,
          'tasks_spec': [
            {
              'task_number': 1,
              'task_type': 'multiple_choice',
              'format': _listeningTask1Format(level),
              'stimulus_word_range': _listeningWordRange(level, part: 1),
              'include_visual_prompt_description':
                  level == CefrLevel.a1 || level == CefrLevel.a2,
              'questions_count': 5,
              'options_per_question': 3,
              'max_points': 10,
              'rubric':
                  '2 points per correct item. Extended natural multi-turn spoken dialogue (10–16 turns) for TTS playback.',
            },
            {
              'task_number': 2,
              'task_type': 'matching',
              'format': _listeningTask2Format(level),
              'stimulus_word_range': _listeningWordRange(level, part: 2),
              'questions_count': 4,
              'options_per_question': 5,
              'max_points': 8,
              'rubric':
                  '2 points per correct match between 4 extended speaker monologues/messages and 5 choices (A–E).',
            },
            {
              'task_number': 3,
              'task_type': 'multiple_choice',
              'format': _listeningTask3Format(level),
              'stimulus_word_range': _listeningWordRange(level, part: 3),
              'questions_count': 4,
              'options_per_question': 3,
              'max_points': 8,
              'rubric':
                  '2 points per correct answer. Extended radio broadcast, tour guide talk, or podcast monologue.',
            },
            {
              'task_number': 4,
              'task_type': 'short_answer',
              'format': _listeningTask4Format(level),
              'stimulus_word_range': _listeningWordRange(level, part: 4),
              'questions_count': 3,
              'options_per_question': 0,
              'max_points': 6,
              'rubric':
                  '2 points per exact detail heard (price, time, date, gate, code, keyword).',
            },
          ],
        },
      ExamSubtest.writing => {
          'standard':
              'CEFR Companion Volume (2020) / ALTE / Goethe / Cambridge / DELF',
          'subtest': 'Writing',
          'level': level.code,
          'time_limit_minutes': timeLimit,
          'pass_threshold_percent': 60,
          'cefr_companion_descriptor': _writingDescriptor(level),
          'tasks_count': 3,
          'tasks_spec': [
            {
              'task_number': 1,
              'task_type': 'open_writing',
              'format': _writingTask1Format(level),
              'min_words': _writingMinWords(level, part: 1),
              'max_points': 10,
              'questions_count': 3,
              'rubric':
                  'Task completion covering all 3 bullet points (4 pts), coherence & register (3 pts), lexical & grammatical accuracy for ${level.code} (3 pts).',
            },
            {
              'task_number': 2,
              'task_type': 'open_writing',
              'format': _writingTask2Format(level),
              'min_words': _writingMinWords(level, part: 2),
              'max_points': 10,
              'questions_count': 3,
              'rubric':
                  'Formal/practical register & communicative goal (4 pts), clear paragraphing (3 pts), language range & accuracy for ${level.code} (3 pts).',
            },
            {
              'task_number': 3,
              'task_type': 'open_writing',
              'format': _writingTask3Format(level),
              'include_visual_prompt_description': true,
              'min_words': _writingMinWords(level, part: 3),
              'max_points': 15,
              'questions_count': 3,
              'rubric':
                  'Extended argumentation/narrative & examples (5 pts), logical organization & connectors (5 pts), vocabulary & grammatical range for ${level.code} (5 pts).',
            },
          ],
        },
      ExamSubtest.speaking => {
          'standard':
              'CEFR Companion Volume (2020) / ALTE / Goethe / Cambridge / DELF',
          'subtest': 'Speaking',
          'level': level.code,
          'time_limit_minutes': timeLimit,
          'pass_threshold_percent': 60,
          'cefr_companion_descriptor': _speakingDescriptor(level),
          'tasks_count': 3,
          'tasks_spec': [
            {
              'task_number': 1,
              'task_type': 'speaking_roleplay',
              'format': _speakingTask1Format(level),
              'min_words': _speakingMinWords(level, part: 1),
              'max_points': 10,
              'questions_count': 4,
              'rubric':
                  'Structured interview answering all examiner prompts (4 pts), intelligibility & pronunciation (3 pts), vocabulary & grammar for ${level.code} (3 pts).',
            },
            {
              'task_number': 2,
              'task_type': 'speaking_roleplay',
              'format': _speakingTask2Format(level),
              'min_words': _speakingMinWords(level, part: 2),
              'max_points': 10,
              'questions_count': 3,
              'rubric':
                  'Interactive roleplay & problem solving (4 pts), natural register & fluency (3 pts), accuracy for ${level.code} (3 pts).',
            },
            {
              'task_number': 3,
              'task_type': 'speaking_roleplay',
              'format': _speakingTask3Format(level),
              'include_visual_prompt_description': true,
              'min_words': _speakingMinWords(level, part: 3),
              'max_points': 15,
              'questions_count': 3,
              'rubric':
                  'Sustained monologue comparing visual options & justifying choice (5 pts), fluency & cohesion (5 pts), precision & register for ${level.code} (5 pts).',
            },
          ],
        },
    };
  }

  static String _readingDescriptor(CefrLevel l) => switch (l) {
        CefrLevel.a1 =>
          'Can understand short, concrete everyday texts (notices, personal letters, timetables, simple stories) picking up familiar names, places, numbers, and basic facts.',
        CefrLevel.a2 =>
          'Can understand multi-paragraph texts on familiar everyday matters, personal emails, local guides, and routine workplace notices with high-frequency vocabulary.',
        CefrLevel.b1 =>
          'Can read straightforward factual articles, travel blogs, and workplace correspondence on familiar subjects with solid comprehension of main points and details.',
        CefrLevel.b2 =>
          'Can read extended contemporary articles, reports, and opinion pieces independently, recognising writer attitudes, arguments, and implicit viewpoints.',
        CefrLevel.c1 =>
          'Can understand in detail lengthy, complex analytical and academic texts, including subtle attitudes, rhetorical structure, and implicit meanings.',
        CefrLevel.c2 =>
          'Can understand with ease virtually all forms of written language, including dense scholarly commentary, literary nuance, and complex policy analyses.',
      };

  static String _listeningDescriptor(CefrLevel l) => switch (l) {
        CefrLevel.a1 =>
          'Can follow slow, clearly articulated everyday dialogues and announcements about times, prices, shopping, family, and daily routines.',
        CefrLevel.a2 =>
          'Can understand extended everyday conversations, voice messages, and travel announcements on topics of immediate relevance.',
        CefrLevel.b1 =>
          'Can understand straightforward factual information in extended interviews, radio features, and workplace discussions, identifying both main points and specific details.',
        CefrLevel.b2 =>
          'Can understand extended standard spoken language in podcasts, interviews, and panel talks, identifying speaker viewpoints, arguments, and tone.',
        CefrLevel.c1 =>
          'Can follow extended, complex spoken discourse, lectures, and debates even when relationships are implied, recognising idioms and register shifts.',
        CefrLevel.c2 =>
          'Can understand virtually any extended spoken language delivered at natural speed, including nuanced critical debate, understatement, and irony.',
      };

  static String _writingDescriptor(CefrLevel l) => switch (l) {
        CefrLevel.a1 =>
          'Can write simple connected notes, SMS replies, postcards, and short personal descriptions about familiar daily topics.',
        CefrLevel.a2 =>
          'Can write personal emails, short invitations, diary entries, and simple practical messages linked with basic connectors.',
        CefrLevel.b1 =>
          'Can produce connected multi-paragraph emails, reviews, and opinion texts describing experiences, reasons, and plans.',
        CefrLevel.b2 =>
          'Can produce clear, detailed formal letters, reports, and discursive essays synthesising arguments and evaluating options.',
        CefrLevel.c1 =>
          'Can produce well-structured, detailed proposals, executive reports, and argumentative essays with appropriate register and rhetorical flow.',
        CefrLevel.c2 =>
          'Can produce complex, smoothly flowing analytical and editorial texts demonstrating stylistic mastery and idiomatic precision.',
      };

  static String _speakingDescriptor(CefrLevel l) => switch (l) {
        CefrLevel.a1 =>
          'Can introduce themselves, answer concrete personal questions, and manage basic everyday transactions using simple phrases.',
        CefrLevel.a2 =>
          'Can describe daily routines, past trips, and surroundings in connected sentences and handle practical service roleplays.',
        CefrLevel.b1 =>
          'Can sustain a clear description or monologue on familiar topics, resolve practical travel/work problems in roleplay, and explain personal opinions.',
        CefrLevel.b2 =>
          'Can develop clear, well-supported arguments, negotiate solutions in professional/social roleplays, and compare complex options fluently.',
        CefrLevel.c1 =>
          'Can present structured arguments on complex societal or professional topics, mediate disagreements diplomatically, and respond spontaneously.',
        CefrLevel.c2 =>
          'Can express nuanced viewpoints effortlessly and precisely, handling subtle counterarguments and complex dilemmas spontaneously.',
      };

  static String _readingTask1Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Multi-paragraph community notice & local event guide',
        CefrLevel.a2 => 'Personal travel letter / neighborhood newsletter article',
        CefrLevel.b1 => 'Feature magazine article on lifestyle, work, or travel',
        CefrLevel.b2 => 'In-depth newspaper feature exploring pros, cons, and attitudes',
        CefrLevel.c1 => 'Long-form analytical essay with nuanced perspectives',
        CefrLevel.c2 => 'Dense academic / cultural critical essay with stylistic subtlety',
      };

  static String _readingTask2Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Match 4 people’s needs to 5 detailed community ads (A–E)',
        CefrLevel.a2 => 'Match 4 readers to 5 detailed weekend courses/clubs (A–E)',
        CefrLevel.b1 => 'Match 4 travelers/professionals to 5 detailed programs (A–E)',
        CefrLevel.b2 => 'Match 4 readers’ goals to 5 extended reviews/articles (A–E)',
        CefrLevel.c1 => 'Match 4 complex research briefs to 5 editorial positions (A–E)',
        CefrLevel.c2 => 'Match 4 critical stances to 5 scholarly abstracts (A–E)',
      };

  static String _readingTask3Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Detailed personal email about weekend plans & family visit',
        CefrLevel.a2 => 'Customer service email & local museum visitor information',
        CefrLevel.b1 => 'Workplace policy memo & employee feedback summary',
        CefrLevel.b2 => 'Editorial commentary on technology, society, or education',
        CefrLevel.c1 => 'Policy report examining systemic economic or urban trends',
        CefrLevel.c2 => 'Philosophical / scientific review analysing conflicting theories',
      };

  static String _readingTask4Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Detailed train/bus booking confirmation & station guide',
        CefrLevel.a2 => 'Hotel & excursion itinerary with exact times, prices, and rules',
        CefrLevel.b1 => 'University/course orientation handbook excerpt with exact deadlines',
        CefrLevel.b2 => 'Corporate project brief with budget figures, milestones, and contacts',
        CefrLevel.c1 => 'Empirical study summary extracting exact metrics and caveats',
        CefrLevel.c2 => 'Regulatory & institutional white paper extracting exact clauses',
      };

  static String _readingWordRange(CefrLevel l, {required int part}) =>
      switch (l) {
        CefrLevel.a1 => part == 4 ? '120–160 words' : '150–210 words',
        CefrLevel.a2 => part == 4 ? '150–200 words' : '190–260 words',
        CefrLevel.b1 => part == 4 ? '180–240 words' : '240–330 words',
        CefrLevel.b2 => part == 4 ? '210–280 words' : '300–400 words',
        CefrLevel.c1 => part == 4 ? '240–320 words' : '360–460 words',
        CefrLevel.c2 => part == 4 ? '260–350 words' : '400–520 words',
      };

  static String _listeningTask1Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Extended 12-turn dialogue at a hotel reception / train station',
        CefrLevel.a2 => 'Extended 12-turn phone conversation planning a trip or event',
        CefrLevel.b1 => 'Extended radio interview (12–14 turns) with an entrepreneur or traveler',
        CefrLevel.b2 => 'Extended podcast discussion weighing arguments on work or society',
        CefrLevel.c1 => 'Extended panel debate with implicit disagreements and nuance',
        CefrLevel.c2 => 'Extended critical seminar dialogue with idioms and subtle irony',
      };

  static String _listeningTask2Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => '4 extended voice messages from friends about daily plans',
        CefrLevel.a2 => '4 extended public announcements & customer calls',
        CefrLevel.b1 => '4 extended radio caller opinions on a community topic',
        CefrLevel.b2 => '4 professionals describing distinct career challenges',
        CefrLevel.c1 => '4 policy analysts giving contrasting interpretations',
        CefrLevel.c2 => '4 cultural critics assessing an intellectual trend',
      };

  static String _listeningTask3Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Extended guided walking tour introduction for visitors',
        CefrLevel.a2 => 'Extended local radio community bulletin & weather/events report',
        CefrLevel.b1 => 'Extended documentary radio segment about an inspiring project',
        CefrLevel.b2 => 'Extended conference keynote excerpt on innovation and wellbeing',
        CefrLevel.c1 => 'Extended university lecture excerpt on behavioral science',
        CefrLevel.c2 => 'Extended broadcast essay exploring historical & modern paradoxes',
      };

  static String _listeningTask4Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Detailed voicemail & airport/station transfer announcement',
        CefrLevel.a2 => 'Detailed tour operator phone briefing with times, prices, and meeting point',
        CefrLevel.b1 => 'Detailed festival / seminar organizer briefing with deadlines and fees',
        CefrLevel.b2 => 'Detailed project kick-off briefing with deliverables and constraints',
        CefrLevel.c1 => 'Detailed research briefing with methodology numbers and exceptions',
        CefrLevel.c2 => 'Detailed policy briefing with exact thresholds and legal caveats',
      };

  static String _listeningWordRange(CefrLevel l, {required int part}) =>
      switch (l) {
        CefrLevel.a1 => '150–210 words spoken script (~1.2–1.6 min audio)',
        CefrLevel.a2 => '200–270 words spoken script (~1.5–2.0 min audio)',
        CefrLevel.b1 => '260–340 words spoken script (~1.8–2.4 min audio)',
        CefrLevel.b2 => '310–410 words spoken script (~2.2–2.8 min audio)',
        CefrLevel.c1 => '360–460 words spoken script (~2.5–3.2 min audio)',
        CefrLevel.c2 => '400–500 words spoken script (~2.8–3.5 min audio)',
      };

  static String _writingTask1Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Personal SMS / email reply answering 3 concrete questions',
        CefrLevel.a2 => 'Informal email to a friend about weekend plans & invitation details',
        CefrLevel.b1 => 'Semi-formal email explaining a change of plan, apologising, and suggesting alternatives',
        CefrLevel.b2 => 'Formal letter of inquiry/complaint detailing issues and requesting action',
        CefrLevel.c1 => 'Formal executive proposal addressing an organizational challenge',
        CefrLevel.c2 => 'Critical letter to the editor responding to a published argument',
      };

  static String _writingTask2Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Short note to a neighbor or teacher explaining a practical schedule change',
        CefrLevel.a2 => 'Review of a café, hotel, or course you recently visited',
        CefrLevel.b1 => 'Detailed product/event review or practical report with recommendations',
        CefrLevel.b2 => 'Structured workplace/community report evaluating options and giving recommendations',
        CefrLevel.c1 => 'Analytical policy brief weighing stakeholder perspectives',
        CefrLevel.c2 => 'Synthesis report reconciling conflicting empirical sources',
      };

  static String _writingTask3Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Short illustrated postcard / personal story describing a weekend day',
        CefrLevel.a2 => 'Picture-prompt narrative describing a memorable trip or experience',
        CefrLevel.b1 => 'Opinion essay / forum article with 2–3 reasons and personal example',
        CefrLevel.b2 => 'Discursive opinion essay weighing advantages, disadvantages, and clear conclusion',
        CefrLevel.c1 => 'Extended argumentative essay with counter-arguments, evidence, and nuanced conclusion',
        CefrLevel.c2 => 'Mastery analytical essay demonstrating rhetorical elegance and idiomatic command',
      };

  static int _writingMinWords(CefrLevel l, {required int part}) => switch (l) {
        CefrLevel.a1 => part == 3 ? 45 : 30,
        CefrLevel.a2 => part == 3 ? 75 : 50,
        CefrLevel.b1 => part == 3 ? 120 : 80,
        CefrLevel.b2 => part == 3 ? 170 : 120,
        CefrLevel.c1 => part == 3 ? 210 : 150,
        CefrLevel.c2 => part == 3 ? 250 : 180,
      };

  static String _speakingTask1Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Structured personal interview (4 simple questions on home, family, hobbies, schedule)',
        CefrLevel.a2 => 'Extended personal interview on recent weekend, work/studies, and favorite places',
        CefrLevel.b1 => 'Interview on personal experiences, learning goals, and travel memories',
        CefrLevel.b2 => 'In-depth interview on career choices, modern habits, and social change',
        CefrLevel.c1 => 'Academic/professional interview exploring complex values and cultural trends',
        CefrLevel.c2 => 'Spontaneous high-level interview probing subtle intellectual positions',
      };

  static String _speakingTask2Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Everyday service roleplay (ordering food, buying a ticket, asking prices/times)',
        CefrLevel.a2 => 'Practical problem roleplay (rescheduling an appointment or exchanging an item)',
        CefrLevel.b1 => 'Guided negotiation roleplay planning a joint trip or resolving a hotel issue',
        CefrLevel.b2 => 'Workplace/community negotiation balancing competing priorities diplomatically',
        CefrLevel.c1 => 'Complex mediation roleplay resolving a conflict between two teams',
        CefrLevel.c2 => 'High-stakes diplomatic negotiation handling unexpected objections',
      };

  static String _speakingTask3Format(CefrLevel l) => switch (l) {
        CefrLevel.a1 => 'Describe a pictured everyday scene and answer 3 simple follow-up questions',
        CefrLevel.a2 => 'Compare two familiar daily activities from a visual prompt and state preferences',
        CefrLevel.b1 => 'Sustained monologue on a visual scenario comparing two options with reasons',
        CefrLevel.b2 => 'Structured presentation comparing two societal approaches + critical evaluation',
        CefrLevel.c1 => 'Extended analytical talk integrating visual data, trade-offs, and long-term impact',
        CefrLevel.c2 => 'Spontaneous critical commentary on a multifaceted dilemma with nuanced synthesis',
      };

  static int _speakingMinWords(CefrLevel l, {required int part}) => switch (l) {
        CefrLevel.a1 => part == 3 ? 20 : 15,
        CefrLevel.a2 => part == 3 ? 30 : 22,
        CefrLevel.b1 => part == 3 ? 45 : 35,
        CefrLevel.b2 => part == 3 ? 60 : 45,
        CefrLevel.c1 => part == 3 ? 75 : 55,
        CefrLevel.c2 => part == 3 ? 90 : 65,
      };

  /// Full-length, multi-tier certification fallback paper (localized automatically
  /// into `targetLanguage` and `nativeLanguage` if AI is offline or in Demo mode).
  /// Contains 4 full Reading tasks (16 Qs), 4 long Listening tracks (16 Qs),
  /// 3 Writing tasks, and 3 Speaking parts tailored to A1-A2, B1-B2, and C1-C2!
  static OfficialExamSubtestPaper buildEnglishFallbackPaper({
    required CefrLevel level,
    required ExamSubtest subtest,
    required LanguageOption targetLanguage,
  }) {
    final timeLimit = defaultTimeLimitMinutes(level, subtest);
    final meta = ExamMeta(
      language: targetLanguage.englishName,
      level: level.code,
      subtest: subtest,
      timeLimitMinutes: timeLimit,
      passThresholdPercent: 60,
    );

    final tasks = switch (subtest) {
      ExamSubtest.reading => _fallbackReadingTasks(level),
      ExamSubtest.listening => _fallbackListeningTasks(level),
      ExamSubtest.writing => _fallbackWritingTasks(level),
      ExamSubtest.speaking => _fallbackSpeakingTasks(level),
    };

    return OfficialExamSubtestPaper(
      examMeta: meta,
      tasks: tasks,
      usedAi: false,
      providerUsed: 'CEFR Full Blueprint Exam',
    );
  }

  static int _tier(CefrLevel l) {
    if (l == CefrLevel.a1 || l == CefrLevel.a2) return 0; // Basic
    if (l == CefrLevel.b1 || l == CefrLevel.b2) return 1; // Independent
    return 2; // Proficient (C1-C2)
  }

  // ===========================================================================
  // FULL-LENGTH READING FALLBACK (4 TASKS, 16 QUESTIONS, 32 POINTS)
  // ===========================================================================
  static List<OfficialExamTask> _fallbackReadingTasks(CefrLevel l) {
    final tier = _tier(l);

    // --- TASK 1: Extended Multi-Paragraph Article (5 Multiple Choice Qs) ---
    final task1 = switch (tier) {
      0 => const OfficialExamTask(
          taskNumber: 1,
          taskType: OfficialTaskType.multipleChoice,
          instructionUi:
              'Read the full community newsletter article below carefully and choose the single correct answer (A, B, or C) for each of the 5 questions.',
          instructionTarget:
              'Read the text carefully and select the best answer (A, B, or C) for questions 1–5.',
          stimulus: ExamStimulus(
            textOrTranscript:
                'Welcome to the Newly Renovated Riverside Community Center!\n\n'
                'After six months of building work, Riverside Community Center opens its doors again this Monday at 8:00 AM. '
                'Our building now has a bright main library on the first floor, a quiet study hall with forty desks, and a brand-new family café overlooking the river garden. '
                'On weekdays, the center stays open until 8:30 PM so students and working adults can visit in the evening. On Saturdays, we open at 9:00 AM and close at 5:00 PM. We remain closed on Sundays for cleaning and maintenance.\n\n'
                'Becoming a member is quick and completely free for residents, students, and seniors. Simply bring a photo ID or student card to the front desk. '
                'Members can borrow up to six books at a time for three weeks, reserve free laptop lockers, and sign up for weekly language exchange tables every Wednesday evening.\n\n'
                'Please remember two simple house rules: food and hot drinks are welcome only inside the ground-floor café, not in the reading rooms, and mobile phones should stay on silent mode upstairs. '
                'To celebrate our reopening, this Saturday afternoon we are hosting a free live acoustic concert and a children’s book swap in the courtyard starting at 2:00 PM. Everyone in the neighborhood is warmly invited!',
          ),
          questions: [
            OfficialExamQuestionItem(
              id: 1,
              questionText: 'How long was the community center closed for renovation?',
              options: ['A) Three weeks', 'B) Six months', 'C) One full year'],
              correctAnswer: 'B',
              explanation: 'The first paragraph states: "After six months of building work, Riverside Community Center opens its doors again."',
            ),
            OfficialExamQuestionItem(
              id: 2,
              questionText: 'What time does the center close on Saturdays?',
              options: ['A) 5:00 PM', 'B) 8:30 PM', 'C) 2:00 PM'],
              correctAnswer: 'A',
              explanation: 'On Saturdays, the center opens at 9:00 AM and closes at 5:00 PM.',
            ),
            OfficialExamQuestionItem(
              id: 3,
              questionText: 'How many books can a registered member borrow at one time?',
              options: ['A) Up to three books', 'B) Up to six books', 'C) Up to forty books'],
              correctAnswer: 'B',
              explanation: 'Members can borrow up to six books at a time for three weeks.',
            ),
            OfficialExamQuestionItem(
              id: 4,
              questionText: 'Where are visitors allowed to drink coffee or eat snacks?',
              options: [
                'A) In the upstairs quiet study hall',
                'B) Only in the ground-floor café',
                'C) Anywhere inside the library',
              ],
              correctAnswer: 'B',
              explanation: 'The house rules say food and hot drinks are welcome only inside the ground-floor café.',
            ),
            OfficialExamQuestionItem(
              id: 5,
              questionText: 'What special event takes place this Saturday at 2:00 PM?',
              options: [
                'A) A free concert and children’s book swap',
                'B) A weekly language exchange table',
                'C) A building cleaning day',
              ],
              correctAnswer: 'A',
              explanation: 'This Saturday afternoon features a free live acoustic concert and a children’s book swap starting at 2:00 PM.',
            ),
          ],
          evaluationCriteria: ExamEvaluationCriteria(
            minWords: 0,
            maxPoints: 10,
            rubric: '2 points per correct answer (max 10 points).',
          ),
        ),
      1 => const OfficialExamTask(
          taskNumber: 1,
          taskType: OfficialTaskType.multipleChoice,
          instructionUi:
              'Read the magazine feature article below carefully and select the single best option (A, B, or C) for each of the 5 questions.',
          instructionTarget:
              'Read the article thoroughly and choose the correct answer (A, B, or C) for questions 1–5.',
          stimulus: ExamStimulus(
            textOrTranscript:
                'Why European Cities Are Rethinking the Fifteen-Minute Neighborhood\n\n'
                'For decades, urban planners assumed that modern cities needed wider highways and larger shopping complexes on the outskirts. '
                'Yet over the past five years, municipal leaders from Vienna to Lyon have begun reversing that logic by adopting the "fifteen-minute city" model. '
                'The central idea is remarkably straightforward: residents should be able to reach essential daily services—groceries, primary healthcare, schools, green parks, and local workspaces—within a fifteen-minute walk or bicycle ride from their front door.\n\n'
                'Last year, a joint university study tracked 2,400 households across three pilot districts that redesigned major streets into tree-lined pedestrian corridors and protected bike lanes. '
                'Within eighteen months, short car trips under three kilometers dropped by nearly 34 percent, while foot traffic at independent neighborhood bakeries, bookshops, and repair cafés rose by 28 percent. '
                'Residents also reported lower evening noise levels and higher satisfaction with local air quality.\n\n'
                'However, urban sociologists warn that the model is not without challenges. When certain central neighborhoods become significantly greener and quieter, property rents often climb rapidly, pushing lower-income families further away from the very amenities designed to help them. '
                'To prevent this imbalance, successful cities pair street redesigns with strict affordable housing quotas and reliable public transit connecting outer suburbs to neighborhood hubs. '
                'As city planner Clara Novak explains, "A livable city cannot be a luxury reserved for a few postal codes; accessibility must belong to everyone."',
          ),
          questions: [
            OfficialExamQuestionItem(
              id: 1,
              questionText: 'What is the main goal of the "fifteen-minute city" concept?',
              options: [
                'A) Building faster highways between suburbs and shopping malls',
                'B) Ensuring daily essentials are reachable within 15 minutes on foot or by bike',
                'C) Limiting public transport routes to central tourist zones',
              ],
              correctAnswer: 'B',
              explanation: 'The first paragraph defines it as reaching essential daily services within a 15-minute walk or bike ride.',
            ),
            OfficialExamQuestionItem(
              id: 2,
              questionText: 'What happened to local independent shops during the 18-month pilot study?',
              options: [
                'A) Foot traffic increased by 28 percent',
                'B) Sales fell because drivers could not park outside',
                'C) Nearly 34 percent of shops moved to the outskirts',
              ],
              correctAnswer: 'A',
              explanation: 'The study recorded a 28% rise in foot traffic at independent bakeries, bookshops, and repair cafés.',
            ),
            OfficialExamQuestionItem(
              id: 3,
              questionText: 'What negative side effect do urban sociologists warn about?',
              options: [
                'A) Increased street noise during the evening',
                'B) Rising housing rents that can displace lower-income families',
                'C) Longer travel times to primary schools',
              ],
              correctAnswer: 'B',
              explanation: 'Sociologists warn that greener, quieter neighborhoods often see rapid rent increases pushing lower-income families out.',
            ),
            OfficialExamQuestionItem(
              id: 4,
              questionText: 'How do successful cities prevent this unintended inequality?',
              options: [
                'A) By banning bicycles from outer districts',
                'B) By combining street redesigns with affordable housing quotas and strong transit links',
                'C) By cancelling park projects in residential districts',
              ],
              correctAnswer: 'B',
              explanation: 'Paragraph 3 notes they pair street redesigns with strict affordable housing quotas and reliable transit.',
            ),
            OfficialExamQuestionItem(
              id: 5,
              questionText: 'What is Clara Novak’s overall message at the end of the article?',
              options: [
                'A) Only historic downtown areas deserve green spaces',
                'B) Urban livability and accessibility should benefit all residents equally',
                'C) Private cars should be completely outlawed nationwide',
              ],
              correctAnswer: 'B',
              explanation: 'Novak emphasizes that a livable city cannot be a luxury for a few postal codes and accessibility must belong to everyone.',
            ),
          ],
          evaluationCriteria: ExamEvaluationCriteria(
            minWords: 0,
            maxPoints: 10,
            rubric: '2 points per correct answer (max 10 points).',
          ),
        ),
      _ => const OfficialExamTask(
          taskNumber: 1,
          taskType: OfficialTaskType.multipleChoice,
          instructionUi:
              'Read the analytical essay below closely, paying attention to implicit arguments and rhetorical nuance, and select the best answer (A, B, or C) for questions 1–5.',
          instructionTarget:
              'Read the following essay carefully and choose the single most accurate answer (A, B, or C) for questions 1–5.',
          stimulus: ExamStimulus(
            textOrTranscript:
                'The Paradox of Algorithmic Efficiency in Creative Knowledge Work\n\n'
                'Whenever a transformative productivity tool enters the workplace, public debate tends to polarize between utopian promises of liberation and bleak forecasts of obsolescence. '
                'Yet longitudinal research on automated decision-support systems suggests a subtler reality: while algorithmic assistants compress the time required to produce routine drafts and summarize vast datasets, they simultaneously alter how professionals cultivate judgment. '
                'Historically, junior analysts, architects, and editors honed their diagnostic instincts precisely by wrestling with tedious preliminary tasks—synthesizing messy primary sources, testing dead-end hypotheses, and revising flawed prototypes.\n\n'
                'A recent comparative study of four European engineering consultancies illustrates this tension. Teams that integrated generative design tools reduced initial proposal turnaround by nearly 40 percent, delighting clients with rapid iterations. '
                'Nevertheless, internal peer reviews eighteen months later revealed an unexpected vulnerability: junior engineers who relied heavily on pre-generated templates struggled to detect subtle structural anomalies when atypical site constraints appeared. '
                'In contrast, firms that embedded "deliberate friction"—requiring junior staff to annotate assumptions manually and defend design trade-offs before consulting automated models—retained both high speed and rigorous diagnostic accuracy.\n\n'
                'The lesson is neither to reject automation nor to worship raw speed, but to distinguish between friction that merely wastes time and cognitive friction that builds durable mastery. '
                'Organizations that treat efficiency as an end in itself risk hollowing out the very human expertise required to audit automated outputs when stakes are highest.',
          ),
          questions: [
            OfficialExamQuestionItem(
              id: 1,
              questionText: 'According to the author, what vital role did tedious preliminary tasks historically play?',
              options: [
                'A) They prevented junior staff from interacting with clients',
                'B) They helped newcomers develop diagnostic judgment through hands-on struggle',
                'C) They slowed projects down without offering any educational value',
              ],
              correctAnswer: 'B',
              explanation: 'Paragraph 1 argues that junior professionals honed diagnostic instincts precisely by wrestling with messy preliminary tasks.',
            ),
            OfficialExamQuestionItem(
              id: 2,
              questionText: 'What unexpected weakness emerged in the engineering consultancies after 18 months?',
              options: [
                'A) Clients were dissatisfied with the speed of proposals',
                'B) Over-reliance on templates weakened junior engineers’ ability to spot atypical flaws',
                'C) Senior partners refused to review automated blueprints',
              ],
              correctAnswer: 'B',
              explanation: 'Peer reviews showed junior engineers relying heavily on templates struggled to detect subtle anomalies under atypical constraints.',
            ),
            OfficialExamQuestionItem(
              id: 3,
              questionText: 'What does "deliberate friction" refer to in the second paragraph?',
              options: [
                'A) Intentionally delaying client deliveries to increase billing hours',
                'B) Requiring manual assumption checks and trade-off justification before using automation',
                'C) Removing all digital tools from engineering workflows',
              ],
              correctAnswer: 'B',
              explanation: 'Firms using deliberate friction required staff to annotate assumptions manually and defend trade-offs first.',
            ),
            OfficialExamQuestionItem(
              id: 4,
              questionText: 'What distinction does the author draw in the final paragraph?',
              options: [
                'A) Between wasteful administrative delay and productive cognitive effort that builds expertise',
                'B) Between European and American engineering standards',
                'C) Between open-source and proprietary software licenses',
              ],
              correctAnswer: 'A',
              explanation: 'The author contrasts friction that merely wastes time with cognitive friction that builds durable mastery.',
            ),
            OfficialExamQuestionItem(
              id: 5,
              questionText: 'What overall risk does the author warn organizations against?',
              options: [
                'A) Investing too much in staff mentoring',
                'B) Pursuing speed alone at the expense of the human expertise needed to audit outputs',
                'C) Allowing clients to inspect preliminary prototypes',
              ],
              correctAnswer: 'B',
              explanation: 'The closing sentence warns that treating efficiency as an end in itself hollows out the expertise needed to audit automated outputs.',
            ),
          ],
          evaluationCriteria: ExamEvaluationCriteria(
            minWords: 0,
            maxPoints: 10,
            rubric: '2 points per correct answer (max 10 points).',
          ),
        ),
    };

    // --- TASK 2: Extended Matching (5 Rich Descriptions A-E, 4 Matching Qs) ---
    final task2 = switch (tier) {
      0 => const OfficialExamTask(
          taskNumber: 2,
          taskType: OfficialTaskType.matching,
          instructionUi:
              'Read the 5 detailed local club and course announcements (A–E) carefully, then match each person (1–4) to the single most suitable option.',
          instructionTarget:
              'Read descriptions A–E and match each person (1–4) to the best option.',
          stimulus: ExamStimulus(
            textOrTranscript:
                'A) Riverbank Cycling Club — Join our friendly guided bike rides every Saturday morning from 9:00 to 12:30 along flat riverside paths. All bicycles, helmets, and reflective vests are provided free of charge, so beginners without their own bike are very welcome.\n\n'
                'B) Evening Clay & Pottery Studio — Unwind after work at our relaxed two-hour ceramics workshops every Tuesday and Thursday from 18:30. Our instructor teaches beginners how to shape mugs and bowls by hand. All clay, glaze, and kiln firing fees are included.\n\n'
                'C) World Voices Language Café — Practice real-life conversation in small groups with native speakers over complimentary tea and pastries every Wednesday evening from 19:00 to 21:00. No textbooks or grammar exams—just lively discussion for A1 to C1 learners.\n\n'
                'D) Neighborhood Tech Repair Clinic — Do you have a slow laptop, cracked tablet, or broken coffee maker? Our volunteer engineers offer free hands-on diagnostics and repair advice every Sunday afternoon between 13:00 and 17:00. Bring only replacement parts if needed.\n\n'
                'E) Sunrise Urban Gardening Group — Help grow organic herbs and vegetables in our rooftop community plot every Friday morning from 7:30 to 9:30. Members take home a basket of fresh seasonal produce each week.',
          ),
          questions: [
            OfficialExamQuestionItem(
              id: 1,
              questionText:
                  'Elena works until 18:00 on weekdays and wants to improve her spoken conversation in a relaxed group without textbooks.',
              options: [
                'A) Riverbank Cycling Club',
                'B) Evening Clay & Pottery Studio',
                'C) World Voices Language Café',
                'D) Neighborhood Tech Repair Clinic',
                'E) Sunrise Urban Gardening Group',
              ],
              correctAnswer: 'C',
              explanation: 'World Voices Language Café meets Wednesday evenings at 19:00 for relaxed conversation without textbooks.',
            ),
            OfficialExamQuestionItem(
              id: 2,
              questionText:
                  'Marco loves active outdoor weekends in nature, but he recently moved to the city and has not bought a bicycle yet.',
              options: [
                'A) Riverbank Cycling Club',
                'B) Evening Clay & Pottery Studio',
                'C) World Voices Language Café',
                'D) Neighborhood Tech Repair Clinic',
                'E) Sunrise Urban Gardening Group',
              ],
              correctAnswer: 'A',
              explanation: 'Riverbank Cycling Club rides on Saturday mornings and provides bicycles and helmets for free.',
            ),
            OfficialExamQuestionItem(
              id: 3,
              questionText:
                  'Sofia’s old laptop stopped charging properly, and she is looking for free volunteer help on the weekend.',
              options: [
                'A) Riverbank Cycling Club',
                'B) Evening Clay & Pottery Studio',
                'C) World Voices Language Café',
                'D) Neighborhood Tech Repair Clinic',
                'E) Sunrise Urban Gardening Group',
              ],
              correctAnswer: 'D',
              explanation: 'Neighborhood Tech Repair Clinic offers free volunteer laptop diagnostics on Sunday afternoons.',
            ),
            OfficialExamQuestionItem(
              id: 4,
              questionText:
                  'Tomas wants a calm creative hobby on Thursday evenings where he can make handmade gifts with all materials included.',
              options: [
                'A) Riverbank Cycling Club',
                'B) Evening Clay & Pottery Studio',
                'C) World Voices Language Café',
                'D) Neighborhood Tech Repair Clinic',
                'E) Sunrise Urban Gardening Group',
              ],
              correctAnswer: 'B',
              explanation: 'Evening Clay & Pottery Studio runs Thursday evenings at 18:30 with all materials included.',
            ),
          ],
          evaluationCriteria: ExamEvaluationCriteria(
            minWords: 0,
            maxPoints: 8,
            rubric: '2 points per accurate match (max 8 points).',
          ),
        ),
      _ => const OfficialExamTask(
          taskNumber: 2,
          taskType: OfficialTaskType.matching,
          instructionUi:
              'Read the 5 detailed professional development & fellowship descriptions (A–E), then match each candidate (1–4) to the program that best fits their profile.',
          instructionTarget:
              'Read program descriptions A–E and match each candidate (1–4) to the single best option.',
          stimulus: ExamStimulus(
            textOrTranscript:
                'A) Alpine Renewable Energy Lab — A six-month paid field placement in mountain hydro and solar microgrids. Applicants must hold an engineering degree and be willing to spend four days a week inspecting remote outdoor stations in all weather conditions.\n\n'
                'B) Civic Data Journalism Fellowship — Designed for writers and researchers passionate about public transparency. Fellows spend twelve weeks analyzing open municipal budgets, interviewing local policymakers, and publishing interactive visual investigations. Fully remote with weekly editorial mentoring.\n\n'
                'C) Multilingual Cultural Heritage Residency — Open to historians, museum curators, and linguists fluent in at least two European languages. Residents catalog archival manuscripts in Prague and coordinate public exhibitions for international visitors. Accommodation near the museum is fully funded.\n\n'
                'D) Sustainable Packaging Accelerator — Supports early-stage startup founders who already have a working physical prototype reducing plastic waste in food delivery. Includes seed funding, laboratory testing equipment, and pitch coaching for green investors.\n\n'
                'E) Clinical Communication Workshop Series — A flexible evening seminar program for doctors, nurses, and hospital administrators seeking practical strategies for empathetic patient consultations and cross-cultural healthcare mediation.',
          ),
          questions: [
            OfficialExamQuestionItem(
              id: 1,
              questionText:
                  'Nadia is an investigative reporter who works from home and wants mentorship in turning public budget figures into interactive stories.',
              options: [
                'A) Alpine Renewable Energy Lab',
                'B) Civic Data Journalism Fellowship',
                'C) Multilingual Cultural Heritage Residency',
                'D) Sustainable Packaging Accelerator',
                'E) Clinical Communication Workshop Series',
              ],
              correctAnswer: 'B',
              explanation: 'Civic Data Journalism Fellowship focuses on municipal budgets, interactive stories, remote work, and editorial mentoring.',
            ),
            OfficialExamQuestionItem(
              id: 2,
              questionText:
                  'Lukas developed a biodegradable takeaway cup prototype in his garage and needs lab testing and investor pitch coaching.',
              options: [
                'A) Alpine Renewable Energy Lab',
                'B) Civic Data Journalism Fellowship',
                'C) Multilingual Cultural Heritage Residency',
                'D) Sustainable Packaging Accelerator',
                'E) Clinical Communication Workshop Series',
              ],
              correctAnswer: 'D',
              explanation: 'Sustainable Packaging Accelerator supports founders with working prototypes reducing plastic waste in food delivery.',
            ),
            OfficialExamQuestionItem(
              id: 3,
              questionText:
                  'Dr. Amira manages a busy city hospital clinic during the day and wants evening training on sensitive cross-cultural patient communication.',
              options: [
                'A) Alpine Renewable Energy Lab',
                'B) Civic Data Journalism Fellowship',
                'C) Multilingual Cultural Heritage Residency',
                'D) Sustainable Packaging Accelerator',
                'E) Clinical Communication Workshop Series',
              ],
              correctAnswer: 'E',
              explanation: 'Clinical Communication Workshop Series offers evening seminars for healthcare professionals on patient consultations.',
            ),
            OfficialExamQuestionItem(
              id: 4,
              questionText:
                  'Matteo speaks three languages, researches historical archives, and is looking for a funded stay abroad to help curate museum exhibitions.',
              options: [
                'A) Alpine Renewable Energy Lab',
                'B) Civic Data Journalism Fellowship',
                'C) Multilingual Cultural Heritage Residency',
                'D) Sustainable Packaging Accelerator',
                'E) Clinical Communication Workshop Series',
              ],
              correctAnswer: 'C',
              explanation: 'Multilingual Cultural Heritage Residency funds accommodation for linguists/historians curating exhibitions in Prague.',
            ),
          ],
          evaluationCriteria: ExamEvaluationCriteria(
            minWords: 0,
            maxPoints: 8,
            rubric: '2 points per accurate match (max 8 points).',
          ),
        ),
    };

    // --- TASK 3: Detailed Email / Workplace Memo (4 Multiple Choice Qs) ---
    final task3 = switch (tier) {
      0 => const OfficialExamTask(
          taskNumber: 3,
          taskType: OfficialTaskType.multipleChoice,
          instructionUi:
              'Read the email from a language school coordinator carefully and answer questions 1–4.',
          instructionTarget:
              'Read the email below and select the correct answer (A, B, or C) for each question.',
          stimulus: ExamStimulus(
            textOrTranscript:
                'Subject: Important Updates for Next Week’s Summer Language Camp\n\n'
                'Dear Students,\n\n'
                'We are excited to welcome everyone to our two-week Summer Language Camp starting Monday, 12 July! '
                'Please note a few important changes to our original timetable. Because the main hall is being painted on Monday morning, our welcome registration will now take place in Room 204 on the second floor instead of the ground-floor lobby. '
                'Registration opens at 8:45 AM, and placement interviews begin promptly at 9:30 AM.\n\n'
                'Every morning from Monday to Friday, you will attend conversation and grammar workshops until 12:30 PM. '
                'Hot lunch is served in the courtyard canteen—vegetarian and gluten-free meals are available every day if you tick your preference on the registration card. '
                'In the afternoons, we organize cultural outings: on Wednesday we will take a guided boat tour along the harbor, and on Friday afternoon all groups will present short cooking demonstrations using traditional recipes.\n\n'
                'Please bring a notebook, a refillable water bottle, and comfortable walking shoes for the excursions. All textbooks and audio study packs are already included in your course fee, so you do not need to buy anything beforehand.\n\n'
                'Warm regards,\nHannah Weber, Camp Coordinator',
          ),
          questions: [
            OfficialExamQuestionItem(
              id: 1,
              questionText: 'Why was Monday’s registration moved to Room 204?',
              options: [
                'A) The main hall is being painted',
                'B) Too many students cancelled their trip',
                'C) Room 204 is next to the harbor',
              ],
              correctAnswer: 'A',
              explanation: 'The email states: "Because the main hall is being painted on Monday morning, our welcome registration will now take place in Room 204."',
            ),
            OfficialExamQuestionItem(
              id: 2,
              questionText: 'How can students request a vegetarian or gluten-free lunch?',
              options: [
                'A) By bringing their own food from home',
                'B) By ticking their preference on the registration card',
                'C) By paying an extra fee on Friday',
              ],
              correctAnswer: 'B',
              explanation: 'Students just need to tick their preference on the registration card.',
            ),
            OfficialExamQuestionItem(
              id: 3,
              questionText: 'What afternoon activity is scheduled for Wednesday?',
              options: [
                'A) Traditional cooking demonstrations',
                'B) Placement interviews',
                'C) A guided harbor boat tour',
              ],
              correctAnswer: 'C',
              explanation: 'On Wednesday afternoon there is a guided boat tour along the harbor.',
            ),
            OfficialExamQuestionItem(
              id: 4,
              questionText: 'What do students NOT need to purchase before arriving?',
              options: [
                'A) Textbooks and audio study packs',
                'B) Comfortable walking shoes',
                'C) A notebook',
              ],
              correctAnswer: 'A',
              explanation: 'All textbooks and audio study packs are already included in the course fee.',
            ),
          ],
          evaluationCriteria: ExamEvaluationCriteria(
            minWords: 0,
            maxPoints: 8,
            rubric: '2 points per correct answer (max 8 points).',
          ),
        ),
      _ => const OfficialExamTask(
          taskNumber: 3,
          taskType: OfficialTaskType.multipleChoice,
          instructionUi:
              'Read the internal workplace policy memo carefully and choose the best answer (A, B, or C) for questions 1–4.',
          instructionTarget:
              'Read the memo below and select the correct answer (A, B, or C) for questions 1–4.',
          stimulus: ExamStimulus(
            textOrTranscript:
                'INTERNAL MEMORANDUM — Hybrid Work & Deep-Focus Policy Update\n'
                'To: All Product, Design, and Operations Teams\n'
                'From: Operations Leadership Committee\n\n'
                'Following our six-month hybrid work pilot involving 185 employees across four departments, we are formally adopting a permanent flexible schedule beginning 1 October. '
                'During the pilot, anonymous quarterly surveys and project metrics revealed a 24 percent improvement in on-time milestone delivery and a noticeable drop in unplanned sick leave. '
                'Employees particularly praised the elimination of mid-week rush-hour commuting, noting that quiet home mornings enabled deeper analytical writing and coding.\n\n'
                'At the same time, two recurring concerns emerged from our feedback workshops. First, newly hired junior staff reported feeling hesitant to interrupt senior colleagues over chat for quick informal questions, which slowed down onboarding. '
                'Second, several cross-functional teams noticed that back-to-back video calls on remote days left little uninterrupted time for strategic thinking.\n\n'
                'To address both issues directly, the permanent policy introduces two core norms: (1) Tuesdays and Wednesdays are designated as collaborative in-office anchor days, featuring structured 45-minute peer-mentoring blocks for junior teammates; and (2) Thursday mornings until 13:00 are now company-wide "No-Meeting Deep Work Hours" across all calendars, whether you work from home or the office. '
                'Additionally, every employee receives an annual 450-euro ergonomic home-office stipend, reimbursable upon submitting receipts through the HR portal.',
          ),
          questions: [
            OfficialExamQuestionItem(
              id: 1,
              questionText: 'What measurable improvement did the six-month pilot produce?',
              options: [
                'A) A 24% increase in on-time milestone delivery and fewer sick days',
                'B) A 45% reduction in office electricity costs',
                'C) Twice as many daily video meetings',
              ],
              correctAnswer: 'A',
              explanation: 'The memo cites a 24% improvement in on-time milestone delivery and a drop in unplanned sick leave.',
            ),
            OfficialExamQuestionItem(
              id: 2,
              questionText: 'Why did junior employees experience slower onboarding during the pilot?',
              options: [
                'A) They lacked internet connections at home',
                'B) They felt reluctant to interrupt senior colleagues via chat with quick questions',
                'C) They were excluded from quarterly surveys',
              ],
              correctAnswer: 'B',
              explanation: 'Junior staff felt hesitant to interrupt senior colleagues over chat for quick informal questions.',
            ),
            OfficialExamQuestionItem(
              id: 3,
              questionText: 'What is the purpose of Thursday mornings until 13:00 under the new policy?',
              options: [
                'A) Mandatory in-office mentoring sessions',
                'B) Uninterrupted company-wide deep work without meetings',
                'C) Submitting HR expense receipts',
              ],
              correctAnswer: 'B',
              explanation: 'Thursday mornings until 13:00 are designated as company-wide "No-Meeting Deep Work Hours."',
            ),
            OfficialExamQuestionItem(
              id: 4,
              questionText: 'How can employees use the annual 450-euro stipend?',
              options: [
                'A) For ergonomic home-office equipment reimbursed via receipts on the HR portal',
                'B) Exclusively for public transit season passes',
                'C) Only after completing two full years at the company',
              ],
              correctAnswer: 'A',
              explanation: 'Every employee receives an annual 450-euro ergonomic home-office stipend reimbursed upon submitting receipts.',
            ),
          ],
          evaluationCriteria: ExamEvaluationCriteria(
            minWords: 0,
            maxPoints: 8,
            rubric: '2 points per correct answer (max 8 points).',
          ),
        ),
    };

    // --- TASK 4: Information-Dense Document (3 Exact Short Answer Qs) ---
    final task4 = const OfficialExamTask(
      taskNumber: 4,
      taskType: OfficialTaskType.shortAnswer,
      instructionUi:
          'Read the detailed rail & conference travel confirmation below and write a concise, exact factual answer (1–4 words or a number) for each question.',
      instructionTarget:
          'Read the document carefully and write short exact answers to questions 1–3.',
      stimulus: ExamStimulus(
        textOrTranscript:
            'OFFICIAL TRAVEL & EVENT CONFIRMATION — Reference Code: TRV-9420\n\n'
            'Passenger: Daniel Novak | Ticket Class: 2nd Class Quiet Car\n'
            'Outbound Journey: EuroCity Express 174 departs Central Station from Platform 6 at 08:45 on Friday, 14 May, arriving at Alpine Congress Hub at 11:20. '
            'Your reserved seat is Seat 18B in Coach 3 (window side with power socket). Please arrive at the station at least 15 minutes before departure for automated ticket boarding.\n\n'
            'Conference Check-In & Hotel Shuttle: Upon arrival at Alpine Congress Hub, exit through the North Concourse toward Bus Bay 4. '
            'The complimentary green conference shuttle runs every 20 minutes directly to Panorama Conference Hotel. '
            'Your keynote badge can be collected at Desk C in the Main Atrium until 18:00. Remember to keep your confirmation reference code handy for express check-in.',
      ),
      questions: [
        OfficialExamQuestionItem(
          id: 1,
          questionText: 'From which platform number does EuroCity Express 174 depart?',
          options: [],
          correctAnswer: '6 / Platform 6',
          explanation: 'The confirmation specifies: "departs Central Station from Platform 6 at 08:45."',
        ),
        OfficialExamQuestionItem(
          id: 2,
          questionText: 'What is the passenger’s reserved seat number?',
          options: [],
          correctAnswer: '18B / Seat 18B',
          explanation: 'The document states: "Your reserved seat is Seat 18B in Coach 3."',
        ),
        OfficialExamQuestionItem(
          id: 3,
          questionText: 'How often does the complimentary green conference shuttle run (in minutes)?',
          options: [],
          correctAnswer: '20 / every 20 minutes / 20 minutes',
          explanation: 'The shuttle runs every 20 minutes from Bus Bay 4.',
        ),
      ],
      evaluationCriteria: ExamEvaluationCriteria(
        minWords: 0,
        maxPoints: 6,
        rubric: '2 points per exact factual answer (max 6 points).',
      ),
    );

    return [task1, task2, task3, task4];
  }

  // ===========================================================================
  // FULL-LENGTH LISTENING FALLBACK (4 LONG AUDIO TRACKS, 16 QUESTIONS, 32 PTS)
  // ===========================================================================
  static List<OfficialExamTask> _fallbackListeningTasks(CefrLevel l) {
    final tier = _tier(l);

    // --- AUDIO TRACK 1: Extended 12-14 Turn Realistic Dialogue (5 Qs, ~1.5-2.2 min) ---
    final task1 = switch (tier) {
      0 => const OfficialExamTask(
          taskNumber: 1,
          taskType: OfficialTaskType.multipleChoice,
          instructionUi:
              'Listen carefully to the full hotel booking phone conversation (approx. 1.5 minutes). You may listen again or use 0.5x Slow speed, then answer all 5 questions.',
          instructionTarget:
              'Listen to the full conversation and choose the correct answer (A, B, or C) for questions 1–5.',
          stimulus: ExamStimulus(
            textOrTranscript:
                'Receptionist: Good morning, Grand River Hotel, Maria speaking. How can I help you today?\n'
                'Guest: Hello Maria! My name is David Miller. I would like to book a quiet double room for myself and my wife next week.\n'
                'Receptionist: I would be happy to check availability for you, Mr. Miller. Which dates are you planning to stay?\n'
                'Guest: We arrive on Thursday afternoon, the sixteenth of May, and we check out on Sunday morning. So that is three nights in total.\n'
                'Receptionist: Let me look at our calendar. Yes, we have a lovely river-view double room available on the fourth floor. It is very quiet because it faces the garden instead of the main street.\n'
                'Guest: That sounds wonderful. Could you tell me the price per night, and whether breakfast is included?\n'
                'Receptionist: The river-view room costs ninety-five euros per night. That price includes our full hot and cold breakfast buffet every morning from seven to ten thirty, plus free Wi-Fi and access to the indoor swimming pool.\n'
                'Guest: Ninety-five euros with breakfast and the pool is great. One more question: we are flying into the airport around four in the afternoon. Does the hotel run a shuttle bus?\n'
                'Receptionist: Yes, our blue hotel shuttle leaves directly outside Terminal Two every thirty minutes, on the hour and on the half hour. The ride takes about twenty minutes and costs just five euros per person.\n'
                'Guest: Perfect! Also, my wife is allergic to feathers. Could we have synthetic pillows in the room?\n'
                'Receptionist: Of course! I have added a note for housekeeping right now so allergy-free pillows will be ready before you arrive. May I take your email address to send the confirmation?\n'
                'Guest: Yes, thank you very much for your help!',
            visualPromptDescription:
                'A bright hotel reception desk with a receptionist speaking on a headset next to a brochure displaying icons for River View, Breakfast Buffet, Indoor Pool, and Terminal 2 Shuttle.',
          ),
          questions: [
            OfficialExamQuestionItem(
              id: 1,
              questionText: 'How many nights does David Miller book at the hotel?',
              options: ['A) Two nights', 'B) Three nights', 'C) Four nights'],
              correctAnswer: 'B',
              explanation: 'David checks in on Thursday afternoon and checks out Sunday morning: three nights in total.',
            ),
            OfficialExamQuestionItem(
              id: 2,
              questionText: 'Why is the fourth-floor room especially quiet?',
              options: [
                'A) It faces the garden rather than the main street',
                'B) It is next to the indoor swimming pool',
                'C) No other guests stay on that floor',
              ],
              correctAnswer: 'A',
              explanation: 'Maria explains the room is quiet because it faces the garden instead of the main street.',
            ),
            OfficialExamQuestionItem(
              id: 3,
              questionText: 'What is included in the 95-euro nightly rate?',
              options: [
                'A) Breakfast buffet, Wi-Fi, and the indoor pool',
                'B) Dinner and free airport taxi',
                'C) Only the room without meals',
              ],
              correctAnswer: 'A',
              explanation: 'The rate includes breakfast from 7:00 to 10:30, free Wi-Fi, and indoor swimming pool access.',
            ),
            OfficialExamQuestionItem(
              id: 4,
              questionText: 'How often does the hotel shuttle depart from Terminal Two?',
              options: [
                'A) Once every hour',
                'B) Every thirty minutes',
                'C) Only in the morning',
              ],
              correctAnswer: 'B',
              explanation: 'The blue hotel shuttle leaves Terminal Two every thirty minutes (on the hour and half hour).',
            ),
            OfficialExamQuestionItem(
              id: 5,
              questionText: 'What special request does David make for his wife?',
              options: [
                'A) A late check-out on Sunday',
                'B) Allergy-free synthetic pillows instead of feathers',
                'C) A vegetarian dinner reservation',
              ],
              correctAnswer: 'B',
              explanation: 'His wife is allergic to feathers, so Maria requests allergy-free pillows from housekeeping.',
            ),
          ],
          evaluationCriteria: ExamEvaluationCriteria(
            minWords: 0,
            maxPoints: 10,
            rubric: '2 points per correct listening answer (max 10 points).',
          ),
        ),
      _ => const OfficialExamTask(
          taskNumber: 1,
          taskType: OfficialTaskType.multipleChoice,
          instructionUi:
              'Listen carefully to the full radio interview (approx. 2 minutes) with an urban architect discussing sustainable timber buildings. You can replay or slow down to 0.5x, then answer questions 1–5.',
          instructionTarget:
              'Listen to the radio interview and select the single correct answer (A, B, or C) for questions 1–5.',
          stimulus: ExamStimulus(
            textOrTranscript:
                'Host: Welcome back to Future Cities Radio. Today in the studio we are joined by structural architect Jonas Lindqvist, whose team recently completed a twelve-story apartment building made almost entirely from engineered cross-laminated timber. Jonas, when most listeners hear "wooden building," they imagine a small cabin, not a high-rise. How is this possible?\n'
                'Jonas: Thank you for having me! That reaction is completely understandable. Engineered timber is very different from ordinary lumber. We bond layers of sustainably harvested spruce together at alternating ninety-degree angles under intense pressure. The resulting panels are remarkably strong, surprisingly light, and carry a fraction of the carbon footprint of reinforced concrete and steel.\n'
                'Host: Let us address the biggest question listeners immediately send in: what about fire safety and long-term moisture?\n'
                'Jonas: Excellent question. Paradoxically, thick engineered timber performs predictably in a fire because the outer surface forms a dense protective char layer that insulates the structural core underneath for hours—unlike steel, which can suddenly soften at high heat. As for moisture, we install wireless humidity sensors inside exterior joints during construction so maintenance teams receive early alerts long before any rot could ever develop.\n'
                'Host: And how long did construction take compared with a traditional concrete building of the same size?\n'
                'Jonas: Because ninety percent of the walls and floor slabs were precision-cut in a factory and delivered like giant puzzle pieces, we assembled the twelve floors in just seven months—roughly forty percent faster than concrete. Local neighbors also loved it because crane assembly is dramatically quieter and creates almost zero concrete dust.\n'
                'Host: Are there still financial hurdles preventing every developer from switching?\n'
                'Jonas: Upfront material prices are currently about eight percent higher, and some older insurance firms still hesitate to evaluate newer materials. However, once you factor in faster completion, earlier rental income, and lower foundation costs due to lighter weight, the total lifecycle cost is already competitive—and falling every year.',
            visualPromptDescription:
                'A bright radio studio with a host and an architect examining an architectural scale model of a 12-story modern timber apartment tower.',
          ),
          questions: [
            OfficialExamQuestionItem(
              id: 1,
              questionText: 'How is engineered cross-laminated timber manufactured for strength?',
              options: [
                'A) By coating ordinary pine planks with concrete',
                'B) By bonding layers of spruce at alternating 90-degree angles under pressure',
                'C) By hollowing out steel beams and filling them with wood',
              ],
              correctAnswer: 'B',
              explanation: 'Jonas explains that layers of spruce are bonded at alternating 90-degree angles under intense pressure.',
            ),
            OfficialExamQuestionItem(
              id: 2,
              questionText: 'Why does thick engineered timber perform predictably during a fire?',
              options: [
                'A) The outer surface forms a protective char layer insulating the core',
                'B) It is completely fireproof and never burns',
                'C) Water pipes run through every wooden plank',
              ],
              correctAnswer: 'A',
              explanation: 'The outer surface forms a dense char layer that insulates the structural core underneath.',
            ),
            OfficialExamQuestionItem(
              id: 3,
              questionText: 'How does the design prevent hidden moisture damage over time?',
              options: [
                'A) By repainting the facade every six months',
                'B) By embedding wireless humidity sensors inside exterior joints',
                'C) By building only in dry desert regions',
              ],
              correctAnswer: 'B',
              explanation: 'Wireless humidity sensors inside exterior joints send early alerts to maintenance teams.',
            ),
            OfficialExamQuestionItem(
              id: 4,
              questionText: 'Why was the twelve-story building assembled roughly 40% faster than concrete?',
              options: [
                'A) Twice as many workers worked night shifts',
                'B) Ninety percent of components were precision-cut in a factory beforehand',
                'C) The building required no foundation at all',
              ],
              correctAnswer: 'B',
              explanation: 'Ninety percent of walls and floor slabs were pre-cut in a factory and assembled on site like puzzle pieces.',
            ),
            OfficialExamQuestionItem(
              id: 5,
              questionText: 'What is Jonas’s conclusion regarding the overall cost of timber towers?',
              options: [
                'A) They remain far too expensive for commercial developers',
                'B) Upfront material cost is slightly higher, but faster completion makes total lifecycle cost competitive',
                'C) Insurance companies now offer 50% discounts on all wooden buildings',
              ],
              correctAnswer: 'B',
              explanation: 'Material prices are ~8% higher upfront, but faster completion and lighter foundations make total lifecycle costs competitive.',
            ),
          ],
          evaluationCriteria: ExamEvaluationCriteria(
            minWords: 0,
            maxPoints: 10,
            rubric: '2 points per correct listening answer (max 10 points).',
          ),
        ),
    };

    // --- AUDIO TRACK 2: 4 Extended Speaker Voice Messages / Monologues (4 Matching Qs) ---
    final task2 = switch (tier) {
      0 => const OfficialExamTask(
          taskNumber: 2,
          taskType: OfficialTaskType.matching,
          instructionUi:
              'Listen to the 4 extended voice messages (approx. 1.5 minutes) and match each speaker (1–4) to their main purpose (A–E).',
          instructionTarget:
              'Listen to Speakers 1–4 and match each speaker to the correct purpose (A–E).',
          stimulus: ExamStimulus(
            textOrTranscript:
                'Speaker One: Hi Anna, it is Tom calling from the central train line. I am so sorry, there was a sudden signal failure near Oak Bridge and our train has been stopped for fifteen minutes already. I am definitely going to arrive about twenty-five minutes late for our coffee meeting. Please go ahead and order your cappuccino without waiting for me, and I will pay for both when I get there!\n\n'
                'Speaker Two: Good afternoon, this is Clara from Bright Smile Dental Clinic calling to confirm your annual check-up with Doctor Patel tomorrow morning at ten fifteen. Because we recently updated our patient records system, please remember to arrive ten minutes early with your health insurance card. If you need to reschedule, call our reception desk before five o’clock today.\n\n'
                'Speaker Three: Hey everyone in the hiking group! Just a quick update before our mountain walk on Saturday morning. I checked the latest highland weather forecast, and although the valley will be sunny and warm, strong cold winds are expected near the summit after three in the afternoon. Please pack a windproof jacket, extra water, and sturdy boots—trainers will be too slippery on the wet rocks.\n\n'
                'Speaker Four: Hello! This is Ben from Riverside Bicycle Shop. Great news: we finished replacing the rear brakes and adjusting the gears on your blue city bike earlier than expected. Everything rides smoothly now. You can pick it up anytime before six thirty this evening, or tomorrow morning from nine o’clock. The total repair bill is thirty-two euros.',
          ),
          questions: [
            OfficialExamQuestionItem(
              id: 1,
              questionText: 'What is the main purpose of Speaker 1’s message?',
              options: [
                'A) Apologising for a travel delay before a meeting',
                'B) Confirming a medical appointment and arrival instructions',
                'C) Giving weather and equipment advice for an outdoor trip',
                'D) Notifying a customer that a repair is ready for pickup',
                'E) Inviting friends to a birthday dinner at a restaurant',
              ],
              correctAnswer: 'A',
              explanation: 'Tom is delayed by a train signal failure and apologises for arriving 25 minutes late.',
            ),
            OfficialExamQuestionItem(
              id: 2,
              questionText: 'What is the main purpose of Speaker 2’s message?',
              options: [
                'A) Apologising for a travel delay before a meeting',
                'B) Confirming a medical appointment and arrival instructions',
                'C) Giving weather and equipment advice for an outdoor trip',
                'D) Notifying a customer that a repair is ready for pickup',
                'E) Inviting friends to a birthday dinner at a restaurant',
              ],
              correctAnswer: 'B',
              explanation: 'Bright Smile Dental Clinic confirms tomorrow’s check-up and asks the patient to arrive 10 minutes early.',
            ),
            OfficialExamQuestionItem(
              id: 3,
              questionText: 'What is the main purpose of Speaker 3’s message?',
              options: [
                'A) Apologising for a travel delay before a meeting',
                'B) Confirming a medical appointment and arrival instructions',
                'C) Giving weather and equipment advice for an outdoor trip',
                'D) Notifying a customer that a repair is ready for pickup',
                'E) Inviting friends to a birthday dinner at a restaurant',
              ],
              correctAnswer: 'C',
              explanation: 'Speaker 3 warns hikers about cold summit winds and advises packing jackets and sturdy boots.',
            ),
            OfficialExamQuestionItem(
              id: 4,
              questionText: 'What is the main purpose of Speaker 4’s message?',
              options: [
                'A) Apologising for a travel delay before a meeting',
                'B) Confirming a medical appointment and arrival instructions',
                'C) Giving weather and equipment advice for an outdoor trip',
                'D) Notifying a customer that a repair is ready for pickup',
                'E) Inviting friends to a birthday dinner at a restaurant',
              ],
              correctAnswer: 'D',
              explanation: 'Riverside Bicycle Shop calls to say the bike brake and gear repair is finished and ready for pickup.',
            ),
          ],
          evaluationCriteria: ExamEvaluationCriteria(
            minWords: 0,
            maxPoints: 8,
            rubric: '2 points per correct speaker match (max 8 points).',
          ),
        ),
      _ => const OfficialExamTask(
          taskNumber: 2,
          taskType: OfficialTaskType.matching,
          instructionUi:
              'Listen to 4 professionals sharing their experiences of changing careers (approx. 2 minutes) and match each speaker (1–4) to the statement (A–E) that best captures their view.',
          instructionTarget:
              'Listen to Speakers 1–4 and match each speaker to the corresponding viewpoint (A–E).',
          stimulus: ExamStimulus(
            textOrTranscript:
                'Speaker One: After ten years in corporate accounting, everyone warned me that retraining as a culinary baker at thirty-four would destroy my financial stability. Honestly, the first year was exhausting—waking up at four every morning and taking a sharp pay cut. Yet strangely, my stress levels plummeted because I could finally see and smell the tangible result of my day’s work rather than staring at abstract spreadsheets.\n\n'
                'Speaker Two: People often romanticize quitting your job overnight to chase a passion, but I took a far more cautious route. For eighteen months, I kept my daytime marketing contract while completing evening certificates in user-experience design and taking small weekend freelance briefs. By the time I handed in my resignation, I already had three regular clients and six months of savings, which took all the panic out of the transition.\n\n'
                'Speaker Three: When I left university lecturing to join an environmental technology startup, I assumed my academic research skills would translate effortlessly. Instead, the biggest shock was the pace of decision-making. In academia, we spent months perfecting a single paper; in a startup, you have to ship an imperfect version by Friday and learn from real customer feedback on Monday. Adapting to that rhythm was far harder than learning new software.\n\n'
                'Speaker Four: Looking back, the turning point in my career shift was not any expensive course I paid for—it was simply reaching out to five strangers working in renewable energy and asking for twenty-minute coffee chats. Two of those conversations revealed skills I already had from project management that I had completely undervalued, and one eventually led directly to my current role.',
          ),
          questions: [
            OfficialExamQuestionItem(
              id: 1,
              questionText: 'Which viewpoint matches Speaker 1?',
              options: [
                'A) Tangible hands-on work reduced stress despite lower initial pay',
                'B) Building freelance clients gradually before quitting eliminated financial panic',
                'C) Adjusting to a much faster workplace decision rhythm was the hardest challenge',
                'D) Informal networking conversations opened unexpected doors using existing skills',
                'E) Regretting leaving a high-paying office job and planning to return',
              ],
              correctAnswer: 'A',
              explanation: 'Speaker 1 took a pay cut and early hours, yet stress plummeted because of tangible work.',
            ),
            OfficialExamQuestionItem(
              id: 2,
              questionText: 'Which viewpoint matches Speaker 2?',
              options: [
                'A) Tangible hands-on work reduced stress despite lower initial pay',
                'B) Building freelance clients gradually before quitting eliminated financial panic',
                'C) Adjusting to a much faster workplace decision rhythm was the hardest challenge',
                'D) Informal networking conversations opened unexpected doors using existing skills',
                'E) Regretting leaving a high-paying office job and planning to return',
              ],
              correctAnswer: 'B',
              explanation: 'Speaker 2 studied at night and built 3 freelance clients and savings over 18 months before resigning.',
            ),
            OfficialExamQuestionItem(
              id: 3,
              questionText: 'Which viewpoint matches Speaker 3?',
              options: [
                'A) Tangible hands-on work reduced stress despite lower initial pay',
                'B) Building freelance clients gradually before quitting eliminated financial panic',
                'C) Adjusting to a much faster workplace decision rhythm was the hardest challenge',
                'D) Informal networking conversations opened unexpected doors using existing skills',
                'E) Regretting leaving a high-paying office job and planning to return',
              ],
              correctAnswer: 'C',
              explanation: 'Speaker 3 found adapting from slow academic perfectionism to rapid startup shipping the hardest part.',
            ),
            OfficialExamQuestionItem(
              id: 4,
              questionText: 'Which viewpoint matches Speaker 4?',
              options: [
                'A) Tangible hands-on work reduced stress despite lower initial pay',
                'B) Building freelance clients gradually before quitting eliminated financial panic',
                'C) Adjusting to a much faster workplace decision rhythm was the hardest challenge',
                'D) Informal networking conversations opened unexpected doors using existing skills',
                'E) Regretting leaving a high-paying office job and planning to return',
              ],
              correctAnswer: 'D',
              explanation: 'Speaker 4 credits 20-minute coffee chats with revealing transferable skills and leading to their new job.',
            ),
          ],
          evaluationCriteria: ExamEvaluationCriteria(
            minWords: 0,
            maxPoints: 8,
            rubric: '2 points per correct speaker match (max 8 points).',
          ),
        ),
    };

    // --- AUDIO TRACK 3: Extended Radio Documentary / Guided Tour Monologue (4 Qs) ---
    final task3 = const OfficialExamTask(
      taskNumber: 3,
      taskType: OfficialTaskType.multipleChoice,
      instructionUi:
          'Listen carefully to the extended museum audio guide & documentary broadcast (approx. 1.8 minutes), then answer questions 1–4.',
      instructionTarget:
          'Listen to the broadcast and select the correct answer (A, B, or C) for questions 1–4.',
      stimulus: ExamStimulus(
        textOrTranscript:
            'Welcome to the Maritime Discovery Museum’s special exhibition, "Voices of the Northern Sea." '
            'Before we step into the main gallery, take a moment to look at the large oak compass chest standing beside the entrance. '
            'That chest survived nearly three hundred years beneath cold coastal waters before marine archaeologists lifted it from a merchant ship in nineteen ninety-eight. '
            'Because the seabed mud sealed out oxygen, even the handwritten trading ledgers and spice jars inside remained astonishingly readable.\n\n'
            'As you walk into Gallery Two, you will hear ambient sound recordings of traditional harbor shipwrights hammering wooden hulls. '
            'Our curators spent two years interviewing retired boatbuilders from six coastal villages so visitors can understand not only what sailors traded—amber, dried fish, wool, and salt—but also how entire communities depended on seasonal winds. '
            'Notice the interactive map table in the center of the hall: by placing any wooden ship token onto a port city, you can listen to real diary entries written by seventeenth-century captains describing storms, navigation tricks, and life aboard ship.\n\n'
            'A brief practical reminder for your visit today: flash photography is not permitted inside the manuscript wing to protect the fragile ink, though non-flash photos are welcome everywhere else. '
            'At three thirty this afternoon, Chief Conservator Helena Berg will hold a live thirty-minute demonstration in the Restoration Glass Studio showing how ancient iron anchors are cleaned without damaging the metal. Admission to the talk is free with your regular museum ticket.',
      ),
      questions: [
        OfficialExamQuestionItem(
          id: 1,
          questionText: 'Why did the handwritten trading ledgers survive underwater for nearly 300 years?',
          options: [
            'A) They were sealed in seabed mud that kept oxygen out',
            'B) Sailors wrapped them in waterproof plastic',
            'C) The ship sank in warm tropical waters',
          ],
          correctAnswer: 'A',
          explanation: 'The broadcast explains that seabed mud sealed out oxygen, preserving the ledgers and spice jars.',
        ),
        OfficialExamQuestionItem(
          id: 2,
          questionText: 'What can visitors trigger at the interactive map table in Gallery Two?',
          options: [
            'A) Live weather forecasts for modern ships',
            'B) Audio diary entries written by 17th-century captains',
            'C) Tickets for harbor ferry rides',
          ],
          correctAnswer: 'B',
          explanation: 'Placing a wooden ship token on a port plays real 17th-century captains’ diary entries.',
        ),
        OfficialExamQuestionItem(
          id: 3,
          questionText: 'What is the photography rule inside the manuscript wing?',
          options: [
            'A) Cameras are banned throughout the entire museum',
            'B) Flash photography is prohibited to protect fragile ink',
            'C) Visitors must pay a photography fee at the entrance',
          ],
          correctAnswer: 'B',
          explanation: 'Flash photography is not permitted in the manuscript wing, though non-flash photos are welcome.',
        ),
        OfficialExamQuestionItem(
          id: 4,
          questionText: 'What will Helena Berg demonstrate at 3:30 PM in the Restoration Glass Studio?',
          options: [
            'A) How to carve wooden ship tokens',
            'B) How ancient iron anchors are safely cleaned',
            'C) How to sail a traditional merchant ship',
          ],
          correctAnswer: 'B',
          explanation: 'Helena Berg will demonstrate cleaning ancient iron anchors without damaging the metal.',
        ),
      ],
      evaluationCriteria: ExamEvaluationCriteria(
        minWords: 0,
        maxPoints: 8,
        rubric: '2 points per correct listening answer (max 8 points).',
      ),
    );

    // --- AUDIO TRACK 4: Detailed Travel & Event Briefing (3 Short Answer Qs) ---
    final task4 = const OfficialExamTask(
      taskNumber: 4,
      taskType: OfficialTaskType.shortAnswer,
      instructionUi:
          'Listen carefully to the full station & excursion coordinator announcement (approx. 1.2 minutes) and type the exact requested detail (number, time, or keyword) for each question.',
      instructionTarget:
          'Listen to the announcement and write the exact details for questions 1–3.',
      stimulus: ExamStimulus(
        textOrTranscript:
            'Attention passengers and Lake Valley Day-Tour guests, please listen carefully to an important boarding update. '
            'Because of maintenance work on the south concourse, the direct intercity coach to Riverside and Lake Valley will NOT depart from Gate Four as printed on earlier tickets. '
            'Instead, boarding has been moved to Gate Twelve on the east side of the terminal, right next to the yellow information kiosk.\n\n'
            'Departure time remains strictly at sixteen twenty, and boarding doors close ten minutes earlier at sixteen ten, so please have your digital QR tickets and photo ID ready. '
            'Once we arrive in Riverside, our guided walking tour includes free entry to the Botanical Conservatory; however, passengers who wish to join the optional evening lake cruise should register with the tour guide before noon. '
            'The discounted group ticket for the boat cruise costs eighteen euros per adult and includes a complimentary warm herbal tea on deck. Thank you and enjoy your journey!',
      ),
      questions: [
        OfficialExamQuestionItem(
          id: 1,
          questionText: 'From which gate number will the intercity coach depart now?',
          options: [],
          correctAnswer: '12 / Gate 12 / twelve',
          explanation: 'Boarding was moved from Gate 4 to Gate 12.',
        ),
        OfficialExamQuestionItem(
          id: 2,
          questionText: 'What is the coach’s exact departure time (e.g. 16:20)?',
          options: [],
          correctAnswer: '16:20 / 4:20',
          explanation: 'Departure time remains strictly at 16:20.',
        ),
        OfficialExamQuestionItem(
          id: 3,
          questionText: 'How much does the optional evening boat cruise cost per adult (in euros)?',
          options: [],
          correctAnswer: '18 / 18 euros / eighteen',
          explanation: 'The discounted group ticket costs 18 euros per adult.',
        ),
      ],
      evaluationCriteria: ExamEvaluationCriteria(
        minWords: 0,
        maxPoints: 6,
        rubric: '2 points per exact heard detail (max 6 points).',
      ),
    );

    return [task1, task2, task3, task4];
  }

  // ===========================================================================
  // FULL-LENGTH WRITING FALLBACK (3 TASKS, 35 POINTS)
  // ===========================================================================
  static List<OfficialExamTask> _fallbackWritingTasks(CefrLevel l) {
    final min1 = _writingMinWords(l, part: 1);
    final min2 = _writingMinWords(l, part: 2);
    final min3 = _writingMinWords(l, part: 3);

    return [
      OfficialExamTask(
        taskNumber: 1,
        taskType: OfficialTaskType.openWriting,
        instructionUi:
            'Task 1 — Personal Correspondence: Read the incoming email carefully and write a complete, natural reply in the target language (minimum $min1 words). Be sure to address ALL 3 points below.',
        instructionTarget:
            'Read the email below and write a full reply (at least $min1 words) covering all three bullet points.',
        stimulus: const ExamStimulus(
          textOrTranscript:
              'From: Alex Novak\n'
              'Subject: Visiting your city next weekend!\n\n'
              'Hi there! Great news—I finally booked my train tickets and I will be visiting your city next Saturday and Sunday! '
              'I have never explored your neighborhood before, so I would love your local recommendations. '
              'Where should we meet on Saturday afternoon, what local place or activity do you think I should not miss, and is there anything special I should pack for the weather? '
              'Let me know what time works best for you!\n\n'
              'Cheers, Alex',
        ),
        questions: const [
          OfficialExamQuestionItem(
            id: 1,
            questionText: 'Greet Alex warmly and suggest a concrete meeting place and time for Saturday.',
            options: [],
            correctAnswer: '',
            explanation: 'Address the logistics clearly with a natural greeting.',
          ),
          OfficialExamQuestionItem(
            id: 2,
            questionText: 'Recommend one interesting local attraction, café, or activity and explain why you like it.',
            options: [],
            correctAnswer: '',
            explanation: 'Give a concrete recommendation with a short reason.',
          ),
          OfficialExamQuestionItem(
            id: 3,
            questionText: 'Mention what to pack for the weather and close your email naturally.',
            options: [],
            correctAnswer: '',
            explanation: 'Include practical packing advice and a polite sign-off.',
          ),
        ],
        evaluationCriteria: ExamEvaluationCriteria(
          minWords: min1,
          maxPoints: 10,
          rubric:
              'Full coverage of all 3 points (4 pts), coherence & natural register (3 pts), grammar & vocabulary for ${l.code} (3 pts). Minimum $min1 words.',
        ),
      ),
      OfficialExamTask(
        taskNumber: 2,
        taskType: OfficialTaskType.openWriting,
        instructionUi:
            'Task 2 — Practical / Formal Communication: Read the real-world scenario below and write a clear, polite formal message or review (minimum $min2 words).',
        instructionTarget:
            'Write a clear, well-structured message (at least $min2 words) addressing all points in the scenario.',
        stimulus: const ExamStimulus(
          textOrTranscript:
              'Scenario: Last week you attended a three-day online workshop or stayed at a local guesthouse. '
              'Although the staff/instructors were very friendly and helpful, two practical details did not match what was advertised on the website (for example, missing study materials, noisy surroundings, or broken Wi-Fi). '
              'Write a polite message to the organizer/manager.',
        ),
        questions: const [
          OfficialExamQuestionItem(
            id: 1,
            questionText: 'State clearly what you attended/booked and highlight one positive aspect you appreciated.',
            options: [],
            correctAnswer: '',
            explanation: 'Open professionally and balance feedback with a positive detail.',
          ),
          OfficialExamQuestionItem(
            id: 2,
            questionText: 'Describe two specific problems clearly and politely.',
            options: [],
            correctAnswer: '',
            explanation: 'Use clear connectors and appropriate formal/semi-formal tone.',
          ),
          OfficialExamQuestionItem(
            id: 3,
            questionText: 'Suggest a constructive improvement or request a reasonable follow-up action.',
            options: [],
            correctAnswer: '',
            explanation: 'Conclude constructively with a formal sign-off.',
          ),
        ],
        evaluationCriteria: ExamEvaluationCriteria(
          minWords: min2,
          maxPoints: 10,
          rubric:
              'Communicative goal & polite register (4 pts), paragraph organization (3 pts), accuracy & lexical range for ${l.code} (3 pts). Minimum $min2 words.',
        ),
      ),
      OfficialExamTask(
        taskNumber: 3,
        taskType: OfficialTaskType.openWriting,
        instructionUi:
            'Task 3 — Extended Essay / Structured Opinion: Study the topic and visual prompt, then write a well-organized multi-paragraph text (minimum $min3 words) with introduction, supporting arguments, example, and conclusion.',
        instructionTarget:
            'Write a structured multi-paragraph essay (at least $min3 words) presenting your viewpoint with clear arguments and examples.',
        stimulus: ExamStimulus(
          textOrTranscript:
              'Essay Prompt (${l.code}): Many people today learn foreign languages and professional skills primarily through interactive apps, online videos, and real-life immersion rather than traditional classrooms and paper textbooks. '
              'Do you believe self-directed digital learning can fully replace classroom education, or is a combination of both approaches essential? Discuss both sides and justify your opinion.',
          visualPromptDescription:
              'A split-frame illustration: on the left, a learner wearing headphones watching a foreign-language video with digital flashcards on a tablet; on the right, a small group discussing around a classroom table with a teacher.',
        ),
        questions: const [
          OfficialExamQuestionItem(
            id: 1,
            questionText: 'Introduce the topic and state your main thesis clearly.',
            options: [],
            correctAnswer: '',
            explanation: 'A strong introduction frames the question and states your stance.',
          ),
          OfficialExamQuestionItem(
            id: 2,
            questionText: 'Compare at least one advantage and one limitation of digital self-study vs. classroom learning, using a real example.',
            options: [],
            correctAnswer: '',
            explanation: 'Develop ideas with linking expressions (however, furthermore, for instance).',
          ),
          OfficialExamQuestionItem(
            id: 3,
            questionText: 'Summarize your viewpoint in a clear concluding paragraph.',
            options: [],
            correctAnswer: '',
            explanation: 'Bring the essay to a coherent, memorable finish.',
          ),
        ],
        evaluationCriteria: ExamEvaluationCriteria(
          minWords: min3,
          maxPoints: 15,
          rubric:
              'Depth of arguments & concrete examples (5 pts), logical structure & cohesion (5 pts), vocabulary & grammar mastery for ${l.code} (5 pts). Minimum $min3 words.',
        ),
      ),
    ];
  }

  // ===========================================================================
  // FULL-LENGTH SPEAKING FALLBACK (3 PARTS, 35 POINTS)
  // ===========================================================================
  static List<OfficialExamTask> _fallbackSpeakingTasks(CefrLevel l) {
    final min1 = _speakingMinWords(l, part: 1);
    final min2 = _speakingMinWords(l, part: 2);
    final min3 = _speakingMinWords(l, part: 3);

    return [
      OfficialExamTask(
        taskNumber: 1,
        taskType: OfficialTaskType.speakingRoleplay,
        instructionUi:
            'Part 1 — Examiner Interview: Listen to the examiner’s full welcome and 4 interview questions, then press the microphone and answer all of them aloud in complete sentences.',
        instructionTarget:
            'Listen to the examiner and answer all four interview questions naturally aloud.',
        stimulus: const ExamStimulus(
          textOrTranscript:
              'Examiner: Welcome to your official speaking examination! Let us start with a few personal questions so I can get to know you. '
              'First, could you introduce yourself and tell me a little about the city or town where you live? '
              'Second, how do you usually spend a typical weekday? '
              'Third, what hobby or activity helps you relax after a busy day? '
              'And finally, why are you learning this language and how do you plan to use it in the future?',
        ),
        questions: const [
          OfficialExamQuestionItem(
            id: 1,
            questionText: '1. Introduce yourself and describe where you live.',
            options: [],
            correctAnswer: '',
            explanation: 'Give 2–3 natural sentences about yourself and your hometown.',
          ),
          OfficialExamQuestionItem(
            id: 2,
            questionText: '2. Describe your typical weekday routine.',
            options: [],
            correctAnswer: '',
            explanation: 'Mention work/study and daily habits.',
          ),
          OfficialExamQuestionItem(
            id: 3,
            questionText: '3. Share a hobby or way you relax in your free time.',
            options: [],
            correctAnswer: '',
            explanation: 'Explain what you do and why you enjoy it.',
          ),
          OfficialExamQuestionItem(
            id: 4,
            questionText: '4. Explain your motivation and future goals for learning this language.',
            options: [],
            correctAnswer: '',
            explanation: 'Connect language skills to travel, career, or personal growth.',
          ),
        ],
        evaluationCriteria: ExamEvaluationCriteria(
          minWords: min1,
          maxPoints: 10,
          rubric:
              'Answering all 4 interview questions (4 pts), pronunciation & intelligibility (3 pts), grammar & vocabulary for ${l.code} (3 pts).',
        ),
      ),
      OfficialExamTask(
        taskNumber: 2,
        taskType: OfficialTaskType.speakingRoleplay,
        instructionUi:
            'Part 2 — Practical Problem-Solving Roleplay: Read and listen to the realistic situation below, then record your spoken response addressing all 3 objectives naturally.',
        instructionTarget:
            'Act out the roleplay aloud, politely explaining the problem and agreeing on a clear solution.',
        stimulus: const ExamStimulus(
          textOrTranscript:
              'Examiner (playing Hotel / Event Manager): Good afternoon! I understand you have a concern regarding your reservation for this weekend. '
              'Unfortunately, our building is very busy today, so please explain clearly what went wrong, tell me what solution you would prefer, and let me know when you are available to confirm the new arrangement.',
        ),
        questions: const [
          OfficialExamQuestionItem(
            id: 1,
            questionText: 'Politely explain the booking mistake (e.g., wrong room type, noisy floor, or wrong date).',
            options: [],
            correctAnswer: '',
            explanation: 'Use polite, clear framing without sounding rude.',
          ),
          OfficialExamQuestionItem(
            id: 2,
            questionText: 'Propose two possible solutions (e.g., switching rooms, adjusting the time, or a partial refund).',
            options: [],
            correctAnswer: '',
            explanation: 'Show negotiation flexibility.',
          ),
          OfficialExamQuestionItem(
            id: 3,
            questionText: 'Ask one clarifying question and thank the manager politely.',
            options: [],
            correctAnswer: '',
            explanation: 'Close the interaction naturally.',
          ),
        ],
        evaluationCriteria: ExamEvaluationCriteria(
          minWords: min2,
          maxPoints: 10,
          rubric:
              'Interactive problem-solving & covering all 3 goals (4 pts), register & fluency (3 pts), accuracy for ${l.code} (3 pts).',
        ),
      ),
      OfficialExamTask(
        taskNumber: 3,
        taskType: OfficialTaskType.speakingRoleplay,
        instructionUi:
            'Part 3 — Extended Monologue & Visual Comparison: Study the visual scenario description and examiner prompt, then record a sustained, structured spoken talk.',
        instructionTarget:
            'Compare the two options shown in the visual prompt, state your preference, and justify it with detailed reasons.',
        stimulus: const ExamStimulus(
          textOrTranscript:
              'Examiner: For the final part of the exam, imagine you and a close friend have four free days to travel together. '
              'Look at the two travel options described below: exploring a vibrant historic European capital full of museums and cafés, OR spending four peaceful days in a mountain cabin beside an alpine lake. '
              'Please compare both options, explain which destination you would choose and why, and suggest two concrete activities you would plan.',
          visualPromptDescription:
              'Two contrasting full-color travel photographs side by side: Photo A shows a sunlit historic square with grand museums, street musicians, and outdoor cafés; Photo B shows a wooden cabin overlooking a clear turquoise mountain lake with pine forests and hiking trails.',
        ),
        questions: const [
          OfficialExamQuestionItem(
            id: 1,
            questionText: 'Briefly describe and compare the atmosphere of both destinations.',
            options: [],
            correctAnswer: '',
            explanation: 'Use comparison structures (whereas, on the other hand, while).',
          ),
          OfficialExamQuestionItem(
            id: 2,
            questionText: 'State your clear choice and support it with at least two well-developed reasons.',
            options: [],
            correctAnswer: '',
            explanation: 'Develop each reason with a brief personal explanation.',
          ),
          OfficialExamQuestionItem(
            id: 3,
            questionText: 'Propose two specific activities for your trip and summarize why your friend would enjoy it too.',
            options: [],
            correctAnswer: '',
            explanation: 'Round off your monologue smoothly.',
          ),
        ],
        evaluationCriteria: ExamEvaluationCriteria(
          minWords: min3,
          maxPoints: 15,
          rubric:
              'Sustained coherent monologue & comparison (5 pts), fluency & pronunciation (5 pts), vocabulary & accuracy for ${l.code} (5 pts).',
        ),
      ),
    ];
  }
}
