enum SrsRating { again, hard, good, easy }

class VocabWord {
  const VocabWord({
    required this.id,
    required this.word,
    required this.translation,
    this.languageCode = 'en',
    this.contextSentence = '',
    this.exampleSentence = '',
    this.partOfSpeech = '',
    this.sourceTitle = '',
    required this.createdAt,
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    this.repetitions = 0,
    this.lapses = 0,
    required this.nextReviewAt,
  });

  final String id;
  final String word;
  final String translation;
  final String languageCode;
  final String contextSentence;
  final String exampleSentence;
  final String partOfSpeech;
  final String sourceTitle;
  final DateTime createdAt;

  // SM-2 spaced repetition state
  final int intervalDays;
  final double easeFactor;
  final int repetitions;
  final int lapses;
  final DateTime nextReviewAt;

  bool get isDue => !nextReviewAt.isAfter(DateTime.now());
  bool get isMastered => repetitions >= 3 && intervalDays >= 7;

  VocabWord copyWith({
    String? id,
    String? word,
    String? translation,
    String? languageCode,
    String? contextSentence,
    String? exampleSentence,
    String? partOfSpeech,
    String? sourceTitle,
    DateTime? createdAt,
    int? intervalDays,
    double? easeFactor,
    int? repetitions,
    int? lapses,
    DateTime? nextReviewAt,
  }) {
    return VocabWord(
      id: id ?? this.id,
      word: word ?? this.word,
      translation: translation ?? this.translation,
      languageCode: languageCode ?? this.languageCode,
      contextSentence: contextSentence ?? this.contextSentence,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      createdAt: createdAt ?? this.createdAt,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
      repetitions: repetitions ?? this.repetitions,
      lapses: lapses ?? this.lapses,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
    );
  }

  /// Applies SM-2 spaced repetition scheduling based on [rating].
  VocabWord applySrsRating(SrsRating rating) {
    final now = DateTime.now();
    int newReps = repetitions;
    int newInterval = intervalDays;
    double newEase = easeFactor;
    int newLapses = lapses;

    switch (rating) {
      case SrsRating.again:
        newReps = 0;
        newInterval = 0;
        newEase = (easeFactor - 0.2).clamp(1.3, 3.0);
        newLapses = lapses + 1;
        return copyWith(
          repetitions: newReps,
          intervalDays: newInterval,
          easeFactor: newEase,
          lapses: newLapses,
          nextReviewAt: now.add(const Duration(minutes: 10)),
        );
      case SrsRating.hard:
        newReps = repetitions + 1;
        newInterval = intervalDays <= 1 ? 1 : (intervalDays * 1.2).round();
        newEase = (easeFactor - 0.15).clamp(1.3, 3.0);
      case SrsRating.good:
        newReps = repetitions + 1;
        if (newReps == 1) {
          newInterval = 1;
        } else if (newReps == 2) {
          newInterval = 6;
        } else {
          newInterval = (intervalDays * easeFactor).round().clamp(1, 365);
        }
      case SrsRating.easy:
        newReps = repetitions + 1;
        if (newReps == 1) {
          newInterval = 4;
        } else {
          newInterval =
              ((intervalDays <= 0 ? 3 : intervalDays) * easeFactor * 1.3)
                  .round()
                  .clamp(4, 365);
        }
        newEase = (easeFactor + 0.15).clamp(1.3, 3.0);
    }

    return copyWith(
      repetitions: newReps,
      intervalDays: newInterval,
      easeFactor: newEase,
      lapses: newLapses,
      nextReviewAt: now.add(Duration(days: newInterval)),
    );
  }

  /// Human-readable preview of the next review interval for a given rating.
  String previewIntervalLabel(SrsRating rating) {
    final next = applySrsRating(rating);
    if (rating == SrsRating.again) {
      return '10 хв';
    }
    final days = next.intervalDays;
    if (days <= 1) return '1 дн.';
    if (days < 30) return '$days дн.';
    final months = (days / 30).round();
    return '$months міс.';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'translation': translation,
      'languageCode': languageCode,
      'contextSentence': contextSentence,
      'exampleSentence': exampleSentence,
      'partOfSpeech': partOfSpeech,
      'sourceTitle': sourceTitle,
      'createdAt': createdAt.toIso8601String(),
      'intervalDays': intervalDays,
      'easeFactor': easeFactor,
      'repetitions': repetitions,
      'lapses': lapses,
      'nextReviewAt': nextReviewAt.toIso8601String(),
    };
  }

  factory VocabWord.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return VocabWord(
      id: json['id'] as String? ?? '${now.microsecondsSinceEpoch}',
      word: json['word'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      languageCode: json['languageCode'] as String? ?? 'en',
      contextSentence: json['contextSentence'] as String? ?? '',
      exampleSentence: json['exampleSentence'] as String? ?? '',
      partOfSpeech: json['partOfSpeech'] as String? ?? '',
      sourceTitle: json['sourceTitle'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 0,
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      lapses: (json['lapses'] as num?)?.toInt() ?? 0,
      nextReviewAt:
          DateTime.tryParse(json['nextReviewAt'] as String? ?? '') ?? now,
    );
  }
}
