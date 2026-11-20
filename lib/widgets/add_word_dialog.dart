import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/vocab_word.dart';
import '../services/word_script_validator.dart';
import '../state/app_controller.dart';

/// Opens the AI-assisted "Add Word to Vocabulary" bottom sheet.
/// Returns the created [VocabWord] when the user saves, or `null` if cancelled.
Future<VocabWord?> showAddWordSheet(BuildContext context) {
  return showModalBottomSheet<VocabWord>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _AddWordSheet(),
  );
}

enum _AutofillStatusKind {
  idle,
  loading,
  fromCache,
  fromAi,
  fromFallback,
  languageMismatch,
  unavailable,
}

class _AddWordSheet extends StatefulWidget {
  const _AddWordSheet();

  @override
  State<_AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends State<_AddWordSheet> {
  static const _debounceDuration = Duration(milliseconds: 700);

  final TextEditingController _wordCtrl = TextEditingController();
  final TextEditingController _transCtrl = TextEditingController();
  final TextEditingController _exampleCtrl = TextEditingController();
  final TextEditingController _exampleTransCtrl = TextEditingController();

  Timer? _debounceTimer;
  int _requestSeq = 0;

  _AutofillStatusKind _statusKind = _AutofillStatusKind.idle;
  String _providerName = '';
  String _partOfSpeech = '';
  String _detectedLanguage = '';
  String _lastAutofilledWord = '';

  ScriptValidationResult? _scriptMismatch;
  WordAutofillResult? _aiMismatch;

  bool _applyingAutofill = false;
  bool _manualTransEdit = false;
  bool _manualExampleEdit = false;
  bool _manualExampleTransEdit = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _wordCtrl.dispose();
    _transCtrl.dispose();
    _exampleCtrl.dispose();
    _exampleTransCtrl.dispose();
    super.dispose();
  }

