import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Standardized result returned by [AiRouterClient.generateTextSmart].
typedef AiSmartResponse = ({
  String text,
  String provider,
  String? finishReason,
  String? errorSummary,
  String? userKeyErrorSummary,
});

/// Core Multi-AI provider router with Dynamic Model Discovery, Smart Caching,
/// automatic HTTP 429/404/402 eviction, and free built-in fallback.
class AiRouterClient {
  AiRouterClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const List<String> geminiFallbackModels = [
    'gemini-3.8-flash',
    'gemini-4-hydrogen',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
  ];

  static const List<String> groqPriorityModels = [
    'openai/gpt-oss-120b',
    'qwen/qwen3.8-27b',
    'openai/gpt-oss-20b',
  ];

  /// Lightweight, ultra-fast models prioritized first for NVIDIA NIM
  /// to avoid stalling on heavyweight 120B+ models.
  static const List<String> nvidiaPriorityModels = [
    'minimaxai/minimax-m3.1-flash',
    'mistralai/mistral-large-4',
    'moonshotai/kimi-k3.1-pro',
    'nvidia/nemotron-3.5-super-vl-120b-a12b',
  ];

  static const List<String> openRouterFreeModels = [
    'openrouter/free',
    'google/gemma-4-31b-it:free',
    'google/gemma-4-26b-a4b-it:free',
  ];

  static const List<String> openAiHeavyPriorityModels = [
    'gpt-4.1',
    'gpt-4o',
    'gpt-4.1-mini',
    'gpt-4o-mini',
  ];

  static const List<String> openAiFastPriorityModels = [
    'gpt-4.1-mini',
    'gpt-4o-mini',
    'gpt-4.1-nano',
    'gpt-4o',
  ];

  /// In-memory cache: `provider:tier:keyFingerprint` -> last working model.
  final Map<String, String> _workingModelCache = {};

  /// Cached discovered model IDs per `provider:keyFingerprint`.
  final Map<String, List<String>> _discoveredModelsCache = {};

  /// Models that returned HTTP 429 (0/0 or exhausted), 404, 410, or 402 for a key.
  final Map<String, Set<String>> _exhaustedModels = {};

  /// OpenRouter key fingerprints detected as free-tier (via /auth/key or HTTP 402).
  final Set<String> _openRouterFreeOnlyKeys = {};
  final Set<String> _openRouterAuthChecked = {};

  /// Vertex AI (`AQ...`) key fingerprints where Vertex AI returned 401/403
  /// (disabled / unauthorized) during the current session.
  final Set<String> _vertexDisabledKeys = {};

  Map<String, String> get workingModelCache =>
      Map.unmodifiable(_workingModelCache);

  void recordModelSuccess(String cacheKey, String model, {String? exhaustedKey}) {
    _workingModelCache[cacheKey] = model;
    if (exhaustedKey != null) {
      _exhaustedModels[exhaustedKey]?.remove(model);
    }
  }

  void handleFailedModelStatus({
    required String cacheKey,
    required String exhaustedKey,
    required String model,
    required int? statusCode,
  }) {
    if (statusCode == 429 ||
        statusCode == 404 ||
        statusCode == 410 ||
        statusCode == 402) {
      if (_workingModelCache[cacheKey] == model) {
        _workingModelCache.remove(cacheKey);
      }
      _exhaustedModels.putIfAbsent(exhaustedKey, () => <String>{}).add(model);
      debugPrint(
        '[Reman AI] Cache evicted / skipped "$model" after HTTP $statusCode',
      );
    } else if (statusCode == 401 || statusCode == 403) {
      if (_workingModelCache[cacheKey] == model) {
        _workingModelCache.remove(cacheKey);
      }
    }
  }

  /// Detects provider name from any pasted key or returns built-in free AI.
  static String detectProviderName(String rawKeys) {
    final trimmed = rawKeys.trim();
    if (trimmed.isEmpty) {
      return 'Авто (Безкоштовний вбудований ШІ)';
    }
    final keys = trimmed
        .split(RegExp(r'[\n,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (keys.isEmpty) {
      return 'Авто (Безкоштовний вбудований ШІ)';
    }
    final firstKey = keys.first;
    if (firstKey.startsWith('nvapi-')) return 'NVIDIA NIM AI (Auto)';
    if (firstKey.startsWith('AIza')) return 'Google Gemini AI (Auto)';
    if (firstKey.startsWith('AQ.')) return 'Google Vertex AI (Gemini)';
    if (firstKey.startsWith('AQ')) return 'Google Vertex AI (Gemini)';
    if (firstKey.startsWith('gsk_')) return 'Groq Cloud AI (Auto)';
    if (firstKey.startsWith('sk-or-')) return 'OpenRouter AI (Auto)';
    if (firstKey.startsWith('sk-')) return 'OpenAI / DeepSeek API';
    return 'Мульти-ШІ Роутер + Безкоштовний ШІ';
  }

  /// Returns the human-readable provider and active cached model for the given key.
  String describeActiveProvider(String rawKeys) {
    final base = detectProviderName(rawKeys);
    final keys = parseKeys(rawKeys);
    if (keys.isEmpty) return base;
    final firstKey = keys.first;
    String? providerId;
    if (firstKey.startsWith('AIza')) {
      providerId = 'gemini';
    } else if (firstKey.startsWith('AQ')) {
      providerId = 'vertex';
    } else if (firstKey.startsWith('gsk_')) {
      providerId = 'groq';
    } else if (firstKey.startsWith('nvapi-')) {
      providerId = 'nvidia';
    } else if (firstKey.startsWith('sk-or-')) {
      providerId = 'openrouter';
    } else if (firstKey.startsWith('sk-')) {
      providerId = 'openai';
    }
    if (providerId == null) return base;
    final fp = keyFingerprint(firstKey);
    final activeModel = _workingModelCache['$providerId:heavy:$fp'] ??
        _workingModelCache['$providerId:fast:$fp'];
    if (activeModel != null && activeModel.isNotEmpty) {
      final cleanBase =
          base.replaceAll(' (Auto)', '').replaceAll(' (Gemini)', '');
      return '$cleanBase ($activeModel)';
    }
    return base;
  }

  /// Prioritizes fast keys (Groq `gsk_...`, Gemini `AIza...`) ahead of slower
  /// providers (such as NVIDIA `nvapi-...`) so fast responses return within 1-2s.
  static List<String> prioritizeKeys(List<String> keys) {
    int keyScore(String k) {
      final trimmed = k.trim();
      if (trimmed.startsWith('gsk_')) return 40; // Groq: fastest inference (~0.3-1s)
      if (trimmed.startsWith('AIza')) return 30; // Google Gemini: very fast (~1-2s)
      if (trimmed.startsWith('AQ')) return 25; // Vertex
      if (trimmed.startsWith('sk-or-')) return 20; // OpenRouter
      if (trimmed.startsWith('sk-')) return 15; // OpenAI / DeepSeek
      if (trimmed.startsWith('nvapi-')) return 10; // NVIDIA NIM
      return 5;
    }

    final sorted = List<String>.from(keys);
    sorted.sort((a, b) => keyScore(b).compareTo(keyScore(a)));
    return sorted;
  }

  List<String> parseKeys(String raw) {
    final parsed = raw
        .split(RegExp(r'[\n,;\s]+'))
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    return prioritizeKeys(parsed);
  }

  Future<({bool ok, String providerUsed, String? errorDetail})> testAiConnection(
    String rawApiKey,
  ) async {
    try {
      final result = await generateTextSmart(
        prompt: 'Respond with the single word OK.',
        rawKeys: rawApiKey,
        timeout: const Duration(seconds: 10),
      );
      if (rawApiKey.trim().isNotEmpty &&
          result.userKeyErrorSummary != null &&
          result.provider.contains('Безкоштовний')) {
        return (
          ok: false,
          providerUsed: 'Недоступно',
          errorDetail: result.userKeyErrorSummary!,
        );
      }
      if (result.text.trim().isNotEmpty) {
        return (ok: true, providerUsed: result.provider, errorDetail: null);
      }
      return (
        ok: false,
        providerUsed: 'Недоступно',
        errorDetail: result.userKeyErrorSummary ??
            result.errorSummary ??
            'Empty response from all providers',
      );
    } catch (e) {
      debugPrint('[Reman AI] testAiConnection error: $e');
      return (
        ok: false,
        providerUsed: 'Недоступно',
        errorDetail: shortError(e),
      );
    }
  }

  String shortError(Object error) {
    final raw = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (raw.length <= 160) return raw;
    return '${raw.substring(0, 157)}...';
  }

  String preview300(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 300) return cleaned;
    return '${cleaned.substring(0, 297)}...';
  }

