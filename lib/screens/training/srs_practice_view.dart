import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/vocab_word.dart';
import '../../state/app_controller.dart';
import '../../widgets/pronunciation_practice_sheet.dart';

class SrsPracticeView extends StatefulWidget {
  const SrsPracticeView({super.key});

  @override
  State<SrsPracticeView> createState() => _SrsPracticeViewState();
}

class _SrsPracticeViewState extends State<SrsPracticeView> {
  final ScrollController _scrollController = ScrollController();
  bool _showAnswer = false;
  bool _audioMode = false;
  bool _autoListening = false;
  bool _practiceAllMode = false;
  int _sessionIndex = 0;
  int _reviewedCount = 0;
  double _speechRate = 0.48;

  @override
  void dispose() {
    _autoListening = false;
    _scrollController.dispose();
    super.dispose();
  }

  List<VocabWord> _activeDeck(AppController controller) {
    final due = controller.dueWords;
    if (due.isNotEmpty && !_practiceAllMode) return due;
    if (_practiceAllMode) return controller.vocabulary;
    return const [];
  }

  Future<void> _speakCard(AppController controller, VocabWord card) async {
    await controller.tts.setSpeechRate(_speechRate);
    await controller.speakTarget(card.word);
    if (card.contextSentence.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await controller.speakTarget(card.contextSentence);
    }
  }

  Future<void> _toggleAutoListen(
    AppController controller,
    List<VocabWord> deck,
  ) async {
    if (_autoListening) {
      setState(() => _autoListening = false);
      await controller.tts.stop();
      return;
    }
    if (deck.isEmpty) return;

    setState(() {
      _audioMode = true;
      _autoListening = true;
    });

    while (mounted && _autoListening) {
      final currentDeck = _activeDeck(controller);
      if (currentDeck.isEmpty) break;
      final card = currentDeck[_sessionIndex % currentDeck.length];

      if (mounted) {
        setState(() => _showAnswer = false);
      }
      await controller.tts.setSpeechRate(_speechRate);
      await controller.speakTarget(card.word);
      if (!mounted || !_autoListening) break;

      if (card.contextSentence.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted || !_autoListening) break;
        await controller.speakTarget(card.contextSentence);
      }

      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted || !_autoListening) break;

      setState(() => _showAnswer = true);
      await controller.speakNative(card.translation);
      if (!mounted || !_autoListening) break;

      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (!mounted || !_autoListening) break;

