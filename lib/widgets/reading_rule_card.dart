import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/reading_rules_book.dart';

/// Card displaying a single alphabet character or diacritic with TTS playback.
class AlphabetEntryCard extends StatelessWidget {
  const AlphabetEntryCard({
    super.key,
    required this.entry,
    required this.onSpeak,
  });

  final AlphabetEntry entry;
  final ValueChanged<String> onSpeak;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final speakable =
        entry.exampleWord.isNotEmpty ? entry.exampleWord : entry.symbol;

    return Card(
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                entry.symbol,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.pronunciation,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (entry.exampleWord.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.exampleWord,
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        if (entry.exampleTranslation.isNotEmpty)
                          Text(
                            '— ${entry.exampleTranslation}',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (entry.note.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      entry.note,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: s.tr('rules_book_listen_tooltip'),
              onPressed: () {
                HapticFeedback.selectionClick();
                onSpeak(speakable);
              },
              icon: Icon(
                Icons.volume_up_rounded,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card displaying a reading, stress, or writing rule with speakable examples.
class ReadingRuleItemCard extends StatelessWidget {
  const ReadingRuleItemCard({
    super.key,
    required this.item,
    required this.accentColor,
    required this.onSpeak,
  });

  final ReadingRuleItem item;
  final Color accentColor;
  final ValueChanged<String> onSpeak;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.explanation,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.92),
                height: 1.45,
              ),
            ),
            if (item.examples.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...item.examples.map((ex) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    ex.text,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  if (ex.pronunciation.isNotEmpty)
                                    Text(
                                      ex.pronunciation,
                                      style: textTheme.labelMedium?.copyWith(
                                        color: accentColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              if (ex.translation.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  ex.translation,
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
                          tooltip: s.tr('rules_book_listen_tooltip'),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            onSpeak(ex.text);
                          },
                          icon: Icon(
                            Icons.volume_up_rounded,
                            size: 20,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
