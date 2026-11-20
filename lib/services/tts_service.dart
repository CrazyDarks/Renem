import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

class VoiceChoice {
  const VoiceChoice({
    required this.name,
    required this.locale,
    required this.displayLabel,
    required this.isHighQuality,
    required this.genderHint,
  });

  final String name;
  final String locale;
  final String displayLabel;
  final bool isHighQuality;
  final String genderHint; // 'female', 'male', 'neutral'
}

class TtsService {
  static const MethodChannel _audioChannel =
      MethodChannel('com.languagema/external_launcher');

  TtsService() {
    _tts = FlutterTts();
    _init();
  }

  late final FlutterTts _tts;
  double _speechRate = 0.48;
  String _voicePreset = 'neural_natural';
  String _preferredVoiceName = '';
  List<Map<String, String>>? _cachedVoices;

  bool _useCustomAiVoice = false;
  String _customAiVoiceApiKey = '';
  String _customAiVoiceEndpoint = '';
  String _customAiVoiceModel = 'alloy';

  /// Tracks live playback state & active track ID so long listening tracks
  /// show accurate play/stop controls in the UI.
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<String?> activeTrackId = ValueNotifier<String?>(null);
  int _speakSessionId = 0;

  double get speechRate => _speechRate;
  String get voicePreset => _voicePreset;
  String get preferredVoiceName => _preferredVoiceName;
  bool get useCustomAiVoice => _useCustomAiVoice;

  Future<void> _init() async {
    try {
      await _tts.setSpeechRate(_speechRate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.02);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Ignore initialization errors on unsupported environments.
    }
  }

  void configure({
    String? voicePreset,
    String? preferredVoiceName,
    double? speechRate,
    bool? useCustomAiVoice,
    String? customAiVoiceApiKey,
    String? customAiVoiceEndpoint,
    String? customAiVoiceModel,
  }) {
    if (voicePreset != null) _voicePreset = voicePreset;
    if (preferredVoiceName != null) _preferredVoiceName = preferredVoiceName;
    if (speechRate != null) _speechRate = speechRate.clamp(0.25, 0.85);
    if (useCustomAiVoice != null) _useCustomAiVoice = useCustomAiVoice;
    if (customAiVoiceApiKey != null) {
      _customAiVoiceApiKey = customAiVoiceApiKey.trim();
    }
    if (customAiVoiceEndpoint != null) {
      _customAiVoiceEndpoint = customAiVoiceEndpoint.trim();
    }
    if (customAiVoiceModel != null) {
      _customAiVoiceModel = customAiVoiceModel.trim();
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.25, 1.0);
    try {
      await _tts.setSpeechRate(_speechRate);
    } catch (_) {}
  }

  Future<List<Map<String, String>>> _loadAllVoices() async {
    if (_cachedVoices != null && _cachedVoices!.isNotEmpty) {
      return _cachedVoices!;
    }
    try {
      final raw = await _tts.getVoices;
      if (raw is List) {
        final parsed = <Map<String, String>>[];
        for (final item in raw) {
          if (item is Map) {
            final map = <String, String>{};
            item.forEach((k, v) {
              if (k != null && v != null) {
                map[k.toString()] = v.toString();
              }
            });
            if ((map['name'] ?? '').isNotEmpty &&
                (map['locale'] ?? '').isNotEmpty) {
              parsed.add(map);
            }
          }
        }
        _cachedVoices = parsed;
        return parsed;
      }
    } catch (e) {
      debugPrint('TTS getVoices error: $e');
    }
    return const [];
  }

