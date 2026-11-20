import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../models/vocab_word.dart';
import '../../state/app_controller.dart';
import '../../widgets/pronunciation_practice_sheet.dart';
import '../../widgets/user_avatar_button.dart';
import '../profile/profile_screen.dart';

enum _VocabFilter { all, due, mastered }

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';
  _VocabFilter _filter = _VocabFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _exportCsv() async {
    final controller = AppScope.of(context);
    if (controller.vocabulary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).tr('empty_vocab')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final path = await controller.csv.exportVocabularyToFile(
        controller.vocabulary,
      );
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV (${controller.vocabulary.length}) ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _importCsv() async {
    final controller = AppScope.of(context);
    try {
      final result = await controller.csv.importVocabularyFromFile();
      if (!mounted || result.cancelled) return;

      final added = await controller.importWords(result.importedWords);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+$added CSV ✓'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddWordDialog() async {
    final s = AppStrings.of(context);
    final wordCtrl = TextEditingController();
    final transCtrl = TextEditingController();
    final ctxCtrl = TextEditingController();
    final exampleCtrl = TextEditingController();

    final created = await showDialog<VocabWord>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('new_word_title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wordCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: s.tr('word_or_phrase'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: transCtrl,
                decoration: InputDecoration(
                  labelText: s.tr('translation_label'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctxCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: s.tr('context_optional'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: exampleCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: s.tr('example_optional'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.tr('cancel_btn')),
          ),
          FilledButton(
            onPressed: () {
              final w = wordCtrl.text.trim();
              final t = transCtrl.text.trim();
              if (w.isEmpty || t.isEmpty) return;
              final now = DateTime.now();
              Navigator.of(ctx).pop(
                VocabWord(
                  id: 'manual_word_${now.microsecondsSinceEpoch}',
                  word: w,
                  translation: t,
                  contextSentence: ctxCtrl.text.trim(),
                  exampleSentence: exampleCtrl.text.trim(),
                  sourceTitle: '',
                  createdAt: now,
                  nextReviewAt: now,
                ),
              );
            },
            child: Text(s.tr('add_btn')),
          ),
        ],
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 450), () {
      wordCtrl.dispose();
      transCtrl.dispose();
      ctxCtrl.dispose();
      exampleCtrl.dispose();
    });

    if (created != null && mounted) {
      final controller = AppScope.of(context);
      await controller.addWord(created);
    }
  }

  List<VocabWord> _filteredWords(List<VocabWord> all) {
    final q = _query.trim().toLowerCase();
    return all.where((w) {
      switch (_filter) {
        case _VocabFilter.due:
          if (!w.isDue) return false;
        case _VocabFilter.mastered:
          if (!w.isMastered) return false;
        case _VocabFilter.all:
          break;
      }
      if (q.isEmpty) return true;
      return w.word.toLowerCase().contains(q) ||
          w.translation.toLowerCase().contains(q) ||
          w.contextSentence.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final allWords = controller.vocabulary;
    final words = _filteredWords(allWords);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          '${s.tr('tab_vocab')} (${allWords.length})',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'CSV (Anki)',
            icon: const Icon(Icons.import_export_rounded),
            onSelected: (value) {
              if (value == 'import') {
                _importCsv();
              } else if (value == 'export') {
                _exportCsv();
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem<String>(
                value: 'import',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.file_upload_outlined),
                  title: Text('Import CSV (Anki)'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'export',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.file_download_outlined),
                  title: Text('Export CSV (Anki)'),
                ),
              ),
            ],
          ),
          StreakXpHeaderBadges(
            onProfileTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton.extended(
          onPressed: _showAddWordDialog,
          icon: const Icon(Icons.add_rounded),
          label: Text(s.tr('word_btn')),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: s.tr('search_vocab_hint'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                FilterChip(
                  label: Text('${s.tr('filter_all')} (${allWords.length})'),
                  selected: _filter == _VocabFilter.all,
                  onSelected: (_) => setState(() => _filter = _VocabFilter.all),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: Text(
                    '${s.tr('filter_due')} (${allWords.where((w) => w.isDue).length})',
                  ),
                  selected: _filter == _VocabFilter.due,
                  onSelected: (_) => setState(() => _filter = _VocabFilter.due),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  label: Text(
                    '${s.tr('filter_mastered')} (${allWords.where((w) => w.isMastered).length})',
                  ),
                  selected: _filter == _VocabFilter.mastered,
                  onSelected: (_) =>
                      setState(() => _filter = _VocabFilter.mastered),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: words.isEmpty
                ? _buildMotivatingEmptyState(
                    context: context,
                    controller: controller,
                    s: s,
                    allWords: allWords,
                  )
                : ListView.separated(
                    key: const PageStorageKey<String>('vocab_scroll_list'),
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 152),
                    itemCount: words.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final w = words[index];
                      return _VocabCard(
                        word: w,
                        onSpeak: () => controller.speakTarget(w.word),
                        onDelete: () => controller.deleteWord(w.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivatingEmptyState({
    required BuildContext context,
    required AppController controller,
    required AppStrings s,
    required List<VocabWord> allWords,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasQuery = _query.trim().isNotEmpty;

    // 1. User actually typed a search query that returned 0 matches
    if (hasQuery) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                s.tr('no_search_results'),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // 2. Filter: Mastered (0)
    if (_filter == _VocabFilter.mastered && allWords.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 46,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.tr('empty_mastered_title'),
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.tr('empty_mastered_desc'),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  controller.navigateToTab(2, trainingSubMode: 0);
                },
                icon: const Icon(Icons.style_rounded),
                label: Text(s.tr('go_to_srs_btn')),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Filter: Due for review (0)
    if (_filter == _VocabFilter.due && allWords.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  size: 46,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.tr('empty_due_title'),
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.tr('empty_due_desc'),
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.tonalIcon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  controller.navigateToTab(2, trainingSubMode: 0);
                },
                icon: const Icon(Icons.style_rounded),
                label: Text(s.tr('go_to_srs_btn')),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Vocabulary is completely empty
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate_rounded,
              size: 48,
              color: scheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              s.tr('empty_vocab'),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _VocabCard extends StatelessWidget {
  const _VocabCard({
    required this.word,
    required this.onSpeak,
    required this.onDelete,
  });

  final VocabWord word;
  final VoidCallback onSpeak;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.word,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        word.translation,
                        style: textTheme.bodyLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.volume_up_rounded, size: 19),
                  onPressed: onSpeak,
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.mic_rounded, size: 19),
                  onPressed: () {
                    showPronunciationPracticeSheet(
                      context: context,
                      targetText: word.word,
                      translation: word.translation,
                    );
                  },
                ),
              ],
            ),
            if (word.contextSentence.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  word.contextSentence,
                  style: textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (word.partOfSpeech.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            word.partOfSpeech,
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      _WordMasteryIndicator(word: word),
                      if (word.sourceTitle.isNotEmpty &&
                          word.sourceTitle != s.tr('manual_sub') &&
                          word.sourceTitle.toLowerCase() != 'вручну' &&
                          word.sourceTitle.toLowerCase() != 'manual')
                        Text(
                          word.sourceTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WordMasteryIndicator extends StatelessWidget {
  const _WordMasteryIndicator({required this.word});

  final VocabWord word;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 4 mastery stages:
    // 1: New word (repetitions == 0) -> Red / DeepOrange
    // 2: Learning (repetitions == 1 or intervalDays < 3) -> Orange / Amber
    // 3: Consolidating (repetitions >= 2 and !isMastered) -> Light Green / Teal
    // 4: Mastered (isMastered) -> Green
    final int stage;
    final Color activeColor;
    final String label;

    if (word.repetitions == 0) {
      stage = 1;
      activeColor = Colors.deepOrangeAccent;
      label = s.tr('vocab_status_new');
    } else if (word.isMastered) {
      stage = 4;
      activeColor = Colors.green.shade400;
      label = s.tr('vocab_status_mastered');
    } else if (word.repetitions == 1 || word.intervalDays < 3) {
      stage = 2;
      activeColor = Colors.amber.shade600;
      label = word.isDue
          ? s.tr('vocab_status_review')
          : s.tr('vocab_status_learning');
    } else {
      stage = 3;
      activeColor = Colors.tealAccent.shade400;
      label = word.isDue
          ? s.tr('vocab_status_review')
          : s.tr('vocab_status_consolidating');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) {
              final filled = i < stage;
              return Container(
                width: 11,
                height: 5,
                margin: EdgeInsets.only(right: i < 3 ? 3 : 0),
                decoration: BoxDecoration(
                  color: filled
                      ? activeColor
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: activeColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
