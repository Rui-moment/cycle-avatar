import 'package:flutter_test/flutter_test.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';
import 'package:cycle_avatar/domain/entities/constants.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/recovery_state.dart';
import 'package:cycle_avatar/domain/services/deload_detector.dart';

void main() {
  group('DeloadDetector Tests', () {
    late DeloadDetector deloadDetector;

    setUp(() {
      deloadDetector = DeloadDetector();
    });

    group('analyzeDeloadNeed', () {
      test('should recommend deload with excessive volume increase and high fatigue', () {
        // Given: High volume progression and chronic fatigue
        final sessions = _createHighVolumeProgressionSessions();
        final recoveryStates = _createHighFatigueRecoveryStates();

        // When: Analyze deload need
        final recommendation = deloadDetector.analyzeDeloadNeed(
          recentSessions: sessions,
          currentRecoveryStates: recoveryStates,
        );

        // Then: Should recommend deload
        expect(recommendation.isNeeded, true);
        expect(recommendation.priority, DeloadPriority.high);
        expect(recommendation.reasons.isNotEmpty, true);
        expect(recommendation.volumeReduction, greaterThan(0.3));
      });

      test('should not recommend deload with balanced training load', () {
        // Given: Moderate volume and good recovery
        final sessions = _createBalancedSessions();
        final recoveryStates = _createGoodRecoveryStates();

        // When: Analyze deload need
        final recommendation = deloadDetector.analyzeDeloadNeed(
          recentSessions: sessions,
          currentRecoveryStates: recoveryStates,
        );

        // Then: Should not recommend deload
        expect(recommendation.isNeeded, false);
        expect(recommendation.primaryReason.contains('balanced'), true);
      });

      test('should return not needed with insufficient training history', () {
        // Given: Few sessions
        final sessions = _createFewSessions();
        final recoveryStates = _createGoodRecoveryStates();

        // When: Analyze deload need
        final recommendation = deloadDetector.analyzeDeloadNeed(
          recentSessions: sessions,
          currentRecoveryStates: recoveryStates,
        );

        // Then: Should not recommend deload
        expect(recommendation.isNeeded, false);
        expect(recommendation.primaryReason.contains('Insufficient'), true);
      });

      test('should recommend medium priority deload with moderate indicators', () {
        // Given: Moderate volume increase and some fatigue
        final sessions = _createModerateVolumeProgressionSessions();
        final recoveryStates = _createModerateFatigueRecoveryStates();

        // When: Analyze deload need
        final recommendation = deloadDetector.analyzeDeloadNeed(
          recentSessions: sessions,
          currentRecoveryStates: recoveryStates,
        );

        // Then: Should recommend medium priority deload
        expect(recommendation.isNeeded, true);
        expect(recommendation.priority, DeloadPriority.medium);
        expect(recommendation.recommendedDurationDays, 5);
      });
    });

    group('calculateVolumeProgression', () {
      test('should calculate correct volume increase percentage', () {
        // Given: Sessions with 25% volume increase
        final sessions = _createProgressiveVolumeSessions(increasePercentage: 0.25);

        // When: Calculate volume progression
        final analysis = deloadDetector.calculateVolumeProgression(
          sessions: sessions,
          weeks: 4,
        );

        // Then: Should detect volume increase
        expect(analysis.totalVolumeIncrease, closeTo(0.25, 0.05));
        expect(analysis.isExcessiveIncrease, true);
        expect(analysis.weeklyVolumes.length, 4);
      });

      test('should handle stable volume correctly', () {
        // Given: Sessions with stable volume
        final sessions = _createStableVolumeSessions();

        // When: Calculate volume progression
        final analysis = deloadDetector.calculateVolumeProgression(
          sessions: sessions,
          weeks: 4,
        );

        // Then: Should show stable volume
        expect(analysis.totalVolumeIncrease, closeTo(0.0, 0.05));
        expect(analysis.isExcessiveIncrease, false);
        expect(analysis.trend, VolumeTrend.stable);
      });

      test('should handle decreasing volume', () {
        // Given: Sessions with decreasing volume
        final sessions = _createDecreasingVolumeSessions();

        // When: Calculate volume progression
        final analysis = deloadDetector.calculateVolumeProgression(
          sessions: sessions,
          weeks: 4,
        );

        // Then: Should show decreasing trend
        expect(analysis.totalVolumeIncrease, lessThan(0.0));
        expect(analysis.trend, VolumeTrend.decreasing);
      });

      test('should return empty analysis with insufficient data', () {
        // Given: Very few sessions
        final sessions = [_createTestSession()];

        // When: Calculate volume progression
        final analysis = deloadDetector.calculateVolumeProgression(
          sessions: sessions,
          weeks: 4,
        );

        // Then: Should return empty analysis
        expect(analysis.weeklyVolumes.isEmpty, true);
        expect(analysis.totalVolumeIncrease, 0.0);
      });
    });

    group('analyzeChronicFatigue', () {
      test('should detect chronic fatigue correctly', () {
        // Given: High fatigue recovery states
        final recoveryStates = _createHighFatigueRecoveryStates();
        final sessions = _createBalancedSessions();

        // When: Analyze chronic fatigue
        final analysis = deloadDetector.analyzeChronicFatigue(
          recoveryStates: recoveryStates,
          recentSessions: sessions,
        );

        // Then: Should detect chronic fatigue
        expect(analysis.isChronicFatiguePresent, true);
        expect(analysis.highFatigueMuscleGroups.length, greaterThanOrEqualTo(3));
        expect(analysis.severity, FatigueSeverity.moderate);
      });

      test('should show no chronic fatigue with good recovery', () {
        // Given: Good recovery states
        final recoveryStates = _createGoodRecoveryStates();
        final sessions = _createBalancedSessions();

        // When: Analyze chronic fatigue
        final analysis = deloadDetector.analyzeChronicFatigue(
          recoveryStates: recoveryStates,
          recentSessions: sessions,
        );

        // Then: Should show no chronic fatigue
        expect(analysis.isChronicFatiguePresent, false);
        expect(analysis.highFatigueMuscleGroups.isEmpty, true);
        expect(analysis.severity, FatigueSeverity.none);
      });

      test('should calculate average recovery percentage correctly', () {
        // Given: Mixed recovery states
        final recoveryStates = {
          'chest': RecoveryState(
            id: 'chest_recovery',
            muscleGroupId: 'chest',
            currentFatigue: 20.0,
            lastUpdated: DateTime.now(),
            readinessLevel: ReadinessLevel.ready,
            lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 24)),
            initialFatigue: 100.0,
          ),
          'back': RecoveryState(
            id: 'back_recovery',
            muscleGroupId: 'back',
            currentFatigue: 60.0,
            lastUpdated: DateTime.now(),
            readinessLevel: ReadinessLevel.warm,
            lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 12)),
            initialFatigue: 100.0,
          ),
        };
        final sessions = _createBalancedSessions();

        // When: Analyze chronic fatigue
        final analysis = deloadDetector.analyzeChronicFatigue(
          recoveryStates: recoveryStates,
          recentSessions: sessions,
        );

        // Then: Should calculate correct average
        expect(analysis.averageRecoveryPercentage, closeTo(0.6, 0.1)); // (0.8 + 0.4) / 2
      });
    });

    group('analyzePerformanceStagnation', () {
      test('should detect performance stagnation with increasing RPE', () {
        // Given: Sessions with increasing RPE but stable volume
        final sessions = _createStagnantPerformanceSessions();

        // When: Analyze performance stagnation
        final analysis = deloadDetector.analyzePerformanceStagnation(
          sessions: sessions,
          weeks: 2,
        );

        // Then: Should detect stagnation
        expect(analysis.isPerformanceStagnant, true);
        expect(analysis.averageRPEIncrease, greaterThan(0.3));
      });

      test('should not detect stagnation with improving performance', () {
        // Given: Sessions with improving performance
        final sessions = _createImprovingPerformanceSessions();

        // When: Analyze performance stagnation
        final analysis = deloadDetector.analyzePerformanceStagnation(
          sessions: sessions,
          weeks: 2,
        );

        // Then: Should not detect stagnation
        expect(analysis.isPerformanceStagnant, false);
        expect(analysis.stagnantExercises.length, lessThan(2));
      });

      test('should identify stagnant exercises correctly', () {
        // Given: Sessions with specific stagnant exercises
        final sessions = _createMixedPerformanceSessions();

        // When: Analyze performance stagnation
        final analysis = deloadDetector.analyzePerformanceStagnation(
          sessions: sessions,
          weeks: 2,
        );

        // Then: Should identify stagnant exercises
        expect(analysis.stagnantExercises.isNotEmpty, true);
      });
    });

    group('deload recommendation formatting', () {
      test('should format volume reduction correctly', () {
        // Given: Deload recommendation
        final recommendation = DeloadRecommendation.needed(
          priority: DeloadPriority.medium,
          reasons: ['Test reason'],
          recommendedDuration: 5,
          volumeReduction: 0.4,
          intensityReduction: 2,
        );

        // When: Get formatted volume reduction
        final formatted = recommendation.formattedVolumeReduction;

        // Then: Should format correctly
        expect(formatted, '40%');
      });

      test('should format duration correctly', () {
        // Given: Week-long deload recommendation
        final weekRecommendation = DeloadRecommendation.needed(
          priority: DeloadPriority.high,
          reasons: ['Test reason'],
          recommendedDuration: 7,
          volumeReduction: 0.5,
          intensityReduction: 3,
        );

        // When: Get formatted duration
        final weekFormatted = weekRecommendation.formattedDuration;

        // Then: Should format as week
        expect(weekFormatted, '1 week');

        // Given: Day-long deload recommendation
        final dayRecommendation = DeloadRecommendation.needed(
          priority: DeloadPriority.low,
          reasons: ['Test reason'],
          recommendedDuration: 3,
          volumeReduction: 0.3,
          intensityReduction: 1,
        );

        // When: Get formatted duration
        final dayFormatted = dayRecommendation.formattedDuration;

        // Then: Should format as days
        expect(dayFormatted, '3 days');
      });
    });

    group('edge cases', () {
      test('should handle empty recovery states', () {
        // Given: Empty recovery states
        final sessions = _createBalancedSessions();
        final recoveryStates = <String, RecoveryState>{};

        // When: Analyze deload need
        final recommendation = deloadDetector.analyzeDeloadNeed(
          recentSessions: sessions,
          currentRecoveryStates: recoveryStates,
        );

        // Then: Should handle gracefully
        expect(recommendation.isNeeded, false);
      });

      test('should handle sessions with zero volume', () {
        // Given: Sessions with zero volume
        final sessions = _createZeroVolumeSessions();
        final recoveryStates = _createGoodRecoveryStates();

        // When: Calculate volume progression
        final analysis = deloadDetector.calculateVolumeProgression(
          sessions: sessions,
          weeks: 4,
        );

        // Then: Should handle gracefully
        expect(analysis.totalVolumeIncrease, 0.0);
        expect(analysis.isExcessiveIncrease, false);
      });

      test('should handle very short analysis period', () {
        // Given: Sessions and short analysis period
        final sessions = _createBalancedSessions();
        final recoveryStates = _createGoodRecoveryStates();

        // When: Analyze with 1 week period
        final recommendation = deloadDetector.analyzeDeloadNeed(
          recentSessions: sessions,
          currentRecoveryStates: recoveryStates,
          analysisWeeks: 1,
        );

        // Then: Should handle gracefully
        expect(recommendation.isNeeded, false);
      });
    });
  });
}

