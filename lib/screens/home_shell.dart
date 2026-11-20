import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../state/app_controller.dart';
import '../widgets/app_tutorial_overlay.dart';
import 'materials/materials_screen.dart';
import 'training/training_screen.dart';
import 'vocabulary/vocabulary_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _isBottomBarVisible = true;

  static const List<Widget> _pages = [
    MaterialsScreen(),
    VocabularyScreen(),
    TrainingScreen(),
  ];

  bool _handleScrollUpdate(ScrollUpdateNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final delta = notification.scrollDelta ?? 0;

    // Scrolling down -> hide bottom bar automatically
    if (delta > 3.5 && _isBottomBarVisible) {
      setState(() => _isBottomBarVisible = false);
    }
    // Scrolling up or back at top -> show bottom bar automatically
    else if (!_isBottomBarVisible &&
        (delta < -3.5 || notification.metrics.pixels <= 8)) {
      setState(() => _isBottomBarVisible = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final currentIndex = controller.currentTabIndex;
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final showBar = _isBottomBarVisible && !keyboardOpen;

    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: _handleScrollUpdate,
        child: Stack(
          children: [
            IndexedStack(
              index: currentIndex,
              children: _pages,
            ),
            // Compact floating pill navigation bar that auto-hides on scroll down and returns on scroll up
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  offset: showBar ? Offset.zero : const Offset(0, 1.8),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: showBar ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !showBar,
                      child: Material(
                        elevation: 6,
                        shadowColor: Colors.black38,
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(28),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _NavPillItem(
                                  icon: Icons.menu_book_rounded,
                                  label: s.tr('tab_materials'),
                                  selected: currentIndex == 0,
                                  onTap: () => controller.navigateToTab(0),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _NavPillItem(
                                  icon: Icons.bookmark_rounded,
                                  label: s.tr('tab_vocab'),
                                  selected: currentIndex == 1,
                                  onTap: () => controller.navigateToTab(1),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: _NavPillItem(
                                  icon: Icons.fitness_center_rounded,
                                  label: s.tr('tab_training'),
                                  selected: currentIndex == 2,
                                  onTap: () => controller.navigateToTab(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (controller.showTutorialOverlay)
              const Positioned.fill(
                child: AppTutorialOverlay(),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavPillItem extends StatelessWidget {
  const _NavPillItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
