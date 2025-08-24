import '../entities/enums.dart';
import '../entities/avatar_state.dart';
import '../entities/workout_session.dart';
import '../entities/pr_record.dart';

/// System for managing badges and achievements
class BadgeSystem {
  /// Available badge types
  static const String FIRST_WORKOUT = 'first_workout';
  static const String FIRST_PR = 'first_pr';
  static const String STREAK_7_DAYS = 'streak_7_days';
  static const String STREAK_30_DAYS = 'streak_30_days';
  static const String STREAK_100_DAYS = 'streak_100_days';
  static const String LEVEL_10_MUSCLE = 'level_10_muscle';
  static const String LEVEL_25_MUSCLE = 'level_25_muscle';
  static const String LEVEL_50_MUSCLE = 'level_50_muscle';
  static const String ALL_MUSCLE_GROUPS_LEVEL_5 = 'all_muscle_groups_level_5';
  static const String OPTIMAL_RECOVERY_MASTER = 'optimal_recovery_master';
  static const String PROGRESSION_MASTER = 'progression_master';
  static const String VOLUME_MILESTONE_1000 = 'volume_milestone_1000';
  static const String VOLUME_MILESTONE_10000 = 'volume_milestone_10000';
  static const String DELOAD_WISDOM = 'deload_wisdom';
  static const String CONSISTENCY_CHAMPION = 'consistency_champion';

  /// Checks for newly earned badges after a workout session
  List<String> checkForNewBadges({
    required AvatarState currentState,
    required WorkoutSession session,
    required List<WorkoutSession> allSessions,
    required List<PRRecord> prRecords,
    required int currentStreak,
  }) {
    final newBadges = <String>[];
    
    // First workout badge
    if (!currentState.unlockedBadges.contains(FIRST_WORKOUT) && 
        allSessions.length == 1) {
      newBadges.add(FIRST_WORKOUT);
    }
    
    // First PR badge
    if (!currentState.unlockedBadges.contains(FIRST_PR) && 
        prRecords.isNotEmpty) {
      newBadges.add(FIRST_PR);
    }
    
    // Streak badges
    newBadges.addAll(_checkStreakBadges(currentState, currentStreak));
    
    // Level-based badges
    newBadges.addAll(_checkLevelBadges(currentState));
    
    // Volume milestone badges
    newBadges.addAll(_checkVolumeBadges(currentState, allSessions));
    
    // Special achievement badges
    newBadges.addAll(_checkSpecialBadges(currentState, allSessions));
    
    return newBadges;
  }

  /// Gets badge information including name and description
  BadgeInfo getBadgeInfo(String badgeId, String locale) {
    switch (badgeId) {
      case FIRST_WORKOUT:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '初回ワークアウト' : 'First Workout',
          description: locale == 'ja' 
              ? '最初のワークアウトを完了しました' 
              : 'Completed your first workout',
          icon: '🏋️',
          rarity: BadgeRarity.common,
        );
        
      case FIRST_PR:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '初PR達成' : 'First PR',
          description: locale == 'ja' 
              ? '初めての個人記録を達成しました' 
              : 'Achieved your first personal record',
          icon: '🏆',
          rarity: BadgeRarity.common,
        );
        
