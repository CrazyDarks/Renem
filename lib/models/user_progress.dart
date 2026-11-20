import 'package:flutter/material.dart';

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.xpReward,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int xpReward;
}

const List<AchievementDef> allAchievements = [
  AchievementDef(
    id: 'first_word',
    title: 'Перший крок',
    description: 'Додайте перше слово у власний словник',
    icon: Icons.auto_awesome_rounded,
    color: Colors.green,
    xpReward: 20,
  ),
  AchievementDef(
    id: 'vocab_15',
    title: 'Колекціонер слів',
    description: 'Зберіть 15 слів у словнику',
    icon: Icons.collections_bookmark_rounded,
    color: Colors.blue,
    xpReward: 50,
  ),
  AchievementDef(
    id: 'vocab_50',
    title: 'Поліглот',
    description: 'Зберіть 50 слів у словнику',
    icon: Icons.stars_rounded,
    color: Colors.purple,
    xpReward: 150,
  ),
  AchievementDef(
    id: 'streak_3',
    title: 'Ударний темп: 3 дні',
    description: 'Займайтеся 3 дні поспіль без перерви',
    icon: Icons.local_fire_department_rounded,
    color: Colors.deepOrange,
    xpReward: 40,
  ),
  AchievementDef(
    id: 'streak_7',
    title: 'Тижневий вогонь: 7 днів',
    description: 'Тримайте стрік 7 днів поспіль',
    icon: Icons.whatshot_rounded,
    color: Colors.redAccent,
    xpReward: 120,
  ),
  AchievementDef(
    id: 'srs_20',
    title: 'Майстер інтервалів (SRS)',
    description: 'Повторіть 20 карток за системою SRS',
    icon: Icons.psychology_rounded,
    color: Colors.teal,
    xpReward: 60,
  ),
  AchievementDef(
    id: 'pronunciation_star',
    title: 'Чиста вимова',
    description: 'Наберіть 85%+ точності вимови в мікрофон 5 разів',
    icon: Icons.mic_rounded,
    color: Colors.indigo,
    xpReward: 80,
  ),
  AchievementDef(
    id: 'youtube_learner',
    title: 'Кіноман',
    description: 'Додайте своє перше YouTube відео з субтитрами',
    icon: Icons.ondemand_video_rounded,
    color: Colors.pink,
    xpReward: 50,
  ),
  AchievementDef(
    id: 'exam_master',
    title: 'Відмінник CEFR',
    description: 'Складіть тестовий іспит із 20 питань на 80% або вище',
    icon: Icons.emoji_events_rounded,
    color: Colors.amber,
    xpReward: 100,
  ),
];

class FriendProfile {
  const FriendProfile({
    required this.id,
    required this.name,
    required this.friendCode,
    this.xp = 180,
    this.streak = 3,
    this.targetLanguageCode = 'en',
    this.cheeredToday = false,
  });

  final String id;
  final String name;
  final String friendCode;
  final int xp;
  final int streak;
  final String targetLanguageCode;
  final bool cheeredToday;

  int get level => (xp ~/ 100) + 1;

  FriendProfile copyWith({
    String? id,
    String? name,
    String? friendCode,
    int? xp,
    int? streak,
    String? targetLanguageCode,
    bool? cheeredToday,
  }) {
    return FriendProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      friendCode: friendCode ?? this.friendCode,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      targetLanguageCode: targetLanguageCode ?? this.targetLanguageCode,
      cheeredToday: cheeredToday ?? this.cheeredToday,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'friendCode': friendCode,
        'xp': xp,
        'streak': streak,
        'targetLanguageCode': targetLanguageCode,
        'cheeredToday': cheeredToday,
      };

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    return FriendProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Reman Friend',
      friendCode: json['friendCode'] as String? ?? 'REMAN-1000',
      xp: (json['xp'] as num?)?.toInt() ?? 150,
      streak: (json['streak'] as num?)?.toInt() ?? 2,
      targetLanguageCode: json['targetLanguageCode'] as String? ?? 'en',
      cheeredToday: json['cheeredToday'] as bool? ?? false,
    );
  }
}

class DuelRecord {
  const DuelRecord({
    required this.id,
    required this.myScore,
    required this.correctAnswers,
    required this.maxCombo,
    this.friendName,
    this.friendScore,
    required this.languageCode,
    required this.playedAt,
  });

