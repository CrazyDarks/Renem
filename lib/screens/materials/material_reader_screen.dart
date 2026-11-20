import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../l10n/app_strings.dart';
import '../../models/study_material.dart';
import '../../state/app_controller.dart';
import '../../widgets/interactive_text_reader.dart';

class MaterialReaderScreen extends StatefulWidget {
  const MaterialReaderScreen({
    super.key,
    required this.material,
  });

  final StudyMaterial material;

  @override
  State<MaterialReaderScreen> createState() => _MaterialReaderScreenState();
}

class _MaterialReaderScreenState extends State<MaterialReaderScreen> {
  static const MethodChannel _launcherChannel =
      MethodChannel('com.languagema/external_launcher');

  YoutubePlayerController? _ytController;
  late StudyMaterial _currentMaterial;
  int _activeCueIndex = -1;
  double _fontSize = 17;
  bool _translatingAll = false;
  bool _showAllTranslations = false;
  bool _loadingMissingCues = false;
  bool _hasEmbedError = false;

  /// Tracks per-cue translation loading and visibility overrides.
  final Set<int> _translatingCueIndices = {};
  final Set<int> _visibleCueTranslations = {};

  /// Tracks sentence-by-sentence translations for manual / photo / web text materials.
  final Map<int, String> _paragraphTranslations = {};
  final Set<int> _translatingParagraphs = {};
  final Set<int> _visibleParagraphTranslations = {};

  bool get _hasYoutube =>
      _currentMaterial.sourceType == MaterialSourceType.youtube &&
      (_currentMaterial.youtubeVideoId?.isNotEmpty ?? false);

