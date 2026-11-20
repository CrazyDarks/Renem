import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_strings.dart';
import '../../models/user_progress.dart';
import '../../state/app_controller.dart';
import '../../widgets/profile_duel_history_card.dart';
import '../../widgets/profile_friends_card.dart';
import '../../widgets/user_avatar_button.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;

  Future<void> _changeAvatar() async {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final choice = await showModalBottomSheet<String>(
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
                title: Text(s.tr('photo')),
                onTap: () => Navigator.of(ctx).pop('camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text(s.tr('gallery_label')),
                onTap: () => Navigator.of(ctx).pop('gallery'),
              ),
              if (controller.progress.avatarBase64.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: Text(s.tr('reset_label')),
                  onTap: () => Navigator.of(ctx).pop('reset'),
                ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;
    if (choice == 'reset') {
      await controller.updateProfile(avatarBase64: '');
      return;
    }

    if (choice == 'camera') {
      final hasCamera = await controller.permissions.ensureCamera();
      if (!hasCamera) return;
    }

    try {
      final picked = await _picker.pickImage(
        source:
            choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 82,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      final encoded = base64Encode(bytes);
      await controller.updateProfile(avatarBase64: encoded);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _connectGoogleAccount() async {
    final controller = AppScope.of(context);
    setState(() => _busy = true);
    try {
      final profile = await controller.googleAccount.signInWithGoogle();
      if (!mounted) return;
      if (profile != null) {
        final currentName = controller.progress.displayName.trim();
        final keepName = currentName.isNotEmpty &&
            currentName != 'Учень Reman' &&
            currentName != 'Учень LanguageMa';
        await controller.updateProfile(
          displayName: keepName ? currentName : profile.displayName,
          email: profile.email,
          googleId: profile.id,
          googlePhotoUrl: profile.photoUrl,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Google: ${profile.email}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editDisplayName() async {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final nameCtrl = TextEditingController(
      text: controller.progress.displayName,
    );

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('profile_title')),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.tr('cancel_btn')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(nameCtrl.text.trim()),
            child: Text(s.tr('save_btn')),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 450), nameCtrl.dispose);

    if (newName != null && newName.isNotEmpty && mounted) {
      await controller.updateProfile(displayName: newName);
    }
  }

  Future<void> _showAddFriendSheet() async {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final friendCtrl = TextEditingController();

    final entered = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.person_add_alt_1_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('add_friend_btn'),
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${s.tr('your_friend_code')} ${controller.progress.remanFriendCode}',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: friendCtrl,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
              decoration: InputDecoration(
                labelText: s.tr('friend_input_hint'),
                hintText: 'Alex / REMAN-4821',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(s.tr('cancel_btn')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(ctx).pop(friendCtrl.text.trim()),
                    icon: const Icon(Icons.person_add_rounded),
                    label: Text(s.tr('add_btn')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 450), friendCtrl.dispose);

    if (entered == null || entered.isEmpty || !mounted) return;
    final added = await controller.addFriend(nameOrCode: entered);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? '✓ $entered (+10 XP)'
              : '✓ $entered',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _backupProgress() async {
    final controller = AppScope.of(context);
    try {
      final payload = controller.buildFullBackupPayload();
      final path =
          await controller.googleAccount.exportFullCloudBackup(payload);
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Google Drive Backup saved!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _restoreProgress() async {
    final controller = AppScope.of(context);
    try {
      final data = await controller.googleAccount.importFullCloudBackup();
      if (data == null || !mounted) return;
      await controller.restoreFromBackupPayload(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Progress restored!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final s = AppStrings.of(context);
    final progress = controller.progress;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          s.tr('profile_title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded),
            tooltip: s.tr('settings_title'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
          children: [
            // Profile & Avatar Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            UserAvatarWidget(
                              radius: 38,
                              onTap: _changeAvatar,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: InkWell(
                                onTap: _changeAvatar,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      progress.displayName,
                                      style: textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    onPressed: _editDisplayName,
                                  ),
                                ],
                              ),
                              Text(
                                progress.isGoogleConnected &&
                                        progress.email.isNotEmpty
                                    ? progress.email
                                    : s.tr('google_not_connected'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primaryContainer
                                      .withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.military_tech_rounded,
                                      size: 16,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        '${s.tr('level_label')} ${progress.level} • ${progress.xp} XP',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: scheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                          ),
                          onPressed: _busy ? null : _connectGoogleAccount,
                          icon: const Icon(Icons.cloud_done_rounded, size: 18),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              progress.isGoogleConnected
                                  ? s.tr('google_switch_btn')
                                  : s.tr('google_signin_btn'),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: _backupProgress,
                        icon: const Icon(Icons.cloud_upload_rounded),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        onPressed: _restoreProgress,
                        icon: const Icon(Icons.cloud_download_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Quick Settings button inside Profile
          Card(
            child: ListTile(
              onTap: _openSettings,
              leading: CircleAvatar(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                child: const Icon(Icons.tune_rounded),
              ),
              title: Text(
                s.tr('app_settings_btn'),
                maxLines: 2,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${controller.settings.targetLanguage.flag} ${controller.settings.targetLanguage.displayNativeName} → ${controller.settings.nativeLanguage.flag} ${controller.settings.nativeLanguage.displayNativeName}',
                maxLines: 2,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Friends & Leaderboard Card ("Друзі в Reman")
          ProfileFriendsCard(onAddFriendTap: _showAddFriendSheet),
          const SizedBox(height: 16),

          // Duel History & Records Card ("Дуелі перекладів")
          const ProfileDuelHistoryCard(),
          const SizedBox(height: 16),

          // Streak Card
          Card(
            color: Colors.deepOrange.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.deepOrange,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.tr('streak_title')}: ${progress.currentStreak} ${s.tr('days_short')}',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                            Text(
                              '🏆 ${progress.longestStreak} ${s.tr('days_short')} • ❄️ ${progress.streakFreezes}',
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildWeeklyStreakRow(context, progress),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${s.tr('daily_goal_xp')}: ${progress.todayXp} / ${progress.dailyGoalXp} XP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress.dailyGoalProgress * 100).round()}%',
                        style: textTheme.labelLarge?.copyWith(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress.dailyGoalProgress,
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.deepOrange,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Achievements Section
          Row(
            children: [
              Expanded(
                child: Text(
                  s.tr('achievements_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${progress.unlockedAchievements.length} / ${allAchievements.length}',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...allAchievements.map((ach) {
            final unlocked = progress.unlockedAchievements.contains(ach.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: unlocked
                    ? ach.color.withValues(alpha: 0.12)
                    : scheme.surfaceContainerLowest,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: unlocked
                            ? ach.color
                            : scheme.surfaceContainerHighest,
                        foregroundColor: unlocked
                            ? Colors.white
                            : scheme.onSurfaceVariant,
                        child: Icon(ach.icon, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.tr('ach_${ach.id}_title'),
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: unlocked
                                    ? null
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              s.tr('ach_${ach.id}_desc'),
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: unlocked
                              ? ach.color.withValues(alpha: 0.18)
                              : scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: unlocked
                                ? ach.color.withValues(alpha: 0.45)
                                : scheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          unlocked
                              ? s.tr('unlocked_badge')
                              : '+${ach.xpReward} XP',
                          maxLines: 1,
                          softWrap: false,
                          style: textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: unlocked
                                ? ach.color
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      ),
    );
  }

  Widget _buildWeeklyStreakRow(BuildContext context, UserProgress progress) {
    final now = DateTime.now();
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final activeSet = progress.activeDates.toSet();

    final days = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      final key = UserProgress.todayKey(date);
      final isActive =
          activeSet.contains(key) || key == UserProgress.todayKey(now);
      final label = dayLabels[date.weekday - 1];
      return (label: label, active: isActive);
    });

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((d) {
        return Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: d.active
                  ? Colors.deepOrange
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              foregroundColor: d.active
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              child: Icon(
                d.active
                    ? Icons.local_fire_department_rounded
                    : Icons.circle_outlined,
                size: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              d.label,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        );
      }).toList(),
    );
  }
}
