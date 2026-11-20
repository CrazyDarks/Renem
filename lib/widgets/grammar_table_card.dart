import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../models/grammar_book_models.dart';
import '../models/reading_rules_book.dart';

/// Dark-theme horizontal-scrollable grammar table (cases, endings, conjugations).
class GrammarTableCard extends StatelessWidget {
  const GrammarTableCard({
    super.key,
    required this.table,
    required this.accentColor,
  });

  final GrammarTable table;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final colCount = table.headers.length;
    if (colCount == 0 || table.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (table.title.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.table_chart_rounded, size: 17, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      table.title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  border: TableBorder.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.16),
                      ),
                      children: table.headers
                          .map(
                            (h) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              child: Text(
                                h,
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    ...List.generate(table.rows.length, (rowIdx) {
                      final rawRow = table.rows[rowIdx];
                      final cells = List<String>.generate(
                        colCount,
                        (c) => c < rawRow.length ? rawRow[c] : '',
                      );
                      return TableRow(
                        decoration: BoxDecoration(
                          color: rowIdx.isEven
                              ? scheme.surfaceContainerLowest
                                  .withValues(alpha: 0.5)
                              : scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.28),
                        ),
                        children: List.generate(cells.length, (cIdx) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                cells[cIdx],
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: cIdx == 0
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: cIdx == 0
                                      ? accentColor
                                      : scheme.onSurface,
                                  height: 1.32,
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ],
                ),
              ),
            ),
            if (table.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                table.note,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable speakable example tile with inline TTS button.
class GrammarExampleTile extends StatelessWidget {
  const GrammarExampleTile({
    super.key,
    required this.example,
    required this.accentColor,
    required this.onSpeak,
  });

  final ReadingRuleExample example;
  final Color accentColor;
  final ValueChanged<String> onSpeak;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
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
                        example.text,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (example.pronunciation.isNotEmpty)
                        Text(
                          example.pronunciation,
                          style: textTheme.labelMedium?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  if (example.translation.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      example.translation,
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
                onSpeak(example.text);
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
  }
}

/// Deep grammar rule block card displaying explanation, specific exceptions,
/// and 2-3 speakable examples.
class GrammarRuleSectionCard extends StatelessWidget {
  const GrammarRuleSectionCard({
    super.key,
    required this.section,
    required this.accentColor,
    required this.onSpeak,
  });

  final GrammarRuleSection section;
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
                    section.title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              section.explanation,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.92),
                height: 1.48,
              ),
            ),
            if (section.exceptions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
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
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.amber.shade400,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.tr('grammar_qa_exceptions_label'),
                            style: textTheme.labelMedium?.copyWith(
                              color: Colors.amber.shade300,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...section.exceptions.map(
                      (ex) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '• $ex',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.9),
                            height: 1.38,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (section.examples.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...section.examples.map(
                (ex) => GrammarExampleTile(
                  example: ex,
                  accentColor: accentColor,
                  onSpeak: onSpeak,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Saved Q&A entry card displayed in "Мої запитання" (and latest answer banner).
class GrammarQaCard extends StatelessWidget {
  const GrammarQaCard({
    super.key,
    required this.entry,
    required this.onSpeak,
    this.onDelete,
    this.highlighted = false,
  });

  final GrammarQaEntry entry;
  final ValueChanged<String> onSpeak;
  final VoidCallback? onDelete;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: highlighted
              ? scheme.primary.withValues(alpha: 0.65)
              : scheme.outlineVariant.withValues(alpha: 0.35),
          width: highlighted ? 1.4 : 1,
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
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.question,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.28,
                        ),
                      ),
                      if (entry.providerName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          entry.providerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: s.tr('grammar_qa_delete_tooltip'),
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              entry.answer,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.94),
                height: 1.5,
              ),
            ),
            if (entry.tables.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...entry.tables.map(
                (t) => GrammarTableCard(
                  table: t,
                  accentColor: scheme.primary,
                ),
              ),
            ],
            if (entry.examples.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                s.tr('grammar_qa_examples_label'),
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ...entry.examples.map(
                (ex) => GrammarExampleTile(
                  example: ex,
                  accentColor: scheme.primary,
                  onSpeak: onSpeak,
                ),
              ),
            ],
            if (entry.exceptionsAndMistakes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
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
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Colors.amber.shade400,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.tr('grammar_qa_exceptions_label'),
                            style: textTheme.labelMedium?.copyWith(
                              color: Colors.amber.shade300,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...entry.exceptionsAndMistakes.map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '• $tip',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.9),
                            height: 1.38,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
