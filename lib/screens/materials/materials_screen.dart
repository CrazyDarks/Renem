import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_strings.dart';
import '../../models/study_material.dart';
import '../../state/app_controller.dart';
import '../../widgets/user_avatar_button.dart';
import '../profile/profile_screen.dart';
import 'material_reader_screen.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _busy = false;
  String? _busyMessage;

  Future<void> _showAddManualTextDialog() async {
    final s = AppStrings.of(context);
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    final saved = await showModalBottomSheet<StudyMaterial>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.tr('add_manual_text_title'),
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: s.tr('material_title_label'),
                    hintText: s.tr('material_title_hint'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  maxLines: 7,
                  minLines: 4,
                  decoration: InputDecoration(
                    labelText: s.tr('foreign_text_label'),
                    hintText: s.tr('foreign_text_hint'),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final text = contentCtrl.text.trim();
                      if (text.isEmpty) return;
                      final title = titleCtrl.text.trim().isEmpty
                          ? '${s.tr('badge_text')} (${DateTime.now().day}.${DateTime.now().month})'
                          : titleCtrl.text.trim();
                      Navigator.of(ctx).pop(
                        StudyMaterial(
                          id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
                          title: title,
                          content: text,
                          sourceType: MaterialSourceType.manual,
                          createdAt: DateTime.now(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: Text(s.tr('save_and_open_btn')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 450), () {
      titleCtrl.dispose();
      contentCtrl.dispose();
    });

    if (saved != null && mounted) {
      final controller = AppScope.of(context);
      await controller.addMaterial(saved);
      if (mounted) _openMaterial(saved);
    }
  }

  Future<void> _showAddYoutubeDialog() async {
    final s = AppStrings.of(context);
    final urlCtrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('add_youtube_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.tr('add_youtube_desc')),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: s.tr('youtube_url_label'),
                hintText: 'https://www.youtube.com/watch?v=...',
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.tr('cancel_btn')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(urlCtrl.text.trim()),
            child: Text(s.tr('download_btn')),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 450), urlCtrl.dispose);

    if (url == null || url.isEmpty || !mounted) return;

    final controller = AppScope.of(context);
    setState(() {
      _busy = true;
      _busyMessage = s.tr('loading_video_subs');
    });

    try {
      final result = await controller.youtube.fetchVideoAndSubtitles(
        url,
        preferredLangCode: controller.settings.targetLanguageCode,
        nativeLangCode: controller.settings.nativeLanguageCode,
      );
      final material = StudyMaterial(
        id: 'yt_${DateTime.now().microsecondsSinceEpoch}',
        title: result.title,
        content: result.fullTranscript,
        sourceType: MaterialSourceType.youtube,
        youtubeVideoId: result.videoId,
        subtitles: result.subtitles,
        createdAt: DateTime.now(),
      );
      await controller.addMaterial(material);
      if (!mounted) return;

      if (result.warningMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.warningMessage!),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _openMaterial(material);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('FormatException: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _showScanImageOptions() async {
    final s = AppStrings.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text(s.tr('take_photo_camera')),
                subtitle: Text(s.tr('take_photo_camera_sub')),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(s.tr('pick_from_gallery')),
                subtitle: Text(s.tr('pick_from_gallery_sub')),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;
    await _scanFromSource(source);
  }

  Future<void> _scanFromSource(ImageSource source) async {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    if (source == ImageSource.camera) {
      final hasCamera = await controller.permissions.ensureCamera();
      if (!hasCamera) return;
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() {
        _busy = true;
        _busyMessage = s.tr('ocr_loading_msg');
      });

      final bytes = await picked.readAsBytes();
      final lowerName = picked.name.toLowerCase();
      final mimeType = lowerName.endsWith('.png') ? 'image/png' : 'image/jpeg';

      final extracted = await controller.gemini.extractTextFromImage(
        imageBytes: bytes,
        mimeType: mimeType,
        settings: controller.settings,
      );

      if (!mounted) return;
      final material = StudyMaterial(
        id: 'scan_${DateTime.now().microsecondsSinceEpoch}',
        title:
            '${s.tr('badge_photo_scan')} (${DateTime.now().day}.${DateTime.now().month})',
        content: extracted,
        sourceType: MaterialSourceType.photo,
        createdAt: DateTime.now(),
      );
      await controller.addMaterial(material);
      if (mounted) _openMaterial(material);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Bad state: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _showAddWebsiteUrlDialog() async {
    final s = AppStrings.of(context);
    final urlCtrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('add_web_url_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.tr('add_web_url_desc')),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: s.tr('web_url_input_label'),
                hintText: 'https://bbc.com/news/...',
                prefixIcon: const Icon(Icons.public_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.tr('cancel_btn')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(urlCtrl.text.trim()),
            icon: const Icon(Icons.article_rounded, size: 18),
            label: Text(s.tr('download_btn')),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 450), urlCtrl.dispose);

    if (url == null || url.isEmpty || !mounted) return;

    final controller = AppScope.of(context);
    setState(() {
      _busy = true;
      _busyMessage = s.tr('loading_web_article');
    });

    try {
      final result = await controller.webArticle.fetchArticle(url);
      if (!mounted) return;
      final material = StudyMaterial(
        id: 'web_${DateTime.now().microsecondsSinceEpoch}',
        title: result.title,
        content: result.content,
        sourceType: MaterialSourceType.web,
        sourceUrl: result.url,
        languageCode: controller.settings.targetLanguageCode,
        createdAt: DateTime.now(),
      );
      await controller.addMaterial(material);
      if (!mounted) return;
      _openMaterial(material);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('FormatException: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  void _openMaterial(StudyMaterial material) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MaterialReaderScreen(material: material),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final materials = controller.materials;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          s.tr('tab_materials'),
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
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
            children: [
              _DailyMissionCard(
                onActionTap: () {
                  HapticFeedback.lightImpact();
                  if (controller.dueWords.isNotEmpty) {
                    controller.navigateToTab(2, trainingSubMode: 0);
                  } else if (materials.isNotEmpty) {
                    controller.awardXp(15);
                    _openMaterial(materials.first);
                  }
                },
              ),
              const SizedBox(height: 18),
              Text(
                s.tr('add_new_content'),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickAddCard(
                      icon: Icons.edit_note_rounded,
                      label: s.tr('text_manual'),
                      subtitle: s.tr('manual_sub'),
                      color: scheme.primaryContainer,
                      onColor: scheme.onPrimaryContainer,
                      onTap: _showAddManualTextDialog,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAddCard(
                      icon: Icons.public_rounded,
                      label: s.tr('web_url_card_title'),
                      subtitle: s.tr('web_url_card_sub'),
                      color: scheme.surfaceContainerHighest,
                      onColor: scheme.onSurface,
                      onTap: _showAddWebsiteUrlDialog,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickAddCard(
                      icon: Icons.smart_display_rounded,
                      label: 'YouTube',
                      subtitle: s.tr('video_subs'),
                      color: scheme.tertiaryContainer,
                      onColor: scheme.onTertiaryContainer,
                      onTap: _showAddYoutubeDialog,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAddCard(
                      icon: Icons.document_scanner_rounded,
                      label: s.tr('photo'),
                      subtitle: 'OCR',
                      color: scheme.secondaryContainer,
                      onColor: scheme.onSecondaryContainer,
                      onTap: _showScanImageOptions,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${s.tr('your_library')} (${controller.settings.targetLanguage.flag})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${materials.length}',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (materials.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 44,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.tr('empty_materials'),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...materials.map((m) => _MaterialTile(
                      material: m,
                      onOpen: () => _openMaterial(m),
                      onDelete: () => controller.deleteMaterial(m.id),
                    )),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(28),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _busyMessage ?? s.tr('loading_generic'),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DailyMissionCard extends StatelessWidget {
  const _DailyMissionCard({
    required this.onActionTap,
  });

  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = controller.progress;
    final dueCount = controller.dueWords.length;
    final materials = controller.materials;
    final goalDone = progress.todayXp >= progress.dailyGoalXp;

    final String actionTitle = dueCount > 0
        ? '${s.tr('mission_review_due')} ($dueCount)'
        : materials.isNotEmpty
            ? '${s.tr('mission_continue_reading')}: ${materials.first.title}'
            : s.tr('mission_review_due');
    final IconData actionIcon =
        dueCount > 0 ? Icons.style_rounded : Icons.auto_stories_rounded;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.72),
            scheme.tertiaryContainer.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onActionTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      goalDone
                          ? Icons.workspace_premium_rounded
                          : Icons.local_fire_department_rounded,
                      size: 20,
                      color: goalDone ? Colors.amber : Colors.deepOrangeAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        goalDone
                            ? s.tr('mission_goal_completed')
                            : '${s.tr('daily_mission_title')} • ${progress.todayXp}/${progress.dailyGoalXp} XP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+15 XP',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.dailyGoalProgress,
                    minHeight: 6,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    color: goalDone ? Colors.greenAccent.shade400 : scheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: scheme.primary.withValues(alpha: 0.18),
                      foregroundColor: scheme.primary,
                      child: Icon(actionIcon, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        actionTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAddCard extends StatelessWidget {
  const _QuickAddCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: onColor, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: onColor.withValues(alpha: 0.85),
                    ),
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({
    required this.material,
    required this.onOpen,
    required this.onDelete,
  });

  final StudyMaterial material;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  IconData get _icon {
    switch (material.sourceType) {
      case MaterialSourceType.manual:
        return Icons.article_rounded;
      case MaterialSourceType.youtube:
        return Icons.play_circle_fill_rounded;
      case MaterialSourceType.photo:
        return Icons.document_scanner_rounded;
      case MaterialSourceType.web:
        return Icons.public_rounded;
    }
  }

  String _badge(AppStrings s) {
    switch (material.sourceType) {
      case MaterialSourceType.manual:
        return s.tr('badge_text');
      case MaterialSourceType.youtube:
        return material.subtitles.isNotEmpty
            ? 'YouTube • ${material.subtitles.length} ${s.tr('badge_lines')}'
            : 'YouTube';
      case MaterialSourceType.photo:
        return s.tr('badge_photo_scan');
      case MaterialSourceType.web:
        final host = Uri.tryParse(material.sourceUrl ?? '')?.host ?? '';
        return host.isNotEmpty
            ? '${s.tr('badge_web_article')} • $host'
            : s.tr('badge_web_article');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final preview = material.content
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('\n', ' ')
        .trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Icon(_icon, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        material.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _badge(s),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: s.tr('delete_material_tooltip'),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