/// Helper function to create high volume progression sessions
List<WorkoutSession> _createHighVolumeProgressionSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  // Create 16 sessions over 4 weeks with 30% volume increase
  for (int i = 0; i < 16; i++) {
    final sessionDate = now.subtract(Duration(days: (16 - i) * 2));
    final volumeMultiplier = 1.0 + (i * 0.02); // 2% increase per session
    
    sessions.add(_createTestSession(
      volumeMultiplier: volumeMultiplier,
      startTime: sessionDate,
    ));
  }
  
  return sessions;
}

/// Helper function to create balanced training sessions
List<WorkoutSession> _createBalancedSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  // Create 12 sessions with stable volume
  for (int i = 0; i < 12; i++) {
    final sessionDate = now.subtract(Duration(days: i * 2));
    sessions.add(_createTestSession(
      volumeMultiplier: 1.0,
      startTime: sessionDate,
    ));
  }
  
  return sessions;
}

/// Helper function to create few sessions
List<WorkoutSession> _createFewSessions() {
  return [
    _createTestSession(startTime: DateTime.now().subtract(const Duration(days: 1))),
    _createTestSession(startTime: DateTime.now().subtract(const Duration(days: 3))),
  ];
}

/// Helper function to create moderate volume progression sessions
List<WorkoutSession> _createModerateVolumeProgressionSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  // Create sessions with 15% volume increase (moderate)
  for (int i = 0; i < 12; i++) {
    final sessionDate = now.subtract(Duration(days: (12 - i) * 2));
    final volumeMultiplier = 1.0 + (i * 0.015); // 1.5% increase per session
    
    sessions.add(_createTestSession(
      volumeMultiplier: volumeMultiplier,
      startTime: sessionDate,
    ));
  }
  
  return sessions;
}

