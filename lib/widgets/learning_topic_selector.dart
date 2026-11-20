import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/learning_topic.dart';

/// Reusable dark-theme selector for the 6 [LearningTopic] domains.
/// Used both in first-launch onboarding and in Settings.
class LearningTopicSelector extends StatelessWidget {
  const LearningTopicSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final LearningTopic selected;
  final ValueChanged<LearningTopic> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: LearningTopic.values.map((topic) {
        final isSelected = topic == selected;
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 8 : 10),
          child: Material(
            color: isSelected
                ? scheme.primaryContainer.withValues(alpha: 0.42)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(topic);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: compact ? 9 : 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.7)
                        : scheme.outlineVariant.withValues(alpha: 0.3),
                    width: isSelected ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: compact ? 34 : 38,
                      height: compact ? 34 : 38,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? scheme.primary.withValues(alpha: 0.22)
                            : scheme.surfaceContainerHighest
                                .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        topic.icon,
                        size: compact ? 18 : 20,
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.tr(topic.titleKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (compact
                                    ? textTheme.labelLarge
                                    : textTheme.titleSmall)
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? scheme.onSurface
                                  : scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.tr(topic.descKey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: isSelected
                          ? scheme.primary
                          : scheme.outlineVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
