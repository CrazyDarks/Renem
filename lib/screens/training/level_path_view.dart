import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../models/exam_models.dart';
import '../../models/level_curriculum.dart';
import '../../state/app_controller.dart';
import '../rules/reading_rules_screen.dart';
import 'level_module_sheet.dart';

class LevelPathView extends StatefulWidget {
  const LevelPathView({super.key});

  @override
  State<LevelPathView> createState() => _LevelPathViewState();
}

class _LevelPathViewState extends State<LevelPathView> {
  CefrLevel _selectedCefr = CefrLevel.a1;
  Set<String> _cachedKeys = const {};
  bool _loadedCacheIndex = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedCacheIndex) {
      _loadedCacheIndex = true;
      _refreshCacheIndex();
    }
  }

  Future<void> _refreshCacheIndex() async {
    final controller = AppScope.of(context);
    final keys = await controller.storage.loadCachedLevelKeys();
    if (mounted) {
      setState(() => _cachedKeys = keys);
    }
  }

  bool _isNodeUnlocked({
    required CurriculumModuleNode node,
    required List<CurriculumModuleNode> levelNodes,
    required Set<String> completedKeys,
    required String langCode,
  }) {
    if (node.stepNumber == 1) return true;
    final prev = levelNodes.firstWhere(
      (n) => n.stepNumber == node.stepNumber - 1,
      orElse: () => node,
    );
    return completedKeys.contains(prev.progressKey(langCode));
  }

  Future<void> _openNodeModule(CurriculumModuleNode node) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => LevelModuleSheet(node: node),
    );
    if (mounted) {
      await _refreshCacheIndex();
    }
  }

  void _openReadingRules() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ReadingRulesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final langCode = controller.settings.targetLanguageCode;
    final nativeLangCode = controller.settings.nativeLanguageCode;
    final topicId = controller.settings.learningTopicId;
    final completedKeys = controller.progress.completedPathNodes.toSet();
    final allNodes = UniversalCurriculumBlueprint.allNodes;
    final completedForLang = allNodes
        .where((n) => completedKeys.contains(n.progressKey(langCode)))
        .length;
    final levelNodes = UniversalCurriculumBlueprint.nodesForLevel(_selectedCefr);

    return ListView(
      key: const PageStorageKey<String>('level_path_scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 116),
      children: [
        // Reading & Writing Rules Handbook ("Книжечка з правилами") Entry Card
        Card(
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.teal.withValues(alpha: 0.42),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _openReadingRules,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: Colors.teal.shade300,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.tr('rules_book_title')} (${controller.settings.targetLanguage.flag})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.tr('rules_book_sub'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.teal.shade300,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Top Overview Card
        Card(
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.route_rounded,
                        color: scheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.tr('level_path_title')} (${controller.settings.targetLanguage.flag} ${controller.settings.targetLanguage.displayNativeName})',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s.tr('level_path_sub'),
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$completedForLang / ${allNodes.length}',
                        style: textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // CEFR Level Selector Pills (A1..C2)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: CefrLevel.values.map((lvl) {
                      final isSelected = lvl == _selectedCefr;
                      final lvlNodes =
                          UniversalCurriculumBlueprint.nodesForLevel(lvl);
                      final lvlDone = lvlNodes
                          .where(
                            (n) => completedKeys.contains(
                              n.progressKey(langCode),
                            ),
                          )
                          .length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCefr = lvl);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? scheme.primary
                                    : scheme.outlineVariant
                                        .withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  lvl.code,
                                  style: textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? scheme.onPrimary
                                        : scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$lvlDone/${lvlNodes.length}',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: isSelected
                                        ? scheme.onPrimary
                                            .withValues(alpha: 0.85)
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        // Vertical Architectural Path Nodes (7 per CEFR level)
        ...List.generate(levelNodes.length, (idx) {
          final node = levelNodes[idx];
          final progressKey = node.progressKey(langCode);
          final cacheKey = node.cacheKey(
            targetLangCode: langCode,
            nativeLangCode: nativeLangCode,
            topicId: topicId,
          );
          final isCached = _cachedKeys.contains(cacheKey);
          final isCompleted = completedKeys.contains(progressKey);
          final isUnlocked = isCompleted ||
              _isNodeUnlocked(
                node: node,
                levelNodes: levelNodes,
                completedKeys: completedKeys,
                langCode: langCode,
              );
          final isLast = idx == levelNodes.length - 1;

          final Color accentColor = isCompleted
              ? Colors.green.shade400
              : isUnlocked
                  ? scheme.primary
                  : scheme.outline;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left timeline connector column
                SizedBox(
                  width: 44,
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? Colors.green.withValues(alpha: 0.18)
                              : isUnlocked
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest,
                          border: Border.all(
                            color: accentColor,
                            width: isUnlocked ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.check_rounded
                              : isUnlocked
                                  ? Icons.auto_awesome_rounded
                                  : Icons.lock_outline_rounded,
                          size: 18,
                          color: accentColor,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2.5,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: isCompleted
                                ? Colors.green.withValues(alpha: 0.5)
                                : scheme.outlineVariant.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Right Module Card
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: isCompleted
                              ? Colors.green.withValues(alpha: 0.45)
                              : isUnlocked
                                  ? scheme.primary.withValues(alpha: 0.55)
                                  : scheme.outlineVariant
                                      .withValues(alpha: 0.35),
                          width: isUnlocked && !isCompleted ? 1.5 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: isUnlocked
                            ? () => _openNodeModule(node)
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(s.tr('level_locked_badge')),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          accentColor.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${node.cefr.code} • ${node.stepNumber}',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: accentColor,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isCompleted
                                                  ? s.tr(
                                                      'level_completed_badge')
                                                  : isUnlocked
                                                      ? s.tr(
                                                          'level_unlocked_badge')
                                                      : s.tr(
                                                          'level_locked_short'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: textTheme.labelSmall
                                                  ?.copyWith(
                                                color: isCompleted
                                                    ? Colors.green.shade400
                                                    : scheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (isCached) ...[
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.offline_pin_rounded,
                                            size: 16,
                                            color: Colors.teal.shade300,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: isUnlocked
                                        ? scheme.primary
                                        : scheme.outline,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                node.title(nativeLangCode),
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isUnlocked
                                      ? scheme.onSurface
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                node.subtitle(nativeLangCode),
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
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
        }),
      ],
    );
  }
}
