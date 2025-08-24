import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/entities/avatar_state.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/pr_record.dart';
import 'package:cycle_avatar/domain/services/badge_system.dart';

void main() {
  group('BadgeSystem', () {
    late BadgeSystem badgeSystem;
    late AvatarState testAvatarState;
    late WorkoutSession testSession;

    setUp(() {
      badgeSystem = BadgeSystem();
      
      testAvatarState = AvatarState(
        id: 'test_avatar',
        userId: 'test_user',
        muscleGroupLevels: {
          'chest': 5,
          'back': 3,
          'legs': 4,
        },
        growthPoints: {
          'chest': 2500.0,
          'back': 900.0,
          'legs': 1600.0,
        },
        totalGrowthPoints: 5000.0,
        unlockedBadges: [], // Start with no badges
      );

      testSession = WorkoutSession(
        id: 'test_session',
        userId: 'test_user',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
        sessionType: SessionType.strength,
        createdAt: DateTime.now(),
        sets: [
          WorkoutSet(
            id: 'set_1',
            sessionId: 'test_session',
            exerciseId: 'bench_press',
            weight: 100.0,
            reps: 8,
            rpe: 8,
            setOrder: 1,
            createdAt: DateTime.now(),
          ),
        ],
      );
    });

    group('checkForNewBadges', () {
      test('should award first workout badge for first session', () {
        final result = badgeSystem.checkForNewBadges(
          currentState: testAvatarState,
          session: testSession,
          allSessions: [testSession], // Only one session
          prRecords: [],
          currentStreak: 1,
        );

        expect(result, contains(BadgeSystem.FIRST_WORKOUT));
      });

      test('should not award first workout badge if already unlocked', () {
        final stateWithBadge = testAvatarState.copyWith(
          unlockedBadges: [BadgeSystem.FIRST_WORKOUT],
        );

        final result = badgeSystem.checkForNewBadges(
          currentState: stateWithBadge,
          session: testSession,
          allSessions: [testSession],
          prRecords: [],
          currentStreak: 1,
        );

        expect(result, isNot(contains(BadgeSystem.FIRST_WORKOUT)));
      });

      test('should award first PR badge when PR records exist', () {
        final prRecord = PRRecord(
          id: 'pr_1',
          userId: 'test_user',
          exerciseId: 'bench_press',
          weight: 100.0,
          reps: 8,
          estimatedMax: 125.0,
          achievedAt: DateTime.now(),
        );

        final result = badgeSystem.checkForNewBadges(
          currentState: testAvatarState,
          session: testSession,
          allSessions: [testSession],
          prRecords: [prRecord],
          currentStreak: 1,
        );

        expect(result, contains(BadgeSystem.FIRST_PR));
      });

      test('should award streak badges for appropriate streaks', () {
        // Test 7-day streak
        var result = badgeSystem.checkForNewBadges(
          currentState: testAvatarState,
          session: testSession,
          allSessions: [testSession],
          prRecords: [],
          currentStreak: 7,
        );
        expect(result, contains(BadgeSystem.STREAK_7_DAYS));

        // Test 30-day streak
        result = badgeSystem.checkForNewBadges(
          currentState: testAvatarState,
          session: testSession,
          allSessions: [testSession],
          prRecords: [],
          currentStreak: 30,
        );
        expect(result, contains(BadgeSystem.STREAK_30_DAYS));

        // Test 100-day streak
        result = badgeSystem.checkForNewBadges(
          currentState: testAvatarState,
          session: testSession,
          allSessions: [testSession],
          prRecords: [],
          currentStreak: 100,
        );
        expect(result, contains(BadgeSystem.STREAK_100_DAYS));
      });

      test('should award level-based badges', () {
        // Test level 10 badge
        final stateLevel10 = testAvatarState.copyWith(
          muscleGroupLevels: {'chest': 10, 'back': 5, 'legs': 3},
        );

        var result = badgeSystem.checkForNewBadges(
          currentState: stateLevel10,
          session: testSession,
          allSessions: [testSession],
          prRecords: [],
          currentStreak: 1,
        );
        expect(result, contains(BadgeSystem.LEVEL_10_MUSCLE));

        // Test level 25 badge
        final stateLevel25 = testAvatarState.copyWith(
          muscleGroupLevels: {'chest': 25, 'back': 5, 'legs': 3},
        );

        result = badgeSystem.checkForNewBadges(
          currentState: stateLevel25,
          session: testSession,
          allSessions: [testSession],
          prRecords: [],
          currentStreak: 1,
        );
        expect(result, contains(BadgeSystem.LEVEL_25_MUSCLE));

        // Test level 50 badge
        final stateLevel50 = testAvatarState.copyWith(
          muscleGroupLevels: {'chest': 50, 'back': 5, 'legs': 3},
        );

        result = badgeSystem.checkForNewBadges(
          currentState: stateLevel50,
          session: testSession,
          allSessions: [testSession],
          prRecords: [],
          currentStreak: 1,
        );
        expect(result, contains(BadgeSystem.LEVEL_50_MUSCLE));
      });

      test('should award all muscle groups level 5 badge', () {
        final stateAllLevel5 = testAvatarState.copyWith(
          muscleGroupLevels: {
            'chest': 5,
            'back': 6,
            'legs': 7,
            'shoulders': 5,
            'arms': 8,
          },
        );

        final result = badgeSystem.checkForNewBadges(
          currentState: stateAllLevel5,
          session: testSession,
          allSessions: [testSession],
          prRecords: [],
          currentStreak: 1,
        );

        expect(result, contains(BadgeSystem.ALL_MUSCLE_GROUPS_LEVEL_5));
      });

      test('should award volume milestone badges', () {
        // Create sessions with high volume
        final highVolumeSessions = List.generate(10, (index) => 
          WorkoutSession(
            id: 'session_$index',
            userId: 'test_user',
            startTime: DateTime.now().subtract(Duration(days: index)),
            endTime: DateTime.now().subtract(Duration(days: index, hours: -1)),
            sessionType: SessionType.strength,
            createdAt: DateTime.now().subtract(Duration(days: index)),
            sets: [
              WorkoutSet(
                id: 'set_${index}_1',
                sessionId: 'session_$index',
                exerciseId: 'squat',
                weight: 150.0, // High weight
                reps: 10,
                rpe: 8,
                setOrder: 1,
                createdAt: DateTime.now().subtract(Duration(days: index)),
              ),
            ],
          ),
        );

        final result = badgeSystem.checkForNewBadges(
          currentState: testAvatarState,
          session: testSession,
          allSessions: highVolumeSessions,
          prRecords: [],
          currentStreak: 1,
        );

        // Total volume should exceed 1000kg (10 sessions × 150kg × 10 reps = 15000kg)
        expect(result, contains(BadgeSystem.VOLUME_MILESTONE_1000));
        expect(result, contains(BadgeSystem.VOLUME_MILESTONE_10000));
      });

      test('should award consistency champion badge for long-term training', () {
        // Create sessions spanning 6+ months with sufficient frequency
        final now = DateTime.now();
        final consistentSessions = List.generate(60, (index) => 
          WorkoutSession(
            id: 'session_$index',
            userId: 'test_user',
            startTime: now.subtract(Duration(days: 240 - index * 4)), // Spread over 240 days (>180)
            endTime: now.subtract(Duration(days: 240 - index * 4, hours: -1)),
            sessionType: SessionType.strength,
            createdAt: now.subtract(Duration(days: 220 - index * 3)),
            sets: [
              WorkoutSet(
                id: 'set_${index}_1',
                sessionId: 'session_$index',
                exerciseId: 'squat',
                weight: 100.0,
                reps: 8,
                rpe: 8,
                setOrder: 1,
                createdAt: now.subtract(Duration(days: 240 - index * 4)),
              ),
            ],
          ),
        );

        final result = badgeSystem.checkForNewBadges(
          currentState: testAvatarState,
          session: testSession,
          allSessions: consistentSessions,
          prRecords: [],
          currentStreak: 1,
        );

        expect(result, contains(BadgeSystem.CONSISTENCY_CHAMPION));
      });
    });

    group('getBadgeInfo', () {
      test('should return correct badge info for English locale', () {
        final badgeInfo = badgeSystem.getBadgeInfo(BadgeSystem.FIRST_WORKOUT, 'en');

        expect(badgeInfo.id, equals(BadgeSystem.FIRST_WORKOUT));
        expect(badgeInfo.name, equals('First Workout'));
        expect(badgeInfo.description, equals('Completed your first workout'));
        expect(badgeInfo.icon, equals('🏋️'));
        expect(badgeInfo.rarity, equals(BadgeRarity.common));
      });

      test('should return correct badge info for Japanese locale', () {
        final badgeInfo = badgeSystem.getBadgeInfo(BadgeSystem.FIRST_WORKOUT, 'ja');

        expect(badgeInfo.id, equals(BadgeSystem.FIRST_WORKOUT));
        expect(badgeInfo.name, equals('初回ワークアウト'));
        expect(badgeInfo.description, equals('最初のワークアウトを完了しました'));
        expect(badgeInfo.icon, equals('🏋️'));
        expect(badgeInfo.rarity, equals(BadgeRarity.common));
      });

      test('should return unknown badge info for invalid badge ID', () {
        final badgeInfo = badgeSystem.getBadgeInfo('invalid_badge', 'en');

        expect(badgeInfo.id, equals('invalid_badge'));
        expect(badgeInfo.name, equals('Unknown Badge'));
        expect(badgeInfo.description, equals('Unknown badge'));
        expect(badgeInfo.icon, equals('❓'));
        expect(badgeInfo.rarity, equals(BadgeRarity.common));
      });
    });

    group('getAllBadgeIds', () {
      test('should return all available badge IDs', () {
        final allBadges = badgeSystem.getAllBadgeIds();

        expect(allBadges, contains(BadgeSystem.FIRST_WORKOUT));
        expect(allBadges, contains(BadgeSystem.FIRST_PR));
        expect(allBadges, contains(BadgeSystem.STREAK_7_DAYS));
        expect(allBadges, contains(BadgeSystem.LEVEL_10_MUSCLE));
        expect(allBadges, contains(BadgeSystem.CONSISTENCY_CHAMPION));
        expect(allBadges.length, greaterThan(10));
      });
    });
  });

  group('BadgeRarity', () {
    test('should return correct localized names', () {
      expect(BadgeRarity.common.getLocalizedName('en'), equals('Common'));
      expect(BadgeRarity.common.getLocalizedName('ja'), equals('コモン'));
      expect(BadgeRarity.legendary.getLocalizedName('en'), equals('Legendary'));
      expect(BadgeRarity.legendary.getLocalizedName('ja'), equals('レジェンダリー'));
    });

    test('should return correct color hex codes', () {
      expect(BadgeRarity.common.colorHex, equals('#9E9E9E'));
      expect(BadgeRarity.uncommon.colorHex, equals('#4CAF50'));
      expect(BadgeRarity.rare.colorHex, equals('#2196F3'));
      expect(BadgeRarity.epic.colorHex, equals('#9C27B0'));
      expect(BadgeRarity.legendary.colorHex, equals('#FF9800'));
    });
  });
}