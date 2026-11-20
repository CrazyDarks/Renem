import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../models/grammar_book_models.dart';
import '../../state/app_controller.dart';
import '../../widgets/grammar_table_card.dart';
import 'grammar_chapter_screen.dart';

/// Full 9-chapter "Книжечка з правилами" (Comprehensive Grammar Handbook)
/// with per-chapter offline caching and an interactive "Ask AI about any rule
/// or exception" panel backed by persistent offline Q&A history.
class ReadingRulesScreen extends StatefulWidget {
  const ReadingRulesScreen({super.key});

  @override
  State<ReadingRulesScreen> createState() => _ReadingRulesScreenState();
}

class _ReadingRulesScreenState extends State<ReadingRulesScreen> {
  final TextEditingController _questionController = TextEditingController();
  final FocusNode _questionFocusNode = FocusNode();

  int _selectedTab = 0; // 0 = 9 Chapters TOC, 1 = My Questions History
  Set<String> _cachedChapterKeys = const {};
  List<GrammarQaEntry> _qaHistory = const [];
  GrammarQaEntry? _latestAnswer;
  bool _askingAi = false;
  String? _askError;
  String _loadedPairKey = '';

  @override
  void dispose() {
    _questionController.dispose();
    _questionFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    final pairKey =
        '${controller.settings.targetLanguageCode}_${controller.settings.nativeLanguageCode}';
    if (_loadedPairKey != pairKey) {
      _loadedPairKey = pairKey;
      _latestAnswer = null;
      _askError = null;
      _reloadLocalState();
    }
  }

  Future<void> _reloadLocalState() async {
    final controller = AppScope.of(context);
    final targetCode = controller.settings.targetLanguageCode;
    final nativeCode = controller.settings.nativeLanguageCode;

    final cachedKeys = await controller.storage.loadCachedGrammarChapterKeys(
      targetLangCode: targetCode,
      nativeLangCode: nativeCode,
    );
    final qaKey = GrammarQaEntry.storageKey(
      targetLangCode: targetCode,
      nativeLangCode: nativeCode,
    );
    final rawQa = await controller.storage.loadGrammarQaHistory(qaKey);
    final parsedQa = rawQa
        .map(GrammarQaEntry.fromJson)
        .where((entry) => entry.isValid)
        .toList();

    if (!mounted) return;
    setState(() {
      _cachedChapterKeys = cachedKeys;
      _qaHistory = parsedQa;
    });
  }

