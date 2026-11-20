import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/exam_models.dart';
import '../models/vocab_word.dart';
import '../state/app_controller.dart';
import 'pronunciation_practice_sheet.dart';

Future<void> showWordLookupSheet({
  required BuildContext context,
  required String word,
  required String contextSentence,
  required String sourceTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _WordLookupSheet(
      word: word,
      contextSentence: contextSentence,
      sourceTitle: sourceTitle,
    ),
  );
}

class _WordLookupSheet extends StatefulWidget {
  const _WordLookupSheet({
    required this.word,
    required this.contextSentence,
    required this.sourceTitle,
  });

  final String word;
  final String contextSentence;
  final String sourceTitle;

  @override
  State<_WordLookupSheet> createState() => _WordLookupSheetState();
}

class _WordLookupSheetState extends State<_WordLookupSheet> {
  WordLookupResult? _result;
  bool _loading = true;
  bool _saved = false;
  String? _error;
  bool _didStart = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didStart) {
      _didStart = true;
      final controller = AppScope.of(context);
      _saved = controller.hasWord(widget.word);
      _fetchLookup(controller);
    }
  }

  Future<void> _fetchLookup(AppController controller) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await controller.gemini.lookupWordInContext(
        word: widget.word,
        contextSentence: widget.contextSentence,
        settings: controller.settings,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveToVocabulary() async {
    final controller = AppScope.of(context);
    final res = _result;
    if (res == null) return;

    final now = DateTime.now();
    final vocab = VocabWord(
      id: 'word_${now.microsecondsSinceEpoch}',
      word: widget.word,
      translation: res.translation,
      contextSentence: widget.contextSentence,
      exampleSentence: res.example,
      partOfSpeech: res.partOfSpeech,
      sourceTitle: widget.sourceTitle,
      createdAt: now,
      nextReviewAt: now,
    );

    await controller.addWord(vocab);
    if (!mounted) return;
    setState(() {
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                        widget.word,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_result != null && _result!.partOfSpeech.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _result!.partOfSpeech,
                              style: textTheme.labelMedium?.copyWith(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () {
                    showPronunciationPracticeSheet(
                      context: context,
                      targetText: widget.word,
                      translation: _result?.translation,
                    );
                  },
                  icon: const Icon(Icons.mic_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => controller.speakTarget(widget.word),
                  icon: const Icon(Icons.volume_up_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    '$_error',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              )
            else if (_result != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${controller.settings.nativeLanguage.flag} ${s.langName(controller.settings.nativeLanguage)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          _result!.usedAi
                              ? Icons.auto_awesome_rounded
                              : Icons.translate_rounded,
                          size: 16,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result!.translation,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_result!.example.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _result!.example,
                        style: textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.volume_up_outlined, size: 20),
                      onPressed: () =>
                          controller.speakTarget(_result!.example),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (_result!.explanation.isNotEmpty) ...[
                Text(
                  _result!.explanation,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (widget.contextSentence.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.contextSentence,
                    style: textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saved ? null : _saveToVocabulary,
                  icon: Icon(
                    _saved
                        ? Icons.check_circle_rounded
                        : Icons.bookmark_add_rounded,
                  ),
                  label: Text(
                    _saved ? s.tr('already_in_vocab') : s.tr('add_to_vocab'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