  void _onWordChanged(String value) {
    _debounceTimer?.cancel();
    final trimmed = value.trim();
    final normalized = WordAutofillResult.normalizeWord(trimmed);

    if (normalized != _lastAutofilledWord) {
      _manualTransEdit = false;
      _manualExampleEdit = false;
      _manualExampleTransEdit = false;
      _aiMismatch = null;
      _detectedLanguage = '';
    }

    if (trimmed.isEmpty) {
      _requestSeq++;
      setState(() {
        _statusKind = _AutofillStatusKind.idle;
        _providerName = '';
        _partOfSpeech = '';
        _detectedLanguage = '';
        _lastAutofilledWord = '';
        _scriptMismatch = null;
        _aiMismatch = null;
      });
      return;
    }

    // 1. Instant local writing-script check (zero API quota spent)
    final targetCode = AppScope.of(context).settings.targetLanguageCode;
    final scriptCheck = WordScriptValidator.validate(
      text: trimmed,
      targetLangCode: targetCode,
    );
    if (!scriptCheck.isCompatible) {
      _requestSeq++;
      setState(() {
        _scriptMismatch = scriptCheck;
        _aiMismatch = null;
        _detectedLanguage = '';
        _statusKind = _AutofillStatusKind.idle;
        _providerName = '';
      });
      return;
    }

    setState(() {
      _scriptMismatch = null;
    });

    if (normalized == _lastAutofilledWord &&
        (_transCtrl.text.trim().isNotEmpty || _aiMismatch != null)) {
      return;
    }

    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;
      _runAutofill(manualTrigger: false);
    });
  }

  Future<void> _runAutofill({required bool manualTrigger}) async {
    _debounceTimer?.cancel();
    final word = _wordCtrl.text.trim();
    if (word.isEmpty) return;

    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final targetLang = controller.settings.targetLanguage;
    final scriptCheck = WordScriptValidator.validate(
      text: word,
      targetLangCode: targetLang.code,
    );
    if (!scriptCheck.isCompatible) {
      _requestSeq++;
      setState(() {
        _scriptMismatch = scriptCheck;
        _aiMismatch = null;
        _detectedLanguage = '';
        _statusKind = _AutofillStatusKind.idle;
      });
      return;
    }

    final normalized = WordAutofillResult.normalizeWord(word);
    final forceRefresh = manualTrigger &&
        normalized == _lastAutofilledWord &&
        (_transCtrl.text.trim().isNotEmpty || _aiMismatch != null);

    final seq = ++_requestSeq;
    setState(() {
      _scriptMismatch = null;
      _aiMismatch = null;
      _statusKind = _AutofillStatusKind.loading;
    });

    try {
      final result = await controller.autofillVocabWord(
        word,
        forceRefresh: forceRefresh,
      );
      if (!mounted || seq != _requestSeq) return;
      if (WordAutofillResult.normalizeWord(_wordCtrl.text) != normalized) {
        return;
      }

      final detectedMatchesTarget =
          WordScriptValidator.doesDetectedLanguageMatchTarget(
        detectedLanguage: result.detectedLanguage,
        detectedLanguageCode: result.detectedLanguageCode,
        targetLang: targetLang,
        localizedTargetName: s.shortLangName(targetLang),
      );
      final isLanguageMismatch =
          result.hasLanguageMismatch || !detectedMatchesTarget;

      if (isLanguageMismatch) {
        setState(() {
          _lastAutofilledWord = normalized;
          _aiMismatch = result.copyWith(isTargetLanguage: false);
          _detectedLanguage = result.detectedLanguage;
          _providerName = result.providerName;
          _statusKind = _AutofillStatusKind.languageMismatch;
        });
        return;
      }

      if (result.hasTranslation) {
        _applyingAutofill = true;
        try {
          if (manualTrigger ||
              !_manualTransEdit ||
              _transCtrl.text.trim().isEmpty) {
            _transCtrl.text = result.translation;
            _manualTransEdit = false;
          }
          if (result.example.isNotEmpty &&
              (manualTrigger ||
                  !_manualExampleEdit ||
                  _exampleCtrl.text.trim().isEmpty)) {
            _exampleCtrl.text = result.example;
            _manualExampleEdit = false;
          }
          if (result.exampleTranslation.isNotEmpty &&
              (manualTrigger ||
                  !_manualExampleTransEdit ||
                  _exampleTransCtrl.text.trim().isEmpty)) {
            _exampleTransCtrl.text = result.exampleTranslation;
            _manualExampleTransEdit = false;
          }
        } finally {
          _applyingAutofill = false;
        }

        final resolvedDetected = result.hasDetectedLanguage
            ? result.detectedLanguage
            : (result.usedAi ? s.shortLangName(targetLang) : '');

        setState(() {
          _lastAutofilledWord = normalized;
          _aiMismatch = null;
          _detectedLanguage = resolvedDetected;
          _partOfSpeech = result.partOfSpeech;
          _providerName = result.providerName;
          if (result.fromCache) {
            _statusKind = _AutofillStatusKind.fromCache;
          } else if (result.usedAi) {
            _statusKind = _AutofillStatusKind.fromAi;
          } else {
            _statusKind = _AutofillStatusKind.fromFallback;
          }
        });
      } else {
        setState(() {
          _detectedLanguage = result.detectedLanguage;
          _statusKind = _AutofillStatusKind.unavailable;
          _providerName = '';
        });
      }
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _detectedLanguage = '';
        _statusKind = _AutofillStatusKind.unavailable;
        _providerName = '';
      });
    }
  }

  Future<void> _applySuggestedTargetWord(WordAutofillResult mismatch) async {
    final suggested = mismatch.suggestedTargetWord.trim();
    if (suggested.isEmpty) return;

    _debounceTimer?.cancel();
    _requestSeq++;

    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final targetLang = controller.settings.targetLanguage;
    final normalizedSuggested = WordAutofillResult.normalizeWord(suggested);

    _applyingAutofill = true;
    try {
      _wordCtrl.value = TextEditingValue(
        text: suggested,
        selection: TextSelection.collapsed(offset: suggested.length),
      );
      if (mismatch.hasTranslation) {
        _transCtrl.text = mismatch.translation;
        _manualTransEdit = false;
      }
      if (mismatch.hasExample) {
        _exampleCtrl.text = mismatch.example;
        _manualExampleEdit = false;
      }
      if (mismatch.exampleTranslation.trim().isNotEmpty) {
        _exampleTransCtrl.text = mismatch.exampleTranslation;
        _manualExampleTransEdit = false;
      }
    } finally {
      _applyingAutofill = false;
    }

    final scriptCheck = WordScriptValidator.validate(
      text: suggested,
      targetLangCode: targetLang.code,
    );

    if (mismatch.hasTranslation &&
        mismatch.hasExample &&
        scriptCheck.isCompatible) {
      final verifiedDetected = s.shortLangName(targetLang);
      setState(() {
        _scriptMismatch = null;
        _aiMismatch = null;
        _detectedLanguage = verifiedDetected;
        _lastAutofilledWord = normalizedSuggested;
        _partOfSpeech = mismatch.partOfSpeech;
        _providerName = mismatch.providerName;
        _statusKind = mismatch.fromCache
            ? _AutofillStatusKind.fromCache
            : _AutofillStatusKind.fromAi;
      });

      final verifiedEntry = WordAutofillResult(
        word: suggested,
        translation: mismatch.translation,
        example: mismatch.example,
        exampleTranslation: mismatch.exampleTranslation,
        partOfSpeech: mismatch.partOfSpeech,
        isTargetLanguage: true,
        detectedLanguage: verifiedDetected,
        detectedLanguageCode: targetLang.code,
        usedAi: true,
        providerName: mismatch.providerName,
      );
      await controller.cacheVerifiedWordAutofill(verifiedEntry);
      return;
    }

    setState(() {
      _scriptMismatch = scriptCheck.isCompatible ? null : scriptCheck;
      _aiMismatch = null;
      _detectedLanguage = '';
      _lastAutofilledWord = '';
    });

    if (scriptCheck.isCompatible) {
      await _runAutofill(manualTrigger: true);
    }
  }

  Future<void> _saveWord() async {
    final w = _wordCtrl.text.trim();
    final t = _transCtrl.text.trim();
    if (w.isEmpty || t.isEmpty) return;

    final hasWarning = _scriptMismatch != null || _aiMismatch != null;
    if (hasWarning) {
      final s = AppStrings.of(context);
      final targetLangName =
          s.shortLangName(AppScope.of(context).settings.targetLanguage);
      final bodyText = _scriptMismatch != null
          ? s
              .tr('vocab_save_mismatch_body_script')
              .replaceAll('{word}', w)
              .replaceAll('{target}', targetLangName)
          : (_aiMismatch!.detectedLanguage.isNotEmpty
              ? s
                  .tr('vocab_save_mismatch_body_lang')
                  .replaceAll('{word}', w)
                  .replaceAll('{detected}', _aiMismatch!.detectedLanguage)
                  .replaceAll('{target}', targetLangName)
              : s
                  .tr('vocab_lang_mismatch_generic')
                  .replaceAll('{target}', targetLangName));

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber.shade700,
            size: 28,
          ),
          title: Text(s.tr('vocab_save_mismatch_title')),
          content: Text(bodyText),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(s.tr('cancel_btn')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(s.tr('vocab_save_anyway_btn')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final now = DateTime.now();
    Navigator.of(context).pop(
      VocabWord(
        id: 'manual_word_${now.microsecondsSinceEpoch}',
        word: w,
        translation: t,
        contextSentence: '',
        exampleSentence: _exampleCtrl.text.trim(),
        exampleTranslation: _exampleTransCtrl.text.trim(),
        partOfSpeech: _partOfSpeech.trim(),
        sourceTitle: '',
        createdAt: now,
        nextReviewAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final warningColor = isDark ? Colors.amber.shade400 : Colors.orange.shade800;

    final targetLang = controller.settings.targetLanguage;
    final nativeLang = controller.settings.nativeLanguage;
    final topic = controller.settings.learningTopic;
    final shortTargetName = s.shortLangName(targetLang);

    final wordText = _wordCtrl.text.trim();
    final transText = _transCtrl.text.trim();
    final exampleText = _exampleCtrl.text.trim();
    final isDuplicate = wordText.isNotEmpty && controller.hasWord(wordText);
    final isLoading = _statusKind == _AutofillStatusKind.loading;
    final hasScriptMismatch = _scriptMismatch != null;
    final hasAiMismatch = _aiMismatch != null;
    final hasLanguageWarning = hasScriptMismatch || hasAiMismatch;
    final canSave = wordText.isNotEmpty && transText.isNotEmpty && !isDuplicate;

    final warningBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: warningColor, width: 1.8),
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 2,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('new_word_title'),
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${targetLang.flag} ${s.langName(targetLang)} → ${nativeLang.flag} ${s.langName(nativeLang)}',
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  topic.icon,
                                  size: 13,
                                  color: scheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  s.tr(topic.titleKey),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: s.tr('cancel_btn'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Primary input field: Word or phrase in target language + TTS
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _wordCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: _onWordChanged,
                    onSubmitted: (_) => _runAutofill(manualTrigger: true),
                    decoration: InputDecoration(
                      labelText: s.tr('word_in_target_lang_label'),
                      hintText: s.tr('word_in_target_lang_hint'),
                      prefixIcon: Icon(
                        hasLanguageWarning
                            ? Icons.warning_amber_rounded
                            : Icons.edit_note_rounded,
                        color: hasLanguageWarning ? warningColor : null,
                      ),
                      enabledBorder: hasLanguageWarning ? warningBorder : null,
                      focusedBorder: hasLanguageWarning ? warningBorder : null,
                      suffixIcon: wordText.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _wordCtrl.clear();
                                _onWordChanged('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filledTonal(
                    tooltip: s.tr('speak_word_tooltip'),
                    onPressed: wordText.isEmpty
                        ? null
                        : () => controller.speakTarget(wordText),
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                ),
              ],
            ),

            // Always show compact detected-origin badge when word origin is known
            if (!hasScriptMismatch &&
                !hasAiMismatch &&
                _detectedLanguage.isNotEmpty)
              _buildDetectedOriginBadge(
                context: context,
                s: s,
                detectedLanguage: _detectedLanguage,
              ),

            if (hasScriptMismatch)
              _buildScriptMismatchBanner(
                context: context,
                s: s,
                validation: _scriptMismatch!,
                targetLangName: shortTargetName,
                warningColor: warningColor,
              ),

            if (hasAiMismatch)
              _buildAiLanguageMismatchBanner(
                context: context,
                s: s,
                mismatch: _aiMismatch!,
                targetLangName: shortTargetName,
                warningColor: warningColor,
              ),

            if (isDuplicate) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: scheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.tr('already_in_vocab'),
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Quick AI autofill action button
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: wordText.isEmpty || isLoading || hasScriptMismatch
                    ? null
                    : () => _runAutofill(manualTrigger: true),
                icon: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onSecondaryContainer,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  isLoading
                      ? s.tr('ai_autofill_loading')
                      : s.tr('ai_autofill_btn'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            if (isLoading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(minHeight: 3),
              ),
            ] else ...[
              _buildStatusBanner(context, s),
            ],

            const SizedBox(height: 14),

            // 2. Translation field (auto-filled, editable)
            TextField(
              controller: _transCtrl,
              onChanged: (_) {
                if (!_applyingAutofill) {
                  _manualTransEdit = true;
                  setState(() {});
                }
              },
              decoration: InputDecoration(
                labelText: s.tr('translation_label'),
                hintText: '${nativeLang.flag} ${s.langName(nativeLang)}',
                prefixIcon: const Icon(Icons.translate_rounded),
              ),
            ),
            const SizedBox(height: 12),

            // 3. Example sentence field (auto-filled, editable) + TTS button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _exampleCtrl,
                    minLines: 1,
                    maxLines: 3,
                    onChanged: (_) {
                      if (!_applyingAutofill) {
                        _manualExampleEdit = true;
                        setState(() {});
                      }
                    },
                    decoration: InputDecoration(
                      labelText: s.tr('example_usage_label'),
                      hintText: '${targetLang.flag} ${s.langName(targetLang)}',
                      prefixIcon: const Icon(Icons.format_quote_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filledTonal(
                    tooltip: s.tr('speak_example_tooltip'),
                    onPressed: exampleText.isEmpty
                        ? null
                        : () => controller.speakTarget(exampleText),
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 4. Example translation field (auto-filled, displayed & editable)
            TextField(
              controller: _exampleTransCtrl,
              minLines: 1,
              maxLines: 2,
              onChanged: (_) {
                if (!_applyingAutofill) {
                  _manualExampleTransEdit = true;
                }
              },
              decoration: InputDecoration(
                labelText: s.tr('example_translation_label'),
                hintText: '${nativeLang.flag} ${s.langName(nativeLang)}',
                prefixIcon: const Icon(Icons.subtitles_outlined),
              ),
            ),
            const SizedBox(height: 18),

            // Bottom action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      s.tr('cancel_btn'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: canSave ? _saveWord : null,
                    icon: Icon(
                      hasLanguageWarning
                          ? Icons.warning_amber_rounded
                          : Icons.check_rounded,
                      size: 19,
                    ),
                    label: Text(
                      s.tr('add_btn'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectedOriginBadge({
    required BuildContext context,
    required AppStrings s,
    required String detectedLanguage,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final label = s
        .tr('vocab_detected_origin_label')
        .replaceAll('{detected}', detectedLanguage);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: 14,
              color: scheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScriptMismatchBanner({
    required BuildContext context,
    required AppStrings s,
    required ScriptValidationResult validation,
    required String targetLangName,
    required Color warningColor,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final detectedScript = validation.detectedUnexpectedScript;
    final scriptLabel =
        detectedScript != null ? s.tr(detectedScript.l10nKey) : '';

    final String message;
    if (validation.isMixedToken && scriptLabel.isNotEmpty) {
      message = s
          .tr('vocab_script_mismatch_mixed')
          .replaceAll('{script}', scriptLabel)
          .replaceAll('{target}', targetLangName);
    } else if (scriptLabel.isNotEmpty) {
      message = s
          .tr('vocab_script_mismatch_warning')
          .replaceAll('{script}', scriptLabel)
          .replaceAll('{target}', targetLangName);
    } else {
      message = s
          .tr('vocab_script_mismatch_generic')
          .replaceAll('{target}', targetLangName);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: warningColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: warningColor.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.spellcheck_rounded,
              size: 18,
              color: warningColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: textTheme.bodySmall?.copyWith(
                  color: warningColor,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiLanguageMismatchBanner({
    required BuildContext context,
    required AppStrings s,
    required WordAutofillResult mismatch,
    required String targetLangName,
    required Color warningColor,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final detected = mismatch.detectedLanguage.trim();
    final suggested = mismatch.suggestedTargetWord.trim();

    final message = detected.isNotEmpty
        ? s
            .tr('vocab_lang_mismatch_warning')
            .replaceAll('{detected}', detected)
            .replaceAll('{target}', targetLangName)
        : s
            .tr('vocab_lang_mismatch_generic')
            .replaceAll('{target}', targetLangName);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: warningColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: warningColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 19,
                  color: warningColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: textTheme.bodySmall?.copyWith(
                      color: warningColor,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            if (suggested.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _applySuggestedTargetWord(mismatch),
                  style: FilledButton.styleFrom(
                    backgroundColor: warningColor,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.black87
                            : Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(
                    s
                        .tr('vocab_replace_word_btn')
                        .replaceAll('{word}', suggested),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, AppStrings s) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    switch (_statusKind) {
      case _AutofillStatusKind.idle:
      case _AutofillStatusKind.loading:
      case _AutofillStatusKind.languageMismatch:
        return const SizedBox.shrink();

      case _AutofillStatusKind.fromCache:
      case _AutofillStatusKind.fromAi:
      case _AutofillStatusKind.fromFallback:
        final icon = _statusKind == _AutofillStatusKind.fromCache
            ? Icons.offline_bolt_rounded
            : (_statusKind == _AutofillStatusKind.fromAi
                ? Icons.auto_awesome_rounded
                : Icons.translate_rounded);
        final label = _statusKind == _AutofillStatusKind.fromCache
            ? s.tr('ai_autofill_done_cache')
            : (_statusKind == _AutofillStatusKind.fromAi
                ? s.tr('ai_autofill_done_ai')
                : s.tr('ai_autofill_done_fallback'));
        final detailParts = <String>[
          label,
          if (_partOfSpeech.isNotEmpty) _partOfSpeech,
          if (_providerName.isNotEmpty &&
              _statusKind == _AutofillStatusKind.fromAi)
            _providerName,
        ];

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(icon, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  detailParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case _AutofillStatusKind.unavailable:
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.tr('ai_autofill_offline_hint'),
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
