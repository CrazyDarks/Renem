import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/exam_models.dart';
import '../../services/cefr_exam_blueprints.dart';
import '../../state/app_controller.dart';

class ExamView extends StatefulWidget {
  const ExamView({super.key});

  @override
  State<ExamView> createState() => _ExamViewState();
}

class _ExamViewState extends State<ExamView> {
  final ScrollController _introScrollController = ScrollController();
  final ScrollController _examScrollController = ScrollController();
  final ScrollController _evalScrollController = ScrollController();

  CefrLevel _selectedLevel = CefrLevel.b1;

  /// `null` means Full Official Certification Exam (all 4 subtests in parallel).
  ExamSubtest? _selectedSubtest;

  bool _loading = false;
  bool _evaluating = false;

  // Live generation progress state (0% -> 100%) with smooth timer
  int _genPercent = 0;
  String _genStageKey = 'exam_stage_prepare';
  int _genElapsedSeconds = 0;
  Map<ExamSubtest, bool> _genSubtestStatus = {};
  Timer? _genSmoothTimer;

  // Active exam state
  OfficialExamSession? _session;
  int _activeSubtestIndex = 0;
  Timer? _examTimer;
  final ValueNotifier<int> _remainingSeconds = ValueNotifier<int>(0);
  bool _showScrollToTop = false;

  // Candidate answers keyed cleanly by subtest/task/question
  // Choice key: '${subtest.apiName}_${taskNumber}_${questionId}'
  final Map<String, int> _choiceAnswers = {};
  // Short answer key: '${subtest.apiName}_${taskNumber}_${questionId}'
  // Open writing key: '${subtest.apiName}_${taskNumber}'
  final Map<String, String> _textAnswers = {};
  final Map<String, TextEditingController> _textControllers = {};
  // Speaking key: '${subtest.apiName}_${taskNumber}'
  final Map<String, String> _speakingTranscripts = {};
  final Map<String, int> _speakingPronScores = {};
  String? _activeRecordingTaskKey;

  OfficialExamEvaluation? _evaluation;

  @override
  void initState() {
    super.initState();
    _examScrollController.addListener(_onExamScroll);
  }

