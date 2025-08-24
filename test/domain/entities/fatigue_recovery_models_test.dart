import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/domain/entities/entities.dart';

void main() {
  group('Fatigue and Recovery Models Tests', () {
    test('FatigueEvent should calculate current contribution correctly', () {
      final fatigueEvent = FatigueEvent(
        id: 'test-fatigue-1',
        muscleGroupId: 'chest',
        fatigueScore: 100.0,
        timestamp: DateTime.now().subtract(const Duration(hours: 24)),
        workoutSessionId: 'session-1',
      );

      final contribution = fatigueEvent.calculateCurrentContribution(48.0);
      
      // After 24 hours with tau=48, should be ~60.6% of original
      expect(contribution, closeTo(60.6, 1.0));
    });

    test('RecoveryState should determine readiness level correctly', () {
      final recoveryState = RecoveryState(
        id: 'recovery-1',
        muscleGroupId: 'chest',
        currentFatigue: 25.0,
        lastUpdated: DateTime.now(),
        readinessLevel: ReadinessLevel.ready,
      );

      expect(recoveryState.isReady, isTrue);
      expect(recoveryState.readinessLevel, ReadinessLevel.ready);
    });

    test('AvatarState should calculate growth points correctly', () {
      final growthPoints = AvatarState.calculateGrowthPoints(
        achievedProgression: true,
        preWorkoutReadiness: ReadinessLevel.ready,
        basePoints: 10.0,
      );

      // Should get 1.5x bonus for optimal recovery
      expect(growthPoints, equals(15.0));
    });

    test('PRRecord should detect significant improvements', () {
      final oldPR = PRRecord(
        id: 'pr-1',
        userId: 'user-1',
        exerciseId: 'squat',
        weight: 100.0,
        reps: 5,
        estimatedMax: 112.5,
        achievedAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      final newPR = PRRecord(
        id: 'pr-2',
        userId: 'user-1',
        exerciseId: 'squat',
        weight: 105.0,
        reps: 5,
        estimatedMax: 118.1,
        achievedAt: DateTime.now(),
      );

      expect(newPR.isSignificantImprovement(oldPR), isTrue);
      expect(newPR.calculateImprovementPercentage(oldPR), closeTo(5.0, 0.5));
    });

    test('Template should identify workout split correctly', () {
      final template = Template(
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
          ),
        ],
        createdAt: DateTime.now(),
      );

      expect(template.workoutSplit, equals('Push'));
      expect(template.isSuitableForGoal(TrainingGoal.hypertrophy), isTrue);
    });

    test('Notification should create recovery complete notification', () {
      final notification = Notification.recoveryComplete(
        id: 'notif-1',
        userId: 'user-1',
        muscleGroupName: 'Chest',
        scheduledFor: DateTime.now().add(const Duration(hours: 2)),
        locale: 'en',
      );

      expect(notification.type, NotificationType.recoveryComplete);
      expect(notification.title, contains('Recovery Complete'));
      expect(notification.isScheduled, isTrue);
    });

    test('FatigueCalculations should compute fatigue score correctly', () {
      final fatigueScore = FatigueCalculations.calculateFatigueScore(
        volume: 2400.0, // 3 sets × 8 reps × 100kg
        intensity: 1.0,  // Will be calculated from RPE
        rpe: 8,
        muscleGroupId: 'chest',
      );

      expect(fatigueScore, greaterThan(0));
      expect(fatigueScore, lessThan(10000)); // Reasonable upper bound
    });

    test('FatigueCalculations should compute recovery correctly', () {
      final recovery = FatigueCalculations.calculateRecovery(
        initialFatigue: 100.0,
        timeElapsedHours: 48.0,
        muscleGroupId: 'chest',
      );

      // After 48 hours with tau=48 (chest), should be ~36.8% of original
      expect(recovery, closeTo(36.8, 1.0));
    });
  });
}