import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:logger/logger.dart';

import '../../../lib/data/datasources/local/database_helper.dart';
import '../../../lib/data/repositories/user_repository.dart';
import '../../../lib/data/repositories/exercise_repository.dart';
import '../../../lib/data/repositories/workout_repository.dart';
import '../../../lib/domain/entities/user.dart';
import '../../../lib/domain/entities/exercise.dart';
import '../../../lib/domain/entities/workout_session.dart';
import '../../../lib/domain/entities/enums.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late UserRepository userRepository;
  late ExerciseRepository exerciseRepository;
  late WorkoutSessionRepository sessionRepository;
  late WorkoutSetRepository setRepository;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    
    // Disable logging during tests
    Logger.level = Level.off;
  });

  setUp(() async {
    databaseHelper = DatabaseHelper();
    userRepository = UserRepositoryImpl(databaseHelper);
    exerciseRepository = ExerciseRepositoryImpl(databaseHelper);
    setRepository = WorkoutSetRepositoryImpl(databaseHelper);
    sessionRepository = WorkoutSessionRepositoryImpl(databaseHelper, setRepository);
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  group('Repository Integration Tests', () {
    group('Multi-Repository Workflows', () {
      test('should handle complete user workout journey', () async {
        // 1. Create user
        final user = User(
          id: 'journey_user',
          email: 'journey@test.com',
          displayName: 'Journey User',
          createdAt: DateTime.now(),
          preferredLanguage: 'en',
        );
        
        await userRepository.create(user);
        
        // 2. User starts a workout session
        final session = WorkoutSession(
          id: 'journey_session',
          userId: user.id,
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [],
        );
        
        await sessionRepository.create(session);
        
        // 3. User performs sets for different exercises
        final sets = [
          WorkoutSet(
            id: 'journey_set_1',
            sessionId: session.id,
            exerciseId: 'squat',
            weight: 100.0,
            reps: 10,
            rpe: 8,
            setOrder: 1,
            createdAt: DateTime.now(),
          ),
          WorkoutSet(
            id: 'journey_set_2',
            sessionId: session.id,
            exerciseId: 'squat',
            weight: 105.0,
            reps: 8,
            rpe: 9,
            setOrder: 2,
            createdAt: DateTime.now(),
          ),
          WorkoutSet(
            id: 'journey_set_3',
            sessionId: session.id,
            exerciseId: 'bench_press',
            weight: 80.0,
            reps: 12,
            rpe: 7,
            setOrder: 3,
            createdAt: DateTime.now(),
          ),
        ];
        
        for (final set in sets) {
          await setRepository.create(set);
        }
        
        // 4. End the session
        final endedSession = session.endSession();
        await sessionRepository.update(endedSession);
        
        // 5. Verify the complete workflow
        final foundUser = await userRepository.findById(user.id);
        expect(foundUser, isNotNull);
        
        final foundSession = await sessionRepository.findById(session.id);
        expect(foundSession, isNotNull);
        expect(foundSession!.endTime, isNotNull);
        expect(foundSession.sets.length, equals(3));
        
        final userSessions = await sessionRepository.findByUserId(user.id);
        expect(userSessions.length, equals(1));
        
        final workoutStats = await sessionRepository.getWorkoutStats(user.id);
        expect(workoutStats['total_sessions'], equals(1));
        expect(workoutStats['completed_sessions'], equals(1));
        expect(workoutStats['total_sets'], equals(3));
        expect(workoutStats['total_volume'], equals(100*10 + 105*8 + 80*12));
      });
    });
  });
}    
  test('should handle user progression tracking across multiple sessions', () async {
        // Create user
        final user = User(
          id: 'progression_user',
          email: 'progression@test.com',
          displayName: 'Progression User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        // Create multiple sessions over time showing progression
        final sessions = <WorkoutSession>[];
        final allSets = <WorkoutSet>[];
        
        for (int week = 1; week <= 4; week++) {
          final session = WorkoutSession(
            id: 'progression_session_$week',
            userId: user.id,
            startTime: DateTime.now().subtract(Duration(days: (4 - week) * 7)),
            endTime: DateTime.now().subtract(Duration(days: (4 - week) * 7, hours: -1)),
            sessionType: SessionType.strength,
            createdAt: DateTime.now().subtract(Duration(days: (4 - week) * 7)),
            sets: [],
          );
          
          sessions.add(session);
          
          // Progressive overload: increase weight each week
          final weekSets = [
            WorkoutSet(
              id: 'progression_set_${week}_1',
              sessionId: session.id,
              exerciseId: 'squat',
              weight: 100.0 + (week - 1) * 5, // 100, 105, 110, 115
              reps: 10,
              rpe: 8,
              setOrder: 1,
              createdAt: session.startTime,
            ),
            WorkoutSet(
              id: 'progression_set_${week}_2',
              sessionId: session.id,
              exerciseId: 'squat',
              weight: 100.0 + (week - 1) * 5,
              reps: 9,
              rpe: 8,
              setOrder: 2,
              createdAt: session.startTime,
            ),
            WorkoutSet(
              id: 'progression_set_${week}_3',
              sessionId: session.id,
              exerciseId: 'squat',
              weight: 100.0 + (week - 1) * 5,
              reps: 8,
              rpe: 9,
              setOrder: 3,
              createdAt: session.startTime,
            ),
          ];
          
          allSets.addAll(weekSets);
          
          // Create session with sets
          await sessionRepository.create(session.copyWith(sets: weekSets));
        }
        
        // Verify progression tracking
        final userSessions = await sessionRepository.findByUserId(user.id);
        expect(userSessions.length, equals(4));
        
        // Check personal records
        final prs = await setRepository.getPersonalRecords(user.id);
        final squatPR = prs.firstWhere((pr) => pr['exercise_id'] == 'squat');
        expect(squatPR['max_weight'], equals(115.0));
        
        // Check volume progression
        final week1Volume = await setRepository.calculateVolumeForDateRange(
          user.id,
          DateTime.now().subtract(Duration(days: 21)),
          DateTime.now().subtract(Duration(days: 20)),
        );
        
        final week4Volume = await setRepository.calculateVolumeForDateRange(
          user.id,
          DateTime.now().subtract(Duration(days: 1)),
          DateTime.now(),
        );
        
        expect(week4Volume, greaterThan(week1Volume));
        
        // Verify recent sets show progression
        final recentSets = await setRepository.findRecentSetsForExercise(
          'squat',
          user.id,
          limit: 6,
        );
        
        expect(recentSets.length, equals(6));
        
        // Most recent sets should have higher weight
        final mostRecentWeight = recentSets.first.weight;
        final oldestWeight = recentSets.last.weight;
        expect(mostRecentWeight, greaterThan(oldestWeight));
      });

      test('should handle exercise usage analytics across users', () async {
        // Create multiple users
        final users = [
          User(
            id: 'analytics_user_1',
            email: 'analytics1@test.com',
            displayName: 'Analytics User 1',
            createdAt: DateTime.now(),
          ),
          User(
            id: 'analytics_user_2',
            email: 'analytics2@test.com',
            displayName: 'Analytics User 2',
            createdAt: DateTime.now(),
          ),
        ];
        
        for (final user in users) {
          await userRepository.create(user);
        }
        
        // Create sessions for each user with different exercise preferences
        for (int userIndex = 0; userIndex < users.length; userIndex++) {
          final user = users[userIndex];
          
          for (int sessionIndex = 1; sessionIndex <= 3; sessionIndex++) {
            final session = WorkoutSession(
              id: 'analytics_session_${userIndex + 1}_$sessionIndex',
              userId: user.id,
              startTime: DateTime.now().subtract(Duration(days: sessionIndex)),
              endTime: DateTime.now().subtract(Duration(days: sessionIndex, hours: -1)),
              sessionType: SessionType.strength,
              createdAt: DateTime.now().subtract(Duration(days: sessionIndex)),
              sets: [],
            );
            
            // User 1 prefers squats, User 2 prefers bench press
            final preferredExercise = userIndex == 0 ? 'squat' : 'bench_press';
            final alternateExercise = userIndex == 0 ? 'bench_press' : 'squat';
            
            final sets = [
              // More sets of preferred exercise
              ...List.generate(3, (i) => WorkoutSet(
                id: 'analytics_set_${userIndex + 1}_${sessionIndex}_preferred_$i',
                sessionId: session.id,
                exerciseId: preferredExercise,
                weight: 100.0 + i * 5,
                reps: 10 - i,
                rpe: 8,
                setOrder: i + 1,
                createdAt: session.startTime,
              )),
              // One set of alternate exercise
              WorkoutSet(
                id: 'analytics_set_${userIndex + 1}_${sessionIndex}_alternate',
                sessionId: session.id,
                exerciseId: alternateExercise,
                weight: 80.0,
                reps: 10,
                rpe: 7,
                setOrder: 4,
                createdAt: session.startTime,
              ),
            ];
            
            await sessionRepository.create(session.copyWith(sets: sets));
          }
        }
        
        // Analyze exercise usage
        final usageStats = await exerciseRepository.getExerciseUsageStats();
        
        // Find stats for squat and bench press
        final squatStats = usageStats.firstWhere(
          (stat) => stat['exercise_id'] == 'squat',
          orElse: () => <String, dynamic>{},
        );
        
        final benchStats = usageStats.firstWhere(
          (stat) => stat['exercise_id'] == 'bench_press',
          orElse: () => <String, dynamic>{},
        );
        
        expect(squatStats, isNotEmpty);
        expect(benchStats, isNotEmpty);
        
        // Both exercises should have been used
        expect(squatStats['usage_count'], greaterThan(0));
        expect(benchStats['usage_count'], greaterThan(0));
        
        // Squat should have more usage (3 sets per session * 3 sessions for user 1 + 1 set per session * 3 sessions for user 2 = 12)
        // Bench press should have less usage (1 set per session * 3 sessions for user 1 + 3 sets per session * 3 sessions for user 2 = 12)
        expect(squatStats['usage_count'], equals(12));
        expect(benchStats['usage_count'], equals(12));
        
        // Check average weights
        expect(squatStats['avg_weight'], isA<double>());
        expect(benchStats['avg_weight'], isA<double>());
      });

    group('Repository Error Handling Integration', () {
      test('should handle cascading errors gracefully', () async {
        final user = User(
          id: 'error_user',
          email: 'error@test.com',
          displayName: 'Error User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        // Create session
        final session = WorkoutSession(
          id: 'error_session',
          userId: user.id,
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [],
        );
        
        await sessionRepository.create(session);
        
        // Try to create set with invalid data
        final invalidSet = WorkoutSet(
          id: 'error_set',
          sessionId: session.id,
          exerciseId: 'non_existent_exercise',
          weight: -100.0, // Invalid weight
          reps: 0, // Invalid reps
          rpe: 15, // Invalid RPE
          setOrder: 1,
          createdAt: DateTime.now(),
        );
        
        expect(
          () => setRepository.create(invalidSet),
          throwsA(isA<RepositoryException>()),
        );
        
        // Verify that the session and user are still intact
        final foundUser = await userRepository.findById(user.id);
        expect(foundUser, isNotNull);
        
        final foundSession = await sessionRepository.findById(session.id);
        expect(foundSession, isNotNull);
        
        // Verify no sets were created
        final sessionSets = await setRepository.findBySessionId(session.id);
        expect(sessionSets, isEmpty);
      });

      test('should maintain data consistency during partial failures', () async {
        final user = User(
          id: 'consistency_user',
          email: 'consistency@test.com',
          displayName: 'Consistency User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        // Create multiple sessions, some with valid data, some with invalid
        final validSession = WorkoutSession(
          id: 'valid_session',
          userId: user.id,
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [],
        );
        
        await sessionRepository.create(validSession);
        
        // Try to create invalid session
        final invalidSession = WorkoutSession(
          id: 'invalid_session',
          userId: 'non_existent_user', // Invalid user ID
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [],
        );
        
        expect(
          () => sessionRepository.create(invalidSession),
          throwsA(isA<DatabaseException>()),
        );
        
        // Verify that valid session still exists
        final userSessions = await sessionRepository.findByUserId(user.id);
        expect(userSessions.length, equals(1));
        expect(userSessions.first.id, equals('valid_session'));
        
        // Verify invalid session was not created
        final invalidSessionResult = await sessionRepository.findById('invalid_session');
        expect(invalidSessionResult, isNull);
      });
    });

    group('Repository Performance Integration', () {
      test('should handle complex multi-repository queries efficiently', () async {
        // Create test data
        final user = User(
          id: 'perf_user',
          email: 'perf@test.com',
          displayName: 'Performance User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        // Create many sessions with sets
        final stopwatch = Stopwatch()..start();
        
        for (int i = 1; i <= 20; i++) {
          final session = WorkoutSession(
            id: 'perf_session_$i',
            userId: user.id,
            startTime: DateTime.now().subtract(Duration(days: i)),
            endTime: DateTime.now().subtract(Duration(days: i, hours: -1)),
            sessionType: SessionType.strength,
            createdAt: DateTime.now().subtract(Duration(days: i)),
            sets: List.generate(5, (j) => WorkoutSet(
              id: 'perf_set_${i}_$j',
              sessionId: 'perf_session_$i',
              exerciseId: j % 2 == 0 ? 'squat' : 'bench_press',
              weight: 100.0 + j * 5,
              reps: 10 - j,
              rpe: 8,
              setOrder: j + 1,
              createdAt: DateTime.now().subtract(Duration(days: i)),
            )),
          );
          
          await sessionRepository.create(session);
        }
        
        stopwatch.stop();
        final creationTime = stopwatch.elapsedMilliseconds;
        
        // Perform complex queries
        stopwatch.reset();
        stopwatch.start();
        
        final userSessions = await sessionRepository.findByUserId(user.id);
        final workoutStats = await sessionRepository.getWorkoutStats(user.id);
        final prs = await setRepository.getPersonalRecords(user.id);
        final recentSets = await setRepository.findRecentSetsForExercise('squat', user.id);
        final volume = await setRepository.calculateVolumeForDateRange(
          user.id,
          DateTime.now().subtract(Duration(days: 30)),
          DateTime.now(),
        );
        
        stopwatch.stop();
        final queryTime = stopwatch.elapsedMilliseconds;
        
        // Verify results
        expect(userSessions.length, equals(20));
        expect(workoutStats['total_sessions'], equals(20));
        expect(workoutStats['total_sets'], equals(100));
        expect(prs.length, greaterThanOrEqualTo(2)); // At least squat and bench press
        expect(recentSets, isNotEmpty);
        expect(volume, greaterThan(0));
        
        // Performance expectations
        expect(creationTime, lessThan(10000)); // 10 seconds for creation
        expect(queryTime, lessThan(2000)); // 2 seconds for all queries
      });
    });

    group('Repository Data Validation Integration', () {
      test('should validate data consistency across repositories', () async {
        final user = User(
          id: 'validation_user',
          email: 'validation@test.com',
          displayName: 'Validation User',
          createdAt: DateTime.now(),
        );
        
        await userRepository.create(user);
        
        // Create exercise
        final exercise = Exercise(
          id: 'validation_exercise',
          names: {'en': 'Validation Exercise', 'ja': 'バリデーション運動'},
          category: 'validation',
          equipment: EquipmentType.dumbbell,
          instructions: {'en': 'Test instructions'},
          primaryMuscleGroups: ['chest'],
          secondaryMuscleGroups: ['shoulders'],
          createdAt: DateTime.now(),
        );
        
        await exerciseRepository.create(exercise);
        
        // Create session with sets
        final session = WorkoutSession(
          id: 'validation_session',
          userId: user.id,
          startTime: DateTime.now(),
          endTime: DateTime.now().add(Duration(hours: 1)),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [
            WorkoutSet(
              id: 'validation_set',
              sessionId: 'validation_session',
              exerciseId: exercise.id,
              weight: 100.0,
              reps: 10,
              rpe: 8,
              setOrder: 1,
              createdAt: DateTime.now(),
            ),
          ],
        );
        
        await sessionRepository.create(session);
        
        // Verify all relationships are intact
        final foundUser = await userRepository.findById(user.id);
        expect(foundUser, isNotNull);
        
        final foundExercise = await exerciseRepository.findById(exercise.id);
        expect(foundExercise, isNotNull);
        
        final foundSession = await sessionRepository.findById(session.id);
        expect(foundSession, isNotNull);
        expect(foundSession!.sets.length, equals(1));
        
        final foundSet = foundSession.sets.first;
        expect(foundSet.sessionId, equals(session.id));
        expect(foundSet.exerciseId, equals(exercise.id));
        
        // Verify cross-repository queries work
        final userSessions = await sessionRepository.findByUserId(user.id);
        expect(userSessions.length, equals(1));
        
        final exerciseSets = await setRepository.findByExerciseId(exercise.id);
        expect(exerciseSets.length, equals(1));
        
        final userExerciseSets = await setRepository.findByUserAndExercise(user.id, exercise.id);
        expect(userExerciseSets.length, equals(1));
      });
    });
  });
}