  void _onExamScroll() {
    if (!_examScrollController.hasClients) return;
    final shouldShow = _examScrollController.offset > 360;
    if (shouldShow != _showScrollToTop && mounted) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  @override
  void dispose() {
    _genSmoothTimer?.cancel();
    _examTimer?.cancel();
    _remainingSeconds.dispose();
    _examScrollController.removeListener(_onExamScroll);
    _introScrollController.dispose();
    _examScrollController.dispose();
    _evalScrollController.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<ExamSubtest> get _plannedSubtests => _selectedSubtest == null
      ? ExamSubtest.values
      : <ExamSubtest>[_selectedSubtest!];

  int get _plannedTotalMinutes => _plannedSubtests.fold<int>(
        0,
        (sum, sub) =>
            sum +
            CefrExamBlueprints.defaultTimeLimitMinutes(_selectedLevel, sub),
      );

  void _clearExamState() {
    _examTimer?.cancel();
    _genSmoothTimer?.cancel();
    final oldControllers = _textControllers.values.toList();
    _textControllers.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in oldControllers) {
        c.dispose();
      }
    });
    _choiceAnswers.clear();
    _textAnswers.clear();
    _speakingTranscripts.clear();
    _speakingPronScores.clear();
    _activeRecordingTaskKey = null;
    _activeSubtestIndex = 0;
    _showScrollToTop = false;
  }

  void _startCountdownTimer(int totalMinutes) {
    _examTimer?.cancel();
    _remainingSeconds.value = (totalMinutes <= 0 ? 20 : totalMinutes) * 60;
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          _session == null ||
          _evaluating ||
          _evaluation != null) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds.value <= 1) {
        _remainingSeconds.value = 0;
        timer.cancel();
        _submitExam();
      } else {
        _remainingSeconds.value -= 1;
      }
    });
  }

  String _formatTimer(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  TextEditingController _controllerForKey(String key) {
    return _textControllers.putIfAbsent(key, () {
      final ctrl = TextEditingController(text: _textAnswers[key] ?? '');
      ctrl.addListener(() {
        final prev = _textAnswers[key] ?? '';
        final next = ctrl.text;
        _textAnswers[key] = next;
        // Rebuild so word counter and answered progress stay live
        if (prev != next && mounted) {
          setState(() {});
        }
      });
      return ctrl;
    });
  }

  int _countWords(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  int get _totalGradableItems {
    final session = _session;
    if (session == null) return 0;
    var count = 0;
    for (final paper in session.subtests) {
      for (final task in paper.tasks) {
        if (task.taskType == OfficialTaskType.openWriting ||
            task.taskType == OfficialTaskType.speakingRoleplay) {
          count += 1;
        } else {
          count += task.questions.length;
        }
      }
    }
    return count;
  }

  int get _answeredGradableItems {
    final session = _session;
    if (session == null) return 0;
    var count = 0;
    for (final paper in session.subtests) {
      final sub = paper.examMeta.subtest;
      for (final task in paper.tasks) {
        if (task.taskType == OfficialTaskType.openWriting) {
          final key = '${sub.apiName}_${task.taskNumber}';
          if ((_textAnswers[key] ?? '').trim().isNotEmpty) count++;
        } else if (task.taskType == OfficialTaskType.speakingRoleplay) {
          final key = '${sub.apiName}_${task.taskNumber}';
          if ((_speakingTranscripts[key] ?? '').trim().isNotEmpty) count++;
        } else if (task.taskType == OfficialTaskType.shortAnswer) {
          for (final q in task.questions) {
            final key = '${sub.apiName}_${task.taskNumber}_${q.id}';
            if ((_textAnswers[key] ?? '').trim().isNotEmpty) count++;
          }
        } else {
          for (final q in task.questions) {
            final key = '${sub.apiName}_${task.taskNumber}_${q.id}';
            if (_choiceAnswers.containsKey(key)) count++;
          }
        }
      }
    }
    return count;
  }

  Future<void> _speakSlow(
    AppController controller,
    String text, {
    String? trackId,
  }) async {
    await controller.speakTarget(
      text,
      overrideRate: 0.28,
      trackId: trackId,
    );
  }

  /// Cleans dialogue transcripts so TTS reads only natural speech without
  /// reading speaker labels ("Receptionist:", "Speaker One:", "Host:").
  String _cleanTranscriptForTts(String raw) {
    final lines = raw.split('\n').map((line) {
      final stripped = line.replaceFirst(
        RegExp(r'^[\p{L}\p{N}\s\(\)/\-]{1,36}:\s*', unicode: true),
        '',
      );
      return stripped.trim();
    }).where((l) => l.isNotEmpty);
    return lines.join('\n');
  }

  String _formatApproxAudioDuration(String text) {
    final words = _countWords(text);
    final totalSec = (words / 2.25).round().clamp(15, 360);
    final m = totalSec ~/ 60;
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '~$m:$s';
  }

  Future<void> _startExam() async {
    final controller = AppScope.of(context);
    final planned = _plannedSubtests;
    _clearExamState();

    setState(() {
      _loading = true;
      _session = null;
      _evaluation = null;
      _genPercent = 4;
      _genStageKey = 'exam_stage_prepare';
      _genElapsedSeconds = 0;
      _genSubtestStatus = {for (final sub in planned) sub: false};
    });

    // Smoothly tick elapsed time & gently advance progress up to 92% over the 60s window
    _genSmoothTimer?.cancel();
    _genSmoothTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_loading) {
        timer.cancel();
        return;
      }
      setState(() {
        _genElapsedSeconds += 1;
        // Asymptotic smooth progress while waiting on LLM so the bar always feels alive
        if (_genPercent < 88) {
          final step = _genPercent < 35
              ? 3
              : _genPercent < 65
                  ? 2
                  : 1;
          _genPercent = (_genPercent + step).clamp(0, 88);
        }
      });
    });

    try {
      final session = await controller.gemini.generateOfficialExamSession(
        level: _selectedLevel,
        subtests: planned,
        settings: controller.settings,
        recentWords: controller.vocabulary.map((w) => w.word).toList(),
        onProgress: (percent, stageKey, completedMap) {
          if (!mounted) return;
          setState(() {
            if (percent > _genPercent) _genPercent = percent;
            _genStageKey = stageKey;
            _genSubtestStatus = completedMap;
          });
        },
      );

      _genSmoothTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _genPercent = 100;
        _genStageKey = 'exam_stage_ready';
        _session = session;
        _activeSubtestIndex = 0;
        _loading = false;
      });
      _startCountdownTimer(session.totalTimeMinutes);

      // Surface exact AI failure reason if any subtest fell back to offline Blueprint
      if (session.hasAnyFallback && mounted) {
        final s = AppStrings.of(context);
        final reasons = session.aiFallbackReasons;
        final msg = reasons.isNotEmpty
            ? '${s.tr('exam_ai_fallback_notice')}: ${reasons.first}'
            : s.tr('exam_ai_fallback_notice');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, maxLines: 4, overflow: TextOverflow.ellipsis),
            duration: const Duration(seconds: 7),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _genSmoothTimer?.cancel();
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleSpeakingRecord(
    String taskKey,
    OfficialExamTask task,
  ) async {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);

    if (_activeRecordingTaskKey == taskKey) {
      await controller.pronunciation.stopListening();
      if (!mounted) return;
      setState(() => _activeRecordingTaskKey = null);
      return;
    }

    // Stop any previous recording first
    if (_activeRecordingTaskKey != null) {
      await controller.pronunciation.stopListening();
    }

    final hasMic = await controller.permissions.ensureMicrophone();
    if (!hasMic) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.tr('mic_permission_needed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final referencePrompt = task.stimulus.textOrTranscript.isNotEmpty
        ? task.stimulus.textOrTranscript
        : task.instructionTarget;

    setState(() {
      _activeRecordingTaskKey = taskKey;
    });

    final ok = await controller.pronunciation.startListening(
      localeId: controller.settings.targetLanguage.ttsLocale,
      // Do not auto-stop on a single phrase for free roleplay / monologue speaking
      autoStopTargetText: null,
      recordingSlot: 'exam_sp_$taskKey',
      onResult: (words, isFinal) {
        if (!mounted) return;
        final trimmed = words.trim();
        var clarityScore = _speakingPronScores[taskKey] ?? 0;
        if (trimmed.isNotEmpty) {
          final wordCount = _countWords(trimmed);
          final eval = controller.pronunciation.evaluatePronunciation(
            targetText: referencePrompt.isNotEmpty ? referencePrompt : trimmed,
            spokenText: trimmed,
          );
          // For open speaking tasks, combine recognition clarity + spoken volume
          clarityScore = wordCount >= 5
              ? (75 + (wordCount.clamp(5, 25))).clamp(75, 98)
              : eval.scorePercent.clamp(55, 95);
        }
        setState(() {
          if (trimmed.isNotEmpty) {
            _speakingTranscripts[taskKey] = trimmed;
            _speakingPronScores[taskKey] = clarityScore;
          }
          if (isFinal) {
            _activeRecordingTaskKey = null;
          }
        });
      },
    );

    if (!ok && mounted) {
      setState(() => _activeRecordingTaskKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.tr('speech_unavailable')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmOrSubmitExam() async {
    final s = AppStrings.of(context);
    final total = _totalGradableItems;
    final answered = _answeredGradableItems;
    final unanswered = total - answered;

    if (unanswered > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.tr('confirm_finish_exam_title')),
          content: Text(
            '$answered / $total\n\n${s.tr('confirm_finish_exam_body')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(s.tr('return_to_test_btn')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.tr('finish_short')),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    await _submitExam();
  }

  Future<void> _submitExam() async {
    final session = _session;
    if (session == null) return;

    _examTimer?.cancel();
    final controller = AppScope.of(context);
    await controller.tts.stop();
    await controller.pronunciation.stopListening();

    setState(() {
      _activeRecordingTaskKey = null;
      _evaluating = true;
    });

    try {
      final evaluation = await controller.gemini.evaluateOfficialExam(
        session: session,
        choiceAnswers: Map<String, int>.from(_choiceAnswers),
        textAnswers: Map<String, String>.from(_textAnswers),
        speakingTranscripts: Map<String, String>.from(_speakingTranscripts),
        speakingPronScores: Map<String, int>.from(_speakingPronScores),
        settings: controller.settings,
      );

      await controller.recordExamCompleted(
        evaluation.earnedPoints.round(),
        evaluation.maxPoints > 0 ? evaluation.maxPoints : 1,
      );

      if (!mounted) return;
      setState(() {
        _evaluation = evaluation;
        _evaluating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _evaluating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _subtestLabel(AppStrings s, ExamSubtest sub) {
    return switch (sub) {
      ExamSubtest.reading => s.tr('subtest_reading'),
      ExamSubtest.listening => s.tr('subtest_listening'),
      ExamSubtest.writing => s.tr('subtest_writing'),
      ExamSubtest.speaking => s.tr('subtest_speaking'),
    };
  }

  IconData _subtestIcon(ExamSubtest sub) {
    return switch (sub) {
      ExamSubtest.reading => Icons.menu_book_rounded,
      ExamSubtest.listening => Icons.headphones_rounded,
      ExamSubtest.writing => Icons.edit_note_rounded,
      ExamSubtest.speaking => Icons.record_voice_over_rounded,
    };
  }

  String _taskTypeLabel(AppStrings s, OfficialTaskType type) {
    return switch (type) {
      OfficialTaskType.multipleChoice => s.tr('exam_type_mc'),
      OfficialTaskType.shortAnswer => s.tr('exam_type_short'),
      OfficialTaskType.matching => s.tr('exam_type_matching'),
      OfficialTaskType.openWriting => s.tr('exam_type_writing'),
      OfficialTaskType.speakingRoleplay => s.tr('exam_type_speaking'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    if (_loading) {
      return _buildGenerationProgressView(context, s);
    }
    if (_evaluating) {
      final activeSubtests = _session != null && _session!.subtests.isNotEmpty
          ? _session!.subtests.map((p) => p.examMeta.subtest).toList()
          : _plannedSubtests;
      final evalLabel = activeSubtests.length == 1
          ? s
              .tr('exam_evaluating_single')
              .replaceAll('{subtest}', _subtestLabel(s, activeSubtests.first))
          : activeSubtests.length == ExamSubtest.values.length
              ? s.tr('exam_evaluating')
              : s
                  .tr('exam_evaluating_multi')
                  .replaceAll('{count}', '${activeSubtests.length}');

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                evalLabel,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (activeSubtests.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: activeSubtests
                      .map(
                        (sub) => Chip(
                          avatar: Icon(_subtestIcon(sub), size: 16),
                          label: Text(_subtestLabel(s, sub)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (_evaluation != null && _session != null) {
      return _buildEvaluationView(context, s, _session!, _evaluation!);
    }
    if (_session != null) {
      return _buildActiveExamView(context, s, _session!);
    }
    return _buildIntroView(context, s);
  }

  // ---------------------------------------------------------------------------
  // 1. INTRO & OFFICIAL BLUEPRINT SELECTION SCREEN
  // ---------------------------------------------------------------------------
  Widget _buildIntroView(BuildContext context, AppStrings s) {
    final controller = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final targetLang = controller.settings.targetLanguage;
    final planned = _plannedSubtests;
    final totalMin = _plannedTotalMinutes;

    return ListView(
      controller: _introScrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        // Official Certification Header Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: scheme.onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.tr('exam_official_title'),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${targetLang.flag} ${s.langName(targetLang)} • ${_selectedLevel.code}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  s.tr('exam_official_subtitle'),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // CEFR Level Picker (A1 - C2)
        Text(
          s.tr('choose_cefr_level'),
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: CefrLevel.values.map((lvl) {
            final selected = _selectedLevel == lvl;
            return ChoiceChip(
              selected: selected,
              label: Text(
                lvl.code,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              onSelected: (_) => setState(() => _selectedLevel = lvl),
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        // Subtest Picker (Full 4 subtests OR single subtest)
        Text(
          s.tr('exam_select_subtest'),
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              selected: _selectedSubtest == null,
              avatar: const Icon(Icons.layers_rounded, size: 18),
              label: Text(s.tr('exam_full_4_subtests')),
              onSelected: (_) => setState(() => _selectedSubtest = null),
            ),
            ...ExamSubtest.values.map((sub) {
              final selected = _selectedSubtest == sub;
              return ChoiceChip(
                selected: selected,
                avatar: Icon(_subtestIcon(sub), size: 18),
                label: Text(_subtestLabel(s, sub)),
                onSelected: (_) => setState(() => _selectedSubtest = sub),
              );
            }),
          ],
        ),

        const SizedBox(height: 18),

        // Live Official Blueprint Spec Preview
        Card(
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _SpecPill(
                      icon: Icons.timer_outlined,
                      label:
                          '${s.tr('exam_time_limit')}: $totalMin ${s.tr('exam_min_short')}',
                    ),
                    _SpecPill(
                      icon: Icons.verified_outlined,
                      label: '${s.tr('exam_pass_threshold')}: ≥ 60%',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...planned.map((sub) {
                  final mins = CefrExamBlueprints.defaultTimeLimitMinutes(
                    _selectedLevel,
                    sub,
                  );
                  final taskCnt = CefrExamBlueprints.plannedTaskCount(sub);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          _subtestIcon(sub),
                          size: 20,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _subtestLabel(s, sub),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$taskCnt ${s.tr('exam_tasks_short')} • $mins ${s.tr('exam_min_short')}',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Start Exam CTA
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: _startExam,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              '${s.tr('start_exam')} • ${_selectedLevel.code}'
              '${_selectedSubtest == null ? '' : ' (${_subtestLabel(s, _selectedSubtest!)})'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. LIVE GENERATION PROGRESS VIEW (0% -> 100%)
  // ---------------------------------------------------------------------------
  Widget _buildGenerationProgressView(BuildContext context, AppStrings s) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_genPercent%',
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (_genPercent / 100).clamp(0.02, 1.0),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _genStageKey == 'exam_stage_finalize' &&
                          _genSubtestStatus.length == 1
                      ? s.tr('exam_stage_finalize_single').replaceAll(
                            '{subtest}',
                            _subtestLabel(s, _genSubtestStatus.keys.first),
                          )
                      : s.tr(_genStageKey),
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.tr('exam_waiting_hint'),
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Chip(
                  avatar: const Icon(Icons.schedule_rounded, size: 16),
                  label: Text(_formatTimer(_genElapsedSeconds)),
                ),
                if (_genSubtestStatus.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _genSubtestStatus.entries.map((entry) {
                      final done = entry.value;
                      return Chip(
                        avatar: done
                            ? Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: Colors.green.shade600,
                              )
                            : const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                        label: Text(_subtestLabel(s, entry.key)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. ACTIVE CERTIFICATION EXAM VIEW
  // ---------------------------------------------------------------------------
  Widget _buildActiveExamView(
    BuildContext context,
    AppStrings s,
    OfficialExamSession session,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final currentPaper =
        session.subtests[_activeSubtestIndex.clamp(0, session.subtests.length - 1)];

    return Stack(
      children: [
        Column(
          children: [
            // Sticky Exam Header Bar
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      session.level.code,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: _remainingSeconds,
                    builder: (_, secs, _) {
                      final urgent = secs < 120;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: urgent
                              ? scheme.errorContainer
                              : scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: urgent
                                  ? scheme.onErrorContainer
                                  : scheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimer(secs),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: urgent
                                    ? scheme.onErrorContainer
                                    : scheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$_answeredGradableItems / $_totalGradableItems',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _confirmOrSubmitExam,
                    child: Text(
                      s.tr('finish_short'),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      AppScope.of(context).tts.stop();
                      _clearExamState();
                      setState(() {
                        _session = null;
                        _evaluation = null;
                      });
                    },
                  ),
                ],
              ),
            ),

            // Subtest Switcher Tabs (when Full 4-Subtest Exam is active)
            if (session.subtests.length > 1)
              SizedBox(
                height: 54,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  itemCount: session.subtests.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, idx) {
                    final paper = session.subtests[idx];
                    final selected = idx == _activeSubtestIndex;
                    return ChoiceChip(
                      selected: selected,
                      avatar: Icon(
                        _subtestIcon(paper.examMeta.subtest),
                        size: 16,
                      ),
                      label: Text(_subtestLabel(s, paper.examMeta.subtest)),
                      onSelected: (_) {
                        setState(() => _activeSubtestIndex = idx);
                        if (_examScrollController.hasClients) {
                          _examScrollController.jumpTo(0);
                        }
                      },
                    );
                  },
                ),
              ),

            // Active Subtest Task List
            Expanded(
              child: ListView.builder(
                controller: _examScrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 118),
                itemCount: currentPaper.tasks.length + 1,
                itemBuilder: (ctx, index) {
                  if (index == 0) {
                    return _buildSubtestMetaBanner(context, s, currentPaper);
                  }
                  final task = currentPaper.tasks[index - 1];
                  return _buildOfficialTaskCard(
                    context,
                    s,
                    currentPaper.examMeta.subtest,
                    task,
                  );
                },
              ),
            ),
          ],
        ),
        if (_showScrollToTop)
          Positioned(
            right: 16,
            bottom: 86,
            child: FloatingActionButton.small(
              heroTag: 'exam_scroll_top_fab',
              onPressed: () {
                if (_examScrollController.hasClients) {
                  _examScrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              },
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
          ),
      ],
    );
  }

  Widget _buildSubtestMetaBanner(
    BuildContext context,
    AppStrings s,
    OfficialExamSubtestPaper paper,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  _subtestIcon(paper.examMeta.subtest),
                  color: scheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_subtestLabel(s, paper.examMeta.subtest)} • ${paper.examMeta.level}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${paper.totalMaxPoints} ${s.tr('exam_points_label')} • '
                        '${paper.examMeta.timeLimitMinutes} ${s.tr('exam_min_short')} • '
                        '${paper.usedAi ? paper.providerUsed : 'CEFR Blueprint'}',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!paper.usedAi &&
              (paper.fallbackReason?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.error.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.tr('exam_ai_fallback_notice'),
                          style: textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          paper.fallbackReason!,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onErrorContainer,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfficialTaskCard(
    BuildContext context,
    AppStrings s,
    ExamSubtest subtest,
    OfficialExamTask task,
  ) {
    final controller = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final taskKey = '${subtest.apiName}_${task.taskNumber}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    _subtestIcon(subtest),
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${s.tr('exam_task_label')} ${task.taskNumber} • ${_taskTypeLabel(s, task.taskType)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${task.evaluationCriteria.maxPoints} ${s.tr('exam_points_label')}',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),

            // 1. UI Language Instruction
            if (task.instructionUi.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                task.instructionUi,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],

            // 2. Target Language Official Instruction
            if (task.instructionTarget.isNotEmpty &&
                task.instructionTarget.trim().toLowerCase() !=
                    task.instructionUi.trim().toLowerCase()) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.tr('exam_target_instruction_label'),
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.instructionTarget,
                      style: textTheme.bodyMedium?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],

            // 3. Visual Prompt Scene Card (if visual_prompt_description != null)
            if (task.stimulus.hasVisualPrompt) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.tertiary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 20,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.tr('exam_visual_scene'),
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.tertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            task.stimulus.visualPromptDescription!,
                            style: textTheme.bodySmall?.copyWith(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 4. Stimulus Block (Audio Player for Listening / Text Card for Reading, Writing, Speaking)
            if (task.stimulus.textOrTranscript.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (subtest == ExamSubtest.listening)
                _buildListeningAudioStimulus(
                  context,
                  s,
                  controller,
                  taskKey,
                  task.stimulus.textOrTranscript,
                )
              else
                _buildTextStimulusBox(
                  context,
                  s,
                  controller,
                  subtest,
                  task.stimulus.textOrTranscript,
                ),
            ],

            const SizedBox(height: 14),

            // 5. Interactive Answer Area
            if (task.taskType == OfficialTaskType.multipleChoice ||
                task.taskType == OfficialTaskType.matching)
              _buildMultipleChoiceQuestions(
                context,
                subtest,
                task,
              )
            else if (task.taskType == OfficialTaskType.shortAnswer)
              _buildShortAnswerQuestions(
                context,
                s,
                subtest,
                task,
              )
            else if (task.taskType == OfficialTaskType.openWriting)
              _buildOpenWritingArea(
                context,
                s,
                taskKey,
                task,
              )
            else
              _buildSpeakingRoleplayArea(
                context,
                s,
                controller,
                taskKey,
                task,
              ),

            // 6. Rubric Footer
            if (task.evaluationCriteria.rubric.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${s.tr('exam_rubric_label')}: ${task.evaluationCriteria.rubric}',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListeningAudioStimulus(
    BuildContext context,
    AppStrings s,
    AppController controller,
    String trackId,
    String transcript,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cleanTranscript = _cleanTranscriptForTts(transcript);
    final durationLabel = _formatApproxAudioDuration(cleanTranscript);

    return ValueListenableBuilder<String?>(
      valueListenable: controller.tts.activeTrackId,
      builder: (_, activeId, _) {
        final isPlayingThis = activeId == trackId;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isPlayingThis
                ? scheme.primaryContainer.withValues(alpha: 0.6)
                : scheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPlayingThis
                  ? scheme.primary
                  : scheme.primary.withValues(alpha: 0.3),
              width: isPlayingThis ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isPlayingThis
                        ? Icons.graphic_eq_rounded
                        : Icons.headphones_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isPlayingThis
                          ? s.tr('playing_audio_badge')
                          : '${s.tr('subtest_listening')} • $durationLabel',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isPlayingThis)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      onPressed: () => controller.tts.stop(),
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(s.tr('stop_audio_btn')),
                    )
                  else
                    FilledButton.tonalIcon(
                      onPressed: () => controller.speakTarget(
                        cleanTranscript,
                        trackId: trackId,
                      ),
                      icon: const Icon(Icons.volume_up_rounded),
                      label: Text('${s.tr('listen_short_btn')} ($durationLabel)'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _speakSlow(
                      controller,
                      cleanTranscript,
                      trackId: trackId,
                    ),
                    icon: const Icon(Icons.slow_motion_video_rounded, size: 18),
                    label: Text(s.tr('slow_05x_btn')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                s.tr('exam_listening_hidden_note'),
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextStimulusBox(
    BuildContext context,
    AppStrings s,
    AppController controller,
    ExamSubtest subtest,
    String text,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtest == ExamSubtest.speaking) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.tr('exam_examiner_prompt'),
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  onPressed: () => controller.speakTarget(text),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          SelectableText(
            text,
            style: textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceQuestions(
    BuildContext context,
    ExamSubtest subtest,
    OfficialExamTask task,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: task.questions.map((q) {
        final qKey = '${subtest.apiName}_${task.taskNumber}_${q.id}';
        final selectedIdx = _choiceAnswers[qKey];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${q.id}. ${q.questionText}',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(q.options.length, (optIdx) {
                final isSelected = selectedIdx == optIdx;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setState(() {
                        _choiceAnswers[qKey] = optIdx;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primaryContainer.withValues(alpha: 0.65)
                            : scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: isSelected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 20,
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q.options[optIdx],
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShortAnswerQuestions(
    BuildContext context,
    AppStrings s,
    ExamSubtest subtest,
    OfficialExamTask task,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: task.questions.map((q) {
        final qKey = '${subtest.apiName}_${task.taskNumber}_${q.id}';
        final ctrl = _controllerForKey(qKey);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${q.id}. ${q.questionText}',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: s.tr('exam_short_answer_hint'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOpenWritingArea(
    BuildContext context,
    AppStrings s,
    String taskKey,
    OfficialExamTask task,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ctrl = _controllerForKey(taskKey);
    final wordCount = _countWords(ctrl.text);
    final minWords = task.evaluationCriteria.minWords;
    final metMin = minWords <= 0 ? wordCount > 0 : wordCount >= minWords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.questions.isNotEmpty) ...[
          ...task.questions.map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      q.questionText,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: ctrl,
          minLines: 5,
          maxLines: 12,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: s.tr('exam_write_here_hint'),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              metMin ? Icons.check_circle_rounded : Icons.edit_outlined,
              size: 16,
              color: metMin ? Colors.green.shade700 : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              minWords > 0
                  ? '${s.tr('exam_words_count')}: $wordCount / ${s.tr('exam_min_words')} $minWords'
                  : '${s.tr('exam_words_count')}: $wordCount',
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: metMin ? Colors.green.shade700 : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeakingRoleplayArea(
    BuildContext context,
    AppStrings s,
    AppController controller,
    String taskKey,
    OfficialExamTask task,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isRecording = _activeRecordingTaskKey == taskKey;
    final transcript = _speakingTranscripts[taskKey] ?? '';
    final pronScore = _speakingPronScores[taskKey];
    final wordCount = _countWords(transcript);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.questions.isNotEmpty) ...[
          ...task.questions.map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      q.questionText,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              style: isRecording
                  ? FilledButton.styleFrom(backgroundColor: Colors.red)
                  : null,
              onPressed: () => _toggleSpeakingRecord(taskKey, task),
              icon: Icon(
                isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              ),
              label: Text(
                isRecording
                    ? s.tr('stop_recording')
                    : s.tr('speak_into_mic'),
              ),
            ),
            if (transcript.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () {
                  controller.pronunciation.playRecordedVoice(
                    slot: 'exam_sp_$taskKey',
                    fallbackTtsSpeak: () => controller.speakTarget(transcript),
                  );
                },
                icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                label: Text(s.tr('play_my_voice_btn')),
              ),
            if (pronScore != null)
              Chip(
                label: Text(
                  '${s.tr('exam_words_count')}: $wordCount • $pronScore%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: pronScore >= 60
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                  ),
                ),
              ),
          ],
        ),
        if (transcript.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.tr('you_said_label')}:',
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '«$transcript»',
                  style: textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. OFFICIAL EVALUATION & CERTIFICATE REVIEW VIEW
  // ---------------------------------------------------------------------------
  Widget _buildEvaluationView(
    BuildContext context,
    AppStrings s,
    OfficialExamSession session,
    OfficialExamEvaluation eval,
  ) {
    final controller = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final passColor =
        eval.passed ? Colors.green.shade700 : Colors.orange.shade800;

    OfficialTaskEvaluation? findTaskEval(ExamSubtest sub, int taskNum) {
      for (final te in eval.taskEvaluations) {
        if (te.subtest == sub && te.taskNumber == taskNum) return te;
      }
      return null;
    }

    return ListView(
      controller: _evalScrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 114),
      children: [
        // Result Certificate Hero Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: passColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: passColor),
                  ),
                  child: Text(
                    eval.passed
                        ? s.tr('exam_passed_badge')
                        : s.tr('exam_failed_badge'),
                    style: TextStyle(
                      color: passColor,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${eval.percentage.round()}%',
                  style: textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: passColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${eval.earnedPoints.toStringAsFixed(1)} / ${eval.maxPoints} ${s.tr('exam_points_label')} '
                  '(${s.tr('exam_pass_threshold')}: ≥ ${eval.passThresholdPercent}%)',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Chip(
                  avatar: const Icon(Icons.school_rounded, size: 18),
                  label: Text(
                    '${s.tr('exam_estimated_level_label')}: ${eval.estimatedLevel}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  eval.summary,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ),

        if (eval.strengths.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.thumb_up_alt_rounded,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.tr('exam_strengths_label'),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...eval.strengths.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $line', style: textTheme.bodyMedium),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (eval.improvements.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.tr('exam_improvements_label'),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...eval.improvements.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $line', style: textTheme.bodyMedium),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 18),
        Text(
          s.tr('exam_review_title'),
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Detailed Per-Subtest & Per-Task Review
        for (final paper in session.subtests) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _subtestIcon(paper.examMeta.subtest),
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_subtestLabel(s, paper.examMeta.subtest)} (${paper.examMeta.level})',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          for (final task in paper.tasks)
            _buildTaskReviewCard(
              context,
              s,
              controller,
              paper.examMeta.subtest,
              task,
              findTaskEval(paper.examMeta.subtest, task.taskNumber),
            ),
        ],

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: () {
              _clearExamState();
              setState(() {
                _session = null;
                _evaluation = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(s.tr('exam_new_attempt_btn')),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskReviewCard(
    BuildContext context,
    AppStrings s,
    AppController controller,
    ExamSubtest subtest,
    OfficialExamTask task,
    OfficialTaskEvaluation? taskEval,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final earned = taskEval?.earnedPoints ?? 0.0;
    final maxPts = task.evaluationCriteria.maxPoints;
    final ratio = maxPts <= 0 ? 0.0 : earned / maxPts;
    final badgeColor =
        ratio >= 0.6 ? Colors.green.shade700 : Colors.red.shade700;
    final taskKey = '${subtest.apiName}_${task.taskNumber}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.tr('exam_task_label')} ${task.taskNumber} • ${_taskTypeLabel(s, task.taskType)}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${earned.toStringAsFixed(1)} / $maxPts ${s.tr('exam_points_label')}',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),

            // Reveal Listening audio transcript in review!
            if (subtest == ExamSubtest.listening &&
                task.stimulus.textOrTranscript.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.tr('audio_script_label'),
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.volume_up_rounded, size: 18),
                          onPressed: () {
                            final clean = task.stimulus.textOrTranscript
                                .replaceAll(RegExp(r'^[\p{L}\p{N}\s]+:\s*', multiLine: true, unicode: true), '')
                                .trim();
                            controller.speakTarget(clean);
                          },
                        ),
                      ],
                    ),
                    Text(
                      task.stimulus.textOrTranscript,
                      style: textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],

            // Objective Question-by-Question Review
            if (task.taskType == OfficialTaskType.multipleChoice ||
                task.taskType == OfficialTaskType.matching ||
                task.taskType == OfficialTaskType.shortAnswer) ...[
              const SizedBox(height: 8),
              ...task.questions.map((q) {
                final qKey = '${subtest.apiName}_${task.taskNumber}_${q.id}';
                final isOk = taskEval?.questionCorrectMap[q.id] ?? false;
                String userAnswerDisplay;
                if (task.taskType == OfficialTaskType.shortAnswer) {
                  userAnswerDisplay = (_textAnswers[qKey] ?? '').trim();
                } else {
                  final picked = _choiceAnswers[qKey];
                  userAnswerDisplay =
                      (picked != null && picked >= 0 && picked < q.options.length)
                          ? q.options[picked]
                          : '—';
                }
                if (userAnswerDisplay.isEmpty) userAnswerDisplay = '—';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isOk
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                            size: 18,
                            color: isOk
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${q.id}. ${q.questionText}',
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${s.tr('exam_your_answer_label')}: $userAnswerDisplay',
                        style: textTheme.bodySmall,
                      ),
                      if (!isOk)
                        Text(
                          '${s.tr('correct_answer_label')}: ${q.displayCorrectAnswerText}',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (q.explanation.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            q.explanation,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ] else ...[
              // Open Writing / Speaking Roleplay Review
              const SizedBox(height: 8),
              Builder(
                builder: (_) {
                  final userText = task.taskType == OfficialTaskType.openWriting
                      ? (_textAnswers[taskKey] ?? '').trim()
                      : (_speakingTranscripts[taskKey] ?? '').trim();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.tr('exam_your_answer_label')}: ${userText.isEmpty ? '—' : userText}',
                        style: textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                      if (task.taskType == OfficialTaskType.speakingRoleplay &&
                          userText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              controller.pronunciation.playRecordedVoice(
                                slot: 'exam_sp_$taskKey',
                                fallbackTtsSpeak: () =>
                                    controller.speakTarget(userText),
                              );
                            },
                            icon: const Icon(
                              Icons.play_circle_outline_rounded,
                              size: 16,
                            ),
                            label: Text(s.tr('play_my_voice_btn')),
                          ),
                        ),
                      if ((taskEval?.feedback ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${s.tr('exam_ai_feedback_label')}: ${taskEval!.feedback}',
                            style: textTheme.bodySmall?.copyWith(height: 1.4),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpecPill extends StatelessWidget {
  const _SpecPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
