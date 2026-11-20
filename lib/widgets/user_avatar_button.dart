import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../state/app_controller.dart';

class UserAvatarWidget extends StatelessWidget {
  const UserAvatarWidget({
    super.key,
    this.radius = 18,
    this.onTap,
  });

  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final progress = controller.progress;
    final scheme = Theme.of(context).colorScheme;

    Uint8List? customBytes;
    if (progress.avatarBase64.isNotEmpty) {
      try {
        customBytes = base64Decode(progress.avatarBase64);
      } catch (_) {}
    }

    Widget avatar;
    if (customBytes != null) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(customBytes),
      );
    } else if (progress.googlePhotoUrl.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(progress.googlePhotoUrl),
        onBackgroundImageError: (_, _) {},
      );
    } else {
      final initials = progress.displayName.trim().isNotEmpty
          ? progress.displayName.trim()[0].toUpperCase()
          : 'L';
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(
          initials,
          style: TextStyle(
            fontSize: radius * 0.85,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (onTap == null) return avatar;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: avatar,
    );
  }
}

class StreakXpHeaderBadges extends StatelessWidget {
  const StreakXpHeaderBadges({
    super.key,
    required this.onProfileTap,
  });

  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final progress = controller.progress;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onProfileTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: Colors.deepOrange,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${progress.currentStreak}',
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onProfileTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 15,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${progress.xp} XP',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          UserAvatarWidget(
            radius: 15,
            onTap: onProfileTap,
          ),
        ],
      ),
    );
  }
}