  /// Strips any leftover HTML formatting tags (like `<font color="..."><b>`) from saved captions.
  String _stripHtmlTags(String raw) {
    if (!raw.contains('<') && !raw.contains('&')) return raw;
    return raw
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  void initState() {
    super.initState();
    _currentMaterial = widget.material;
    if (_hasYoutube) {
      _ytController = YoutubePlayerController(
        initialVideoId: _currentMaterial.youtubeVideoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          enableCaption: true,
        ),
      )..addListener(_onYoutubeTick);

      if (_currentMaterial.subtitles.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensureYoutubeSubtitlesLoaded();
        });
      }
    }
  }

  Future<void> _ensureYoutubeSubtitlesLoaded() async {
    if (!mounted || !_hasYoutube || _loadingMissingCues) return;
    final controller = AppScope.of(context);
    setState(() => _loadingMissingCues = true);
    try {
      final res = await controller.youtube.fetchVideoAndSubtitles(
        _currentMaterial.youtubeVideoId!,
        preferredLangCode: controller.settings.targetLanguageCode,
        nativeLangCode: controller.settings.nativeLanguageCode,
      );
      if (!mounted) return;
      if (res.subtitles.isNotEmpty) {
        final updated = _currentMaterial.copyWith(
          title: _currentMaterial.title.startsWith('YouTube')
              ? res.title
              : _currentMaterial.title,
          subtitles: res.subtitles,
          content: res.fullTranscript,
        );
        await controller.addMaterial(updated);
        if (mounted) {
          setState(() => _currentMaterial = updated);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingMissingCues = false);
      }
    }
  }

  Future<void> _openInYoutubeApp({int? startSeconds}) async {
    final vid = _currentMaterial.youtubeVideoId;
    if (vid == null || vid.isEmpty) return;
    final suffix = (startSeconds != null && startSeconds > 0)
        ? '&t=${startSeconds}s'
        : '';
    final url = 'https://www.youtube.com/watch?v=$vid$suffix';
    try {
      await _launcherChannel.invokeMethod<bool>(
        'openExternalUrl',
        {'url': url},
      );
    } catch (_) {}
  }

  void _playCueFromVideo(int index, SubtitleCue cue) {
    setState(() => _activeCueIndex = index);
    if (_hasEmbedError || _ytController == null) {
      _openInYoutubeApp(startSeconds: cue.startMs ~/ 1000);
      return;
    }
    _ytController!.seekTo(cue.startDuration);
    _ytController!.play();
  }

  void _onYoutubeTick() {
    final controller = _ytController;
    if (controller == null) return;

    if (controller.value.hasError && !_hasEmbedError && mounted) {
      setState(() => _hasEmbedError = true);
    }

    if (_currentMaterial.subtitles.isEmpty) return;
    final posMs = controller.value.position.inMilliseconds;
    final cues = _currentMaterial.subtitles;
    var found = -1;
    for (var i = 0; i < cues.length; i++) {
      final start = cues[i].startMs;
      final end = start + (cues[i].durationMs > 0 ? cues[i].durationMs : 3000);
      if (posMs >= start && posMs <= end) {
        found = i;
        break;
      }
    }
    if (found != _activeCueIndex && mounted) {
      setState(() => _activeCueIndex = found);
    }
  }

  /// Translates a single subtitle sentence on-demand and caches it in the material.
  /// If a cached translation already exists for this subtitle line, toggles its visibility immediately.
  Future<void> _translateSingleCue(int index) async {
    final controller = AppScope.of(context);
    final cues = _currentMaterial.subtitles;
    if (index < 0 || index >= cues.length) return;
    if (_translatingCueIndices.contains(index)) return;

    final cue = cues[index];
    final cleanSource = _stripHtmlTags(cue.text);
    final cachedTrans = _stripHtmlTags(cue.translation);

    // Use cached translation if already available
    if (cachedTrans.isNotEmpty) {
      setState(() {
        if (_visibleCueTranslations.contains(index)) {
          _visibleCueTranslations.remove(index);
        } else {
          _visibleCueTranslations.add(index);
        }
      });
      return;
    }

    setState(() => _translatingCueIndices.add(index));
    try {
      final translated = await controller.gemini.translateSentence(
        sentence: cleanSource,
        sourceLangCode: controller.settings.targetLanguageCode,
        targetLangCode: controller.settings.nativeLanguageCode,
      );
      if (!mounted) return;
      final updatedCues = List<SubtitleCue>.from(cues);
      updatedCues[index] = SubtitleCue(
        startMs: cue.startMs,
        durationMs: cue.durationMs,
        text: cleanSource,
        translation: translated,
      );
      final updatedMaterial = _currentMaterial.copyWith(
        subtitles: updatedCues,
      );
      await controller.addMaterial(updatedMaterial);
      if (!mounted) return;
      setState(() {
        _currentMaterial = updatedMaterial;
        _visibleCueTranslations.add(index);
      });
    } finally {
      if (mounted) {
        setState(() => _translatingCueIndices.remove(index));
      }
    }
  }

  /// Top-right Translate button handler:
  /// - For YouTube: translates ALL subtitle lines into current native language (or toggles visibility).
  /// - For Text/Photo/Web: translates all paragraphs/sentences at once.
  Future<void> _handleTopTranslateAction() async {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);

    if (_hasYoutube) {
      final cues = _currentMaterial.subtitles;
      if (cues.isEmpty || _translatingAll) return;

      final allAlreadyHaveTrans =
          cues.every((c) => _stripHtmlTags(c.translation).isNotEmpty);
      if (allAlreadyHaveTrans) {
        setState(() {
          _showAllTranslations = !_showAllTranslations;
          if (!_showAllTranslations) {
            _visibleCueTranslations.clear();
          }
        });
        return;
      }

      setState(() {
        _translatingAll = true;
        _showAllTranslations = true;
      });
      try {
        final cleanTexts = cues.map((c) => _stripHtmlTags(c.text)).toList();
        final translations = await controller.gemini.translateSubtitleCues(
          texts: cleanTexts,
          targetLang: controller.settings.targetLanguage,
          nativeLang: controller.settings.nativeLanguage,
          settings: controller.settings,
        );

        if (translations.isNotEmpty && mounted) {
          final updatedCues = <SubtitleCue>[];
          for (var i = 0; i < cues.length; i++) {
            final trans = i < translations.length
                ? _stripHtmlTags(translations[i])
                : _stripHtmlTags(cues[i].translation);
            updatedCues.add(
              SubtitleCue(
                startMs: cues[i].startMs,
                durationMs: cues[i].durationMs,
                text: cleanTexts[i],
                translation: trans,
              ),
            );
          }

          final updatedMaterial = _currentMaterial.copyWith(
            subtitles: updatedCues,
            content: updatedCues
                .map((c) => c.translation.isNotEmpty
                    ? '${c.text}\n(${c.translation})'
                    : c.text)
                .join('\n\n'),
          );

          await controller.addMaterial(updatedMaterial);
          if (!mounted) return;
          setState(() => _currentMaterial = updatedMaterial);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.tr('subs_translated_toast')),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (_) {
      } finally {
        if (mounted) setState(() => _translatingAll = false);
      }
    } else {
      final sentences = _splitTextIntoSentences(_currentMaterial.content);
      if (sentences.isEmpty || _translatingAll) return;

      if (_paragraphTranslations.length == sentences.length) {
        setState(() {
          _showAllTranslations = !_showAllTranslations;
          if (!_showAllTranslations) {
            _visibleParagraphTranslations.clear();
          }
        });
        return;
      }

      setState(() {
        _translatingAll = true;
        _showAllTranslations = true;
      });
      try {
        final translated = await controller.gemini.batchTranslateTexts(
          texts: sentences,
          sourceLangCode: controller.settings.targetLanguageCode,
          targetLangCode: controller.settings.nativeLanguageCode,
        );
        if (!mounted) return;
        setState(() {
          for (var i = 0; i < sentences.length && i < translated.length; i++) {
            _paragraphTranslations[i] = translated[i];
          }
        });
      } finally {
        if (mounted) setState(() => _translatingAll = false);
      }
    }
  }

  Future<void> _translateSingleSentenceParagraph(
    int index,
    String sentence,
  ) async {
    if (_translatingParagraphs.contains(index)) return;
    final cached = _paragraphTranslations[index] ?? '';
    if (cached.isNotEmpty) {
      setState(() {
        if (_visibleParagraphTranslations.contains(index)) {
          _visibleParagraphTranslations.remove(index);
        } else {
          _visibleParagraphTranslations.add(index);
        }
      });
      return;
    }

    final controller = AppScope.of(context);
    setState(() => _translatingParagraphs.add(index));
    try {
      final trans = await controller.gemini.translateSentence(
        sentence: sentence,
        sourceLangCode: controller.settings.targetLanguageCode,
        targetLangCode: controller.settings.nativeLanguageCode,
      );
      if (!mounted) return;
      setState(() {
        _paragraphTranslations[index] = trans;
        _visibleParagraphTranslations.add(index);
      });
    } finally {
      if (mounted) setState(() => _translatingParagraphs.remove(index));
    }
  }

  List<String> _splitTextIntoSentences(String raw) {
    if (raw.trim().isEmpty) return const [];
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    final paragraphBlocks = normalized
        .split(RegExp(r'\n+'))
        .map((p) => _stripHtmlTags(p))
        .where((p) => p.isNotEmpty)
        .toList();
    if (paragraphBlocks.length >= 2) {
      return paragraphBlocks;
    }
    final cleaned = _stripHtmlTags(raw);
    if (cleaned.isEmpty) return const [];
    final parts = cleaned
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? [cleaned] : parts;
  }

  @override
  void dispose() {
    _ytController?.removeListener(_onYoutubeTick);
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final cues = _currentMaterial.subtitles;
    final textSentences =
        _hasYoutube ? const <String>[] : _splitTextIntoSentences(_currentMaterial.content);

    final isSavedInLibrary =
        controller.materials.any((m) => m.id == _currentMaterial.id);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          _currentMaterial.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              isSavedInLibrary
                  ? Icons.bookmark_added_rounded
                  : Icons.bookmark_add_outlined,
              color: isSavedInLibrary ? scheme.primary : null,
            ),
            tooltip: s.tr('save_to_library_btn'),
            onPressed: () async {
              await controller.addMaterial(_currentMaterial);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(s.tr('saved_in_library_toast')),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          if (_hasYoutube)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip: s.tr('open_in_youtube_btn'),
              onPressed: () => _openInYoutubeApp(),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: _translatingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.translate_rounded,
                    color: _showAllTranslations ? scheme.primary : null,
                  ),
            tooltip: _hasYoutube
                ? (_showAllTranslations
                    ? s.tr('hide_translations_btn')
                    : s.tr('translate_all_subs_btn'))
                : s.tr('translate_full_text_btn'),
            onPressed: _handleTopTranslateAction,
          ),
          if (!_hasYoutube) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.text_decrease_rounded),
              onPressed: () => setState(
                () => _fontSize = (_fontSize - 1.5).clamp(13, 26),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.text_increase_rounded),
              onPressed: () => setState(
                () => _fontSize = (_fontSize + 1.5).clamp(13, 26),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.volume_up_rounded),
              onPressed: () => controller.speakTarget(_currentMaterial.content),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (_hasYoutube && _ytController != null) ...[
              YoutubePlayer(
                controller: _ytController!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: scheme.primary,
              ),
              if (_hasEmbedError)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: scheme.tertiaryContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.smart_display_rounded,
                            size: 20,
                            color: scheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.tr('yt_embed_restricted_banner'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onTertiaryContainer,
                                    height: 1.35,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _openInYoutubeApp(),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: Text(s.tr('open_in_youtube_btn')),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: scheme.secondaryContainer.withValues(alpha: 0.4),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.tr('tap_any_word_hint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.35,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loadingMissingCues
                  ? const Center(child: CircularProgressIndicator())
                  : _hasYoutube && cues.isNotEmpty
                      ? ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          itemCount: cues.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final cue = cues[index];
                            final cleanText = _stripHtmlTags(cue.text);
                            final cleanTrans = _stripHtmlTags(cue.translation);
                            final isActive = index == _activeCueIndex;
                            final isCueTranslating =
                                _translatingCueIndices.contains(index);
                            final showTrans = cleanTrans.isNotEmpty &&
                                (_showAllTranslations ||
                                    _visibleCueTranslations.contains(index));

                            return Card(
                              color: isActive
                                  ? scheme.primaryContainer
                                      .withValues(alpha: 0.45)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Top meta row: Timestamp + Play button so subtitle text spans full width cleanly
                                    Row(
                                      children: [
                                        InkWell(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          onTap: () =>
                                              _playCueFromVideo(index, cue),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme.primary
                                                  .withValues(alpha: 0.14),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              cue.formattedTimestamp,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                    color: scheme.primary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              style: TextButton.styleFrom(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                              ),
                                              onPressed: isCueTranslating
                                                  ? null
                                                  : () => _translateSingleCue(
                                                      index),
                                              icon: isCueTranslating
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.translate_rounded,
                                                      size: 16,
                                                    ),
                                              label: Text(
                                                s.tr('translate_sentence_btn'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: s.tr(
                                            'play_video_moment_tooltip',
                                          ),
                                          onPressed: () =>
                                              _playCueFromVideo(index, cue),
                                          icon: Icon(
                                            isActive
                                                ? Icons
                                                    .pause_circle_filled_rounded
                                                : Icons
                                                    .play_circle_filled_rounded,
                                            color: scheme.primary,
                                            size: 28,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    InteractiveTextReader(
                                      text: cleanText,
                                      sourceTitle: _currentMaterial.title,
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            height: 1.55,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    if (showTrans) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 9,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerHighest
                                              .withValues(alpha: 0.45),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          cleanTrans,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                                height: 1.45,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          itemCount: textSentences.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final sentence = textSentences[idx];
                            final trans = _paragraphTranslations[idx] ?? '';
                            final isTranslating =
                                _translatingParagraphs.contains(idx);
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InteractiveTextReader(
                                      text: sentence,
                                      sourceTitle: _currentMaterial.title,
                                      textStyle: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontSize: _fontSize,
                                            height: 1.65,
                                          ),
                                    ),
                                    if (trans.isNotEmpty &&
                                        (_showAllTranslations ||
                                            _visibleParagraphTranslations
                                                .contains(idx))) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: scheme.primaryContainer
                                              .withValues(alpha: 0.35),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          trans,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: scheme.onSurface,
                                                height: 1.45,
                                              ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          icon: const Icon(
                                            Icons.volume_up_rounded,
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              controller.speakTarget(sentence),
                                        ),
                                        const SizedBox(width: 6),
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          onPressed: isTranslating
                                              ? null
                                              : () =>
                                                  _translateSingleSentenceParagraph(
                                                    idx,
                                                    sentence,
                                                  ),
                                          icon: isTranslating
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.translate_rounded,
                                                  size: 16,
                                                ),
                                          label: Text(
                                            s.tr('translate_sentence_btn'),
                                            style:
                                                const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
