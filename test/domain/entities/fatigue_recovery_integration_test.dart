import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/domain/entities/entities.dart';

void main() {
  group('Fatigue and Recovery System Integration', () {
    late AvatarState avatarState;
    late RecoveryState chestRecovery;
    late FatigueEvent fatigueEvent;

    setUp(() {
      avatarState = AvatarState.fresh(
        id: 'avatar-1',
        userId: 'user-1',
        muscleGroupIds: ['chest', 'triceps', 'shoulders'],
      );

      chestRecovery = RecoveryState.fresh(
        id: 'recovery-1',
        muscleGroupId: 'chest',
      );

      fatigueEvent = FatigueEvent.fromWorkoutData(
        id: 'fatigue-1',
        muscleGroupId: 'chest',
        fatigueScore: 80.0,
        workoutSessionId: 'session-1',
      );
    });

    test('should simulate complete workout cycle with fatigue and recovery', () {
      // Initial state - fresh and ready
      expect(chestRecovery.readinessLevel, equals(ReadinessLevel.ready));
      expect(chestRecovery.currentFatigue, equals(0.0));

      // After workout - fatigued
      final postWorkoutRecovery = chestRecovery.updateFatigue(
        newFatigue: fatigueEvent.fatigueScore,
        newReadinessLevel: ReadinessLevel.fatigued,
        workoutTime: DateTime.now(),
      );

      expect(postWorkoutRecovery.readinessLevel, equals(ReadinessLevel.fatigued));
      expect(postWorkoutRecovery.currentFatigue, equals(80.0));
      expect(postWorkoutRecovery.initialFatigue, equals(80.0));

      // Simulate recovery after 24 hours
      final recoveredFatigue = FatigueCalculations.calculateRecovery(
        initialFatigue: 80.0,
        timeElapsedHours: 24.0,
        muscleGroupId: 'chest',
      );

      final partialRecovery = postWorkoutRecovery.updateRecovery(
        newFatigue: recoveredFatigue,
        newReadinessLevel: FatigueCalculations.getReadinessLevel(recoveredFatigue),
      );

      expect(partialRecovery.currentFatigue, lessThan(80.0));
      expect(partialRecovery.readinessLevel, equals(ReadinessLevel.warm));

      // Full recovery after 48+ hours
      final fullyRecoveredFatigue = FatigueCalculations.calculateRecovery(
        initialFatigue: 80.0,
        timeElapsedHours: 72.0,
        muscleGroupId: 'chest',
      );

      final fullRecovery = partialRecovery.updateRecovery(
        newFatigue: fullyRecoveredFatigue,
        newReadinessLevel: FatigueCalculations.getReadinessLevel(fullyRecoveredFatigue),
      );

      expect(fullRecovery.readinessLevel, equals(ReadinessLevel.ready));
      expect(fullRecovery.recoveryPercentage, greaterThan(0.8));
    });

    test('should handle avatar growth based on recovery state', () {
      // Scenario 1: Training in ready state with progression
      final growthPoints = AvatarState.calculateGrowthPoints(
        achievedProgression: true,
        preWorkoutReadiness: ReadinessLevel.ready,
      );

      final grownAvatar = avatarState.addGrowthPoints(
        muscleGroupId: 'chest',
        points: growthPoints,
      );

      expect(growthPoints, equals(15.0)); // Base 10 * 1.5 bonus
      expect(grownAvatar.getGrowthPointsForMuscleGroup('chest'), equals(15.0));

      // Scenario 2: Training in fatigued state (overtraining penalty)
      final penalizedPoints = AvatarState.calculateGrowthPoints(
        achievedProgression: true,
        preWorkoutReadiness: ReadinessLevel.fatigued,
      );

      expect(penalizedPoints, equals(5.0)); // Base 10 * 0.5 penalty

      // Scenario 3: No progression achieved
      final noProgressPoints = AvatarState.calculateGrowthPoints(
        achievedProgression: false,
        preWorkoutReadiness: ReadinessLevel.ready,
      );

      expect(noProgressPoints, equals(0.0));
    });

    test('should create appropriate notifications for recovery events', () {
      // Recovery complete notification
      final recoveryNotification = Notification.recoveryComplete(
        id: 'notif-1',
        userId: 'user-1',
        muscleGroupName: 'Chest',
        scheduledFor: DateTime.now().add(Duration(hours: 48)),
      );

      expect(recoveryNotification.type, equals(NotificationType.recoveryComplete));
      expect(recoveryNotification.isScheduled, isTrue);
      expect(recoveryNotification.data['muscleGroup'], equals('Chest'));

      // PR achievement notification
      final prNotification = Notification.prAchieved(
        id: 'notif-2',
        userId: 'user-1',
        exerciseName: 'Bench Press',
        weight: 100.0,
        reps: 5,
      );

      expect(prNotification.type, equals(NotificationType.prAchieved));
      expect(prNotification.priority, equals(NotificationPriority.high));
      expect(prNotification.data['weight'], equals(100.0));

      // Avatar level up notification
      final levelUpNotification = Notification.avatarLevelUp(
        id: 'notif-3',
        userId: 'user-1',
        muscleGroupName: 'Chest',
        newLevel: 2,
      );

      expect(levelUpNotification.type, equals(NotificationType.avatarLevelUp));
      expect(levelUpNotification.data['level'], equals(2));
    });

    test('should validate PR records and track improvements', () {
      final initialPR = PRRecord.fromWorkoutSet(
        id: 'pr-1',
        userId: 'user-1',
        exerciseId: 'bench-press',
        weight: 80.0,
        reps: 5,
        achievedAt: DateTime.now().subtract(Duration(days: 30)),
      );

      final newPR = PRRecord.fromWorkoutSet(
        id: 'pr-2',
        userId: 'user-1',
        exerciseId: 'bench-press',
        weight: 85.0,
        reps: 5,
        achievedAt: DateTime.now(),
      );

      expect(newPR.isBetterThan(initialPR), isTrue);
      expect(newPR.isSignificantImprovement(initialPR), isTrue);
      
      final improvementPercentage = newPR.calculateImprovementPercentage(initialPR);
      expect(improvementPercentage, greaterThan(2.5));
    });

    test('should handle template creation and muscle group targeting', () {
      final pushTemplate = Template(
        id: 'template-1',
        userId: 'user-1',
        name: 'Push Day',
        description: 'Chest, shoulders, triceps',
        exercises: [
          TemplateExercise(
            exerciseId: 'bench-press',
            sets: 3,
            targetReps: 8,
            restSeconds: 180,
            order: 1,
            primaryMuscleGroups: ['chest'],
            secondaryMuscleGroups: ['triceps', 'shoulders'],
            targetWeight: 80.0,
          ),
          TemplateExercise(
            exerciseId: 'overhead-press',
            sets: 3,
            targetReps: 10,
            restSeconds: 120,
            order: 2,
            primaryMuscleGroups: ['shoulders'],
            secondaryMuscleGroups: ['triceps'],
            targetWeight: 50.0,
          ),
        ],
        createdAt: DateTime.now(),
      );

      expect(pushTemplate.isValid, isTrue);
      expect(pushTemplate.workoutSplit, equals('Push'));
      expect(pushTemplate.targetsMuscleGroup('chest'), isTrue);
      expect(pushTemplate.targetsMuscleGroup('back'), isFalse);
      expect(pushTemplate.isSuitableForGoal(TrainingGoal.hypertrophy), isTrue);
      expect(pushTemplate.totalVolume, equals(3420.0)); // (80*8*3) + (50*10*3)
    });

    test('should validate all constants are properly defined', () {
      // Test that all major muscle groups have recovery constants
      final majorMuscleGroups = ['chest', 'back', 'quadriceps', 'hamstrings', 'glutes', 'shoulders', 'biceps', 'triceps'];
      
      for (final muscleGroup in majorMuscleGroups) {
        expect(RECOVERY_TAU.containsKey(muscleGroup), isTrue, 
               reason: 'Missing recovery tau for $muscleGroup');
        expect(FATIGUE_MULTIPLIERS.containsKey(muscleGroup), isTrue,
               reason: 'Missing fatigue multiplier for $muscleGroup');
        expect(RECOVERY_TAU[muscleGroup]!, greaterThan(0),
               reason: 'Invalid recovery tau for $muscleGroup');
        expect(FATIGUE_MULTIPLIERS[muscleGroup]!, greaterThan(0),
               reason: 'Invalid fatigue multiplier for $muscleGroup');
      }

      // Test threshold constants
      expect(READY_THRESHOLD, equals(30.0));
      expect(WARM_THRESHOLD, equals(70.0));
      expect(GROWTH_POINTS_BASE, equals(10.0));
      expect(OVERTRAINING_PENALTY, equals(0.5));
      expect(OPTIMAL_RECOVERY_BONUS, equals(1.5));
    });
  });
}