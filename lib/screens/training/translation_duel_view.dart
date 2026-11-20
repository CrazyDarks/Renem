import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../models/user_progress.dart';
import '../../state/app_controller.dart';

class _DuelPromptItem {
  const _DuelPromptItem({
    required this.word,
    required this.correctTranslation,
    required this.options,
    required this.correctIndex,
  });

  final String word;
  final String correctTranslation;
  final List<String> options;
  final int correctIndex;
}

class TranslationDuelView extends StatefulWidget {
  const TranslationDuelView({super.key});

  @override
  State<TranslationDuelView> createState() => _TranslationDuelViewState();
}

class _TranslationDuelViewState extends State<TranslationDuelView> {
  static const int _roundDurationSeconds = 60;

  final Random _rng = Random();
  Timer? _timer;

  bool _isPlaying = false;
  bool _isFinished = false;
  int _secondsLeft = _roundDurationSeconds;
  int _score = 0;
  int _correctCount = 0;
  int _combo = 0;
  int _maxCombo = 0;
  int? _selectedOptionIndex;
  FriendProfile? _challengedFriend;
  int? _simulatedFriendScore;

  List<({String target, String native})> _wordPool = [];
  _DuelPromptItem? _currentPrompt;
  int _poolCursor = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<({String target, String native})> _buildPool(AppController controller) {
    final lang = controller.settings.targetLanguageCode;
    final userWords = controller.vocabulary
        .where((w) => w.word.trim().isNotEmpty && w.translation.trim().isNotEmpty)
        .map((w) => (target: w.word.trim(), native: w.translation.trim()))
        .toList();

    final builtIn = _builtInPairsForLanguage(lang);
    final seen = <String>{};
    final combined = <({String target, String native})>[];

    for (final entry in [...userWords, ...builtIn]) {
      final key = entry.target.toLowerCase();
      if (seen.add(key)) {
        combined.add(entry);
      }
    }
    combined.shuffle(_rng);
    return combined;
  }

  _DuelPromptItem _nextQuestion() {
    if (_wordPool.length < 4) {
      _wordPool = _builtInPairsForLanguage('en')..shuffle(_rng);
    }
    final current = _wordPool[_poolCursor % _wordPool.length];
    _poolCursor++;

    final distractors = <String>[];
    final candidates = List<({String target, String native})>.from(_wordPool)
      ..shuffle(_rng);
    for (final c in candidates) {
      if (c.native.toLowerCase() != current.native.toLowerCase() &&
          !distractors.contains(c.native)) {
        distractors.add(c.native);
        if (distractors.length == 3) break;
      }
    }

    final options = [current.native, ...distractors]..shuffle(_rng);
    final correctIdx = options.indexOf(current.native);

    return _DuelPromptItem(
      word: current.target,
      correctTranslation: current.native,
      options: options,
      correctIndex: correctIdx,
    );
  }

