enum MaterialSourceType { manual, youtube, photo, web }

class SubtitleCue {
  SubtitleCue({
    required this.startMs,
    required this.durationMs,
    required String text,
    String translation = '',
  })  : text = sanitizeSubtitleText(text),
        translation = sanitizeSubtitleText(translation);

  final int startMs;
  final int durationMs;
  final String text;
  final String translation;

  static String sanitizeSubtitleText(String input) {
    if (input.isEmpty) return '';
    // Decode HTML entities first so escaped tags like &lt;font&gt; also get stripped
    var decoded = input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');

    // Remove all HTML/XML tags such as <font color="#00BCE7"><b>...</b></font>, <i>, <c.color>, etc.
    decoded = decoded.replaceAll(RegExp(r'<[^>]*>'), ' ');

    // Remove WebVTT/ASS curly-brace style tags like {\an8}
    decoded = decoded.replaceAll(RegExp(r'\{\\[^}]*\}'), ' ');

    return decoded.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String sanitizeArticleText(String input) {
    if (input.isEmpty) return '';
    var decoded = input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    decoded = decoded.replaceAll(RegExp(r'<[^>]*>'), ' ');
    decoded = decoded.replaceAll(RegExp(r'\{\\[^}]*\}'), ' ');

    final paragraphs = decoded
        .split(RegExp(r'\n\s*\n+'))
        .map((p) => p.replaceAll(RegExp(r'[ \t\n]+'), ' ').trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      return decoded.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return paragraphs.join('\n\n');
  }

  Duration get startDuration => Duration(milliseconds: startMs);

  String get formattedTimestamp {
    final totalSeconds = startMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'startMs': startMs,
        'durationMs': durationMs,
        'text': text,
        'translation': translation,
      };

  factory SubtitleCue.fromJson(Map<String, dynamic> json) {
    return SubtitleCue(
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
    );
  }
}

class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.title,
    required this.content,
    required this.sourceType,
    this.languageCode = 'en',
    this.youtubeVideoId,
    this.sourceUrl,
    this.subtitles = const [],
    required this.createdAt,
  });

  final String id;
  final String title;
  final String content;
  final MaterialSourceType sourceType;
  final String languageCode;
  final String? youtubeVideoId;
  final String? sourceUrl;
  final List<SubtitleCue> subtitles;
  final DateTime createdAt;

  StudyMaterial copyWith({
    String? id,
    String? title,
    String? content,
    MaterialSourceType? sourceType,
    String? languageCode,
    String? youtubeVideoId,
    String? sourceUrl,
    List<SubtitleCue>? subtitles,
    DateTime? createdAt,
  }) {
    return StudyMaterial(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      sourceType: sourceType ?? this.sourceType,
      languageCode: languageCode ?? this.languageCode,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      subtitles: subtitles ?? this.subtitles,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'sourceType': sourceType.name,
        'languageCode': languageCode,
        'youtubeVideoId': youtubeVideoId,
        'sourceUrl': sourceUrl,
        'subtitles': subtitles.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    final typeName = json['sourceType'] as String? ?? 'manual';
    final sourceType = MaterialSourceType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => MaterialSourceType.manual,
    );
    final rawSubtitles = json['subtitles'] as List<dynamic>? ?? const [];
    final cleanSubtitles = rawSubtitles
        .whereType<Map<String, dynamic>>()
        .map(SubtitleCue.fromJson)
        .toList();
    final rawContent = json['content'] as String? ?? '';
    return StudyMaterial(
      id: json['id'] as String? ?? '${DateTime.now().microsecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Без назви',
      content: sourceType == MaterialSourceType.youtube
          ? SubtitleCue.sanitizeSubtitleText(rawContent)
          : SubtitleCue.sanitizeArticleText(rawContent),
      sourceType: sourceType,
      languageCode: json['languageCode'] as String? ?? 'en',
      youtubeVideoId: json['youtubeVideoId'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      subtitles: cleanSubtitles,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