  /// Returns device voices matching [locale], sorted with Neural/HD network voices first.
  Future<List<VoiceChoice>> getVoicesForLocale(String locale) async {
    final all = await _loadAllVoices();
    final langPrefix = locale.split(RegExp(r'[-_]')).first.toLowerCase();
    final fullNorm = locale.replaceAll('_', '-').toLowerCase();

    final matching = all.where((v) {
      final vLoc = (v['locale'] ?? '').replaceAll('_', '-').toLowerCase();
      return vLoc == fullNorm || vLoc.startsWith('$langPrefix-');
    }).toList();

    int scoreVoice(Map<String, String> v) {
      final name = (v['name'] ?? '').toLowerCase();
      final loc = (v['locale'] ?? '').replaceAll('_', '-').toLowerCase();
      final quality = (v['quality'] ?? '').toLowerCase();
      final netReq = (v['network_required'] ?? '').toLowerCase();
      var score = 0;
      if (loc == fullNorm) score += 20;
      if (name.contains('network') || netReq == '1' || netReq == 'true') {
        score += 50;
      }
      if (name.contains('wavenet') ||
          name.contains('neural') ||
          name.contains('studio') ||
          name.contains('journey')) {
        score += 45;
      }
      if (quality.contains('high') || quality == '400' || quality == '500') {
        score += 30;
      }
      if (name.contains('tpf') ||
          name.contains('tpc') ||
          name.contains('tpd') ||
          name.contains('sfg') ||
          name.contains('iol') ||
          name.contains('iom')) {
        score += 15;
      }
      return score;
    }

    matching.sort((a, b) => scoreVoice(b).compareTo(scoreVoice(a)));

    final results = <VoiceChoice>[];
    var hdIndex = 1;
    var stdIndex = 1;
    for (final v in matching.take(15)) {
      final name = v['name'] ?? '';
      final loc = v['locale'] ?? locale;
      final lower = name.toLowerCase();
      final isHd = lower.contains('network') ||
          lower.contains('neural') ||
          lower.contains('wavenet') ||
          (v['quality'] ?? '').toLowerCase().contains('high') ||
          (v['network_required'] ?? '') == '1';
      final gender = _guessGender(lower);
      final genderIcon = gender == 'female'
          ? '👩'
          : gender == 'male'
              ? '👨'
              : '🎙️';
      final tag = isHd ? 'HD Natural #${hdIndex++}' : 'Voice #${stdIndex++}';
      final shortCode = name.split('-').length >= 4
          ? name.split('-')[3].toUpperCase()
          : loc;
      results.add(
        VoiceChoice(
          name: name,
          locale: loc,
          displayLabel: '$genderIcon $tag ($shortCode)',
          isHighQuality: isHd,
          genderHint: gender,
        ),
      );
    }
    return results;
  }

  String _guessGender(String lowerName) {
    const femaleTokens = [
      'female',
      'sfg',
      'tpf',
      'tpc',
      'iob',
      'iod',
      'sfb',
      'fis',
      'esf',
      'def',
      'frf',
      'ukf',
    ];
    const maleTokens = [
      'male',
      'tpd',
      'iom',
      'iog',
      'iol',
      'sfd',
      'esm',
      'dem',
      'frm',
      'ukm',
    ];
    for (final t in femaleTokens) {
      if (lowerName.contains(t)) return 'female';
    }
    for (final t in maleTokens) {
      if (lowerName.contains(t)) return 'male';
    }
    return 'neutral';
  }

  Future<void> _applyNaturalVoiceSettings(String locale) async {
    final voices = await getVoicesForLocale(locale);
    VoiceChoice? selected;

    if (_preferredVoiceName.isNotEmpty) {
      for (final v in voices) {
        if (v.name == _preferredVoiceName) {
          selected = v;
          break;
        }
      }
    }

    if (selected == null && voices.isNotEmpty) {
      if (_voicePreset == 'warm_female') {
        selected = voices.firstWhere(
          (v) => v.genderHint == 'female',
          orElse: () => voices.first,
        );
      } else if (_voicePreset == 'deep_male') {
        selected = voices.firstWhere(
          (v) => v.genderHint == 'male',
          orElse: () => voices.length > 1 ? voices[1] : voices.first,
        );
      } else {
        selected = voices.first;
      }
    }

    if (selected != null) {
      try {
        await _tts.setVoice({
          'name': selected.name,
          'locale': selected.locale,
        });
      } catch (_) {}
    }

    double targetPitch = 1.03;
    double effectiveRate = _speechRate;
    switch (_voicePreset) {
      case 'warm_female':
        targetPitch = 1.08;
        effectiveRate = _speechRate;
      case 'deep_male':
        targetPitch = 0.92;
        effectiveRate = _speechRate * 0.98;
      case 'clear_tutor':
        targetPitch = 1.0;
        effectiveRate = (_speechRate * 0.86).clamp(0.28, 0.7);
      case 'neural_natural':
      default:
        targetPitch = 1.03;
        effectiveRate = _speechRate;
    }

    try {
      await _tts.setPitch(targetPitch);
      await _tts.setSpeechRate(effectiveRate.clamp(0.25, 0.85));
    } catch (_) {}
  }

  /// Splits long audio transcripts into natural sentence/paragraph chunks
  /// (<= [maxChunkChars]) so Android TTS never truncates 2-3 minute exam audios
  /// and pauses naturally between dialogue turns.
  static List<String> splitIntoSpeechChunks(
    String rawText, {
    int maxChunkChars = 320,
  }) {
    final cleaned = rawText.trim();
    if (cleaned.isEmpty) return const [];
    if (cleaned.length <= maxChunkChars) return [cleaned];

    final paragraphs = cleaned
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);