      case STREAK_7_DAYS:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '7日連続' : '7-Day Streak',
          description: locale == 'ja' 
              ? '7日連続でトレーニングしました' 
              : 'Trained for 7 consecutive days',
          icon: '🔥',
          rarity: BadgeRarity.uncommon,
        );
        
      case STREAK_30_DAYS:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '30日連続' : '30-Day Streak',
          description: locale == 'ja' 
              ? '30日連続でトレーニングしました' 
              : 'Trained for 30 consecutive days',
          icon: '🔥🔥',
          rarity: BadgeRarity.rare,
        );
        
      case STREAK_100_DAYS:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '100日連続' : '100-Day Streak',
          description: locale == 'ja' 
              ? '100日連続でトレーニングしました' 
              : 'Trained for 100 consecutive days',
          icon: '🔥🔥🔥',
          rarity: BadgeRarity.legendary,
        );
        
      case LEVEL_10_MUSCLE:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '筋群レベル10' : 'Muscle Level 10',
          description: locale == 'ja' 
              ? 'いずれかの筋群をレベル10に到達させました' 
              : 'Reached level 10 with any muscle group',
          icon: '💪',
          rarity: BadgeRarity.uncommon,
        );
        
      case LEVEL_25_MUSCLE:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '筋群レベル25' : 'Muscle Level 25',
          description: locale == 'ja' 
              ? 'いずれかの筋群をレベル25に到達させました' 
              : 'Reached level 25 with any muscle group',
          icon: '💪💪',
          rarity: BadgeRarity.rare,
        );
        
      case LEVEL_50_MUSCLE:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '筋群レベル50' : 'Muscle Level 50',
          description: locale == 'ja' 
              ? 'いずれかの筋群をレベル50に到達させました' 
              : 'Reached level 50 with any muscle group',
          icon: '💪💪💪',
          rarity: BadgeRarity.legendary,
        );
        
      case ALL_MUSCLE_GROUPS_LEVEL_5:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '全筋群レベル5' : 'All Muscles Level 5',
          description: locale == 'ja' 
              ? '全ての筋群をレベル5以上に到達させました' 
              : 'Reached level 5+ with all muscle groups',
          icon: '🌟',
          rarity: BadgeRarity.rare,
        );
        
      case OPTIMAL_RECOVERY_MASTER:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '最適回復マスター' : 'Optimal Recovery Master',
          description: locale == 'ja' 
              ? '最適回復ウィンドウでのトレーニングを50回達成' 
              : 'Trained in optimal recovery window 50 times',
          icon: '⚡',
          rarity: BadgeRarity.epic,
        );
        
      case PROGRESSION_MASTER:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '漸進マスター' : 'Progression Master',
          description: locale == 'ja' 
              ? '100回の漸進を達成しました' 
              : 'Achieved progression 100 times',
          icon: '📈',
          rarity: BadgeRarity.epic,
        );
        
      case VOLUME_MILESTONE_1000:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? 'ボリューム1000' : 'Volume 1000',
          description: locale == 'ja' 
              ? '累計ボリューム1000kgを達成' 
              : 'Reached 1000kg total volume',
          icon: '📊',
          rarity: BadgeRarity.uncommon,
        );
        
      case VOLUME_MILESTONE_10000:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? 'ボリューム10000' : 'Volume 10000',
          description: locale == 'ja' 
              ? '累計ボリューム10000kgを達成' 
              : 'Reached 10000kg total volume',
          icon: '📊📊',
          rarity: BadgeRarity.epic,
        );
        
      case DELOAD_WISDOM:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? 'デロードの知恵' : 'Deload Wisdom',
          description: locale == 'ja' 
              ? '推奨されたデロード週を実行しました' 
              : 'Followed recommended deload weeks',
          icon: '🧠',
          rarity: BadgeRarity.rare,
        );
        
      case CONSISTENCY_CHAMPION:
        return BadgeInfo(
          id: badgeId,
          name: locale == 'ja' ? '継続チャンピオン' : 'Consistency Champion',
          description: locale == 'ja' 
              ? '6ヶ月間継続してトレーニングしました' 
              : 'Trained consistently for 6 months',
          icon: '👑',
          rarity: BadgeRarity.legendary,
        );
        
      default:
        return BadgeInfo(
          id: badgeId,
          name: 'Unknown Badge',
          description: 'Unknown badge',
          icon: '❓',
          rarity: BadgeRarity.common,
        );
    }
  }

  /// Gets all available badges
  List<String> getAllBadgeIds() {
    return [
      FIRST_WORKOUT,
      FIRST_PR,
      STREAK_7_DAYS,
      STREAK_30_DAYS,
      STREAK_100_DAYS,
      LEVEL_10_MUSCLE,
      LEVEL_25_MUSCLE,
      LEVEL_50_MUSCLE,
      ALL_MUSCLE_GROUPS_LEVEL_5,
      OPTIMAL_RECOVERY_MASTER,
      PROGRESSION_MASTER,
      VOLUME_MILESTONE_1000,
      VOLUME_MILESTONE_10000,
      DELOAD_WISDOM,
      CONSISTENCY_CHAMPION,
    ];
  }

  /// Checks for streak-based badges
  List<String> _checkStreakBadges(AvatarState currentState, int currentStreak) {
    final newBadges = <String>[];
    
    if (currentStreak >= 7 && !currentState.unlockedBadges.contains(STREAK_7_DAYS)) {
      newBadges.add(STREAK_7_DAYS);
    }
    
    if (currentStreak >= 30 && !currentState.unlockedBadges.contains(STREAK_30_DAYS)) {
      newBadges.add(STREAK_30_DAYS);
    }
    
    if (currentStreak >= 100 && !currentState.unlockedBadges.contains(STREAK_100_DAYS)) {
      newBadges.add(STREAK_100_DAYS);
    }
    
    return newBadges;
  }

  /// Checks for level-based badges
  List<String> _checkLevelBadges(AvatarState currentState) {
    final newBadges = <String>[];
    final maxLevel = currentState.maxLevel;
    
    if (maxLevel >= 10 && !currentState.unlockedBadges.contains(LEVEL_10_MUSCLE)) {
      newBadges.add(LEVEL_10_MUSCLE);
    }
    
    if (maxLevel >= 25 && !currentState.unlockedBadges.contains(LEVEL_25_MUSCLE)) {
      newBadges.add(LEVEL_25_MUSCLE);
    }
    
    if (maxLevel >= 50 && !currentState.unlockedBadges.contains(LEVEL_50_MUSCLE)) {
      newBadges.add(LEVEL_50_MUSCLE);
    }
    
    // Check if all muscle groups are level 5+
    if (!currentState.unlockedBadges.contains(ALL_MUSCLE_GROUPS_LEVEL_5)) {
      final allLevel5Plus = currentState.muscleGroupLevels.values
          .every((level) => level >= 5);
      if (allLevel5Plus && currentState.muscleGroupLevels.isNotEmpty) {
        newBadges.add(ALL_MUSCLE_GROUPS_LEVEL_5);
      }
    }
    
    return newBadges;
  }

  /// Checks for volume milestone badges
  List<String> _checkVolumeBadges(AvatarState currentState, List<WorkoutSession> allSessions) {
    final newBadges = <String>[];
    
    // Calculate total volume across all sessions
    final totalVolume = allSessions.fold(0.0, (sum, session) => sum + session.totalVolume);
    
    if (totalVolume >= 1000 && !currentState.unlockedBadges.contains(VOLUME_MILESTONE_1000)) {
      newBadges.add(VOLUME_MILESTONE_1000);
    }
    
    if (totalVolume >= 10000 && !currentState.unlockedBadges.contains(VOLUME_MILESTONE_10000)) {
      newBadges.add(VOLUME_MILESTONE_10000);
    }
    
    return newBadges;
  }

  /// Checks for special achievement badges
  List<String> _checkSpecialBadges(AvatarState currentState, List<WorkoutSession> allSessions) {
    final newBadges = <String>[];
    
    // Consistency champion - 6 months of training (simplified check)
    if (!currentState.unlockedBadges.contains(CONSISTENCY_CHAMPION)) {
      if (allSessions.length >= 50) {
        // Find earliest and latest session dates
        final sessionDates = allSessions.map((s) => s.startTime).toList()..sort();
        final firstSession = sessionDates.first;
        final lastSession = sessionDates.last;
        final daysDifference = lastSession.difference(firstSession).inDays;
        
        if (daysDifference >= 180) {
          newBadges.add(CONSISTENCY_CHAMPION);
        }
      }
    }
    
    return newBadges;
  }
}

