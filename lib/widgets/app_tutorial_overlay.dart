import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../state/app_controller.dart';
import 'learning_topic_selector.dart';

class _TutorialStepData {
  const _TutorialStepData({
    required this.icon,
    required this.accentColor,
    required this.titleKey,
    required this.descKey,
    this.bulletKeys = const [],
    this.bulletIcons = const [],
    this.isTopicPicker = false,
  });

  final IconData icon;
  final Color accentColor;
  final String titleKey;
  final String descKey;
  final List<String> bulletKeys;
  final List<IconData> bulletIcons;
  final bool isTopicPicker;
}

class AppTutorialOverlay extends StatelessWidget {
  const AppTutorialOverlay({super.key});

  static const List<_TutorialStepData> _steps = [
    _TutorialStepData(
      icon: Icons.tune_rounded,
      accentColor: Colors.tealAccent,
      titleKey: 'learning_topic_onboarding_title',
      descKey: 'learning_topic_onboarding_desc',
      isTopicPicker: true,
    ),
    _TutorialStepData(
      icon: Icons.menu_book_rounded,
      accentColor: Colors.indigoAccent,
      titleKey: 'tutorial_step1_title',
      descKey: 'tutorial_step1_desc',
      bulletKeys: [
        'tutorial_step1_b1',
        'tutorial_step1_b2',
        'tutorial_step1_b3',
      ],
      bulletIcons: [
        Icons.record_voice_over_rounded,
        Icons.ondemand_video_rounded,
        Icons.document_scanner_rounded,
      ],
    ),
    _TutorialStepData(
      icon: Icons.bookmark_rounded,
      accentColor: Colors.teal,
      titleKey: 'tutorial_step2_title',
      descKey: 'tutorial_step2_desc',
      bulletKeys: [
        'tutorial_step2_b1',
        'tutorial_step2_b2',
        'tutorial_step2_b3',
      ],
      bulletIcons: [
        Icons.search_rounded,
        Icons.mic_rounded,
        Icons.import_export_rounded,
      ],
    ),
    _TutorialStepData(
      icon: Icons.fitness_center_rounded,
      accentColor: Colors.deepOrange,
      titleKey: 'tutorial_step3_title',
      descKey: 'tutorial_step3_desc',
      bulletKeys: [
        'tutorial_step3_b1',
        'tutorial_step3_b2',
        'tutorial_step3_b3',
      ],
      bulletIcons: [
        Icons.style_rounded,
        Icons.route_rounded,
        Icons.bolt_rounded,
      ],
    ),
    _TutorialStepData(
      icon: Icons.account_circle_rounded,
      accentColor: Colors.amber,
      titleKey: 'tutorial_step4_title',
      descKey: 'tutorial_step4_desc',
      bulletKeys: [
        'tutorial_step4_b1',
        'tutorial_step4_b2',
        'tutorial_step4_b3',
      ],
      bulletIcons: [
        Icons.local_fire_department_rounded,
        Icons.people_alt_rounded,
        Icons.tune_rounded,
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final stepIndex = controller.tutorialStepIndex.clamp(0, _steps.length - 1);
    final step = _steps[stepIndex];
    final isLastStep = stepIndex == _steps.length - 1;

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: step.accentColor.withValues(alpha: 0.45),
                    width: 1.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overflow-safe top row: Guide badge + Step counter + Skip button
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: step.accentColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: step.accentColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 14,
                                  color: step.accentColor,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${s.tr('tutorial_badge')} • ${stepIndex + 1}/${_steps.length}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: step.accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            controller.completeTutorial();
                          },
                          child: Text(
                            s.tr('tutorial_skip'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Hero Icon + Step Title
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: step.accentColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            step.icon,
                            size: 26,
                            color: step.accentColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.tr(step.titleKey),
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Text(
                      s.tr(step.descKey),
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.38,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Step 0: Interactive Learning Topic Picker | Steps 1..4: Feature bullets
                    if (step.isTopicPicker)
                      LearningTopicSelector(
                        compact: true,
                        selected: controller.settings.learningTopic,
                        onSelected: (topic) {
                          controller.updateSettings(
                            controller.settings.copyWith(
                              learningTopicId: topic.id,
                            ),
                          );
                        },
                      )
                    else
                      ...List.generate(step.bulletKeys.length, (idx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  step.bulletIcons[idx],
                                  size: 19,
                                  color: step.accentColor,
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Text(
                                    s.tr(step.bulletKeys[idx]),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurface,
                                      height: 1.35,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 8),

                    // Progress dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_steps.length, (idx) {
                        final active = idx == stepIndex;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.setTutorialStep(idx);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? step.accentColor
                                  : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),

                    // Overflow-safe navigation buttons
                    Row(
                      children: [
                        if (stepIndex > 0) ...[
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                controller.setTutorialStep(stepIndex - 1);
                              },
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  s.tr('tutorial_back'),
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 3,
                          child: FilledButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              if (isLastStep) {
                                controller.completeTutorial();
                              } else {
                                controller.setTutorialStep(stepIndex + 1);
                              }
                            },
                            icon: Icon(
                              isLastStep
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isLastStep
                                    ? s.tr('tutorial_finish')
                                    : s.tr('tutorial_next'),
                                maxLines: 1,
                                softWrap: false,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