    final chunks = <String>[];
    for (final para in paragraphs) {
      if (para.length <= maxChunkChars) {
        chunks.add(para);
        continue;
      }
      final sentences = para
          .split(RegExp(r'(?<=[.!?。！？])\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);

      final buffer = StringBuffer();
      for (final sentence in sentences) {
        if (sentence.length > maxChunkChars) {
          if (buffer.isNotEmpty) {
            chunks.add(buffer.toString().trim());
            buffer.clear();
          }
          // Hard wrap very long run-on sentence on whitespace
          final words = sentence.split(RegExp(r'\s+'));
          final subBuf = StringBuffer();
          for (final w in words) {
            if (subBuf.length + w.length + 1 > maxChunkChars &&
                subBuf.isNotEmpty) {
              chunks.add(subBuf.toString().trim());
              subBuf.clear();
            }
            if (subBuf.isNotEmpty) subBuf.write(' ');
            subBuf.write(w);
          }
          if (subBuf.isNotEmpty) chunks.add(subBuf.toString().trim());
        } else if (buffer.length + sentence.length + 1 > maxChunkChars) {
          if (buffer.isNotEmpty) {
            chunks.add(buffer.toString().trim());
            buffer.clear();
          }
          buffer.write(sentence);
        } else {
          if (buffer.isNotEmpty) buffer.write(' ');
          buffer.write(sentence);
        }
      }
      if (buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
      }
    }

    return chunks;
  }

  /// Calls custom AI TTS API (OpenAI TTS / ElevenLabs / compatible) and plays
  /// the returned audio natively through Android MediaPlayer.
  Future<bool> _speakWithCustomAiVoice(String text) async {
    if (!_useCustomAiVoice || _customAiVoiceApiKey.isEmpty) return false;
    try {
      final endpoint = _customAiVoiceEndpoint.isNotEmpty
          ? _customAiVoiceEndpoint
          : 'https://api.openai.com/v1/audio/speech';
      final voice =
          _customAiVoiceModel.isNotEmpty ? _customAiVoiceModel : 'alloy';

      final isElevenLabs = endpoint.toLowerCase().contains('elevenlabs');
      final headers = isElevenLabs
          ? {
              'Content-Type': 'application/json',
              'Accept': 'audio/mpeg',
              'xi-api-key': _customAiVoiceApiKey,
            }
          : {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_customAiVoiceApiKey',
            };
      final body = isElevenLabs
          ? jsonEncode({
              'text': text,
              'model_id': 'eleven_multilingual_v2',
            })
          : jsonEncode({
              'model': 'tts-1',
              'input': text,
              'voice': voice,
            });

      final resp = await http
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final played = await _audioChannel.invokeMethod<bool>(
          'playEncodedAudio',
          {'bytes': resp.bodyBytes},
        );
        return played == true;
      }
    } catch (e) {
      debugPrint('Custom AI Voice TTS error: $e');
    }
    return false;
  }

  Future<void> speak(
    String text, {
    String locale = 'en-US',
    double? overrideRate,
    String? trackId,
  }) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    final session = ++_speakSessionId;
    await _stopInternalOnly();

    isSpeaking.value = true;
    activeTrackId.value = trackId;

    try {
      if (_useCustomAiVoice) {
        final ok = await _speakWithCustomAiVoice(cleaned);
        if (ok) {
          // Estimate playback duration so UI badge stays active briefly
          final approxSeconds =
              (cleaned.split(RegExp(r'\s+')).length / 2.6).ceil().clamp(2, 180);
          await Future<void>.delayed(Duration(seconds: approxSeconds));
          if (_speakSessionId == session) {
            isSpeaking.value = false;
            activeTrackId.value = null;
          }
          return;
        }
      }

      await _tts.setLanguage(locale);
      await _applyNaturalVoiceSettings(locale);
      if (overrideRate != null) {
        await _tts.setSpeechRate(overrideRate.clamp(0.22, 0.9));
      }

      final chunks = splitIntoSpeechChunks(cleaned);
      for (var i = 0; i < chunks.length; i++) {
        if (_speakSessionId != session) break;
        await _tts.speak(chunks[i]);
        if (_speakSessionId != session) break;
        if (i < chunks.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 220));
        }
      }
    } catch (_) {
    } finally {
      if (_speakSessionId == session) {
        isSpeaking.value = false;
        activeTrackId.value = null;
      }
    }
  }

  Future<void> _stopInternalOnly() async {
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _audioChannel.invokeMethod<bool>('stopEncodedAudio');
    } catch (_) {}
  }

  Future<void> stop() async {
    _speakSessionId++;
    isSpeaking.value = false;
    activeTrackId.value = null;
    await _stopInternalOnly();
  }
}