/// Helper function to create progressive volume sessions
List<WorkoutSession> _createProgressiveVolumeSessions({required double increasePercentage}) {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  // Create 4 weeks of sessions with specified increase
  for (int week = 0; week < 4; week++) {
    for (int session = 0; session < 3; session++) {
      final sessionDate = now.subtract(Duration(days: (4 - week) * 7 - session * 2));
      final volumeMultiplier = 1.0 + (week * increasePercentage);
      
      sessions.add(_createTestSession(
        volumeMultiplier: volumeMultiplier,
        startTime: sessionDate,
      ));
    }
  }
  
  return sessions;
}

/// Helper function to create stable volume sessions
List<WorkoutSession> _createStableVolumeSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  for (int i = 0; i < 12; i++) {
    final sessionDate = now.subtract(Duration(days: i * 2));
    sessions.add(_createTestSession(
      volumeMultiplier: 1.0, // Stable volume
      startTime: sessionDate,
    ));
  }
  
  return sessions;
}

/// Helper function to create decreasing volume sessions
List<WorkoutSession> _createDecreasingVolumeSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  for (int i = 0; i < 12; i++) {
    final sessionDate = now.subtract(Duration(days: i * 2));
    final volumeMultiplier = 1.2 - (i * 0.05); // Decreasing volume
    
    sessions.add(_createTestSession(
      volumeMultiplier: volumeMultiplier,
      startTime: sessionDate,
    ));
  }
  
  return sessions;
}