  String extractApiErrorDetail(String body) {
    final preview = preview300(body);
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final err = decoded['error'];
        if (err is Map<String, dynamic> && err['message'] is String) {
          final msg = (err['message'] as String)
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (msg.isNotEmpty) {
            return msg.length > 180 ? '${msg.substring(0, 177)}...' : msg;
          }
        } else if (decoded['message'] is String) {
          final msg = (decoded['message'] as String)
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (msg.isNotEmpty) {
            return msg.length > 180 ? '${msg.substring(0, 177)}...' : msg;
          }
        }
      }
    } catch (_) {}
    return preview.length > 180 ? '${preview.substring(0, 177)}...' : preview;
  }

  String keyFingerprint(String apiKey) {
    final trimmed = apiKey.trim();
    if (trimmed.length <= 12) return trimmed;
    return '${trimmed.substring(0, 6)}_${trimmed.substring(trimmed.length - 6)}';
  }

  String cacheKey(String provider, String apiKey, {required bool fastTask}) {
    final tier = fastTask ? 'fast' : 'heavy';
    return '$provider:$tier:${keyFingerprint(apiKey)}';
  }

  String exhaustedKey(String provider, String apiKey) {
    return '$provider:${keyFingerprint(apiKey)}';
  }

  List<String> buildOrderedCandidates(
    String cacheKey,
    String exhaustedKey,
    List<String> discovered, {
    bool clearIfAllExhausted = false,
  }) {
    final exhausted = _exhaustedModels[exhaustedKey] ?? const <String>{};
    final result = <String>[];
    final seen = <String>{};

    void addIfEligible(String model) {
      if (model.isEmpty || seen.contains(model) || exhausted.contains(model)) {
        return;
      }
      seen.add(model);
      result.add(model);
    }

    final cached = _workingModelCache[cacheKey];
    if (cached != null) {
      addIfEligible(cached);
    }
    for (final m in discovered) {
      addIfEligible(m);
    }

    if (result.isEmpty && clearIfAllExhausted && discovered.isNotEmpty) {
      _exhaustedModels.remove(exhaustedKey);
      for (final m in discovered) {
        if (m.isNotEmpty && seen.add(m)) {
          result.add(m);
        }
      }
    }
    return result;
  }

  static List<String> filterGeminiModelEntries(List<dynamic> rawModels) {
    final result = <String>[];
    final seen = <String>{};

    for (final entry in rawModels.whereType<Map<String, dynamic>>()) {
      final methods = (entry['supportedGenerationMethods'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      if (!methods.contains('generateContent')) continue;

      final rawName = (entry['name'] as String? ?? '').trim();
      final id = rawName.startsWith('models/')
          ? rawName.substring('models/'.length)
          : rawName;
      if (id.isEmpty) continue;

      final lower = id.toLowerCase();
      if (lower.contains('embedding') ||
          lower.contains('tts') ||
          lower.contains('image') ||
          lower.contains('imagen') ||
          lower.contains('live') ||
          lower.contains('computer-use') ||
          lower.contains('robotics') ||
          lower.contains('veo') ||
          lower.contains('aqa') ||
          lower.contains('audio')) {
        continue;
      }

      if (seen.add(id)) {
        result.add(id);
      }
    }
    return result;
  }

  static int _extractGeminiVersionScore(String lower) {
    final match = RegExp(r'(?:gemini|gemma)-(\d+)(?:\.(\d+))?').firstMatch(lower);
    if (match == null) return 10;
    final major = int.tryParse(match.group(1) ?? '') ?? 1;
    final minor = int.tryParse(match.group(2) ?? '') ?? 0;
    return major * 10 + minor;
  }

  static List<String> sortGeminiModels(
    List<String> modelIds, {
    required bool fastTask,
  }) {
    final unique = <String>[];
    final seen = <String>{};
    for (final id in modelIds) {
      final cleaned = id.trim();
      if (cleaned.isNotEmpty && seen.add(cleaned)) {
        unique.add(cleaned);
      }
    }

    int score(String id) {
      final l = id.toLowerCase();
      final ver = _extractGeminiVersionScore(l);
      final previewPenalty =
          (l.contains('exp') || l.contains('preview')) ? -1 : 0;

      final isLite = l.contains('lite');
      final isFlagship = !isLite &&
          (l.contains('neon') || l.contains('pro') || l.contains('argon'));

      int liteSubScore() {
        if (l.contains('3.5-flash-lite')) return 490;
        if (l.contains('3.1-flash-lite')) return 480;
        if (ver >= 36) return 500 + ver * 5;
        return ver * 10;
      }

      int balancedSubScore() {
        if (l.contains('3.8-flash')) return 490;
        if (l.contains('4-hydrogen')) return 480;
        if (l.contains('3.6-flash')) return 470;
        if (l.contains('3-flash') || l.contains('3.0-flash')) return 460;
        if (ver >= 40 && (l.contains('flash') || l.contains('hydrogen'))) {
          return 500 + ver * 5;
        }
        return ver * 10 +
            (l.contains('flash') || l.contains('hydrogen') ? 20 : 0);
      }

      int flagshipSubScore() {
        final familyBonus = l.contains('neon')
            ? 50
            : l.contains('pro')
                ? 30
                : 20;
        return ver * 10 + familyBonus;
      }

      if (fastTask) {
        if (isLite) return 3000 + liteSubScore() + previewPenalty;
        if (!isFlagship) return 2000 + balancedSubScore() + previewPenalty;
        return 1000 + flagshipSubScore() + previewPenalty;
      } else {
        if (isFlagship) return 3000 + flagshipSubScore() + previewPenalty;
        if (!isLite) return 2000 + balancedSubScore() + previewPenalty;
        return 1000 + liteSubScore() + previewPenalty;
      }
    }

    unique.sort((a, b) => score(b).compareTo(score(a)));
    return unique;
  }

  Future<List<String>> discoverGeminiModels(
    String apiKey, {
    bool fastTask = false,
  }) async {
    final discKey = 'gemini:${keyFingerprint(apiKey)}';
    final cached = _discoveredModelsCache[discKey];
    if (cached != null && cached.isNotEmpty) {
      return sortGeminiModels(cached, fastTask: fastTask);
    }

    try {
      final encodedKey = Uri.encodeQueryComponent(apiKey);
      final resp = await _httpClient
          .get(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models?key=$encodedKey',
            ),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawModels = decoded['models'] as List<dynamic>? ?? const [];
        final filtered = filterGeminiModelEntries(rawModels);
        if (filtered.isNotEmpty) {
          _discoveredModelsCache[discKey] = filtered;
          final sorted = sortGeminiModels(filtered, fastTask: fastTask);
          debugPrint(
            '[Reman AI] Gemini models discovered (${sorted.length}, fast=$fastTask): ${sorted.take(6).toList()}',
          );
          return sorted;
        }
      } else {
        debugPrint(
          '[Reman AI] Gemini /v1beta/models HTTP ${resp.statusCode}: ${preview300(resp.body)}',
        );
      }
    } catch (e) {
      debugPrint('[Reman AI] Gemini /v1beta/models lookup error: $e');
    }

    return sortGeminiModels(geminiFallbackModels, fastTask: fastTask);
  }

  static bool isSupportedOpenAiChatModel(String id) {
    final lower = id.trim().toLowerCase();
    if (lower.isEmpty) return false;
    const blockedFragments = [
      'whisper',
      'embed',
      'rerank',
      'guard',
      'flux',
      'parse',
      'tts',
      'safety',
      'reward',
      'ocr',
      'kosmos',
      'neva',
      'deplot',
      'vila',
      'paligemma',
      'parakeet',
      'riva',
      'dall-e',
      'moderation',
      'transcribe',
      'realtime',
      'audio',
      'sora',
      'imagen',
      'sdxl',
      'stable-diffusion',
      'diffusion',
      'bge-',
      'e5-',
      'speech',
      'lyria',
      'music',
    ];
    for (final frag in blockedFragments) {
      if (lower.contains(frag)) return false;
    }
    return true;
  }

  static List<String> prioritizeOpenAiModels(
    List<String> discovered, {
    required List<String> priorityModels,
    bool onlyFree = false,
  }) {
    final result = <String>[];
    final seenLower = <String>{};

    void addUnique(String id) {
      final cleaned = id.trim();
      if (cleaned.isEmpty) return;
      final lower = cleaned.toLowerCase();
      if (seenLower.add(lower)) {
        result.add(cleaned);
      }
    }

    if (onlyFree) {
      for (final p in priorityModels) {
        addUnique(p);
      }
      for (final d in discovered) {
        final l = d.toLowerCase();
        if (l == 'openrouter/free' || l.endsWith(':free')) {
          addUnique(d);
        }
      }
      return result;
    }

    if (discovered.isEmpty) {
      for (final p in priorityModels) {
        addUnique(p);
      }
      return result;
    }

    final discoveredByLower = <String, String>{
      for (final d in discovered) d.toLowerCase(): d,
    };

    for (final p in priorityModels) {
      final matched = discoveredByLower[p.toLowerCase()];
      if (matched != null) {
        addUnique(matched);
      }
    }

    final rest = discovered
        .where((d) => !seenLower.contains(d.toLowerCase()))
        .toList();

    int scoreRest(String id) {
      final l = id.toLowerCase();
      var s = 0;
      if (l.contains('instruct') || l.contains('chat')) s += 30;
      if (l.contains('large') || l.contains('pro') || l.contains('super')) {
        s += 25;
      }
      if (l.contains('120b') || l.contains('405b') || l.contains('340b')) {
        s += 22;
      } else if (l.contains('70b') || l.contains('72b')) {
        s += 18;
      } else if (l.contains('27b') || l.contains('31b') || l.contains('32b')) {
        s += 14;
      } else if (l.contains('20b') || l.contains('26b')) {
        s += 12;
      }
      if (l.contains('gpt-oss') ||
          l.contains('qwen3') ||
          l.contains('mistral-large') ||
          l.contains('kimi') ||
          l.contains('nemotron') ||
          l.contains('minimax') ||
          l.contains('llama-3.3') ||
          l.contains('deepseek') ||
          l.contains('gemma-4')) {
        s += 20;
      }
      if (l.contains('flash') || l.contains('mini')) s += 10;
      return s;
    }

    rest.sort((a, b) => scoreRest(b).compareTo(scoreRest(a)));
    for (final m in rest) {
      addUnique(m);
    }

    for (final p in priorityModels) {
      addUnique(p);
    }

    return result;
  }

  Future<List<String>> _discoverOpenAiModels(
    String baseUrl,
    String apiKey, {
    List<String> priorityModels = const [],
    bool onlyFree = false,
  }) async {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final discKey = 'oai:$cleanBase:${keyFingerprint(apiKey)}';
    var discovered = _discoveredModelsCache[discKey];

    if (discovered == null) {
      try {
        final resp = await _httpClient
            .get(
              Uri.parse('$cleanBase/models'),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
            )
            .timeout(const Duration(seconds: 8));

        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
          final data = decoded['data'] as List<dynamic>? ?? const [];
          final filtered = data
              .whereType<Map<String, dynamic>>()
              .map((m) => (m['id'] as String? ?? '').trim())
              .where(isSupportedOpenAiChatModel)
              .toList();
          if (filtered.isNotEmpty) {
            discovered = filtered;
            _discoveredModelsCache[discKey] = filtered;
            debugPrint(
              '[Reman AI] Discovered ${filtered.length} models at $cleanBase',
            );
          }
        } else {
          debugPrint(
            '[Reman AI] $cleanBase/models HTTP ${resp.statusCode}: ${preview300(resp.body)}',
          );
        }
      } catch (e) {
        debugPrint('[Reman AI] $cleanBase/models lookup error: $e');
      }
    }

    return prioritizeOpenAiModels(
      discovered ?? const <String>[],
      priorityModels: priorityModels,
      onlyFree: onlyFree,
    );
  }

  Future<bool> _isOpenRouterFreeAccount(String apiKey) async {
    final fp = keyFingerprint(apiKey);
    if (_openRouterFreeOnlyKeys.contains(fp)) return true;
    if (_openRouterAuthChecked.contains(fp)) return false;

    _openRouterAuthChecked.add(fp);
    try {
      final resp = await _httpClient
          .get(
            Uri.parse('https://openrouter.ai/api/v1/auth/key'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
          )
          .timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = decoded['data'] as Map<String, dynamic>?;
        if (data != null) {
          final isFreeTier = data['is_free_tier'] == true;
          final limitRemaining = data['limit_remaining'];
          final noRemainingCredits =
              limitRemaining is num && limitRemaining <= 0;
          if (isFreeTier || noRemainingCredits) {
            _openRouterFreeOnlyKeys.add(fp);
            debugPrint(
              '[Reman AI] OpenRouter account detected as free/zero-credit -> using free models',
            );
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  /// Automatically cascades through configured keys (Groq, Google Gemini,
  /// NVIDIA NIM, OpenRouter, OpenAI, DeepSeek) using Dynamic Model Discovery,
  /// Smart Caching, tight 10-12s timeouts per attempt, and falls back to
  /// the free built-in Pollinations AI.
  Future<AiSmartResponse> generateTextSmart({
    required String prompt,
    required String rawKeys,
    Duration timeout = const Duration(seconds: 12),
    bool expectJson = false,
    int maxTokens = 4096,
    bool fastTask = false,
  }) async {
    final keys = parseKeys(rawKeys);
    final errors = <String>[];
    final userKeyErrors = <String>[];

    void recordFailure(String label, String? err, {bool isUserKey = false}) {
      if (err != null && err.trim().isNotEmpty) {
        final msg = '$label: ${err.trim()}';
        if (!errors.contains(msg)) errors.add(msg);
        if (isUserKey && !userKeyErrors.contains(msg)) {
          userKeyErrors.add(msg);
        }
        debugPrint('[Reman AI] $msg');
      }
    }

    String? userKeySummary() =>
        userKeyErrors.isEmpty ? null : userKeyErrors.take(2).join(' | ');

    final safeExamMaxTokens =
        expectJson && maxTokens < 8192 ? 8192 : maxTokens;

    for (final key in keys) {
      if (key.startsWith('nvapi-')) {
        final cKey = cacheKey('nvidia', key, fastTask: fastTask);
        final eKey = exhaustedKey('nvidia', key);
        final discovered = await _discoverOpenAiModels(
          'https://integrate.api.nvidia.com/v1',
          key,
          priorityModels: nvidiaPriorityModels,
        );
        // Limit to 2 candidate models per NVIDIA attempt (fastest models first)
        // to prevent waiting through multiple slow 120B+ timeouts.
        final candidates =
            buildOrderedCandidates(cKey, eKey, discovered).take(2).toList();

        for (var i = 0; i < candidates.length; i++) {
          final nvModel = candidates[i];
          final res = await _callOpenAiCompatible(
            endpoint: 'https://integrate.api.nvidia.com/v1/chat/completions',
            apiKey: key,
            model: nvModel,
            prompt: prompt,
            timeout: timeout,
            maxTokens: safeExamMaxTokens.clamp(1024, 16384),
            responseFormatJson: expectJson,
            providerTag: 'NVIDIA NIM',
            retryOn429: false,
          );
          if (res.text != null && res.text!.isNotEmpty) {
            recordModelSuccess(cKey, nvModel, exhaustedKey: eKey);
            return (
              text: res.text!,
              provider: 'NVIDIA NIM ($nvModel)',
              finishReason: res.finishReason,
              errorSummary: null,
              userKeyErrorSummary: userKeySummary(),
            );
          }
          handleFailedModelStatus(
            cacheKey: cKey,
            exhaustedKey: eKey,
            model: nvModel,
            statusCode: res.statusCode,
          );
          recordFailure('NVIDIA ($nvModel)', res.error, isUserKey: true);
          if (res.statusCode == 401 || res.statusCode == 403) break;
        }
      } else if (key.startsWith('AQ')) {
        final cKey = cacheKey('vertex', key, fastTask: fastTask);
        final eKey = exhaustedKey('vertex', key);
        final fp = keyFingerprint(key);
        final discovered = await discoverGeminiModels(key, fastTask: fastTask);
        final candidates = buildOrderedCandidates(cKey, eKey, discovered);
        final safeGeminiMax = safeExamMaxTokens.clamp(1024, 16384);
        final encodedKey = Uri.encodeQueryComponent(key);
        var geminiRestAuthFailed = false;

        // Pass 1: Exhaust ALL available Gemini REST API models first.
        // Never fall back to Vertex AI on HTTP 429 while other Gemini REST
        // models remain untried.
        for (final modelName in candidates) {
          final label = 'Google Gemini REST ($modelName)';
          final url =
              'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$encodedKey';

          final res = await _callGoogleGeminiRest(
            endpointUrl: url,
            providerTag: label,
            model: modelName,
            prompt: prompt,
            timeout: timeout,
            maxTokens: safeGeminiMax,
            expectJson: expectJson,
          );
          if (res.text != null && res.text!.isNotEmpty) {
            recordModelSuccess(cKey, modelName, exhaustedKey: eKey);
            return (
              text: res.text!,
              provider: label,
              finishReason: res.finishReason,
              errorSummary: null,
              userKeyErrorSummary: userKeySummary(),
            );
          }
          handleFailedModelStatus(
            cacheKey: cKey,
            exhaustedKey: eKey,
            model: modelName,
            statusCode: res.statusCode,
          );
          recordFailure(label, res.error, isUserKey: true);
          if (res.statusCode == 401 || res.statusCode == 403) {
            geminiRestAuthFailed = true;
            break;
          }
        }

        // Pass 2: Only if Gemini REST rejected the AQ key (pure Vertex key)
        // AND Vertex AI was not previously disabled/unauthorized for this key.
        if (geminiRestAuthFailed && !_vertexDisabledKeys.contains(fp)) {
          final vertexCandidates =
              buildOrderedCandidates(cKey, eKey, discovered);
          for (final modelName in vertexCandidates) {
            final label = 'Google Vertex AI ($modelName)';
            final url =
                'https://aiplatform.googleapis.com/v1/publishers/google/models/$modelName:generateContent?key=$encodedKey';

            final res = await _callGoogleGeminiRest(
              endpointUrl: url,
              providerTag: label,
              model: modelName,
              prompt: prompt,
              timeout: timeout,
              maxTokens: safeGeminiMax,
              expectJson: expectJson,
            );
            if (res.text != null && res.text!.isNotEmpty) {
              recordModelSuccess(cKey, modelName, exhaustedKey: eKey);
              return (
                text: res.text!,
                provider: label,
                finishReason: res.finishReason,
                errorSummary: null,
                userKeyErrorSummary: userKeySummary(),
              );
            }
            handleFailedModelStatus(
              cacheKey: cKey,
              exhaustedKey: eKey,
              model: modelName,
              statusCode: res.statusCode,
            );
            recordFailure(label, res.error, isUserKey: true);
            if (res.statusCode == 401 || res.statusCode == 403) {
              _vertexDisabledKeys.add(fp);
              break;
            }
          }
        }
      } else if (key.startsWith('AIza')) {
        // Standard Google AI Studio key: ONLY iterate all available Gemini REST
        // API models (never Vertex AI). Mark 429 models unavailable for the
        // session and cache the first HTTP 200 model.
        final cKey = cacheKey('gemini', key, fastTask: fastTask);
        final eKey = exhaustedKey('gemini', key);
        final discovered = await discoverGeminiModels(key, fastTask: fastTask);
        final candidates = buildOrderedCandidates(cKey, eKey, discovered);
        final safeGeminiMax = safeExamMaxTokens.clamp(1024, 16384);
        final encodedKey = Uri.encodeQueryComponent(key);

        for (final modelName in candidates) {
          final url =
              'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$encodedKey';

          final res = await _callGoogleGeminiRest(
            endpointUrl: url,
            providerTag: 'Gemini ($modelName)',
            model: modelName,
            prompt: prompt,
            timeout: timeout,
            maxTokens: safeGeminiMax,
            expectJson: expectJson,
          );
          if (res.text != null && res.text!.isNotEmpty) {
            recordModelSuccess(cKey, modelName, exhaustedKey: eKey);
            return (
              text: res.text!,
              provider: 'Gemini ($modelName)',
              finishReason: res.finishReason,
              errorSummary: null,
              userKeyErrorSummary: userKeySummary(),
            );
          }
          handleFailedModelStatus(
            cacheKey: cKey,
            exhaustedKey: eKey,
            model: modelName,
            statusCode: res.statusCode,
          );
          recordFailure('Gemini ($modelName)', res.error, isUserKey: true);
          if (res.statusCode == 401 || res.statusCode == 403) break;
        }
      } else if (key.startsWith('gsk_')) {
        final cKey = cacheKey('groq', key, fastTask: fastTask);
        final eKey = exhaustedKey('groq', key);
        final discovered = await _discoverOpenAiModels(
          'https://api.groq.com/openai/v1',
          key,
          priorityModels: groqPriorityModels,
        );
        final candidates =
            buildOrderedCandidates(cKey, eKey, discovered).take(3).toList();

        for (var i = 0; i < candidates.length; i++) {
          final groqModel = candidates[i];
          final res = await _callOpenAiCompatible(
            endpoint: 'https://api.groq.com/openai/v1/chat/completions',
            apiKey: key,
            model: groqModel,
            prompt: prompt,
            timeout: timeout,
            maxTokens: safeExamMaxTokens.clamp(1024, 16384),
            responseFormatJson: expectJson,
            providerTag: 'Groq',
            retryOn429: false,
          );
          if (res.text != null && res.text!.isNotEmpty) {
            recordModelSuccess(cKey, groqModel, exhaustedKey: eKey);
            return (
              text: res.text!,
              provider: 'Groq ($groqModel)',
              finishReason: res.finishReason,
              errorSummary: null,
              userKeyErrorSummary: userKeySummary(),
            );
          }
          handleFailedModelStatus(
            cacheKey: cKey,
            exhaustedKey: eKey,
            model: groqModel,
            statusCode: res.statusCode,
          );
          recordFailure('Groq ($groqModel)', res.error, isUserKey: true);
          if (res.statusCode == 401 || res.statusCode == 403) break;
        }
      } else if (key.startsWith('sk-or-')) {
        final cKey = cacheKey('openrouter', key, fastTask: fastTask);
        final eKey = exhaustedKey('openrouter', key);
        final fp = keyFingerprint(key);
        var isFreeOnly = await _isOpenRouterFreeAccount(key);

        Future<({String text, String provider, String? finishReason})?>
            tryOpenRouterModels({required bool onlyFree}) async {
          final discovered = await _discoverOpenAiModels(
            'https://openrouter.ai/api/v1',
            key,
            priorityModels: onlyFree
                ? openRouterFreeModels
                : const [
                    'google/gemini-3.8-flash',
                    'openai/gpt-4.1-mini',
                    'openrouter/free',
                    'google/gemma-4-31b-it:free',
                    'google/gemma-4-26b-a4b-it:free',
                  ],
            onlyFree: onlyFree,
          );
          final candidates =
              buildOrderedCandidates(cKey, eKey, discovered).take(3).toList();

          for (var i = 0; i < candidates.length; i++) {
            final orModel = candidates[i];
            final res = await _callOpenAiCompatible(
              endpoint: 'https://openrouter.ai/api/v1/chat/completions',
              apiKey: key,
              model: orModel,
              prompt: prompt,
              timeout: timeout,
              maxTokens: safeExamMaxTokens.clamp(1024, 16384),
              responseFormatJson: expectJson,
              providerTag: 'OpenRouter',
              retryOn429: false,
            );
            if (res.text != null && res.text!.isNotEmpty) {
              recordModelSuccess(cKey, orModel, exhaustedKey: eKey);
              return (
                text: res.text!,
                provider: 'OpenRouter ($orModel)',
                finishReason: res.finishReason,
              );
            }
            handleFailedModelStatus(
              cacheKey: cKey,
              exhaustedKey: eKey,
              model: orModel,
              statusCode: res.statusCode,
            );
            recordFailure('OpenRouter ($orModel)', res.error, isUserKey: true);
            if (res.statusCode == 402 && !onlyFree) {
              _openRouterFreeOnlyKeys.add(fp);
              isFreeOnly = true;
              debugPrint(
                '[Reman AI] OpenRouter HTTP 402 (no credits) -> switching to free models',
              );
              return null;
            }
            if (res.statusCode == 401 || res.statusCode == 403) break;
          }
          return null;
        }

        final firstPass = await tryOpenRouterModels(onlyFree: isFreeOnly);
        if (firstPass != null) {
          return (
            text: firstPass.text,
            provider: firstPass.provider,
            finishReason: firstPass.finishReason,
            errorSummary: null,
            userKeyErrorSummary: userKeySummary(),
          );
        }

        if (isFreeOnly && _openRouterFreeOnlyKeys.contains(fp)) {
          final freePass = await tryOpenRouterModels(onlyFree: true);
          if (freePass != null) {
            return (
              text: freePass.text,
              provider: freePass.provider,
              finishReason: freePass.finishReason,
              errorSummary: null,
              userKeyErrorSummary: userKeySummary(),
            );
          }
        }
      } else if (key.startsWith('sk-')) {
        final cKey = cacheKey('openai', key, fastTask: fastTask);
        final eKey = exhaustedKey('openai', key);
        final discovered = await _discoverOpenAiModels(
          'https://api.openai.com/v1',
          key,
          priorityModels:
              fastTask ? openAiFastPriorityModels : openAiHeavyPriorityModels,
        );
        final candidates =
            buildOrderedCandidates(cKey, eKey, discovered).take(4).toList();

        for (var i = 0; i < candidates.length; i++) {
          final oaModel = candidates[i];
          final openAiRes = await _callOpenAiCompatible(
            endpoint: 'https://api.openai.com/v1/chat/completions',
            apiKey: key,
            model: oaModel,
            prompt: prompt,
            timeout: timeout,
            maxTokens: safeExamMaxTokens.clamp(1024, 16384),
            responseFormatJson: expectJson,
            providerTag: 'OpenAI',
            retryOn429: i == candidates.length - 1,
          );
          if (openAiRes.text != null && openAiRes.text!.isNotEmpty) {
            recordModelSuccess(cKey, oaModel, exhaustedKey: eKey);
            return (
              text: openAiRes.text!,
              provider: 'OpenAI ($oaModel)',
              finishReason: openAiRes.finishReason,
              errorSummary: null,
              userKeyErrorSummary: userKeySummary(),
            );
          }
          handleFailedModelStatus(
            cacheKey: cKey,
            exhaustedKey: eKey,
            model: oaModel,
            statusCode: openAiRes.statusCode,
          );
          recordFailure('OpenAI ($oaModel)', openAiRes.error, isUserKey: true);
          if (openAiRes.statusCode == 401 || openAiRes.statusCode == 403) break;
        }

        final dsCKey = cacheKey('deepseek', key, fastTask: fastTask);
        final dsEKey = exhaustedKey('deepseek', key);
        final dsDiscovered = await _discoverOpenAiModels(
          'https://api.deepseek.com',
          key,
          priorityModels: const ['deepseek-chat', 'deepseek-reasoner'],
        );
        final dsCandidates =
            buildOrderedCandidates(dsCKey, dsEKey, dsDiscovered).take(2).toList();
        for (final dsModel in dsCandidates) {
          final deepSeekRes = await _callOpenAiCompatible(
            endpoint: 'https://api.deepseek.com/chat/completions',
            apiKey: key,
            model: dsModel,
            prompt: prompt,
            timeout: timeout,
            maxTokens: safeExamMaxTokens.clamp(1024, 8192),
            responseFormatJson: expectJson,
            providerTag: 'DeepSeek',
          );
          if (deepSeekRes.text != null && deepSeekRes.text!.isNotEmpty) {
            recordModelSuccess(dsCKey, dsModel, exhaustedKey: dsEKey);
            return (
              text: deepSeekRes.text!,
              provider: 'DeepSeek ($dsModel)',
              finishReason: deepSeekRes.finishReason,
              errorSummary: null,
              userKeyErrorSummary: userKeySummary(),
            );
          }
          handleFailedModelStatus(
            cacheKey: dsCKey,
            exhaustedKey: dsEKey,
            model: dsModel,
            statusCode: deepSeekRes.statusCode,
          );
          recordFailure('DeepSeek ($dsModel)', deepSeekRes.error,
              isUserKey: true);
          if (deepSeekRes.statusCode == 401 || deepSeekRes.statusCode == 403) {
            break;
          }
        }
      } else {
        final nvModels = await _discoverOpenAiModels(
          'https://integrate.api.nvidia.com/v1',
          key,
          priorityModels: nvidiaPriorityModels,
        );
        final nvRes = await _callOpenAiCompatible(
          endpoint: 'https://integrate.api.nvidia.com/v1/chat/completions',
          apiKey: key,
          model: nvModels.first,
          prompt: prompt,
          timeout: timeout,
          maxTokens: safeExamMaxTokens.clamp(1024, 16384),
          responseFormatJson: expectJson,
          providerTag: 'NVIDIA NIM',
        );
        if (nvRes.text != null && nvRes.text!.isNotEmpty) {
          return (
            text: nvRes.text!,
            provider: 'NVIDIA NIM (${nvModels.first})',
            finishReason: nvRes.finishReason,
            errorSummary: null,
            userKeyErrorSummary: userKeySummary(),
          );
        }
        recordFailure('NVIDIA NIM', nvRes.error, isUserKey: true);

        final orRes = await _callOpenAiCompatible(
          endpoint: 'https://openrouter.ai/api/v1/chat/completions',
          apiKey: key,
          model: openRouterFreeModels.first,
          prompt: prompt,
          timeout: timeout,
          maxTokens: safeExamMaxTokens.clamp(1024, 16384),
          responseFormatJson: expectJson,
          providerTag: 'OpenRouter',
        );
        if (orRes.text != null && orRes.text!.isNotEmpty) {
          return (
            text: orRes.text!,
            provider: 'OpenRouter AI',
            finishReason: orRes.finishReason,
            errorSummary: null,
            userKeyErrorSummary: userKeySummary(),
          );
        }
        recordFailure('OpenRouter', orRes.error, isUserKey: true);
      }
    }

    // Built-in 100% Free Keyless AI fallback
    final freeRes = await _callFreePollinationsAi(
      prompt,
      timeout: timeout,
      expectJson: expectJson,
      maxTokens: safeExamMaxTokens.clamp(1024, 16384),
    );
    if (freeRes.text != null && freeRes.text!.isNotEmpty) {
      return (
        text: freeRes.text!,
        provider: 'Безкоштовний ШІ (Auto)',
        finishReason: freeRes.finishReason,
        errorSummary: null,
        userKeyErrorSummary: userKeySummary(),
      );
    }
    recordFailure('Free AI (Pollinations)', freeRes.error);

    final summary = userKeyErrors.isNotEmpty
        ? userKeyErrors.take(2).join(' | ')
        : (errors.isEmpty
            ? 'No AI provider responded'
            : errors.take(3).join(' | '));
    return (
      text: '',
      provider: 'Offline',
      finishReason: null,
      errorSummary: summary,
      userKeyErrorSummary: userKeySummary(),
    );
  }

  Future<({String? text, String? finishReason, int? statusCode, String? error})>
      _callGoogleGeminiRest({
    required String endpointUrl,
    required String providerTag,
    required String model,
    required String prompt,
    Duration timeout = const Duration(seconds: 12),
    int maxTokens = 8192,
    bool expectJson = false,
  }) async {
    Future<({String? text, String? finishReason, int? statusCode, String? error})>
        sendOnce({
      required int tokens,
      required bool useJsonFormat,
    }) async {
      try {
        final payload = <String, dynamic>{
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': <String, dynamic>{
            'temperature': 0.35,
            'maxOutputTokens': tokens,
            if (useJsonFormat) 'responseMimeType': 'application/json',
          },
        };

        final resp = await _httpClient
            .post(
              Uri.parse(endpointUrl),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(payload),
            )
            .timeout(timeout);

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final first = candidates.first as Map<String, dynamic>;
            final content = first['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            final textBuffer = StringBuffer();
            if (parts != null) {
              for (final p in parts.whereType<Map<String, dynamic>>()) {
                if (p['thought'] == true) continue;
                final partText = p['text'] as String?;
                if (partText != null && partText.isNotEmpty) {
                  textBuffer.write(partText);
                }
              }
            }
            final text = textBuffer.toString().trim();
            final rawFinish = first['finishReason']?.toString();
            final finish = rawFinish == 'MAX_TOKENS' ? 'length' : rawFinish;
            if (text.isNotEmpty) {
              return (
                text: text,
                finishReason: finish,
                statusCode: 200,
                error: null,
              );
            }
            return (
              text: null,
              finishReason: finish,
              statusCode: 200,
              error: 'Empty response (finishReason=$rawFinish)',
            );
          }
          return (
            text: null,
            finishReason: null,
            statusCode: 200,
            error: 'No candidates: ${preview300(resp.body)}',
          );
        }

        final preview = preview300(resp.body);
        debugPrint('[Reman AI] $providerTag HTTP ${resp.statusCode}: $preview');
        return (
          text: null,
          finishReason: null,
          statusCode: resp.statusCode,
          error: 'HTTP ${resp.statusCode}: ${extractApiErrorDetail(resp.body)}',
        );
      } catch (e) {
        return (
          text: null,
          finishReason: null,
          statusCode: null,
          error: shortError(e),
        );
      }
    }

    var attempt = await sendOnce(tokens: maxTokens, useJsonFormat: expectJson);
    if (attempt.text != null) return attempt;

    if (attempt.statusCode == 400 && (maxTokens > 8192 || expectJson)) {
      attempt = await sendOnce(
        tokens: maxTokens > 8192 ? 8192 : maxTokens,
        useJsonFormat: false,
      );
      if (attempt.text != null) return attempt;
    }

    // Never retry HTTP 429 on the same Gemini model — return immediately so the
    // caller marks it rate-limited for the session and moves to the next model.
    return attempt;
  }

  Future<({String? text, String? finishReason, int? statusCode, String? error})>
      _callOpenAiCompatible({
    required String endpoint,
    required String apiKey,
    required String model,
    required String prompt,
    Duration timeout = const Duration(seconds: 12),
    int maxTokens = 8192,
    bool responseFormatJson = false,
    String providerTag = 'OpenAI-Compatible',
    bool retryOn429 = false,
  }) async {
    Future<({String? text, String? finishReason, int? statusCode, String? error})>
        sendOnce({
      required int tokens,
      required bool useJsonFormat,
    }) async {
      try {
        final payload = <String, dynamic>{
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a senior language teacher and CEFR/SERRJ methodologist. Always follow JSON formatting instructions strictly.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.35,
          'max_tokens': tokens,
        };

        if (useJsonFormat) {
          payload['response_format'] = {'type': 'json_object'};
        }

        final resp = await _httpClient
            .post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $apiKey',
              },
              body: jsonEncode(payload),
            )
            .timeout(timeout);

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final choices = data['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final first = choices.first as Map<String, dynamic>;
            final msg = first['message'] as Map<String, dynamic>?;
            final content = (msg?['content'] as String?)?.trim();
            final finish = first['finish_reason']?.toString();
            if (content != null && content.isNotEmpty) {
              return (
                text: content,
                finishReason: finish,
                statusCode: 200,
                error: null,
              );
            }
            return (
              text: null,
              finishReason: finish,
              statusCode: 200,
              error: 'Empty choice content (finish_reason=$finish)',
            );
          }
          return (
            text: null,
            finishReason: null,
            statusCode: 200,
            error: 'No choices returned',
          );
        }

        final preview = preview300(resp.body);
        debugPrint(
          '[Reman AI] $providerTag ($model) HTTP ${resp.statusCode}: $preview',
        );
        return (
          text: null,
          finishReason: null,
          statusCode: resp.statusCode,
          error: 'HTTP ${resp.statusCode}: ${extractApiErrorDetail(resp.body)}',
        );
      } catch (e) {
        return (
          text: null,
          finishReason: null,
          statusCode: null,
          error: shortError(e),
        );
      }
    }

    var attempt = await sendOnce(
      tokens: maxTokens,
      useJsonFormat: responseFormatJson,
    );
    if (attempt.text != null) return attempt;

    if (attempt.statusCode == 400 && (maxTokens > 8192 || responseFormatJson)) {
      attempt = await sendOnce(
        tokens: maxTokens > 8192 ? 8192 : maxTokens,
        useJsonFormat: false,
      );
      if (attempt.text != null) return attempt;
    }

    if (attempt.statusCode == 429 && retryOn429) {
      await Future<void>.delayed(const Duration(seconds: 2));
      attempt = await sendOnce(
        tokens: maxTokens > 8192 ? 8192 : maxTokens,
        useJsonFormat: responseFormatJson,
      );
      if (attempt.text != null) return attempt;
    }

    return (
      text: null,
      finishReason: attempt.finishReason,
      statusCode: attempt.statusCode,
      error: attempt.error ?? 'Unknown OpenAI-compatible error',
    );
  }

  Future<({String? text, String? finishReason, String? error})>
      _callFreePollinationsAi(
    String prompt, {
    Duration timeout = const Duration(seconds: 12),
    bool expectJson = false,
    int maxTokens = 8192,
  }) async {
    final effectiveTokens = expectJson && maxTokens < 8192 ? 8192 : maxTokens;

    Future<({String? text, String? finishReason, int? statusCode, String? error})>
        sendOnce({
      required int tokens,
      required bool useJsonFormat,
    }) async {
      try {
        final payload = <String, dynamic>{
          'model': 'openai',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a senior CEFR/SERRJ language teacher. Respond ONLY with valid JSON when requested.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.4,
          'max_tokens': tokens,
        };
        if (useJsonFormat) {
          payload['response_format'] = {'type': 'json_object'};
        }

        final resp = await _httpClient
            .post(
              Uri.parse('https://text.pollinations.ai/openai'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(timeout);

        if (resp.statusCode == 200 && resp.body.trim().isNotEmpty) {
          final body = resp.body.trim();
          if (body.startsWith('{') && body.contains('"choices"')) {
            final data = jsonDecode(body) as Map<String, dynamic>;
            final choices = data['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final first = choices.first as Map<String, dynamic>;
              final msg = first['message'] as Map<String, dynamic>?;
              final finish = first['finish_reason']?.toString();
              final content = (msg?['content'] as String?)?.trim();
              if (content != null && content.isNotEmpty) {
                return (
                  text: content,
                  finishReason: finish,
                  statusCode: 200,
                  error: null,
                );
              }
            }
          }
          return (
            text: body,
            finishReason: null,
            statusCode: 200,
            error: null,
          );
        }
        debugPrint(
          '[Reman AI] Pollinations HTTP ${resp.statusCode}: ${preview300(resp.body)}',
        );
        return (
          text: null,
          finishReason: null,
          statusCode: resp.statusCode,
          error: 'HTTP ${resp.statusCode}: ${extractApiErrorDetail(resp.body)}',
        );
      } catch (e) {
        return (
          text: null,
          finishReason: null,
          statusCode: null,
          error: shortError(e),
        );
      }
    }

    var attempt = await sendOnce(
      tokens: effectiveTokens,
      useJsonFormat: expectJson,
    );
    if (attempt.text != null) {
      return (
        text: attempt.text,
        finishReason: attempt.finishReason,
        error: null,
      );
    }

    if (attempt.statusCode == 400 && (effectiveTokens > 8192 || expectJson)) {
      attempt = await sendOnce(
        tokens: effectiveTokens > 8192 ? 8192 : effectiveTokens,
        useJsonFormat: false,
      );
      if (attempt.text != null) {
        return (
          text: attempt.text,
          finishReason: attempt.finishReason,
          error: null,
        );
      }
    }

    return (
      text: null,
      finishReason: attempt.finishReason,
      error: attempt.error ?? 'Pollinations unavailable',
    );
  }

  /// Extracts the outermost valid JSON object from an LLM text response.
  Map<String, dynamic>? extractJsonObject(String raw) {
    final cleaned = stripCodeFences(raw);
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    try {
      return jsonDecode(cleaned.substring(start, end + 1))
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String stripCodeFences(String text) {
    return text
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
  }
}
