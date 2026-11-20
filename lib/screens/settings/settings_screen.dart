import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/app_settings.dart';
import '../../models/user_progress.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../state/app_controller.dart';
import '../../widgets/language_picker_sheet.dart';
import '../../widgets/learning_topic_selector.dart';
import '../../widgets/user_avatar_button.dart';
import '../profile/profile_screen.dart';
import '../rules/reading_rules_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyCtrl = TextEditingController();
  final TextEditingController _aiVoiceKeyCtrl = TextEditingController();
  final TextEditingController _aiVoiceEndpointCtrl = TextEditingController();
  final TextEditingController _aiVoiceModelCtrl = TextEditingController();

  bool _obscureKey = true;
  bool _obscureVoiceKey = true;
  bool _syncedFromState = false;
  bool _testingKey = false;
  List<VoiceChoice> _availableVoices = const [];
  String _loadedVoicesLocale = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (!_syncedFromState) {
      _syncedFromState = true;
      _apiKeyCtrl.text = controller.settings.geminiApiKey;
      _aiVoiceKeyCtrl.text = controller.settings.customAiVoiceApiKey;
      _aiVoiceEndpointCtrl.text = controller.settings.customAiVoiceEndpoint;
      _aiVoiceModelCtrl.text = controller.settings.customAiVoiceModel;
    }
    final locale = controller.settings.targetLanguage.ttsLocale;
    if (_loadedVoicesLocale != locale) {
      _loadedVoicesLocale = locale;
      _loadDeviceVoices(controller, locale);
    }
  }

  Future<void> _loadDeviceVoices(
    AppController controller,
    String locale,
  ) async {
    final voices = await controller.tts.getVoicesForLocale(locale);
    if (mounted && _loadedVoicesLocale == locale) {
      setState(() => _availableVoices = voices);
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _aiVoiceKeyCtrl.dispose();
    _aiVoiceEndpointCtrl.dispose();
    _aiVoiceModelCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final controller = AppScope.of(context);
    final trimmed = _apiKeyCtrl.text.trim();
    await controller.updateSettings(
      controller.settings.copyWith(geminiApiKey: trimmed),
    );
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final providerName = GeminiService.detectProviderName(trimmed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ $providerName'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveAiVoiceSettings() async {
    final controller = AppScope.of(context);
    await controller.updateSettings(
      controller.settings.copyWith(
        customAiVoiceApiKey: _aiVoiceKeyCtrl.text.trim(),
        customAiVoiceEndpoint: _aiVoiceEndpointCtrl.text.trim(),
        customAiVoiceModel: _aiVoiceModelCtrl.text.trim(),
      ),
    );
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.of(context).tr('custom_ai_voice_saved_toast')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _testAiConnection() async {
    final controller = AppScope.of(context);
    final key = _apiKeyCtrl.text.trim();

    setState(() => _testingKey = true);
    final res = await controller.gemini.testAiConnection(key);
    if (!mounted) return;
    setState(() => _testingKey = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res.ok
              ? '✓ ${res.providerUsed}'
              : '✗ ${res.errorDetail ?? 'Offline / Error'}',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        duration: Duration(seconds: res.ok ? 3 : 6),
        backgroundColor:
            res.ok ? Colors.green.shade800 : Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _sampleSentenceForLang(String code) {
    return switch (code) {
      'uk' => 'Привіт! Я твій живий голосовий помічник у Reman.',
      'es' => '¡Hola! Esta es mi voz natural para practicar español.',
      'de' => 'Hallo! Das ist meine natürliche Stimme zum Deutschlernen.',
      'fr' => 'Bonjour ! Voici ma voix naturelle pour apprendre le français.',
      'pl' => 'Cześć! To jest mój naturalny głos do nauki języka polskiego.',
      'it' => 'Ciao! Questa è la mia voce naturale per praticare l’italiano.',
      'pt' => 'Olá! Esta é a minha voz natural para aprender português.',
      'ja' => 'こんにちは！これは自然な日本語の学習ボイスです。',
      'zh' => '你好！这是用于语言学习的自然语音。',
      'ko' => '안녕하세요! 자연스러운 한국어 학습 음성입니다.',
      'ur' => 'سلام! یہ زبان سیکھنے کے لیے میری قدرتی آواز ہے۔',
      'ar' => 'مرحباً! هذا صوتي الطبيعي لتعلم اللغة.',
      'tr' => 'Merhaba! Dil öğrenmek için doğal sesim budur.',
      'cs' => 'Ahoj! Toto je můj přirozený hlas pro studium češtiny.',
      _ => 'Hello! This is your natural voice assistant in Reman.',
    };
  }

  Future<void> _pickLanguage({
    required String title,
    required String currentCode,
    required ValueChanged<String> onSelected,
  }) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => LanguagePickerSheet(
        title: title,
        currentCode: currentCode,
      ),
    );

    if (chosen != null && mounted) {
      onSelected(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final settings = controller.settings;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final liveKeyText = _apiKeyCtrl.text.trim().isNotEmpty
        ? _apiKeyCtrl.text
        : settings.geminiApiKey;
    final detectedProvider =
        controller.gemini.describeActiveProvider(liveKeyText);

    final voiceOptions = <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(
        value: '',
        child: Text(s.tr('voice_auto_best')),
      ),
      ..._availableVoices.map(
        (v) => DropdownMenuItem<String>(
          value: v.name,
          child: Text(
            v.displayLabel,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
    final effectiveVoiceValue =
        _availableVoices.any((v) => v.name == settings.preferredVoiceName)
            ? settings.preferredVoiceName
            : '';

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          s.tr('settings_title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          StreakXpHeaderBadges(
            onProfileTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
        children: [
          if (controller.translatingUi)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.tr('translating_ui_banner'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Text(
            '${s.tr('languages_section')} (${supportedLanguages.length})',
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _pickLanguage(
                      title: s.tr('target_language'),
                      currentCode: settings.targetLanguageCode,
                      onSelected: (code) {
                        controller.updateSettings(
                          settings.copyWith(
                            targetLanguageCode: code,
                            preferredVoiceName: '',
                          ),
                        );
                      },
                    ),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: s.tr('target_language'),
                        prefixIcon: const Icon(Icons.language_rounded),
                        suffixIcon: const Icon(Icons.search_rounded),
                      ),
                      child: Row(
                        children: [
                          Text(
                            settings.targetLanguage.flag,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${settings.targetLanguage.displayNativeName} (${settings.targetLanguage.englishName})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _pickLanguage(
                      title: s.tr('native_language'),
                      currentCode: settings.nativeLanguageCode,
                      onSelected: (code) {
                        controller.updateSettings(
                          settings.copyWith(nativeLanguageCode: code),
                        );
                      },
                    ),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: s.tr('native_language'),
                        prefixIcon: const Icon(Icons.translate_rounded),
                        suffixIcon: const Icon(Icons.search_rounded),
                      ),
                      child: Row(
                        children: [
                          Text(
                            settings.nativeLanguage.flag,
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${settings.nativeLanguage.displayNativeName} (${settings.nativeLanguage.englishName})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      s.tr('transcription_mode_title'),
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment<bool>(
                          value: false,
                          icon: const Icon(
                            Icons.record_voice_over_rounded,
                            size: 18,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${s.tr('transcription_native')} (${settings.nativeLanguage.flag})',
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          icon: const Icon(Icons.public_rounded, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              s.tr('transcription_international'),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ],
                      selected: {settings.useInternationalIpa},
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty) {
                          controller.updateSettings(
                            settings.copyWith(
                              useInternationalIpa: selection.first,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Quick access to "Книжечка з правилами"
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: Colors.teal.withValues(alpha: 0.18),
                foregroundColor: Colors.teal.shade300,
                child: const Icon(Icons.auto_stories_rounded),
              ),
              title: Text(
                '${s.tr('rules_book_title')} (${settings.targetLanguage.flag})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(s.tr('rules_book_sub')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReadingRulesScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Learning Topic / Domain Section
          Text(
            s.tr('learning_topic_section'),
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            s.tr('learning_topic_subtitle'),
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          LearningTopicSelector(
            selected: settings.learningTopic,
            onSelected: (topic) {
              controller.updateSettings(
                settings.copyWith(learningTopicId: topic.id),
              );
            },
          ),
          const SizedBox(height: 12),

          // Natural / Live Voice Selection Card
          Text(
            s.tr('voice_section_title'),
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: Text(s.tr('voice_preset_natural')),
                        selected: settings.voicePreset == 'neural_natural',
                        onSelected: (_) {
                          controller.updateSettings(
                            settings.copyWith(
                              voicePreset: 'neural_natural',
                              preferredVoiceName: '',
                            ),
                          );
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.face_3_rounded, size: 16),
                        label: Text(s.tr('voice_preset_female')),
                        selected: settings.voicePreset == 'warm_female',
                        onSelected: (_) {
                          controller.updateSettings(
                            settings.copyWith(
                              voicePreset: 'warm_female',
                              preferredVoiceName: '',
                            ),
                          );
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.face_6_rounded, size: 16),
                        label: Text(s.tr('voice_preset_male')),
                        selected: settings.voicePreset == 'deep_male',
                        onSelected: (_) {
                          controller.updateSettings(
                            settings.copyWith(
                              voicePreset: 'deep_male',
                              preferredVoiceName: '',
                            ),
                          );
                        },
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.school_rounded, size: 16),
                        label: Text(s.tr('voice_preset_tutor')),
                        selected: settings.voicePreset == 'clear_tutor',
                        onSelected: (_) {
                          controller.updateSettings(
                            settings.copyWith(
                              voicePreset: 'clear_tutor',
                              preferredVoiceName: '',
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (_availableVoices.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: effectiveVoiceValue,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText:
                            '${s.tr('voice_device_picker_label')} (${settings.targetLanguage.flag})',
                        prefixIcon: const Icon(Icons.record_voice_over_rounded),
                      ),
                      items: voiceOptions,
                      onChanged: (val) {
                        if (val != null) {
                          controller.updateSettings(
                            settings.copyWith(preferredVoiceName: val),
                          );
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.speed_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${s.tr('voice_speed_label')}: ${(settings.speechRate * 2).toStringAsFixed(2)}x',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: settings.speechRate.clamp(0.30, 0.70),
                    min: 0.30,
                    max: 0.70,
                    divisions: 8,
                    onChanged: (v) {
                      controller.updateSettings(
                        settings.copyWith(speechRate: v),
                      );
                    },
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.graphic_eq_rounded),
                    title: Text(s.tr('custom_ai_voice_title')),
                    subtitle: Text(s.tr('custom_ai_voice_sub')),
                    value: settings.useCustomAiVoice,
                    onChanged: (val) {
                      controller.updateSettings(
                        settings.copyWith(useCustomAiVoice: val),
                      );
                    },
                  ),
                  if (settings.useCustomAiVoice) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _aiVoiceKeyCtrl,
                      obscureText: _obscureVoiceKey,
                      decoration: InputDecoration(
                        labelText: 'AI Voice API Key',
                        hintText: 'sk-... / ElevenLabs key',
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureVoiceKey
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                          onPressed: () => setState(
                            () => _obscureVoiceKey = !_obscureVoiceKey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _aiVoiceEndpointCtrl,
                      decoration: InputDecoration(
                        labelText: s.tr('custom_ai_voice_endpoint_label'),
                        hintText: 'https://api.openai.com/v1/audio/speech',
                        prefixIcon: const Icon(Icons.link_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _aiVoiceModelCtrl,
                      decoration: InputDecoration(
                        labelText: s.tr('custom_ai_voice_model_label'),
                        hintText: 'alloy',
                        prefixIcon: const Icon(Icons.mic_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _saveAiVoiceSettings,
                        icon: const Icon(Icons.save_rounded),
                        label: Text(s.tr('custom_ai_voice_save_btn')),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        final sample = _sampleSentenceForLang(
                          settings.targetLanguageCode,
                        );
                        controller.speakTarget(sample);
                      },
                      icon: const Icon(Icons.volume_up_rounded),
                      label: Text(
                        '${s.tr('voice_test_btn')} (${settings.targetLanguage.flag})',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            s.tr('theme_section'),
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          s.tr('theme_light'),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          s.tr('theme_dark'),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon:
                          const Icon(Icons.brightness_auto_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          s.tr('theme_system'),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      controller.updateSettings(
                        settings.copyWith(themeMode: selection.first),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.tr('ai_router_section'),
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 20,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          detectedProvider,
                          maxLines: 2,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: _obscureKey,
                    enableSuggestions: false,
                    autocorrect: false,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText:
                          'API Key (NVIDIA / Gemini / Groq / OpenRouter / OpenAI)',
                      hintText:
                          'nvapi-... / AIza... / gsk_... / sk-or-... / sk-...',
                      prefixIcon: const Icon(Icons.auto_awesome_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _saveApiKey,
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              s.tr('save_btn'),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _testingKey ? null : _testAiConnection,
                          icon: _testingKey
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.bolt_rounded, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              s.tr('test_ai_btn'),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                      if (settings.hasGeminiKey) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            _apiKeyCtrl.clear();
                            _saveApiKey();
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.tr('restart_tutorial_section'),
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: scheme.tertiaryContainer,
                foregroundColor: scheme.onTertiaryContainer,
                child: const Icon(Icons.explore_rounded),
              ),
              title: Text(
                s.tr('restart_tutorial_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(s.tr('restart_tutorial_sub')),
              trailing: const Icon(Icons.play_circle_fill_rounded),
              onTap: () async {
                await controller.restartTutorial();
                if (!context.mounted) return;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
          const SizedBox(height: 20),
          Card(
            color: scheme.surfaceContainerLow,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: const Icon(Icons.auto_stories_rounded),
              ),
              title: const Text('Reman'),
              subtitle: Text(
                '🔥 ${controller.progress.currentStreak} ${s.tr('days_short')} • '
                '${s.tr('tab_vocab')}: ${controller.vocabulary.length} • '
                '🏆 ${controller.progress.unlockedAchievements.length}/${allAchievements.length}',
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