/// Helper function to create stagnant performance sessions
List<WorkoutSession> _createStagnantPerformanceSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  for (int i = 0; i < 8; i++) {
    final sessionDate = now.subtract(Duration(days: i * 2));
    final rpe = 7 + (i * 0.5); // More significant RPE increase
    
    sessions.add(_createTestSession(
      volumeMultiplier: 1.0, // Stable volume
      rpe: rpe.round().clamp(6, 10),
      startTime: sessionDate,
    ));
  }
  
  return sessions;
}

/// Helper function to create improving performance sessions
List<WorkoutSession> _createImprovingPerformanceSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  for (int i = 0; i < 8; i++) {
    final sessionDate = now.subtract(Duration(days: i * 2));
    final volumeMultiplier = 1.0 + (i * 0.05); // Improving volume
    
    sessions.add(_createTestSession(
      volumeMultiplier: volumeMultiplier,
      rpe: 7, // Stable RPE
      startTime: sessionDate,
    ));
  }
  
  return sessions;
}

/// Helper function to create mixed performance sessions
List<WorkoutSession> _createMixedPerformanceSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  for (int i = 0; i < 8; i++) {
    final sessionDate = now.subtract(Duration(days: i * 2));
    
    // Create sets with mixed performance
    final sets = [
      // Stagnant exercise
      WorkoutSet(
        id: 'stagnant_set_$i',
        sessionId: 'session_$i',
        exerciseId: 'stagnant_exercise',
        weight: 100.0, // No progression
        reps: 10,
        rpe: 8,
        setOrder: 1,
        createdAt: sessionDate,
      ),
      // Improving exercise
      WorkoutSet(
        id: 'improving_set_$i',
        sessionId: 'session_$i',
        exerciseId: 'improving_exercise',
        weight: 100.0 + (i * 2.5), // Progressive overload
        reps: 10,
        rpe: 8,
        setOrder: 2,
        createdAt: sessionDate,
      ),
    ];
    
    sessions.add(WorkoutSession(
      id: 'session_$i',
      userId: 'test_user',
      startTime: sessionDate,
      endTime: sessionDate.add(const Duration(hours: 1)),
      sessionType: SessionType.hypertrophy,
      createdAt: sessionDate,
      sets: sets,
    ));
  }
  
  return sessions;
}

/// Helper function to create zero volume sessions
List<WorkoutSession> _createZeroVolumeSessions() {
  final sessions = <WorkoutSession>[];
  final now = DateTime.now();
  
  for (int i = 0; i < 8; i++) {
    final sessionDate = now.subtract(Duration(days: i * 2));
    
    sessions.add(WorkoutSession(
      id: 'zero_session_$i',
      userId: 'test_user',
      startTime: sessionDate,
      endTime: sessionDate.add(const Duration(hours: 1)),
      sessionType: SessionType.hypertrophy,
      createdAt: sessionDate,
      sets: [], // No sets = zero volume
    ));
  }
  
  return sessions;
}