      setState(() {
        _sessionIndex = (_sessionIndex + 1) % currentDeck.length;
        _showAnswer = false;
      });
    }

    if (mounted) {
      setState(() => _autoListening = false);
    }
  }

  Future<void> _rateCard(
    AppController controller,
    VocabWord card,
    SrsRating rating,
  ) async {
    await controller.tts.stop();
    await controller.reviewWord(card.id, rating);
    if (!mounted) return;
    setState(() {
      _showAnswer = false;
      _reviewedCount++;
      if (_practiceAllMode) {
        _sessionIndex++;
      } else {
        _sessionIndex = 0;
      }
    });

    if (_audioMode && !_autoListening) {
      final nextDeck = _activeDeck(controller);
      if (nextDeck.isNotEmpty) {
        final nextCard = nextDeck[_sessionIndex % nextDeck.length];
        _speakCard(controller, nextCard);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final deck = _activeDeck(controller);

    if (controller.vocabulary.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_outlined, size: 52, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                s.tr('srs_empty_hint'),
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (deck.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration_rounded,
                size: 56,
                color: scheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                s.tr('srs_all_done'),
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _practiceAllMode = true;
                    _sessionIndex = 0;
                    _showAnswer = false;
                  });
                },
                icon: const Icon(Icons.replay_rounded),
                label: Text(s.tr('srs_practice_all_btn')),
              ),
            ],
          ),
        ),
      );
    }

    final card = deck[_sessionIndex % deck.length];

    return ListView(
      key: const PageStorageKey<String>('srs_practice_scroll'),
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 112),
      children: [
        Card(
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.headphones_rounded,
                      color:
                          _audioMode ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.tr('audio_mode_title'),
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            s.tr('audio_mode_sub'),
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _audioMode,
                      onChanged: (val) async {
                        setState(() => _audioMode = val);
                        if (!val) {
                          setState(() => _autoListening = false);
                          await controller.tts.stop();
                        } else {
                          _speakCard(controller, card);
                        }
                      },
                    ),
                  ],
                ),
                if (_audioMode) ...[
                  const Divider(height: 12),
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _toggleAutoListen(controller, deck),
                        icon: Icon(
                          _autoListening
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(_autoListening ? 'Stop' : 'Auto'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Slider(
                          value: _speechRate,
                          min: 0.3,
                          max: 0.75,
                          divisions: 9,
                          onChanged: (v) {
                            setState(() => _speechRate = v);
                            controller.tts.setSpeechRate(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '${(_sessionIndex % deck.length) + 1} / ${deck.length}',
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              '✓ $_reviewedCount',
              style: textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => _showAnswer = !_showAnswer),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            constraints: const BoxConstraints(minHeight: 260),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _showAnswer
                  ? scheme.primaryContainer.withValues(alpha: 0.35)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _showAnswer ? scheme.primary : scheme.outlineVariant,
                width: _showAnswer ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_audioMode && !_showAnswer) ...[
                  IconButton.filled(
                    iconSize: 40,
                    padding: const EdgeInsets.all(16),
                    onPressed: () => _speakCard(controller, card),
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s.tr('tap_to_reveal'),
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ] else ...[
                  Text(
                    card.word,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => _speakCard(controller, card),
                        icon: const Icon(Icons.volume_up_rounded),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        onPressed: () {
                          showPronunciationPracticeSheet(
                            context: context,
                            targetText: card.word,
                            translation: card.translation,
                          );
                        },
                        icon: const Icon(Icons.mic_rounded),
                      ),
                    ],
                  ),
                  if (card.partOfSpeech.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.partOfSpeech,
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (card.contextSentence.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      '«${card.contextSentence}»',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
                if (_showAnswer) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  Text(
                    card.translation,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (card.exampleSentence.isNotEmpty &&
                      card.exampleSentence != card.contextSentence) ...[
                    const SizedBox(height: 10),
                    Text(
                      card.exampleSentence,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ] else if (!_audioMode) ...[
                  const SizedBox(height: 24),
                  Text(
                    s.tr('tap_to_reveal'),
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!_showAnswer)
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => _showAnswer = true),
              child: Text(s.tr('show_answer')),
            ),
          )
        else ...[
          Row(
            children: [
              _SrsRatingButton(
                label: s.tr('rate_again'),
                interval: card.previewIntervalLabel(SrsRating.again),
                color: scheme.errorContainer,
                onColor: scheme.onErrorContainer,
                onTap: () => _rateCard(controller, card, SrsRating.again),
              ),
              const SizedBox(width: 8),
              _SrsRatingButton(
                label: s.tr('rate_hard'),
                interval: card.previewIntervalLabel(SrsRating.hard),
                color: scheme.tertiaryContainer,
                onColor: scheme.onTertiaryContainer,
                onTap: () => _rateCard(controller, card, SrsRating.hard),
              ),
              const SizedBox(width: 8),
              _SrsRatingButton(
                label: s.tr('rate_good'),
                interval: card.previewIntervalLabel(SrsRating.good),
                color: scheme.primaryContainer,
                onColor: scheme.onPrimaryContainer,
                onTap: () => _rateCard(controller, card, SrsRating.good),
              ),
              const SizedBox(width: 8),
              _SrsRatingButton(
                label: s.tr('rate_easy'),
                interval: card.previewIntervalLabel(SrsRating.easy),
                color: scheme.secondaryContainer,
                onColor: scheme.onSecondaryContainer,
                onTap: () => _rateCard(controller, card, SrsRating.easy),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SrsRatingButton extends StatelessWidget {
  const _SrsRatingButton({
    required this.label,
    required this.interval,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  final String label;
  final String interval;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: onColor,
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    interval,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: onColor.withValues(alpha: 0.85),
                        ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
