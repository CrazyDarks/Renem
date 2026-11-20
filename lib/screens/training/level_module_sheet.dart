import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../models/level_curriculum.dart';
import '../../state/app_controller.dart';

/// Interactive CEFR level lesson modal sheet:
/// 1) AI-generated (cached offline) grammar rule, common mistakes & examples;
/// 2) 5 interactive multiple-choice practice exercises;
/// 3) Final mastery test (>= 70% unlocks the next level node).
class LevelModuleSheet extends StatefulWidget {
  const LevelModuleSheet({super.key, required this.node});

  final CurriculumModuleNode node;

  @override
  State<LevelModuleSheet> createState() => _LevelModuleSheetState();
}

class _LevelModuleSheetState extends State<LevelModuleSheet> {
  bool _loading = true;
  bool _refreshingAi = false;
  bool _loadedFromCache = false;
  bool _initialized = false;
  GeneratedLevelContent? _content;

  // Interactive practice state (5 drills)
  final Map<int, int> _practiceSelections = {};

  // Final test state (5-6 questions, >= 70% unlocks next node)
  bool _testStarted = false;
  final Map<int, int> _testSelections = {};
  bool _testSubmitted = false;
  int _testScore = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadModuleContent();
    }
  }

  Future<void> _loadModuleContent({bool forceAiRefresh = false}) async {
    final controller = AppScope.of(context);
    final settings = controller.settings;
    final cacheKey = widget.node.cacheKey(
      targetLangCode: settings.targetLanguageCode,
      nativeLangCode: settings.nativeLanguageCode,
      topicId: settings.learningTopicId,
    );

    final offlineFallback = UniversalCurriculumBlueprint.buildOfflineFallback(
      node: widget.node,
      targetLang: settings.targetLanguage,
      nativeLang: settings.nativeLanguage,
      userVocab: controller.vocabulary,
    );

    // 1. Check SharedPreferences local cache first (instant load, 0 API calls)
    if (!forceAiRefresh) {
      final cachedJson =
          await controller.storage.loadLevelContentCache(cacheKey);
      if (cachedJson != null) {
        final parsed = GeneratedLevelContent.fromJson(cachedJson);
        if (parsed.isValid) {
          if (!mounted) return;
          setState(() {
            _content = parsed;
            _loading = false;
            _loadedFromCache = true;
          });
          return;
        }
      }
    }

    if (mounted) {
      setState(() {
        if (forceAiRefresh) {
          _refreshingAi = true;
        } else {
          _loading = true;
        }
      });
    }

    // 2. Single Multi-AI request tailored to targetLang + selected LearningTopic
    final generated = await controller.gemini.generateLevelModuleContent(
      node: widget.node,
      targetLang: settings.targetLanguage,
      nativeLang: settings.nativeLanguage,
      settings: settings,
      offlineFallback: offlineFallback,
    );

    // 3. Persist AI-generated level to local cache
    if (generated.usedAi) {
      await controller.storage.saveLevelContentCache(
        cacheKey,
        generated.toJson(),
      );
    }

    if (!mounted) return;
    setState(() {
      _content = generated;
      _loading = false;
      _refreshingAi = false;
      _loadedFromCache = false;
      if (forceAiRefresh) {
        _practiceSelections.clear();
        _testSelections.clear();
        _testSubmitted = false;
        _testScore = 0;
      }
    });

    if (forceAiRefresh && generated.usedAi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).tr('level_ai_updated_toast')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitFinalTest() async {
    final content = _content;
    if (content == null || content.finalTest.isEmpty) return;

    final controller = AppScope.of(context);
    final items = content.finalTest;
    int correct = 0;
    for (int i = 0; i < items.length; i++) {
      if (_testSelections[i] == items[i].correctIndex) {
        correct++;
      }
    }
    final percent = ((correct / items.length) * 100).round();
    final passed = percent >= 70;

    setState(() {
      _testScore = correct;
      _testSubmitted = true;
    });

    if (passed) {
      HapticFeedback.mediumImpact();
      final progressKey =
          widget.node.progressKey(controller.settings.targetLanguageCode);
      await controller.completeLevelPathNode(progressKey);
    } else {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final uiLang = controller.settings.nativeLanguageCode;
    final targetLang = controller.settings.targetLanguage;
    final content = _content;
    final totalTest = content?.finalTest.length ?? 0;
    final testPercent =
        totalTest == 0 ? 0 : ((_testScore / totalTest) * 100).round();
    final passed = testPercent >= 70;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.90,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (ctx, scrollCtrl) {
        if (_loading || content == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(
                    '${targetLang.flag} ${widget.node.cefr.code} • ${widget.node.title(uiLang)}',
                    textAlign: TextAlign.center,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.tr('level_generating_ai_msg'),
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
          children: [
            // Overflow-safe Wrap for header badges + AI refresh action
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${targetLang.flag} ${widget.node.cefr.code} • #${widget.node.stepNumber}',
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (content.usedAi)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _loadedFromCache
                                  ? Icons.offline_pin_rounded
                                  : Icons.auto_awesome_rounded,
                              size: 13,
                              color: Colors.teal.shade300,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _loadedFromCache
                                  ? s.tr('level_cached_badge')
                                  : 'AI',
                              style: textTheme.labelSmall?.copyWith(
                                color: Colors.teal.shade300,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: _refreshingAi
                      ? null
                      : () => _loadModuleContent(forceAiRefresh: true),
                  icon: _refreshingAi
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(s.tr('refresh_ai_rule_btn')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.node.title(uiLang),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.node.subtitle(uiLang),
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),

            // Offline fallback notice banner if AI was unavailable
            if (!content.usedAi) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      size: 18,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.tr('level_offline_banner'),
                        style: textTheme.bodySmall?.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // 1. AI Rule Explanation + Common Mistakes + Key Tip Card
            Card(
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_rounded,
                          size: 20,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.tr('ai_rule_block_title'),
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      content.grammarRule,
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    if (content.commonMistakes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    s.tr('common_mistakes_title'),
                                    style: textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              content.commonMistakes,
                              style: textTheme.bodySmall?.copyWith(
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (content.keyTip.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              scheme.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                content.keyTip,
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      s.tr('examples_in_context'),
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...content.examples.map((ex) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex.target,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (ex.native.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        ex.native,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    controller.speakTarget(ex.target),
                                icon: Icon(
                                  Icons.volume_up_rounded,
                                  size: 19,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 2. Interactive Practice (5 AI-tailored drills)
            Text(
              '${s.tr('interactive_practice_title')} (${content.practiceExercises.length})',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...List.generate(content.practiceExercises.length, (pIdx) {
              final item = content.practiceExercises[pIdx];
              final selected = _practiceSelections[pIdx];
              final answered = selected != null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pIdx + 1}. ${item.question}',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(item.options.length, (optIdx) {
                          final isChosen = selected == optIdx;
                          final isRight = optIdx == item.correctIndex;
                          Color? borderColor;
                          Color? fillColor;
                          if (answered) {
                            if (isRight) {
                              borderColor = Colors.green;
                              fillColor = Colors.green.withValues(alpha: 0.14);
                            } else if (isChosen) {
                              borderColor = Colors.redAccent;
                              fillColor =
                                  Colors.redAccent.withValues(alpha: 0.14);
                            }
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: answered
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _practiceSelections[pIdx] = optIdx;
                                      });
                                    },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: fillColor ??
                                      scheme.surfaceContainerHighest
                                          .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor ??
                                        scheme.outlineVariant
                                            .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  item.options[optIdx],
                                  style: textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          );
                        }),
                        if (answered && item.explanation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.explanation,
                            style: textTheme.bodySmall?.copyWith(
                              color: selected == item.correctIndex
                                  ? Colors.green.shade400
                                  : Colors.orange.shade300,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),

            // 3. Final Level Mastery Test (5-6 questions, >=70% unlocks next node)
            Card(
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: scheme.secondary.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 20,
                          color: scheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${s.tr('final_level_test_title')} ($totalTest • ≥ 70%)',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_testStarted)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() => _testStarted = true);
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(s.tr('start_final_test_btn')),
                        ),
                      )
                    else ...[
                      ...List.generate(content.finalTest.length, (qIdx) {
                        final q = content.finalTest[qIdx];
                        final chosen = _testSelections[qIdx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${qIdx + 1}. ${q.question}',
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...List.generate(q.options.length, (optIdx) {
                                final isSelected = chosen == optIdx;
                                final isRight = optIdx == q.correctIndex;
                                Color? fill;
                                Color? border;
                                if (_testSubmitted) {
                                  if (isRight) {
                                    fill = Colors.green.withValues(alpha: 0.15);
                                    border = Colors.green;
                                  } else if (isSelected) {
                                    fill =
                                        Colors.redAccent.withValues(alpha: 0.15);
                                    border = Colors.redAccent;
                                  }
                                } else if (isSelected) {
                                  fill = scheme.primaryContainer
                                      .withValues(alpha: 0.6);
                                  border = scheme.primary;
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(11),
                                    onTap: _testSubmitted
                                        ? null
                                        : () {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              _testSelections[qIdx] = optIdx;
                                            });
                                          },
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: fill ??
                                            scheme.surfaceContainerHighest
                                                .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                          color: border ??
                                              scheme.outlineVariant
                                                  .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(q.options[optIdx]),
                                    ),
                                  ),
                                );
                              }),
                              if (_testSubmitted && q.explanation.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    q.explanation,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      if (!_testSubmitted)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _testSelections.length == totalTest
                                ? _submitFinalTest
                                : null,
                            icon: const Icon(Icons.check_circle_rounded),
                            label: Text(s.tr('complete_level_btn')),
                          ),
                        )
                      else ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (passed ? Colors.green : Colors.orange)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: (passed ? Colors.green : Colors.orange)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_testScore / $totalTest ($testPercent%)',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: passed
                                      ? Colors.green.shade400
                                      : Colors.orange.shade300,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                passed
                                    ? s.tr('level_passed_msg')
                                    : s.tr('level_retry_msg'),
                                style: textTheme.bodySmall?.copyWith(
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: passed
                              ? FilledButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(s.tr('ok_btn')),
                                )
                              : OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _testSelections.clear();
                                      _testSubmitted = false;
                                      _testScore = 0;
                                    });
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(s.tr('retake_exam_btn')),
                                ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