/// Helper function to create high fatigue recovery states
Map<String, RecoveryState> _createHighFatigueRecoveryStates() {
  return {
    'chest': RecoveryState(
      id: 'chest_recovery',
      muscleGroupId: 'chest',
      currentFatigue: 85.0, // High fatigue
      lastUpdated: DateTime.now(),
      readinessLevel: ReadinessLevel.fatigued,
      lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 12)),
      initialFatigue: 100.0,
    ),
    'back': RecoveryState(
      id: 'back_recovery',
      muscleGroupId: 'back',
      currentFatigue: 90.0, // High fatigue
      lastUpdated: DateTime.now(),
      readinessLevel: ReadinessLevel.fatigued,
      lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 8)),
      initialFatigue: 100.0,
    ),
    'quadriceps': RecoveryState(
      id: 'quad_recovery',
      muscleGroupId: 'quadriceps',
      currentFatigue: 88.0, // High fatigue
      lastUpdated: DateTime.now(),
      readinessLevel: ReadinessLevel.fatigued,
      lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 10)),
      initialFatigue: 100.0,
    ),
    'shoulders': RecoveryState(
      id: 'shoulder_recovery',
      muscleGroupId: 'shoulders',
      currentFatigue: 82.0, // High fatigue
      lastUpdated: DateTime.now(),
      readinessLevel: ReadinessLevel.fatigued,
      lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 6)),
      initialFatigue: 100.0,
    ),
  };
}

/// Helper function to create good recovery states
Map<String, RecoveryState> _createGoodRecoveryStates() {
  return {
    'chest': RecoveryState(
      id: 'chest_recovery',
      muscleGroupId: 'chest',
      currentFatigue: 20.0, // Low fatigue
      lastUpdated: DateTime.now(),
      readinessLevel: ReadinessLevel.ready,
      lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 48)),
      initialFatigue: 100.0,
    ),
    'back': RecoveryState(
      id: 'back_recovery',
      muscleGroupId: 'back',
      currentFatigue: 25.0, // Low fatigue
      lastUpdated: DateTime.now(),
      readinessLevel: ReadinessLevel.ready,
      lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 72)),
      initialFatigue: 100.0,
    ),
    'quadriceps': RecoveryState(
      id: 'quad_recovery',
      muscleGroupId: 'quadriceps',
      currentFatigue: 15.0, // Low fatigue
      lastUpdated: DateTime.now(),
      readinessLevel: ReadinessLevel.ready,
      lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 72)),
      initialFatigue: 100.0,
    ),
  };
}

/// Helper function to create moderate fatigue recovery states
Map<String, RecoveryState> _createModerateFatigueRecoveryStates() {
  return {
    'chest': RecoveryState(
      id: 'chest_recovery',
      muscleGroupId: 'chest',
      currentFatigue: 50.0, // Moderate fatigue
      lastUpdated: DateTime.now(),
      readinessLevel: ReadinessLevel.warm,
      lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 24)),
      initialFatigue: 100.0,
    ),
    'back': RecoveryState(
      id: 'back_recovery',
      muscleGroupId: 'back',
      currentFatigue: 60.0, // Moderate fatigue
      lastUpdated: DateTime.now(),
      readinessLevel: ReadinessLevel.warm,
      lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 36)),
      initialFatigue: 100.0,
    ),
    'quadriceps': RecoveryState(
      id: 'quad_recovery',
      muscleGroupId: 'quadriceps',
      currentFatigue: 85.0, // High fatigue (one muscle group)
      lastUpdated: DateTime.now(),
      readinessLevel: ReadinessLevel.fatigued,
      lastWorkoutTime: DateTime.now().subtract(const Duration(hours: 12)),
      initialFatigue: 100.0,
    ),
  };
}

/// Helper function to create a test workout session
WorkoutSession _createTestSession({
  double volumeMultiplier = 1.0,
  int rpe = 8,
  DateTime? startTime,
}) {
  final sets = [
    WorkoutSet(
      id: 'test_set_1',
      sessionId: 'test_session',
      exerciseId: 'bench_press',
      weight: 100.0 * volumeMultiplier,
      reps: 10,
      rpe: rpe,
      setOrder: 1,
      createdAt: DateTime.now(),
    ),
    WorkoutSet(
      id: 'test_set_2',
      sessionId: 'test_session',
      exerciseId: 'squat',
      weight: 120.0 * volumeMultiplier,
      reps: 8,
      rpe: rpe,
      setOrder: 2,
      createdAt: DateTime.now(),
    ),
  ];

  return WorkoutSession(
    id: 'test_session',
    userId: 'test_user',
    startTime: startTime ?? DateTime.now().subtract(const Duration(days: 1)),
    endTime: startTime?.add(const Duration(hours: 1)) ?? DateTime.now().subtract(const Duration(hours: 23)),
    sessionType: SessionType.hypertrophy,
    createdAt: DateTime.now(),
    sets: sets,
  );
}