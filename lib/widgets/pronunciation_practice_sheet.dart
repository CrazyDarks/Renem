import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/pronunciation_service.dart';
import '../state/app_controller.dart';

Future<void> showPronunciationPracticeSheet({
  required BuildContext context,
  required String targetText,
  String? translation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PronunciationPracticeSheet(
      targetText: targetText,
      translation: translation,
    ),
  );
}

class _PronunciationPracticeSheet extends StatefulWidget {
  const _PronunciationPracticeSheet({
    required this.targetText,
    this.translation,
  });

  final String targetText;
  final String? translation;

  @override
  State<_PronunciationPracticeSheet> createState() =>
      _PronunciationPracticeSheetState();
}

class _PronunciationPracticeSheetState
    extends State<_PronunciationPracticeSheet> {
  bool _listening = false;
  String _liveRecognized = '';
  String _transcription = '';
  bool _loadedTranscription = false;
  PronunciationEvaluation? _evaluation;
  String? _errorMsg;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedTranscription) {
      _loadedTranscription = true;
      final controller = AppScope.of(context);
      final lang = controller.settings.targetLanguageCode;
      final nativeLang = controller.settings.nativeLanguageCode;
      final useIpa = controller.settings.useInternationalIpa;
      _transcription = controller.pronunciation.buildInstantTranscription(
        widget.targetText,
        langCode: lang,
        nativeLangCode: nativeLang,
        useInternationalIpa: useIpa,
      );
      controller.pronunciation
          .fetchTranscription(
            widget.targetText,
            langCode: lang,
            nativeLangCode: nativeLang,
            useInternationalIpa: useIpa,
          )
          .then((exact) {
        if (mounted && exact.isNotEmpty) {
          setState(() => _transcription = exact);
        }
      });
    }
  }

  Future<void> _speakSlow(AppController controller) async {
    await controller.speakTarget(widget.targetText, overrideRate: 0.28);
  }

  Future<void> _toggleListen() async {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    if (_listening) {
      await controller.pronunciation.stopListening();
      if (!mounted) return;
      setState(() => _listening = false);
      if (_liveRecognized.trim().isNotEmpty) {
        await _evaluate(_liveRecognized);
      }
      return;
    }

    setState(() {
      _errorMsg = null;
      _liveRecognized = '';
      _evaluation = null;
    });

    final granted = await controller.permissions.ensureMicrophone();
    if (!granted) {
      if (!mounted) return;
      setState(() {
        _errorMsg = s.tr('mic_permission_needed');
      });
      return;
    }

    final started = await controller.pronunciation.startListening(
      localeId: controller.settings.targetLanguage.ttsLocale,
      autoStopTargetText: widget.targetText,
      autoStopThreshold: 80,
      recordingSlot: 'practice_sheet',
      onResult: (words, isFinal) {
        if (!mounted) return;
        final liveEval = controller.pronunciation.evaluatePronunciation(
          targetText: widget.targetText,
          spokenText: words,
        );
        setState(() {
          _liveRecognized = words;
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
    if (!started) {
      setState(() {
        _errorMsg = s.tr('speech_unavailable');
      });
    } else {
      setState(() => _listening = true);
    }
  }

  Future<void> _evaluate(String spoken) async {
    final controller = AppScope.of(context);
    final res = controller.pronunciation.evaluatePronunciation(
      targetText: widget.targetText,
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
          children: [
            Row(
              children: [
                Icon(Icons.record_voice_over_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${s.tr('pronunciation')} (${controller.settings.targetLanguage.flag})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _speakSlow(controller),
                  icon: const Icon(Icons.slow_motion_video_rounded),
                  tooltip: s.tr('slow_05x_btn'),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => controller.speakTarget(widget.targetText),
                  icon: const Icon(Icons.volume_up_rounded),
                  tooltip: s.tr('listen_reference_btn'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    widget.targetText,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  if (_transcription.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            scheme.secondaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _transcription,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                  if (widget.translation != null &&
                      widget.translation!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.translation!,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  color: scheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _errorMsg!,
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ),
              ),
            if (_liveRecognized.isNotEmpty) ...[
              Text(
                '${s.tr('you_said_label')}: «$_liveRecognized»',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () {
                  controller.pronunciation.playRecordedVoice(
                    slot: 'practice_sheet',
                    fallbackTtsSpeak: () =>
                        controller.speakTarget(_liveRecognized),
                  );
                },
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: Text(s.tr('play_my_voice_btn')),
              ),
              const SizedBox(height: 14),
            ],
            if (_evaluation != null) ...[
              _buildEvaluationCard(context, _evaluation!),
              const SizedBox(height: 16),
            ],
            GestureDetector(
              onTap: _toggleListen,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listening ? Colors.red : scheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: (_listening ? Colors.red : scheme.primary)
                          .withValues(alpha: 0.35),
                      blurRadius: _listening ? 22 : 10,
                      spreadRadius: _listening ? 4 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  _listening ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _listening ? s.tr('listening_now_hint') : s.tr('tap_mic_hint'),
              textAlign: TextAlign.center,
              style: textTheme.labelMedium?.copyWith(
                color: _listening ? Colors.red : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationCard(
    BuildContext context,
    PronunciationEvaluation eval,
  ) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final textTheme = Theme.of(context).textTheme;
    final Color badgeColor = eval.isExcellent
        ? Colors.green
        : eval.isGood
            ? Colors.orange
            : Colors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                eval.isExcellent
                    ? Icons.verified_rounded
                    : eval.isGood
                        ? Icons.thumbs_up_down_rounded
                        : Icons.replay_rounded,
                color: badgeColor,
              ),
              const SizedBox(width: 8),
              Text(
                '${s.tr('accuracy_label')}: ${eval.scorePercent}%',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: eval.segments.map((seg) {
              final c = seg.matched ? Colors.green : Colors.orange.shade800;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => controller.speakTarget(seg.expectedWord),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    seg.expectedWord,
                    style: textTheme.bodyMedium?.copyWith(
                      color: c,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            s.tr(eval.feedbackKey),
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
