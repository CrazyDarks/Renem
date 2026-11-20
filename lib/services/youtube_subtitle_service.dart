import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/study_material.dart';

class YoutubeVideoFetchResult {
  const YoutubeVideoFetchResult({
    required this.videoId,
    required this.title,
    required this.subtitles,
    this.warningMessage,
  });

  final String videoId;
  final String title;
  final List<SubtitleCue> subtitles;
  final String? warningMessage;

  String get fullTranscript => subtitles
      .map(
        (c) => c.translation.isNotEmpty
            ? '${c.text}\n(${c.translation})'
            : c.text,
      )
      .where((t) => t.isNotEmpty)
      .join('\n\n');
}

class YoutubeSubtitleService {
  static const Map<String, String> _webHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Accept-Language': 'en-US,en;q=0.9,uk;q=0.8',
    'Cookie': 'CONSENT=YES+cb.20210328-17-p0.en+FX+999',
  };

  String? extractVideoId(String urlOrId) {
    final trimmed = urlOrId.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
      return trimmed;
    }
    return YoutubePlayer.convertUrlToId(trimmed);
  }

  Future<YoutubeVideoFetchResult> fetchVideoAndSubtitles(
    String urlOrId, {
    required String preferredLangCode,
    String? nativeLangCode,
  }) async {
    final videoId = extractVideoId(urlOrId);
    if (videoId == null) {
      throw const FormatException(
        'Invalid YouTube URL / Невірне посилання на YouTube.',
      );
    }

    String title = 'YouTube ($videoId)';
    String description = '';

    try {
      final oembedUri = Uri.parse(
        'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json',
      );
      final oembedResp =
          await http.get(oembedUri).timeout(const Duration(seconds: 7));
      if (oembedResp.statusCode == 200) {
        final data = jsonDecode(oembedResp.body) as Map<String, dynamic>;
        final fetchedTitle = (data['title'] as String?)?.trim();
        if (fetchedTitle != null && fetchedTitle.isNotEmpty) {
          title = fetchedTitle;
        }
      }
    } catch (_) {}

    // 1. Try InnerTube updated mobile/VR/embedded player APIs
    var trackFetch = await _fetchViaInnerTube(
      videoId,
      preferredLangCode: preferredLangCode,
    );
    var cues = trackFetch.cues;
    var trackLang = trackFetch.trackLang;

    // 2. Fallback to youtube_explode_dart closed captions manifest + video metadata
    if (cues.isEmpty) {
      final explodeRes = await _fetchViaYoutubeExplode(
        videoId,
        preferredLangCode: preferredLangCode,
      );
      cues = explodeRes.cues;
      trackLang = explodeRes.trackLang;
      if (explodeRes.title.isNotEmpty && title.startsWith('YouTube (')) {
        title = explodeRes.title;
      }
      description = explodeRes.description;
    }

    // 3. Fallback to web page captionTracks parser
    if (cues.isEmpty) {
      final webRes = await _fetchViaWebWatchPage(
        videoId,
        preferredLangCode: preferredLangCode,
      );
      cues = webRes.cues;
      trackLang = webRes.trackLang;
    }

    // 4. If the track was in a different language than preferredLangCode, translate cue.text to preferredLangCode
    if (cues.isNotEmpty &&
        trackLang.isNotEmpty &&
        !trackLang.toLowerCase().startsWith(preferredLangCode.toLowerCase())) {
      cues = await _translateCuePrimaryTexts(
        cues,
        targetLang: preferredLangCode,
      );
    }

    // 5. If the video has NO uploaded captions at all (or subtitles were disabled by the author),
    // automatically generate interactive study subtitles on the video's topic using AI + metadata!
    if (cues.isEmpty) {
      cues = await _generateAiStudySubtitlesForVideo(
        videoId: videoId,
        title: title,
        description: description,
        preferredLangCode: preferredLangCode,
      );
    }

    return YoutubeVideoFetchResult(
      videoId: videoId,
      title: title,
      subtitles: cues,
    );
  }

  Future<({List<SubtitleCue> cues, String trackLang})> _fetchViaInnerTube(
    String videoId, {
    required String preferredLangCode,
  }) async {
    final clients = [
      {
        'clientName': 'ANDROID_VR',
        'clientVersion': '1.60.19',
        'userAgent':
            'com.google.android.apps.youtube.vr.oculus/1.60.19 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
      },
      {
        'clientName': 'IOS',
        'clientVersion': '20.10.4',
        'deviceModel': 'iPhone16,2',
        'userAgent':
            'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_1 like Mac OS X)',
      },
      {
        'clientName': 'ANDROID',
        'clientVersion': '20.10.35',
        'androidSdkVersion': 34,
        'userAgent':
            'com.google.android.youtube/20.10.35 (Linux; U; Android 14) gzip',
      },
      {
        'clientName': 'WEB',
        'clientVersion': '2.20250312.04.00',
        'userAgent': _webHeaders['User-Agent']!,
      },
    ];

    for (final client in clients) {
      try {
        final uri = Uri.parse(
          'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
        );
        final body = jsonEncode({
          'videoId': videoId,
          'context': {
            'client': {
              'clientName': client['clientName'],
              'clientVersion': client['clientVersion'],
              'hl': preferredLangCode,
              'gl': 'US',
              if (client['androidSdkVersion'] != null)
                'androidSdkVersion': client['androidSdkVersion'],
              if (client['deviceModel'] != null)
                'deviceModel': client['deviceModel'],
            },
          },
        });

        final resp = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': client['userAgent'] as String,
                'Cookie': _webHeaders['Cookie']!,
              },
              body: body,
            )
            .timeout(const Duration(seconds: 9));

        if (resp.statusCode != 200) continue;
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final captions = data['captions'] as Map<String, dynamic>?;
        final renderer = captions?['playerCaptionsTracklistRenderer']
            as Map<String, dynamic>?;
        final rawTracks = renderer?['captionTracks'] as List<dynamic>?;
        if (rawTracks == null || rawTracks.isEmpty) continue;

        final tracks = rawTracks.whereType<Map<String, dynamic>>().toList();
        final chosen = _pickBestTrack(tracks, preferredLangCode);
        final baseUrl = chosen['baseUrl'] as String?;
        final langCode = (chosen['languageCode'] as String? ?? '').trim();
        if (baseUrl == null || baseUrl.isEmpty) continue;

        final parsed = await _downloadAndParseTrack(
          baseUrl,
          userAgent: client['userAgent'] as String,
        );
        if (parsed.isNotEmpty) {
          return (cues: parsed, trackLang: langCode);
        }
      } catch (e) {
        debugPrint('InnerTube (${client['clientName']}) subtitle error: $e');
      }
    }
    return (cues: const <SubtitleCue>[], trackLang: '');
  }

  Future<
      ({
        List<SubtitleCue> cues,
        String trackLang,
        String title,
        String description,
      })> _fetchViaYoutubeExplode(
    String videoId, {
    required String preferredLangCode,
  }) async {
    final yt = YoutubeExplode();
    String videoTitle = '';
    String videoDesc = '';
    try {
      try {
        final video = await yt.videos
            .get(videoId)
            .timeout(const Duration(seconds: 8));
        videoTitle = video.title;
        videoDesc = video.description;
      } catch (_) {}

      final manifest = await yt.videos.closedCaptions
          .getManifest(videoId)
          .timeout(const Duration(seconds: 10));
      if (manifest.tracks.isEmpty) {
        return (
          cues: const <SubtitleCue>[],
          trackLang: '',
          title: videoTitle,
          description: videoDesc,
        );
      }

      final pref = preferredLangCode.toLowerCase();
      ClosedCaptionTrackInfo? chosen;

      for (final t in manifest.tracks) {
        final code = t.language.code.toLowerCase();
        if ((code == pref || code.startsWith('$pref-')) && !t.isAutoGenerated) {
          chosen = t;
          break;
        }
      }
      chosen ??= manifest.tracks.cast<ClosedCaptionTrackInfo?>().firstWhere(
            (t) {
              final code = t!.language.code.toLowerCase();
              return code == pref || code.startsWith('$pref-');
            },
            orElse: () => null,
          );
      chosen ??= manifest.tracks.cast<ClosedCaptionTrackInfo?>().firstWhere(
            (t) => t!.language.code.toLowerCase().startsWith('en'),
            orElse: () => manifest.tracks.first,
          );

      final track = await yt.videos.closedCaptions
          .get(chosen!)
          .timeout(const Duration(seconds: 10));

      final list = track.captions
          .where((c) => c.text.trim().isNotEmpty)
          .map(
            (c) => SubtitleCue(
              startMs: c.offset.inMilliseconds,
              durationMs: c.duration.inMilliseconds > 0
                  ? c.duration.inMilliseconds
                  : 2500,
              text: c.text.replaceAll('\n', ' ').trim(),
            ),
          )
          .toList();

      return (
        cues: list,
        trackLang: chosen.language.code,
        title: videoTitle,
        description: videoDesc,
      );
    } catch (e) {
      debugPrint('YoutubeExplode subtitle fallback error: $e');
      return (
        cues: const <SubtitleCue>[],
        trackLang: '',
        title: videoTitle,
        description: videoDesc,
      );
    } finally {
      yt.close();
    }
  }

  Future<({List<SubtitleCue> cues, String trackLang})> _fetchViaWebWatchPage(
    String videoId, {
    required String preferredLangCode,
  }) async {
    try {
      final watchUri =
          Uri.parse('https://www.youtube.com/watch?v=$videoId&hl=en');
      final response = await http
          .get(watchUri, headers: _webHeaders)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return (cues: const <SubtitleCue>[], trackLang: '');
      }

      final tracks = _extractCaptionTracks(response.body);
      if (tracks.isEmpty) {
        return (cues: const <SubtitleCue>[], trackLang: '');
      }

      final chosen = _pickBestTrack(tracks, preferredLangCode);
      final baseUrl = chosen['baseUrl'] as String?;
      final langCode = (chosen['languageCode'] as String? ?? '').trim();
      if (baseUrl == null || baseUrl.isEmpty) {
        return (cues: const <SubtitleCue>[], trackLang: '');
      }

      final parsed = await _downloadAndParseTrack(baseUrl);
      return (cues: parsed, trackLang: langCode);
    } catch (_) {
      return (cues: const <SubtitleCue>[], trackLang: '');
    }
  }

  /// Generates 12 interactive study subtitle cues when a YouTube video has no captions uploaded.
  Future<List<SubtitleCue>> _generateAiStudySubtitlesForVideo({
    required String videoId,
    required String title,
    required String description,
    required String preferredLangCode,
  }) async {
    try {
      final shortDesc = description.length > 350
          ? description.substring(0, 350)
          : description;
      final prompt = '''
The user is studying language "$preferredLangCode" with a YouTube video titled: "$title".
Description context: "$shortDesc"
Create 12 natural, realistic dialogue/transcript sentences in language code "$preferredLangCode" matching this video's topic so the user can read and tap words to learn.
Return ONLY a JSON array of 12 strings (no markdown fences):
["Sentence 1...", "Sentence 2...", ...]
''';
      final resp = await http
          .post(
            Uri.parse('https://text.pollinations.ai/openai'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'openai',
              'messages': [
                {
                  'role': 'system',
                  'content': 'Respond ONLY with a valid JSON array of strings.',
                },
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.5,
            }),
          )
          .timeout(const Duration(seconds: 14));

      if (resp.statusCode == 200 && resp.body.trim().isNotEmpty) {
        String content = resp.body.trim();
        if (content.startsWith('{') && content.contains('"choices"')) {
          final data = jsonDecode(content) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            content = ((choices.first as Map<String, dynamic>)['message']
                        as Map<String, dynamic>?)?['content']
                    ?.toString() ??
                '';
          }
        }
        final start = content.indexOf('[');
        final end = content.lastIndexOf(']');
        if (start != -1 && end != -1 && end > start) {
          final arr =
              jsonDecode(content.substring(start, end + 1)) as List<dynamic>;
          final lines = arr
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (lines.isNotEmpty) {
            return List.generate(lines.length, (i) {
              return SubtitleCue(
                startMs: i * 5000,
                durationMs: 4800,
                text: lines[i],
              );
            });
          }
        }
      }
    } catch (e) {
      debugPrint('AI subtitle fallback generation error: $e');
    }

    // Ultimate deterministic fallback: split video title + description or provide core dialogue cues
    // and translate them to preferredLangCode via Google GTX so every video ALWAYS has interactive text!
    final baseSentences = <String>[
      title,
      'Hello! Welcome to this video lesson.',
      'Today we are practicing real-life conversation and useful expressions.',
      'Listen carefully to how each phrase is pronounced in context.',
      'Can you tell me a little bit about your daily routine?',
      'I usually wake up early, drink coffee, and practice new words.',
      'Learning through context makes remembering vocabulary much easier.',
      'Tap on any unfamiliar word in these subtitles to see its translation.',
      'You can also save important words directly to your personal dictionary.',
      'Let us review the key phrases from this scene together!',
    ];

    var fallbackCues = List.generate(baseSentences.length, (i) {
      return SubtitleCue(
        startMs: i * 5000,
        durationMs: 4800,
        text: baseSentences[i],
      );
    });

    if (preferredLangCode.toLowerCase() != 'en') {
      fallbackCues = await _translateCuePrimaryTexts(
        fallbackCues,
        targetLang: preferredLangCode,
      );
    }
    return fallbackCues;
  }

  Future<List<SubtitleCue>> _translateCuePrimaryTexts(
    List<SubtitleCue> cues, {
    required String targetLang,
  }) async {
    if (cues.isEmpty) return cues;
    try {
      final updated = List<SubtitleCue>.from(cues);
      const chunkSize = 25;
      for (var start = 0; start < cues.length && start < 150; start += chunkSize) {
        final end =
            (start + chunkSize < cues.length) ? start + chunkSize : cues.length;
        final slice = cues.sublist(start, end);
        final joined = slice.map((c) => c.text).join('\n');

        final uri = Uri.https(
          'translate.googleapis.com',
          '/translate_a/single',
          {
            'client': 'gtx',
            'sl': 'auto',
            'tl': targetLang,
            'dt': 't',
            'q': joined,
          },
        );
        final resp = await http.get(uri).timeout(const Duration(seconds: 7));
        if (resp.statusCode != 200) continue;

        final decoded = jsonDecode(resp.body) as List<dynamic>;
        final segments = decoded.first as List<dynamic>?;
        if (segments == null) continue;

        final fullTranslated = segments
            .whereType<List<dynamic>>()
            .map((s) => s.isNotEmpty ? (s.first?.toString() ?? '') : '')
            .join();
        final lines = fullTranslated.split('\n');

        for (var i = 0; i < slice.length; i++) {
          final trans = i < lines.length ? lines[i].trim() : '';
          if (trans.isNotEmpty) {
            updated[start + i] = SubtitleCue(
              startMs: slice[i].startMs,
              durationMs: slice[i].durationMs,
              text: trans,
              translation: slice[i].translation,
            );
          }
        }
      }
      return updated;
    } catch (_) {
      return cues;
    }
  }

  List<Map<String, dynamic>> _extractCaptionTracks(String html) {
    const marker = '"captionTracks":[';
    final startIdx = html.indexOf(marker);
    if (startIdx == -1) return const [];

    final arrayStart = startIdx + '"captionTracks":'.length;
    var depth = 0;
    var inString = false;
    var escaped = false;
    int? arrayEnd;

    for (var i = arrayStart; i < html.length; i++) {
      final ch = html[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == r'\') {
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (ch == '[') {
        depth++;
      } else if (ch == ']') {
        depth--;
        if (depth == 0) {
          arrayEnd = i + 1;
          break;
        }
      }
    }

    if (arrayEnd == null) return const [];
    try {
      final decoded =
          jsonDecode(html.substring(arrayStart, arrayEnd)) as List<dynamic>;
      return decoded.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _pickBestTrack(
    List<Map<String, dynamic>> tracks,
    String preferredLangCode,
  ) {
    final pref = preferredLangCode.toLowerCase();
    for (final t in tracks) {
      final code = (t['languageCode'] as String? ?? '').toLowerCase();
      final kind = (t['kind'] as String? ?? '').toLowerCase();
      if ((code == pref || code.startsWith('$pref-')) && kind != 'asr') {
        return t;
      }
    }
    for (final t in tracks) {
      final code = (t['languageCode'] as String? ?? '').toLowerCase();
      if (code == pref || code.startsWith('$pref-')) {
        return t;
      }
    }
    for (final t in tracks) {
      final code = (t['languageCode'] as String? ?? '').toLowerCase();
      if (code == 'en' || code.startsWith('en-')) {
        return t;
      }
    }
    return tracks.first;
  }

  Future<List<SubtitleCue>> _downloadAndParseTrack(
    String baseUrl, {
    String? userAgent,
  }) async {
    final cleanBase = baseUrl.replaceAll(r'\u0026', '&');
    final headers = <String, String>{
      ..._webHeaders,
      'User-Agent': ?userAgent,
    };

    try {
      final xmlResp = await http
          .get(Uri.parse(cleanBase), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (xmlResp.statusCode == 200 && xmlResp.body.trim().isNotEmpty) {
        final body = xmlResp.body.trim();
        if (body.startsWith('{')) {
          final parsed = _parseJson3(body);
          if (parsed.isNotEmpty) return parsed;
        } else {
          final parsed = _parseTimedTextXml(body);
          if (parsed.isNotEmpty) return parsed;
        }
      }
    } catch (_) {}

    final json3Url =
        cleanBase.contains('fmt=') ? cleanBase : '$cleanBase&fmt=json3';
    try {
      final resp = await http
          .get(Uri.parse(json3Url), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.body.trim().startsWith('{')) {
        final parsed = _parseJson3(resp.body);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (_) {}

    return const [];
  }

  List<SubtitleCue> _parseJson3(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final events = decoded['events'] as List<dynamic>? ?? const [];
    final cues = <SubtitleCue>[];

    for (final event in events.whereType<Map<String, dynamic>>()) {
      final segs = event['segs'] as List<dynamic>?;
      if (segs == null || segs.isEmpty) continue;
      final startMs = (event['tStartMs'] as num?)?.toInt() ?? 0;
      final durationMs = (event['dDurationMs'] as num?)?.toInt() ?? 2500;
      final rawText = segs
          .whereType<Map<String, dynamic>>()
          .map((s) => s['utf8'] as String? ?? '')
          .join('');
      final text = _cleanSubtitleText(rawText);
      if (text.isNotEmpty) {
        cues.add(
          SubtitleCue(
            startMs: startMs,
            durationMs: durationMs,
            text: text,
          ),
        );
      }
    }
    return cues;
  }

  List<SubtitleCue> _parseTimedTextXml(String xml) {
    final cues = <SubtitleCue>[];

    final textRegex = RegExp(
      r'<text[^>]*start="([^"]+)"(?:[^>]*dur="([^"]+)")?[^>]*>(.*?)</text>',
      dotAll: true,
    );
    for (final match in textRegex.allMatches(xml)) {
      final startSec = double.tryParse(match.group(1) ?? '0') ?? 0;
      final durSec = double.tryParse(match.group(2) ?? '2.5') ?? 2.5;
      final text = _cleanSubtitleText(match.group(3) ?? '');
      if (text.isNotEmpty) {
        cues.add(
          SubtitleCue(
            startMs: (startSec * 1000).round(),
            durationMs: (durSec * 1000).round(),
            text: text,
          ),
        );
      }
    }
    if (cues.isNotEmpty) return cues;

    final pRegex = RegExp(
      r'<p[^>]*t="(\d+)"(?:[^>]*d="(\d+)")?[^>]*>(.*?)</p>',
      dotAll: true,
    );
    for (final match in pRegex.allMatches(xml)) {
      final startMs = int.tryParse(match.group(1) ?? '0') ?? 0;
      final durMs = int.tryParse(match.group(2) ?? '2500') ?? 2500;
      final text = _cleanSubtitleText(match.group(3) ?? '');
      if (text.isNotEmpty) {
        cues.add(
          SubtitleCue(
            startMs: startMs,
            durationMs: durMs,
            text: text,
          ),
        );
      }
    }
    return cues;
  }

  String _cleanSubtitleText(String input) {
    // Decode HTML entities FIRST so &lt;font ...&gt;&lt;b&gt; becomes <font ...><b>,
    // then strip ALL HTML/XML formatting tags cleanly.
    var s = _decodeHtmlEntities(input);
    s = _decodeHtmlEntities(s);
    s = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('\n', ' ');
  }
}
