import 'package:flutter/material.dart';

import 'learning_topic.dart';
import 'supported_languages.dart';

export 'learning_topic.dart';
export 'supported_languages.dart';

class AppSettings {
  const AppSettings({
    this.targetLanguageCode = 'en',
    this.nativeLanguageCode = 'uk',
    this.themeMode = ThemeMode.system,
    this.geminiApiKey = '',
    this.useInternationalIpa = false,
    this.voicePreset = 'neural_natural',
    this.preferredVoiceName = '',
    this.speechRate = 0.48,
    this.useCustomAiVoice = false,
    this.customAiVoiceApiKey = '',
    this.customAiVoiceEndpoint = '',
    this.customAiVoiceModel = 'alloy',
    this.learningTopicId = 'neutral',
  });

  final String targetLanguageCode;
  final String nativeLanguageCode;
  final ThemeMode themeMode;
  final String geminiApiKey;

  /// If false (default), phonetic transcription uses the user's native language alphabet.
  /// If true, phonetic transcription uses International Phonetic Alphabet (IPA).
  final bool useInternationalIpa;

  /// Natural voice style preset: 'neural_natural', 'warm_female', 'deep_male', 'clear_tutor'.
  final String voicePreset;

  /// Optional specific Android TTS voice identifier chosen by the user.
  final String preferredVoiceName;

  /// Speech speed (0.30 .. 0.70, default 0.48).
  final double speechRate;

  /// Enable custom AI TTS Voice engine (OpenAI TTS / ElevenLabs / Custom Voice API).
  final bool useCustomAiVoice;
  final String customAiVoiceApiKey;
  final String customAiVoiceEndpoint;
  final String customAiVoiceModel;

  /// Selected thematic domain ID (default: 'neutral').
  final String learningTopicId;

  LanguageOption get targetLanguage => languageByCode(targetLanguageCode);
  LanguageOption get nativeLanguage => languageByCode(nativeLanguageCode);
  LearningTopic get learningTopic => LearningTopic.fromId(learningTopicId);
  bool get hasGeminiKey => geminiApiKey.trim().isNotEmpty;
  bool get hasCustomAiVoiceKey => customAiVoiceApiKey.trim().isNotEmpty;

  AppSettings copyWith({
    String? targetLanguageCode,
    String? nativeLanguageCode,
    ThemeMode? themeMode,
    String? geminiApiKey,
    bool? useInternationalIpa,
    String? voicePreset,
    String? preferredVoiceName,
    double? speechRate,
    bool? useCustomAiVoice,
    String? customAiVoiceApiKey,
    String? customAiVoiceEndpoint,
    String? customAiVoiceModel,
    String? learningTopicId,
  }) {
    return AppSettings(
      targetLanguageCode: targetLanguageCode ?? this.targetLanguageCode,
      nativeLanguageCode: nativeLanguageCode ?? this.nativeLanguageCode,
      themeMode: themeMode ?? this.themeMode,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      useInternationalIpa: useInternationalIpa ?? this.useInternationalIpa,
      voicePreset: voicePreset ?? this.voicePreset,
      preferredVoiceName: preferredVoiceName ?? this.preferredVoiceName,
      speechRate: speechRate ?? this.speechRate,
      useCustomAiVoice: useCustomAiVoice ?? this.useCustomAiVoice,
      customAiVoiceApiKey: customAiVoiceApiKey ?? this.customAiVoiceApiKey,
      customAiVoiceEndpoint:
          customAiVoiceEndpoint ?? this.customAiVoiceEndpoint,
      customAiVoiceModel: customAiVoiceModel ?? this.customAiVoiceModel,
      learningTopicId: learningTopicId ?? this.learningTopicId,
    );
  }

  static ThemeMode themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