  Future<void> _openChapter(GrammarChapterSpec chapter) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GrammarChapterScreen(chapter: chapter),
      ),
    );
    if (mounted) {
      await _reloadLocalState();
    }
  }

  Future<void> _submitQuestion([String? overrideText]) async {
    final question = (overrideText ?? _questionController.text).trim();
    if (question.isEmpty || _askingAi) return;

    final controller = AppScope.of(context);
    final settings = controller.settings;
    final targetLang = settings.targetLanguage;
    final nativeLang = settings.nativeLanguage;

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    setState(() {
      _askingAi = true;
      _askError = null;
    });

    final result = await controller.gemini.askGrammarQuestion(
      question: question,
      targetLang: targetLang,
      nativeLang: nativeLang,
      settings: settings,
    );

    if (!mounted) return;

    if (result.entry != null && result.entry!.isValid) {
      final newEntry = result.entry!;
      final updated = [newEntry, ..._qaHistory];
      final qaKey = GrammarQaEntry.storageKey(
        targetLangCode: targetLang.code,
        nativeLangCode: nativeLang.code,
      );
      await controller.storage.saveGrammarQaHistory(
        qaKey,
        updated.map((e) => e.toJson()).toList(),
      );
      if (!mounted) return;
      _questionController.clear();
      setState(() {
        _askingAi = false;
        _qaHistory = updated;
        _latestAnswer = newEntry;
        _askError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).tr('grammar_qa_saved_toast')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _askingAi = false;
        _askError = result.errorDetail ??
            AppStrings.of(context).tr('grammar_ask_error');
      });
    }
  }

  Future<void> _deleteQaEntry(String entryId) async {
    final controller = AppScope.of(context);
    final qaKey = GrammarQaEntry.storageKey(
      targetLangCode: controller.settings.targetLanguageCode,
      nativeLangCode: controller.settings.nativeLanguageCode,
    );
    final updated = _qaHistory.where((e) => e.id != entryId).toList();
    await controller.storage.saveGrammarQaHistory(
      qaKey,
      updated.map((e) => e.toJson()).toList(),
    );
    if (!mounted) return;
    setState(() {
      _qaHistory = updated;
      if (_latestAnswer?.id == entryId) {
        _latestAnswer = null;
      }
    });
  }

  Future<void> _confirmClearHistory() async {
    if (_qaHistory.isEmpty) return;
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('grammar_qa_clear_confirm_title')),
        content: Text(s.tr('grammar_qa_clear_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.tr('cancel_btn')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.tr('grammar_qa_clear_all')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final controller = AppScope.of(context);
    final qaKey = GrammarQaEntry.storageKey(
      targetLangCode: controller.settings.targetLanguageCode,
      nativeLangCode: controller.settings.nativeLanguageCode,
    );
    await controller.storage.saveGrammarQaHistory(qaKey, const []);
    if (!mounted) return;
    setState(() {
      _qaHistory = const [];
      _latestAnswer = null;
    });
  }

  void _applySuggestionChip(String text) {
    HapticFeedback.selectionClick();
    _questionController.text = '$text ';
    _questionController.selection = TextSelection.fromPosition(
      TextPosition(offset: _questionController.text.length),
    );
    _questionFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = controller.settings;
    final targetLang = settings.targetLanguage;
    final nativeLang = settings.nativeLanguage;
    final topic = settings.learningTopic;

    final cachedCount = GrammarBookBlueprint.chapters.where((ch) {
      final key = ch.cacheKey(
        targetLangCode: targetLang.code,
        nativeLangCode: nativeLang.code,
      );
      return _cachedChapterKeys.contains(key);
    }).length;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          '${s.tr('rules_book_title')} (${targetLang.flag})',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            // Language + Topic + Offline Chapter Progress Header
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${targetLang.flag} ${targetLang.displayNativeName}',
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.offline_pin_rounded,
                        size: 14,
                        color: Colors.teal.shade300,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$cachedCount / ${GrammarBookBlueprint.chapters.length} ${s.tr('grammar_cached_count')}',
                        style: textTheme.labelSmall?.copyWith(
                          color: Colors.teal.shade300,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(topic.icon, size: 14, color: scheme.primary),
                      const SizedBox(width: 5),
                      Text(
                        s.tr(topic.titleKey),
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // "Запитати ШІ про правило або виняток" Interactive Block
            Card(
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.tr('grammar_ask_title'),
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _questionController,
                            focusNode: _questionFocusNode,
                            enabled: !_askingAi,
                            minLines: 1,
                            maxLines: 3,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _submitQuestion(),
                            decoration: InputDecoration(
                              hintText: s.tr('grammar_ask_hint'),
                              isDense: true,
                              filled: true,
                              fillColor: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _askingAi ? null : () => _submitQuestion(),
                          child: _askingAi
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 19),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SuggestionChip(
                          label: s.tr('grammar_ask_chip_1'),
                          onTap: () =>
                              _applySuggestionChip(s.tr('grammar_ask_chip_1')),
                        ),
                        _SuggestionChip(
                          label: s.tr('grammar_ask_chip_2'),
                          onTap: () =>
                              _applySuggestionChip(s.tr('grammar_ask_chip_2')),
                        ),
                        _SuggestionChip(
                          label: s.tr('grammar_ask_chip_3'),
                          onTap: () =>
                              _applySuggestionChip(s.tr('grammar_ask_chip_3')),
                        ),
                      ],
                    ),
                    if (_askingAi) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.tr('grammar_ask_loading'),
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_askError != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 17,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${s.tr('grammar_ask_error')}\n$_askError',
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface,
                                  height: 1.35,
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
            ),

            // Immediately show latest AI answer when on Chapters tab
            if (_latestAnswer != null && _selectedTab == 0) ...[
              const SizedBox(height: 12),
              GrammarQaCard(
                entry: _latestAnswer!,
                highlighted: true,
                onSpeak: controller.speakTarget,
                onDelete: () => _deleteQaEntry(_latestAnswer!.id),
              ),
            ],

            const SizedBox(height: 14),

            // Mode Switcher: "Зміст (9 розділів)" vs "Мої запитання (N)"
            Row(
              children: [
                Expanded(
                  child: _ModeTabButton(
                    selected: _selectedTab == 0,
                    icon: Icons.menu_book_rounded,
                    label: s.tr('grammar_tab_chapters'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTab = 0);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeTabButton(
                    selected: _selectedTab == 1,
                    icon: Icons.question_answer_rounded,
                    label: '${s.tr('grammar_tab_qa')} (${_qaHistory.length})',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTab = 1);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (_selectedTab == 0)
              // 9 Structured Chapters Table of Contents
              ...GrammarBookBlueprint.chapters.map((chapter) {
                final cacheKey = chapter.cacheKey(
                  targetLangCode: targetLang.code,
                  nativeLangCode: nativeLang.code,
                );
                final isCached = _cachedChapterKeys.contains(cacheKey);
                return _ChapterTocCard(
                  chapter: chapter,
                  isCached: isCached,
                  onTap: () => _openChapter(chapter),
                );
              })
            else ...[
              // Saved Q&A History ("Мої запитання")
              if (_qaHistory.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _confirmClearHistory,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: Text(s.tr('grammar_qa_clear_all')),
                    ),
                  ),
                ),
              if (_qaHistory.isEmpty)
                Card(
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 28,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 38,
                          color: scheme.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.tr('grammar_qa_empty_title'),
                          textAlign: TextAlign.center,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.tr('grammar_qa_empty_sub'),
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._qaHistory.map(
                  (entry) => GrammarQaCard(
                    entry: entry,
                    onSpeak: controller.speakTarget,
                    onDelete: () => _deleteQaEntry(entry.id),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.55)
                : scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterTocCard extends StatelessWidget {
  const _ChapterTocCard({
    required this.chapter,
    required this.isCached,
    required this.onTap,
  });

  final GrammarChapterSpec chapter;
  final bool isCached;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCached
              ? Colors.teal.withValues(alpha: 0.45)
              : scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: chapter.accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      chapter.icon,
                      size: 18,
                      color: chapter.accentColor,
                    ),
                    Text(
                      '${chapter.number}',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: chapter.accentColor,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isCached
                                  ? Colors.teal.withValues(alpha: 0.16)
                                  : scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isCached
                                      ? Icons.offline_pin_rounded
                                      : Icons.auto_awesome_rounded,
                                  size: 12,
                                  color: isCached
                                      ? Colors.teal.shade300
                                      : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    isCached
                                        ? s.tr('grammar_offline_ready')
                                        : s.tr('grammar_online_generate'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: isCached
                                          ? Colors.teal.shade300
                                          : scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${chapter.number}. ${s.tr(chapter.titleKey)}',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.tr(chapter.subtitleKey),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
