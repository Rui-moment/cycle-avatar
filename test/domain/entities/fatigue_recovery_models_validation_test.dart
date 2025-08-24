import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/domain/entities/fatigue_event.dart';
import 'package:cycle_avatar/domain/entities/recovery_state.dart';
import 'package:cycle_avatar/domain/entities/avatar_state.dart';
import 'package:cycle_avatar/domain/entities/pr_record.dart';
import 'package:cycle_avatar/domain/entities/template.dart';
import 'package:cycle_avatar/domain/entities/notification.dart';
import 'package:cycle_avatar/domain/entities/constants.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';

void main() {
  group('Fatigue and Recovery Models Validation', () {
    test('FatigueEvent model should validate correctly', () {
      final fatigueEvent = FatigueEvent(
        id: 'test-id',
        muscleGroupId: 'chest',
        fatigueScore: 50.0,
        timestamp: DateTime.now(),
        workoutSessionId: 'session-id',
      );
      
      expect(fatigueEvent.isValid, isTrue);
      expect(fatigueEvent.validate(), isNull);
      expect(fatigueEvent.fatigueCategory, equals('Moderate'));
    });

    test('RecoveryState model should calculate recovery correctly', () {
      final recoveryState = RecoveryState(
        id: 'test-id',
        muscleGroupId: 'chest',
        currentFatigue: 25.0,
        lastUpdated: DateTime.now(),
        readinessLevel: ReadinessLevel.ready,
        initialFatigue: 100.0,
      );
      
      expect(recoveryState.isValid, isTrue);
      expect(recoveryState.isReady, isTrue);
      expect(recoveryState.recoveryPercentage, equals(0.75));
    });

    test('AvatarState model should handle growth points correctly', () {
      final avatarState = AvatarState.fresh(
        id: 'test-id',
        userId: 'user-id',
        muscleGroupIds: ['chest', 'back'],
      );
      
      expect(avatarState.isValid, isTrue);
      expect(avatarState.overallLevel, equals(0.0));
      
      final updatedState = avatarState.addGrowthPoints(
        muscleGroupId: 'chest',
        points: 150.0,
      );
      
      expect(updatedState.getLevelForMuscleGroup('chest'), equals(1));
    });

    test('PRRecord model should calculate estimated max correctly', () {
      final prRecord = PRRecord.fromWorkoutSet(
        id: 'test-id',
        userId: 'user-id',
        exerciseId: 'squat',
        weight: 100.0,
        reps: 5,
        achievedAt: DateTime.now(),
      );
      
      expect(prRecord.isValid, isTrue);
      expect(prRecord.estimatedMax, closeTo(116.67, 0.1));
      expect(prRecord.prType, equals('Strength'));
    });

    test('Template model should validate exercise structure', () {
      final template = Template(
        id: 'test-id',
        userId: 'user-id',
        name: 'Push Day',
        description: 'Chest, shoulders, triceps workout',
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
      
      expect(template.isValid, isTrue);
      expect(template.workoutSplit, equals('Push'));
      expect(template.targetedMuscleGroups, contains('chest'));
    });

    test('Notification model should create localized messages', () {
      final notification = Notification.recoveryComplete(
        id: 'test-id',
        userId: 'user-id',
        muscleGroupName: 'Chest',
        scheduledFor: DateTime.now().add(Duration(hours: 2)),
        locale: 'en',
      );
      
      expect(notification.isValid, isTrue);
      expect(notification.type, equals(NotificationType.recoveryComplete));
      expect(notification.isScheduled, isTrue);
    });

    test('Constants should be properly defined', () {
      expect(RECOVERY_TAU['chest'], equals(48.0));
      expect(RECOVERY_TAU['quadriceps'], equals(72.0));
      expect(FATIGUE_MULTIPLIERS['chest'], equals(1.0));
      expect(FATIGUE_MULTIPLIERS['quadriceps'], equals(1.3));
      
      // Test new additions
      expect(RECOVERY_TAU['serratus'], equals(36.0));
      expect(FATIGUE_MULTIPLIERS['serratus'], equals(0.5));
    });

    test('FatigueCalculations utility functions should work correctly', () {
      final fatigueScore = FatigueCalculations.calculateFatigueScore(
        volume: 1000.0, // 100kg × 5 reps × 2 sets
        intensity: 0.8,
        rpe: 8,
        muscleGroupId: 'chest',
      );
      
      expect(fatigueScore, greaterThan(0));
      
      final recovery = FatigueCalculations.calculateRecovery(
        initialFatigue: 100.0,
        timeElapsedHours: 48.0,
        muscleGroupId: 'chest',
      );
      
      expect(recovery, lessThan(100.0));
      expect(recovery, closeTo(36.79, 0.1)); // e^(-48/48) ≈ 0.3679
      
      final readiness = FatigueCalculations.getReadinessLevel(25.0);
      expect(readiness, equals(ReadinessLevel.ready));
    });

    test('Enums should provide localized names', () {
      expect(ReadinessLevel.ready.getLocalizedName('en'), equals('Ready'));
      expect(ReadinessLevel.ready.getLocalizedName('ja'), equals('準備完了'));
      expect(TrainingGoal.hypertrophy.getLocalizedName('en'), equals('Hypertrophy'));
      expect(TrainingGoal.hypertrophy.getLocalizedName('ja'), equals('筋肥大'));
    });
  });
}