import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../models/grammar_book_models.dart';
import '../../state/app_controller.dart';
import '../../widgets/grammar_table_card.dart';

/// Full-screen deep reader for a single chapter of the 9-chapter Grammar Handbook.
///
/// Loads from local cache (`grammar_book_{targetLang}_{nativeLang}_{chapterId}`)
/// first, generates via Multi-AI on first open or manual refresh, and caches
/// validated output for offline use.
class GrammarChapterScreen extends StatefulWidget {
  const GrammarChapterScreen({
    super.key,
    required this.chapter,
  });

  final GrammarChapterSpec chapter;

  @override
  State<GrammarChapterScreen> createState() => _GrammarChapterScreenState();
}

class _GrammarChapterScreenState extends State<GrammarChapterScreen> {
  GrammarChapterContent? _content;
  bool _initialLoading = true;
  bool _refreshing = false;
  bool _loadedFromCache = false;
  String _loadedKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    final key = widget.chapter.cacheKey(
      targetLangCode: controller.settings.targetLanguageCode,
      nativeLangCode: controller.settings.nativeLanguageCode,
    );
    if (_loadedKey != key) {
      _loadedKey = key;
      _loadChapter(forceAiRefresh: false);
    }
  }

  Future<void> _loadChapter({required bool forceAiRefresh}) async {
    final controller = AppScope.of(context);
    final settings = controller.settings;
    final targetLang = settings.targetLanguage;
    final nativeLang = settings.nativeLanguage;
    final cacheKey = widget.chapter.cacheKey(
      targetLangCode: targetLang.code,
      nativeLangCode: nativeLang.code,
    );

    final offlineFallback = GrammarChapterContent.buildOfflineFallback(
      spec: widget.chapter,
      targetLang: targetLang,
      nativeLang: nativeLang,
    );

    if (!forceAiRefresh) {
      final cachedJson =
          await controller.storage.loadGrammarChapterCache(cacheKey);
      if (cachedJson != null) {
        final cached = GrammarChapterContent.fromJson(
          cachedJson,
          fallbackChapterId: widget.chapter.id,
          fallbackTargetCode: targetLang.code,
          fallbackNativeCode: nativeLang.code,
        );
        if (cached.isValid) {
          if (mounted) {
            setState(() {
              _content = cached;
              _loadedFromCache = true;
              _initialLoading = false;
            });
          }
          return;
        }
      }
    }

    if (mounted) {
      setState(() {
        if (forceAiRefresh) {
          _refreshing = true;
        } else {
          _initialLoading = true;
        }
      });
    }

    final generated = await controller.gemini.generateGrammarChapter(
      chapter: widget.chapter,
      targetLang: targetLang,
      nativeLang: nativeLang,
      settings: settings,
      offlineFallback: offlineFallback,
    );

    if (generated.usedAi && generated.isValid) {
      await controller.storage.saveGrammarChapterCache(
        cacheKey,
        generated.toJson(),
      );
    }

    if (!mounted) return;
    setState(() {
      _content = generated;
      _loadedFromCache = false;
      _initialLoading = false;
      _refreshing = false;
    });

    if (forceAiRefresh && generated.usedAi) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context).tr('grammar_chapter_updated_toast'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final targetLang = controller.settings.targetLanguage;
    final chapter = widget.chapter;
    final content = _content;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          '${chapter.number}. ${s.tr(chapter.titleKey)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: s.tr('grammar_refresh_chapter_btn'),
            onPressed: (_initialLoading || _refreshing)
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _loadChapter(forceAiRefresh: true);
                  },
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _initialLoading || content == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: chapter.accentColor),
                      const SizedBox(height: 16),
                      Text(
                        '${targetLang.flag} ${chapter.number}. ${s.tr(chapter.titleKey)}',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s.tr('grammar_chapter_generating'),
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                children: [
                  // Chapter Header & Refresh Card
                  Card(
                    color: scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: chapter.accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                  color: chapter.accentColor
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${targetLang.flag} ${targetLang.displayNativeName}',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: chapter.accentColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (content.usedAi)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
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
                                        _loadedFromCache
                                            ? Icons.offline_pin_rounded
                                            : Icons.auto_awesome_rounded,
                                        size: 14,
                                        color: Colors.teal.shade300,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _loadedFromCache
                                            ? s.tr('level_cached_badge')
                                            : 'AI',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: Colors.teal.shade300,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${chapter.number}. ${s.tr(chapter.titleKey)}',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            content.summary,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.9),
                              height: 1.48,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _refreshing
                                    ? null
                                    : () {
                                        HapticFeedback.lightImpact();
                                        _loadChapter(forceAiRefresh: true);
                                      },
                                icon: _refreshing
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 17,
                                      ),
                                label: Text(
                                  s.tr('grammar_refresh_chapter_btn'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Offline / Quota Notice Banner
                  if (!content.usedAi) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.wifi_off_rounded,
                                size: 18,
                                color: Colors.amber.shade400,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s.tr('grammar_chapter_offline_banner'),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface,
                                    height: 1.38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if ((content.errorDetail ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              content.errorDetail!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // 1. Reference Tables
                  if (content.tables.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _ChapterSectionHeading(
                      icon: Icons.table_chart_rounded,
                      title: s.tr('grammar_tables_section'),
                      color: chapter.accentColor,
                    ),
                    const SizedBox(height: 8),
                    ...content.tables.map(
                      (table) => GrammarTableCard(
                        table: table,
                        accentColor: chapter.accentColor,
                      ),
                    ),
                  ],

                  // 2. Detailed Rules & Speakable Examples
                  if (content.sections.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _ChapterSectionHeading(
                      icon: Icons.menu_book_rounded,
                      title: s.tr('grammar_rules_section'),
                      color: chapter.accentColor,
                    ),
                    const SizedBox(height: 8),
                    ...content.sections.map(
                      (sec) => GrammarRuleSectionCard(
                        section: sec,
                        accentColor: chapter.accentColor,
                        onSpeak: controller.speakTarget,
                      ),
                    ),
                  ],

                  // 3. Key Chapter Exceptions
                  if (content.keyExceptions.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _BulletHighlightCard(
                      icon: Icons.warning_amber_rounded,
                      title: s.tr('grammar_exceptions_section'),
                      items: content.keyExceptions,
                      color: Colors.amber.shade400,
                    ),
                  ],

                  // 4. Common Mistakes
                  if (content.commonMistakes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _BulletHighlightCard(
                      icon: Icons.error_outline_rounded,
                      title: s.tr('grammar_mistakes_section'),
                      items: content.commonMistakes,
                      color: Colors.redAccent.shade100,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ChapterSectionHeading extends StatelessWidget {
  const _ChapterSectionHeading({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ],
    );
  }
}

class _BulletHighlightCard extends StatelessWidget {
  const _BulletHighlightCard({
    required this.icon,
    required this.title,
    required this.items,
    required this.color,
  });

  final IconData icon;
  final String title;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $line',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.92),
                    height: 1.42,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
