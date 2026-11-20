import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../state/app_controller.dart';
import '../../widgets/user_avatar_button.dart';
import '../profile/profile_screen.dart';
import '../rules/reading_rules_screen.dart';
import 'exam_view.dart';
import 'level_path_view.dart';
import 'pronunciation_trainer_view.dart';
import 'srs_practice_view.dart';
import 'translation_duel_view.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
    );
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
    final modeIndex = controller.trainingModeIndex.clamp(0, 4);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;

    final tabs = <({int index, IconData icon, String label})>[
      (index: 0, icon: Icons.style_rounded, label: s.tr('srs_cards')),
      (index: 1, icon: Icons.route_rounded, label: s.tr('level_path_tab')),
      (index: 2, icon: Icons.bolt_rounded, label: s.tr('duel_tab')),
      (index: 3, icon: Icons.mic_rounded, label: s.tr('pronunciation')),
      (index: 4, icon: Icons.school_rounded, label: s.tr('exam_20')),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          s.tr('tab_training'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: s.tr('rules_book_title'),
            onPressed: _openReadingRules,
            icon: const Icon(Icons.auto_stories_rounded),
          ),
          StreakXpHeaderBadges(onProfileTap: _openProfile),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final tab = tabs[idx];
                final isSelected = modeIndex == tab.index;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    controller.navigateToTab(
                      2,
                      trainingSubMode: tab.index,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? scheme.primary.withValues(alpha: 0.55)
                            : scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.icon,
                          size: 17,
                          color: isSelected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: modeIndex,
              children: const [
                SrsPracticeView(),
                LevelPathView(),
                TranslationDuelView(),
                PronunciationTrainerView(),
                ExamView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
