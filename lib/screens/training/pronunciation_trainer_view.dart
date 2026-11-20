import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/vocab_word.dart';
import '../../services/pronunciation_service.dart';
import '../../state/app_controller.dart';

class PronunciationTrainerView extends StatefulWidget {
  const PronunciationTrainerView({super.key});

  @override
  State<PronunciationTrainerView> createState() =>
      _PronunciationTrainerViewState();
}

class _PronunciationTrainerViewState extends State<PronunciationTrainerView> {
  final TextEditingController _customTextCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _wordIndex = 0;
  bool _useSentence = false;
  bool _listening = false;
  String _recognized = '';
  String _transcription = '';
  String _lastTranscribedTarget = '';
  PronunciationEvaluation? _evaluation;
  String? _errorMsg;

  @override
  void dispose() {
    _customTextCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _currentTarget(List<VocabWord> vocab) {
    final custom = _customTextCtrl.text.trim();
    if (custom.isNotEmpty) return custom;
    if (vocab.isEmpty) {
      return 'Learning a foreign language in context is effective.';
    }
    final card = vocab[_wordIndex % vocab.length];
    if (_useSentence && card.contextSentence.trim().isNotEmpty) {
      return card.contextSentence.trim();
    }
    if (_useSentence && card.exampleSentence.trim().isNotEmpty) {
      return card.exampleSentence.trim();
    }
    return card.word;
  }

  String _currentTranslation(List<VocabWord> vocab) {
    if (_customTextCtrl.text.trim().isNotEmpty || vocab.isEmpty) return '';
    return vocab[_wordIndex % vocab.length].translation;
  }

  void _ensureTranscription(AppController controller, String target) {
    final lang = controller.settings.targetLanguageCode;
    final nativeLang = controller.settings.nativeLanguageCode;
    final useIpa = controller.settings.useInternationalIpa;
    final key = '$lang:$nativeLang:$useIpa:$target';
    if (_lastTranscribedTarget == key) return;
    _lastTranscribedTarget = key;
    _transcription = controller.pronunciation.buildInstantTranscription(
      target,
      langCode: lang,
      nativeLangCode: nativeLang,
      useInternationalIpa: useIpa,
    );
    controller.pronunciation
        .fetchTranscription(
          target,
          langCode: lang,
          nativeLangCode: nativeLang,
          useInternationalIpa: useIpa,
        )
        .then((exact) {
      if (mounted && _lastTranscribedTarget == key && exact.isNotEmpty) {
        setState(() => _transcription = exact);
      }
    });
  }

  Future<void> _speakSlow(AppController controller, String text) async {
    await controller.speakTarget(text, overrideRate: 0.28);
  }

  Future<void> _toggleMicrophone(String target) async {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    if (_listening) {
      await controller.pronunciation.stopListening();
      if (!mounted) return;
      setState(() => _listening = false);
      if (_recognized.trim().isNotEmpty) {
        await _runEvaluation(target, _recognized);
      }
      return;
    }

    setState(() {
      _errorMsg = null;
      _recognized = '';
      _evaluation = null;
    });

    final hasMic = await controller.permissions.ensureMicrophone();
    if (!hasMic) {
      if (!mounted) return;
      setState(() {
        _errorMsg = s.tr('mic_permission_needed');
      });
      return;
    }

    final ok = await controller.pronunciation.startListening(
      localeId: controller.settings.targetLanguage.ttsLocale,
      autoStopTargetText: target,
      autoStopThreshold: 80,
      recordingSlot: 'trainer_main',
      onResult: (words, isFinal) {
        if (!mounted) return;
        final liveEval = controller.pronunciation.evaluatePronunciation(
          targetText: target,
          spokenText: words,
        );
        setState(() {
          _recognized = words;
          _evaluation = liveEval;
          if (isFinal) {
            _listening = false;
          }
        });
        if (isFinal && liveEval.scorePercent > 0) {
          controller.recordPronunciationScore(liveEval.scorePercent);
        }
      },
    );

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _errorMsg = s.tr('speech_unavailable');
      });
    } else {
      setState(() => _listening = true);
    }
  }

  Future<void> _runEvaluation(String target, String spoken) async {
    final controller = AppScope.of(context);
    final res = controller.pronunciation.evaluatePronunciation(
      targetText: target,
      spokenText: spoken,
    );
    if (!mounted) return;
    setState(() => _evaluation = res);
    if (res.scorePercent > 0) {
      await controller.recordPronunciationScore(res.scorePercent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final vocab = controller.vocabulary;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final target = _currentTarget(vocab);
    final translation = _currentTranslation(vocab);
    _ensureTranscription(controller, target);

    return ListView(
      key: const PageStorageKey<String>('pronunciation_trainer_scroll'),
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 112),
      children: [
        Card(
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_rounded, color: scheme.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${s.tr('pronunciation_trainer_title')} (${controller.settings.targetLanguage.flag})',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PronunciationModeOption(
                          label: s.tr('word_btn'),
                          icon: Icons.short_text_rounded,
                          selected: !_useSentence,
                          onTap: () {
                            if (_useSentence) {
                              setState(() {
                                _useSentence = false;
                                _evaluation = null;
                                _recognized = '';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _PronunciationModeOption(
                          label: s.tr('sentence_chip'),
                          icon: Icons.subject_rounded,
                          selected: _useSentence,
                          onTap: () {
                            if (!_useSentence) {
                              setState(() {
                                _useSentence = true;
                                _evaluation = null;
                                _recognized = '';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customTextCtrl,
                  onChanged: (_) => setState(() {
                    _evaluation = null;
                    _recognized = '';
                  }),
                  decoration: InputDecoration(
                    hintText: s.tr('custom_phrase_hint'),
                    prefixIcon: const Icon(Icons.edit_rounded),
                    suffixIcon: _customTextCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _customTextCtrl.clear();
                              setState(() {
                                _evaluation = null;
                                _recognized = '';
                              });
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (vocab.isNotEmpty && _customTextCtrl.text.trim().isEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _wordIndex =
                                (_wordIndex - 1 + vocab.length) % vocab.length;
                            _evaluation = null;
                            _recognized = '';
                          });
                        },
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text(
                        '${(_wordIndex % vocab.length) + 1} / ${vocab.length}',
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _wordIndex = (_wordIndex + 1) % vocab.length;
                            _evaluation = null;
                            _recognized = '';
                          });
                        },
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                Text(
                  target,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_transcription.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _transcription,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (translation.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    translation,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => controller.speakTarget(target),
                      icon: const Icon(Icons.volume_up_rounded),
                      label: Text(s.tr('listen_reference_btn')),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _speakSlow(controller, target),
                      icon: const Icon(Icons.slow_motion_video_rounded),
                      label: Text(s.tr('slow_05x_btn')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (_errorMsg != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  _errorMsg!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          ),
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _toggleMicrophone(target),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _listening ? Colors.red : scheme.primary,
                    boxShadow: [
                      BoxShadow(
                        color: (_listening ? Colors.red : scheme.primary)
                            .withValues(alpha: 0.35),
                        blurRadius: _listening ? 24 : 12,
                        spreadRadius: _listening ? 5 : 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    _listening ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _listening
                    ? s.tr('listening_now_hint')
                    : s.tr('tap_mic_hint'),
                style: textTheme.labelLarge?.copyWith(
                  color: _listening ? Colors.red : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        if (_recognized.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(
                    '${s.tr('you_said_label')}: «$_recognized»',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      controller.pronunciation.playRecordedVoice(
                        slot: 'trainer_main',
                        fallbackTtsSpeak: () =>
                            controller.speakTarget(_recognized),
                      );
                    },
                    icon: const Icon(Icons.play_circle_fill_rounded),
                    label: Text(s.tr('play_my_voice_btn')),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.tr('tap_word_below_hint'),
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_evaluation != null) ...[
          const SizedBox(height: 14),
          _buildScoreCard(context, _evaluation!),
        ],
      ],
    );
  }

  Widget _buildScoreCard(BuildContext context, PronunciationEvaluation eval) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final textTheme = Theme.of(context).textTheme;
    final Color color = eval.isExcellent
        ? Colors.green
        : eval.isGood
            ? Colors.orange
            : Colors.red;

    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(
              '${eval.scorePercent}%',
              style: textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.tr(eval.feedbackKey),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: eval.segments.map((seg) {
                final c = seg.matched ? Colors.green : Colors.red.shade700;
                final wordPhonetic = controller.pronunciation
                    .buildInstantTranscription(
                      seg.expectedWord,
                      langCode: controller.settings.targetLanguageCode,
                      nativeLangCode: controller.settings.nativeLanguageCode,
                      useInternationalIpa:
                          controller.settings.useInternationalIpa,
                    )
                    .replaceAll(RegExp(r'[/\[\]]'), '')
                    .trim();
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => controller.speakTarget(seg.expectedWord),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.withValues(alpha: 0.45)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              seg.matched
                                  ? Icons.check_circle_rounded
                                  : Icons.volume_up_rounded,
                              size: 16,
                              color: c,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              seg.expectedWord,
                              style: TextStyle(
                                color: c,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (wordPhonetic.isNotEmpty)
                          Text(
                            '[$wordPhonetic]',
                            style: TextStyle(
                              fontSize: 11,
                              color: c.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PronunciationModeOption extends StatelessWidget {
  const _PronunciationModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color:
                          selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