  final String id;
  final int myScore;
  final int correctAnswers;
  final int maxCombo;
  final String? friendName;
  final int? friendScore;
  final String languageCode;
  final DateTime playedAt;

  bool get isFriendChallenge =>
      friendName != null && friendName!.isNotEmpty && friendScore != null;
  bool get isWin => !isFriendChallenge || myScore >= (friendScore ?? 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'myScore': myScore,
        'correctAnswers': correctAnswers,
        'maxCombo': maxCombo,
        'friendName': friendName,
        'friendScore': friendScore,
        'languageCode': languageCode,
        'playedAt': playedAt.toIso8601String(),
      };

  factory DuelRecord.fromJson(Map<String, dynamic> json) {
    return DuelRecord(
      id: json['id'] as String? ?? '${DateTime.now().millisecondsSinceEpoch}',
      myScore: (json['myScore'] as num?)?.toInt() ?? 0,
      correctAnswers: (json['correctAnswers'] as num?)?.toInt() ?? 0,
      maxCombo: (json['maxCombo'] as num?)?.toInt() ?? 0,
      friendName: json['friendName'] as String?,
      friendScore: (json['friendScore'] as num?)?.toInt(),
      languageCode: json['languageCode'] as String? ?? 'en',
      playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class UserProgress {
  const UserProgress({
    this.displayName = 'Учень Reman',
    this.email = '',
    this.googleId = '',
    this.googlePhotoUrl = '',
    this.avatarBase64 = '',
    this.currentStreak = 1,
    this.longestStreak = 1,
    this.streakFreezes = 2,
    this.xp = 0,
    this.dailyGoalXp = 50,
    this.todayXp = 0,
    this.lastActiveDate = '',
    this.activeDates = const [],
    this.unlockedAchievements = const [],
    this.friends = const [],
    this.totalSrsReviews = 0,
    this.pronunciationHighScores = 0,
    this.examsPassed = 0,
    this.bestExamPercentage = 0,
    this.youtubeVideosAdded = 0,
    this.completedPathNodes = const [],
    this.bestDuelScore = 0,
    this.bestDuelCombo = 0,
    this.duelHistory = const [],
  });

  final String displayName;
  final String email;
  final String googleId;
  final String googlePhotoUrl;
  final String avatarBase64;
  final int currentStreak;
  final int longestStreak;
  final int streakFreezes;
  final int xp;
  final int dailyGoalXp;
  final int todayXp;
  final String lastActiveDate; // YYYY-MM-DD
  final List<String> activeDates; // last 30 active YYYY-MM-DD dates
  final List<String> unlockedAchievements;
  final List<FriendProfile> friends;
  final int totalSrsReviews;
  final int pronunciationHighScores;
  final int examsPassed;
  final int bestExamPercentage;
  final int youtubeVideosAdded;
  final List<String> completedPathNodes;
  final int bestDuelScore;
  final int bestDuelCombo;
  final List<DuelRecord> duelHistory;

  bool get isGoogleConnected => email.isNotEmpty || googleId.isNotEmpty;
  int get level => (xp ~/ 100) + 1;
  double get dailyGoalProgress =>
      dailyGoalXp <= 0 ? 1.0 : (todayXp / dailyGoalXp).clamp(0.0, 1.0);

  String get remanFriendCode {
    final hash = displayName.codeUnits.fold<int>(0, (acc, c) => (acc * 31 + c) & 0xFFFF);
    final numCode = (1000 + (hash % 9000)).toString();
    return 'REMAN-$numCode';
  }

  UserProgress copyWith({
    String? displayName,
    String? email,
    String? googleId,
    String? googlePhotoUrl,
    String? avatarBase64,
    int? currentStreak,
    int? longestStreak,
    int? streakFreezes,
    int? xp,
    int? dailyGoalXp,
    int? todayXp,
    String? lastActiveDate,
    List<String>? activeDates,
    List<String>? unlockedAchievements,
    List<FriendProfile>? friends,
    int? totalSrsReviews,
    int? pronunciationHighScores,
    int? examsPassed,
    int? bestExamPercentage,
    int? youtubeVideosAdded,
    List<String>? completedPathNodes,
    int? bestDuelScore,
    int? bestDuelCombo,
    List<DuelRecord>? duelHistory,
  }) {
    return UserProgress(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      googleId: googleId ?? this.googleId,
      googlePhotoUrl: googlePhotoUrl ?? this.googlePhotoUrl,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      streakFreezes: streakFreezes ?? this.streakFreezes,
      xp: xp ?? this.xp,
      dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
      todayXp: todayXp ?? this.todayXp,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      activeDates: activeDates ?? this.activeDates,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      friends: friends ?? this.friends,
      totalSrsReviews: totalSrsReviews ?? this.totalSrsReviews,
      pronunciationHighScores:
          pronunciationHighScores ?? this.pronunciationHighScores,
      examsPassed: examsPassed ?? this.examsPassed,
      bestExamPercentage: bestExamPercentage ?? this.bestExamPercentage,
      youtubeVideosAdded: youtubeVideosAdded ?? this.youtubeVideosAdded,
      completedPathNodes: completedPathNodes ?? this.completedPathNodes,
      bestDuelScore: bestDuelScore ?? this.bestDuelScore,
      bestDuelCombo: bestDuelCombo ?? this.bestDuelCombo,
      duelHistory: duelHistory ?? this.duelHistory,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email': email,
        'googleId': googleId,
        'googlePhotoUrl': googlePhotoUrl,
        'avatarBase64': avatarBase64,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'streakFreezes': streakFreezes,
        'xp': xp,
        'dailyGoalXp': dailyGoalXp,
        'todayXp': todayXp,
        'lastActiveDate': lastActiveDate,
        'activeDates': activeDates,
        'unlockedAchievements': unlockedAchievements,
        'friends': friends.map((f) => f.toJson()).toList(),
        'totalSrsReviews': totalSrsReviews,
        'pronunciationHighScores': pronunciationHighScores,
        'examsPassed': examsPassed,
        'bestExamPercentage': bestExamPercentage,
        'youtubeVideosAdded': youtubeVideosAdded,
        'completedPathNodes': completedPathNodes,
        'bestDuelScore': bestDuelScore,
        'bestDuelCombo': bestDuelCombo,
        'duelHistory': duelHistory.map((d) => d.toJson()).toList(),
      };

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    var rawName = json['displayName'] as String? ?? 'Учень Reman';
    if (rawName == 'Учень LanguageMa') {
      rawName = 'Учень Reman';
    } else if (rawName == 'LanguageMa Pro') {
      rawName = 'Reman Pro';
    }
    return UserProgress(
      displayName: rawName,
      email: json['email'] as String? ?? '',
      googleId: json['googleId'] as String? ?? '',
      googlePhotoUrl: json['googlePhotoUrl'] as String? ?? '',
      avatarBase64: json['avatarBase64'] as String? ?? '',
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 1,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 1,
      streakFreezes: (json['streakFreezes'] as num?)?.toInt() ?? 2,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      dailyGoalXp: (json['dailyGoalXp'] as num?)?.toInt() ?? 50,
      todayXp: (json['todayXp'] as num?)?.toInt() ?? 0,
      lastActiveDate: json['lastActiveDate'] as String? ?? '',
      activeDates: (json['activeDates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      unlockedAchievements: (json['unlockedAchievements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      friends: (json['friends'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(FriendProfile.fromJson)
              .toList() ??
          const [],
      totalSrsReviews: (json['totalSrsReviews'] as num?)?.toInt() ?? 0,
      pronunciationHighScores:
          (json['pronunciationHighScores'] as num?)?.toInt() ?? 0,
      examsPassed: (json['examsPassed'] as num?)?.toInt() ?? 0,
      bestExamPercentage: (json['bestExamPercentage'] as num?)?.toInt() ?? 0,
      youtubeVideosAdded: (json['youtubeVideosAdded'] as num?)?.toInt() ?? 0,
      completedPathNodes: (json['completedPathNodes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      bestDuelScore: (json['bestDuelScore'] as num?)?.toInt() ?? 0,
      bestDuelCombo: (json['bestDuelCombo'] as num?)?.toInt() ?? 0,
      duelHistory: (json['duelHistory'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(DuelRecord.fromJson)
              .toList() ??
          const [],
    );
  }

  static String todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