/// Badge information including metadata
class BadgeInfo {
  final String id;
  final String name;
  final String description;
  final String icon;
  final BadgeRarity rarity;

  const BadgeInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.rarity,
  });
}

/// Badge rarity levels
enum BadgeRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary;

  String getLocalizedName(String locale) {
    switch (this) {
      case BadgeRarity.common:
        return locale == 'ja' ? 'コモン' : 'Common';
      case BadgeRarity.uncommon:
        return locale == 'ja' ? 'アンコモン' : 'Uncommon';
      case BadgeRarity.rare:
        return locale == 'ja' ? 'レア' : 'Rare';
      case BadgeRarity.epic:
        return locale == 'ja' ? 'エピック' : 'Epic';
      case BadgeRarity.legendary:
        return locale == 'ja' ? 'レジェンダリー' : 'Legendary';
    }
  }

  /// Gets color associated with rarity
  String get colorHex {
    switch (this) {
      case BadgeRarity.common:
        return '#9E9E9E'; // Gray
      case BadgeRarity.uncommon:
        return '#4CAF50'; // Green
      case BadgeRarity.rare:
        return '#2196F3'; // Blue
      case BadgeRarity.epic:
        return '#9C27B0'; // Purple
      case BadgeRarity.legendary:
        return '#FF9800'; // Orange
    }
  }
}