  void _startDuel(AppController controller) {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _wordPool = _buildPool(controller);
    _poolCursor = 0;

    int? friendTarget;
    if (_challengedFriend != null) {
      // Simulate a realistic rival score based on the friend's level & streak
      final base = 110 + (_challengedFriend!.level * 18);
      friendTarget = base + _rng.nextInt(75);
    }

    setState(() {
      _isPlaying = true;
      _isFinished = false;
      _secondsLeft = _roundDurationSeconds;
      _score = 0;
      _correctCount = 0;
      _combo = 0;
      _maxCombo = 0;
      _selectedOptionIndex = null;
      _simulatedFriendScore = friendTarget;
      _currentPrompt = _nextQuestion();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        _finishDuel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _finishDuel() async {
    _timer?.cancel();
    if (!mounted) return;
    final controller = AppScope.of(context);
    setState(() {
      _isPlaying = false;
      _isFinished = true;
    });
    await controller.recordDuelResult(
      myScore: _score,
      correctAnswers: _correctCount,
      maxCombo: _maxCombo,
      friendName: _challengedFriend?.name,
      friendScore: _simulatedFriendScore,
    );
  }

  void _handleOptionTap(int index) {
    final prompt = _currentPrompt;
    if (!_isPlaying || prompt == null || _selectedOptionIndex != null) return;

    final isCorrect = index == prompt.correctIndex;
    if (isCorrect) {
      HapticFeedback.lightImpact();
      final nextCombo = _combo + 1;
      final multiplier = nextCombo.clamp(1, 5);
      final gained = 10 * multiplier;
      setState(() {
        _selectedOptionIndex = index;
        _correctCount++;
        _combo = nextCombo;
        if (nextCombo > _maxCombo) _maxCombo = nextCombo;
        _score += gained;
      });
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _selectedOptionIndex = index;
        _combo = 0;
      });
    }

    Future<void>.delayed(Duration(milliseconds: isCorrect ? 230 : 520), () {
      if (!mounted || !_isPlaying) return;
      setState(() {
        _selectedOptionIndex = null;
        _currentPrompt = _nextQuestion();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = controller.progress;
    final friends = progress.friends;

    return ListView(
      key: const PageStorageKey<String>('translation_duel_scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 116),
      children: [
        if (!_isPlaying && !_isFinished) ...[
          // Duel Setup & Personal Best Card
          Card(
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: scheme.onPrimaryContainer,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.tr('duel_title')} (${controller.settings.targetLanguage.flag})',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              s.tr('duel_desc'),
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Personal Records Strip
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.emoji_events_rounded,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.tr('duel_best_score'),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      '${progress.bestDuelScore}',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: Colors.deepOrangeAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.tr('duel_max_combo'),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Text(
                                      'x${progress.bestDuelCombo}',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.tr('duel_challenge_friend'),
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        showCheckmark: false,
                        avatar: const Icon(Icons.person_rounded, size: 16),
                        label: Text(s.tr('duel_solo_mode')),
                        selected: _challengedFriend == null,
                        onSelected: (_) =>
                            setState(() => _challengedFriend = null),
                      ),
                      ...friends.map((friend) {
                        final selected = _challengedFriend?.id == friend.id;
                        return ChoiceChip(
                          showCheckmark: false,
                          avatar: const Icon(
                            Icons.sports_kabaddi_rounded,
                            size: 16,
                          ),
                          label: Text(friend.name),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _challengedFriend = friend),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _startDuel(controller),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        _challengedFriend != null
                            ? '${s.tr('duel_start_btn')} vs ${_challengedFriend!.name}'
                            : s.tr('duel_start_btn'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (progress.duelHistory.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              s.tr('duel_history_title'),
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...progress.duelHistory.take(5).map((rec) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: rec.isWin
                          ? Colors.green.withValues(alpha: 0.16)
                          : scheme.tertiaryContainer,
                      foregroundColor:
                          rec.isWin ? Colors.green.shade400 : scheme.tertiary,
                      child: Icon(
                        rec.isFriendChallenge
                            ? Icons.sports_kabaddi_rounded
                            : Icons.bolt_rounded,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      rec.isFriendChallenge
                          ? '${progress.displayName} (${rec.myScore}) vs ${rec.friendName} (${rec.friendScore})'
                          : '${s.tr('duel_score_label')}: ${rec.myScore}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '✓ ${rec.correctAnswers} • 🔥 x${rec.maxCombo}',
                    ),
                  ),
                ),
              );
            }),
          ],
        ] else if (_isPlaying && _currentPrompt != null) ...[
          // Active 60-Second Sprint HUD
          Card(
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 20,
                        color: _secondsLeft <= 10
                            ? Colors.redAccent
                            : scheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_secondsLeft}s',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _secondsLeft <= 10
                              ? Colors.redAccent
                              : scheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _combo >= 2
                              ? Colors.deepOrange.withValues(alpha: 0.18)
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '🔥 x${_combo.clamp(1, 5)}',
                          style: textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _combo >= 2
                                ? Colors.deepOrangeAccent
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_score',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _secondsLeft / _roundDurationSeconds,
                      minHeight: 6,
                      color: _secondsLeft <= 10
                          ? Colors.redAccent
                          : scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Prompt Card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 28,
              ),
              child: Column(
                children: [
                  Text(
                    _currentPrompt!.word,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '✓ $_correctCount',
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 4 Translation Options
          ...List.generate(_currentPrompt!.options.length, (idx) {
            final opt = _currentPrompt!.options[idx];
            final selected = _selectedOptionIndex == idx;
            final isCorrect = idx == _currentPrompt!.correctIndex;
            final answered = _selectedOptionIndex != null;

            Color borderColor = scheme.outlineVariant.withValues(alpha: 0.45);
            Color bgColor = scheme.surfaceContainerLow;
            if (answered) {
              if (isCorrect) {
                borderColor = Colors.green;
                bgColor = Colors.green.withValues(alpha: 0.18);
              } else if (selected) {
                borderColor = Colors.redAccent;
                bgColor = Colors.redAccent.withValues(alpha: 0.18);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _handleOptionTap(idx),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            opt,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (answered && isCorrect)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 20,
                          )
                        else if (answered && selected && !isCorrect)
                          const Icon(
                            Icons.cancel_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ] else if (_isFinished) ...[
          // Duel Result Card ("Ти vs Друг" / Personal Best)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(
                    (_challengedFriend == null ||
                            _score >= (_simulatedFriendScore ?? 0))
                        ? Icons.emoji_events_rounded
                        : Icons.sports_kabaddi_rounded,
                    size: 52,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _challengedFriend != null
                        ? (_score >= (_simulatedFriendScore ?? 0)
                            ? s.tr('duel_victory')
                            : s.tr('duel_close_match'))
                        : '${s.tr('duel_score_label')}: $_score',
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '✓ $_correctCount • 🔥 ${s.tr('duel_max_combo')}: x$_maxCombo',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_challengedFriend != null &&
                      _simulatedFriendScore != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  progress.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_score',
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _score >= _simulatedFriendScore!
                                        ? Colors.green.shade400
                                        : scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'VS',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  _challengedFriend!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_simulatedFriendScore',
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _simulatedFriendScore! > _score
                                        ? Colors.amber
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _isPlaying = false;
                              _isFinished = false;
                            });
                          },
                          child: Text(s.tr('cancel_btn')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _startDuel(controller),
                          icon: const Icon(Icons.replay_rounded),
                          label: Text(s.tr('duel_start_btn')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static List<({String target, String native})> _builtInPairsForLanguage(
    String langCode,
  ) {
    switch (langCode) {
      case 'es':
        return const [
          (target: 'siempre', native: 'завжди'),
          (target: 'descubrir', native: 'відкривати / дізнаватися'),
          (target: 'el desafío', native: 'виклик'),
          (target: 'imprescindible', native: 'незамінний / необхідний'),
          (target: 'la madrugada', native: 'світанок / ранній ранок'),
          (target: 'desarrollar', native: 'розвивати'),
          (target: 'cotidiano', native: 'повсякденний'),
          (target: 'el éxito', native: 'успіх'),
          (target: 'aprovechar', native: 'скористатися нагодою'),
          (target: 'la confianza', native: 'довіра / впевненість'),
          (target: 'sostenible', native: 'сталий / екологічний'),
          (target: 'el entorno', native: 'середовище / оточення'),
        ];
      case 'de':
        return const [
          (target: 'die Erfahrung', native: 'досвід'),
          (target: 'entdecken', native: 'відкривати'),
          (target: 'zuverlässig', native: 'надійний'),
          (target: 'die Herausforderung', native: 'виклик'),
          (target: 'überzeugen', native: 'переконувати'),
          (target: 'nachhaltig', native: 'сталий / довготривалий'),
          (target: 'die Gelegenheit', native: 'нагода / можливість'),
          (target: 'entscheiden', native: 'вирішувати'),
          (target: 'der Fortschritt', native: 'прогрес'),
          (target: 'selbstverständlich', native: 'звісно / само собою'),
          (target: 'die Aufmerksamkeit', native: 'увага'),
          (target: 'vergleichen', native: 'порівнювати'),
        ];
      case 'fr':
        return const [
          (target: 'cependant', native: 'однак / проте'),
          (target: 'améliorer', native: 'покращувати'),
          (target: 'quotidien', native: 'щоденний'),
          (target: 'la confiance', native: 'довіра'),
          (target: 'atteindre', native: 'досягати'),
          (target: 'l’environnement', native: 'довкілля / оточення'),
          (target: 'incontournable', native: 'неодмінний / ключовий'),
          (target: 'partager', native: 'ділитися'),
          (target: 'le défi', native: 'виклик'),
          (target: 'épanouir', native: 'розквітати / розвиватися'),
          (target: 'la réussite', native: 'успіх'),
          (target: 'approfondir', native: 'поглиблювати'),
        ];
      case 'pl':
        return const [
          (target: 'doświadczenie', native: 'досвід'),
          (target: 'wyzwanie', native: 'виклик'),
          (target: 'niezawodny', native: 'надійний'),
          (target: 'osiągnąć', native: 'досягти'),
          (target: 'codzienny', native: 'щоденний'),
          (target: 'rozwijać', native: 'розвивати'),
          (target: 'współpraca', native: 'співпраця'),
          (target: 'przekonać', native: 'переконати'),
          (target: 'środowisko', native: 'середовище'),
          (target: 'możliwość', native: 'можливість'),
          (target: 'skuteczny', native: 'ефективний'),
          (target: 'porównać', native: 'порівняти'),
        ];
      default:
        return const [
          (target: 'immerse', native: 'занурюватися'),
          (target: 'effortless', native: 'невимушений / легкий'),
          (target: 'authentic', native: 'автентичний / справжній'),
          (target: 'resilient', native: 'стійкий / витривалий'),
          (target: 'breakthrough', native: 'прорив / відкриття'),
          (target: 'ambiguous', native: 'неоднозначний'),
          (target: 'comprehensive', native: 'всебічний / вичерпний'),
          (target: 'inevitable', native: 'неминучий'),
          (target: 'accomplish', native: 'досягати / виконувати'),
          (target: 'persuade', native: 'переконувати'),
          (target: 'sustainable', native: 'сталий / довготривалий'),
          (target: 'accurate', native: 'точний'),
          (target: 'reluctant', native: 'неохочий'),
          (target: 'enhance', native: 'покращувати / посилювати'),
          (target: 'crucial', native: 'вирішальний / ключовий'),
          (target: 'consequence', native: 'наслідок'),
        ];
    }
  }
}
