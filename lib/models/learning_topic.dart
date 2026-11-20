import 'package:flutter/material.dart';

/// User-selected thematic domain for personalizing all AI-generated
/// vocabulary examples, exercises, exams, and reading rule samples.
enum LearningTopic {
  neutral(
    id: 'neutral',
    titleKey: 'topic_neutral_title',
    descKey: 'topic_neutral_desc',
    icon: Icons.public_rounded,
    aiPromptContext:
        'General, well-balanced everyday and standard contexts (neutral topic).',
  ),
  dailyLife(
    id: 'daily_life',
    titleKey: 'topic_daily_life_title',
    descKey: 'topic_daily_life_desc',
    icon: Icons.shopping_bag_rounded,
    aiPromptContext:
        'Everyday domestic life, groceries, shopping, cooking, housing, bills, and local services.',
  ),
  workCareer(
    id: 'work_career',
    titleKey: 'topic_work_career_title',
    descKey: 'topic_work_career_desc',
    icon: Icons.work_rounded,
    aiPromptContext:
        'Work, career, office communication, meetings, job interviews, emails, teamwork, and projects.',
  ),
  travel(
    id: 'travel',
    titleKey: 'topic_travel_title',
    descKey: 'topic_travel_desc',
    icon: Icons.flight_takeoff_rounded,
    aiPromptContext:
        'Travel, airports, hotels, public transport, navigation, restaurants, and sightseeing.',
  ),
  medicineHealth(
    id: 'medicine_health',
    titleKey: 'topic_medicine_health_title',
    descKey: 'topic_medicine_health_desc',
    icon: Icons.medical_services_rounded,
    aiPromptContext:
        'Medicine, healthcare, doctor appointments, pharmacy, symptoms, wellbeing, and healthy habits.',
  ),
  friendsSocial(
    id: 'friends_social',
    titleKey: 'topic_friends_social_title',
    descKey: 'topic_friends_social_desc',
    icon: Icons.groups_rounded,
    aiPromptContext:
        'Casual conversation with friends, hobbies, invitations, weekend plans, emotions, and social hangouts.',
  );

  const LearningTopic({
    required this.id,
    required this.titleKey,
    required this.descKey,
    required this.icon,
    required this.aiPromptContext,
  });

  final String id;
  final String titleKey;
  final String descKey;
  final IconData icon;
  final String aiPromptContext;

  bool get isNeutral => this == LearningTopic.neutral;

  /// Compact prompt instruction appended to all AI requests.
  String get aiPromptDirective {
    if (isNeutral) {
      return 'Learning focus: Neutral / general universal context (balanced everyday topics).';
    }
    return 'Learning focus domain: $aiPromptContext Prioritize words, examples, dialogues, and scenarios from this domain wherever natural.';
  }

  static LearningTopic fromId(String? rawId) {
    final normalized = (rawId ?? '').trim().toLowerCase();
    for (final topic in LearningTopic.values) {
      if (topic.id == normalized) return topic;
    }
    return LearningTopic.neutral;
  }
}
