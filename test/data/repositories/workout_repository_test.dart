import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../lib/data/datasources/local/database_helper.dart';
import '../../../lib/data/repositories/workout_repository.dart';
import '../../../lib/domain/entities/workout_session.dart';
import '../../../lib/domain/entities/enums.dart';

void main() {
  late DatabaseHelper databaseHelper;
  late WorkoutSessionRepository sessionRepository;
  late WorkoutSetRepository setRepository;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseHelper = DatabaseHelper();
    setRepository = WorkoutSetRepositoryImpl(databaseHelper);
    sessionRepository = WorkoutSessionRepositoryImpl(databaseHelper, setRepository);
    
    // Create test user
    final db = await databaseHelper.database;
    await db.insert('users', {
      'id': 'test_user',
      'email': 'test@example.com',
      'display_name': 'Test User',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  group('WorkoutSessionRepository', () {
    final testSession = WorkoutSession(
      id: 'test_session',
      userId: 'test_user',
      startTime: DateTime.now().subtract(Duration(hours: 1)),
      endTime: DateTime.now(),
      sessionType: SessionType.strength,
      notes: 'Test workout session',
      createdAt: DateTime.now(),
      sets: [],
    );

    final testSet = WorkoutSet(
      id: 'test_set',
      sessionId: 'test_session',
      exerciseId: 'squat',
      weight: 100.0,
      reps: 10,
      rpe: 8,
      restSeconds: 120,
      setOrder: 1,
      createdAt: DateTime.now(),
    );

    group('Create Operations', () {
      test('should create workout session successfully', () async {
        final createdSession = await sessionRepository.create(testSession);
        
        expect(createdSession, equals(testSession));
        
        // Verify session was saved to database
        final foundSession = await sessionRepository.findById(testSession.id);
        expect(foundSession, isNotNull);
        expect(foundSession!.userId, equals(testSession.userId));
      });

      test('should create workout session with sets', () async {
        final sessionWithSets = testSession.copyWith(sets: [testSet]);
        
        final createdSession = await sessionRepository.create(sessionWithSets);
        
        expect(createdSession.sets.length, equals(1));
        
        // Verify session and sets were saved
        final foundSession = await sessionRepository.findById(testSession.id);
        expect(foundSession, isNotNull);
        expect(foundSession!.sets.length, equals(1));
        expect(foundSession.sets.first.exerciseId, equals(testSet.exerciseId));
      });

      test('should throw exception when creating session with invalid data', () async {
        final invalidSession = WorkoutSession(
          id: '',
          userId: '',
          startTime: DateTime.now(),
          sessionType: SessionType.strength,
          createdAt: DateTime.now(),
          sets: [],
        );

        expect(
          () => sessionRepository.create(invalidSession),
          throwsA(isA<RepositoryException>()),
        );
      });
    });

    group('Read Operations', () {
      setUp(() async {
        await sessionRepository.create(testSession);
      });

      test('should find session by id', () async {
        final foundSession = await sessionRepository.findById(testSession.id);
        
        expect(foundSession, isNotNull);
        expect(foundSession!.id, equals(testSession.id));
        expect(foundSession.userId, equals(testSession.userId));
        expect(foundSession.sessionType, equals(testSession.sessionType));
      });

      test('should return null when session not found', () async {
        final foundSession = await sessionRepository.findById('non_existent_id');
        expect(foundSession, isNull);
      });

      test('should find sessions by user id', () async {
        final sessions = await sessionRepository.findByUserId('test_user');
        
        expect(sessions, isNotEmpty);
        expect(sessions.map((s) => s.id), contains(testSession.id));
        
        for (final session in sessions) {
          expect(session.userId, equals('test_user'));
        }
      });

      test('should find sessions by user id and date range', () async {
        final startDate = DateTime.now().subtract(Duration(days: 1));
        final endDate = DateTime.now().add(Duration(days: 1));
        
        final sessions = await sessionRepository.findByUserIdAndDateRange(
          'test_user',
          startDate,
          endDate,
        );
        
        expect(sessions, isNotEmpty);
        expect(sessions.map((s) => s.id), contains(testSession.id));
      });

      test('should find active sessions', () async {
        // Create an active session (no end time)
        final activeSession = testSession.copyWith(
          id: 'active_session',
          endTime: null,
        );
        await sessionRepository.create(activeSession);
        
        final activeSessions = await sessionRepository.findActiveSessionsByUserId('test_user');
        
        expect(activeSessions, isNotEmpty);
        expect(activeSessions.map((s) => s.id), contains('active_session'));
        
        for (final session in activeSessions) {
          expect(session.endTime, isNull);
        }
      });

      test('should find sessions by type', () async {
        final strengthSessions = await sessionRepository.findBySessionType(SessionType.strength);
        
        expect(strengthSessions, isNotEmpty);
        expect(strengthSessions.map((s) => s.id), contains(testSession.id));
        
        for (final session in strengthSessions) {
          expect(session.sessionType, equals(SessionType.strength));
        }
      });

      test('should find unsynced sessions', () async {
        final unsyncedSessions = await sessionRepository.findUnsyncedSessions();
        
        expect(unsyncedSessions, isNotEmpty);
        expect(unsyncedSessions.map((s) => s.id), contains(testSession.id));
        
        for (final session in unsyncedSessions) {
          expect(session.isSynced, isFalse);
        }
      });

      test('should get recent sessions', () async {
        // Create additional sessions
        for (int i = 1; i <= 5; i++) {
          await sessionRepository.create(testSession.copyWith(
            id: 'session_$i',
            startTime: DateTime.now().subtract(Duration(days: i)),
          ));
        }
        
        final recentSessions = await sessionRepository.getRecentSessions('test_user', limit: 3);
        
        expect(recentSessions.length, equals(3));
        
        // Should be ordered by start time descending
        for (int i = 0; i < recentSessions.length - 1; i++) {
          expect(
            recentSessions[i].startTime.isAfter(recentSessions[i + 1].startTime) ||
            recentSessions[i].startTime.isAtSameMomentAs(recentSessions[i + 1].startTime),
            isTrue,
          );
        }
      });
    });

    group('Update Operations', () {
      setUp(() async {
        await sessionRepository.create(testSession);
      });

      test('should update session successfully', () async {
        final updatedSession = testSession.copyWith(
          notes: 'Updated notes',
          sessionType: SessionType.hypertrophy,
          isSynced: true,
        );

        final result = await sessionRepository.update(updatedSession);
        
        expect(result.notes, equals('Updated notes'));
        expect(result.sessionType, equals(SessionType.hypertrophy));
        expect(result.isSynced, isTrue);
        
        // Verify update in database
        final foundSession = await sessionRepository.findById(testSession.id);
        expect(foundSession!.notes, equals('Updated notes'));
        expect(foundSession.sessionType, equals(SessionType.hypertrophy));
      });

      test('should mark session as synced', () async {
        await sessionRepository.markAsSynced(testSession.id);
        
        final foundSession = await sessionRepository.findById(testSession.id);
        expect(foundSession!.isSynced, isTrue);
      });

      test('should throw exception when updating non-existent session', () async {
        final nonExistentSession = testSession.copyWith(id: 'non_existent');

        expect(
          () => sessionRepository.update(nonExistentSession),
          throwsA(isA<RepositoryException>()),
        );
      });
    });

    group('Delete Operations', () {
      setUp(() async {
        await sessionRepository.create(testSession.copyWith(sets: [testSet]));
      });

      test('should delete session by id', () async {
        final deleted = await sessionRepository.deleteById(testSession.id);
        expect(deleted, isTrue);

        final foundSession = await sessionRepository.findById(testSession.id);
        expect(foundSession, isNull);
        
        // Verify sets were also deleted (cascade)
        final sets = await setRepository.findBySessionId(testSession.id);
        expect(sets, isEmpty);
      });

      test('should return false when deleting non-existent session', () async {
        final deleted = await sessionRepository.deleteById('non_existent_id');
        expect(deleted, isFalse);
      });
    });

    group('Statistics', () {
      setUp(() async {
        // Create session with sets for statistics
        final sessionWithSets = testSession.copyWith(sets: [
          testSet,
          testSet.copyWith(id: 'set_2', weight: 105.0, reps: 8, setOrder: 2),
          testSet.copyWith(id: 'set_3', weight: 110.0, reps: 6, setOrder: 3),
        ]);
        await sessionRepository.create(sessionWithSets);
      });

      test('should get workout statistics', () async {
        final stats = await sessionRepository.getWorkoutStats('test_user');
        
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['total_sessions'], equals(1));
        expect(stats['completed_sessions'], equals(1));
        expect(stats['total_volume'], greaterThan(0));
        expect(stats['total_sets'], equals(3));
        expect(stats['avg_duration_minutes'], isA<double>());
      });
    });
  });

  group('WorkoutSetRepository', () {
    final testSet = WorkoutSet(
      id: 'test_set',
      sessionId: 'test_session',
      exerciseId: 'squat',
      weight: 100.0,
      reps: 10,
      rpe: 8,
      restSeconds: 120,
      setOrder: 1,
      createdAt: DateTime.now(),
    );

    setUp(() async {
      // Create test session first
      final db = await databaseHelper.database;
      await db.insert('workout_sessions', {
        'id': 'test_session',
        'user_id': 'test_user',
        'start_time': DateTime.now().millisecondsSinceEpoch,
        'session_type': 'strength',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    });

    group('Create Operations', () {
      test('should create workout set successfully', () async {
        final createdSet = await setRepository.create(testSet);
        
        expect(createdSet, equals(testSet));
        
        // Verify set was saved to database
        final foundSet = await setRepository.findById(testSet.id);
        expect(foundSet, isNotNull);
        expect(foundSet!.weight, equals(testSet.weight));
      });

      test('should throw exception when creating set with invalid data', () async {
        final invalidSet = WorkoutSet(
          id: '',
          sessionId: '',
          exerciseId: '',
          weight: -1.0,
          reps: 0,
          rpe: 11,
          setOrder: 0,
          createdAt: DateTime.now(),
        );

        expect(
          () => setRepository.create(invalidSet),
          throwsA(isA<RepositoryException>()),
        );
      });
    });

    group('Read Operations', () {
      setUp(() async {
        await setRepository.create(testSet);
      });

      test('should find set by id', () async {
        final foundSet = await setRepository.findById(testSet.id);
        
        expect(foundSet, isNotNull);
        expect(foundSet!.id, equals(testSet.id));
        expect(foundSet.weight, equals(testSet.weight));
        expect(foundSet.reps, equals(testSet.reps));
      });

      test('should find sets by session id', () async {
        final sets = await setRepository.findBySessionId('test_session');
        
        expect(sets, isNotEmpty);
        expect(sets.map((s) => s.id), contains(testSet.id));
        
        for (final set in sets) {
          expect(set.sessionId, equals('test_session'));
        }
      });

      test('should find sets by exercise id', () async {
        final sets = await setRepository.findByExerciseId('squat');
        
        expect(sets, isNotEmpty);
        expect(sets.map((s) => s.id), contains(testSet.id));
        
        for (final set in sets) {
          expect(set.exerciseId, equals('squat'));
        }
      });

      test('should find sets by user and exercise', () async {
        final sets = await setRepository.findByUserAndExercise('test_user', 'squat');
        
        expect(sets, isNotEmpty);
        expect(sets.map((s) => s.id), contains(testSet.id));
      });

      test('should find recent sets for exercise', () async {
        // Create additional sets
        for (int i = 1; i <= 3; i++) {
          await setRepository.create(testSet.copyWith(
            id: 'set_$i',
            weight: 100.0 + i * 5,
            createdAt: DateTime.now().subtract(Duration(days: i)),
          ));
        }
        
        final recentSets = await setRepository.findRecentSetsForExercise(
          'squat',
          'test_user',
          limit: 2,
        );
        
        expect(recentSets.length, equals(2));
        
        // Should be ordered by created_at descending
        for (int i = 0; i < recentSets.length - 1; i++) {
          expect(
            recentSets[i].createdAt.isAfter(recentSets[i + 1].createdAt) ||
            recentSets[i].createdAt.isAtSameMomentAs(recentSets[i + 1].createdAt),
            isTrue,
          );
        }
      });
    });

    group('Update Operations', () {
      setUp(() async {
        await setRepository.create(testSet);
      });

      test('should update set successfully', () async {
        final updatedSet = testSet.copyWith(
          weight: 105.0,
          reps: 8,
          rpe: 9,
          notes: 'Updated set',
        );

        final result = await setRepository.update(updatedSet);
        
        expect(result.weight, equals(105.0));
        expect(result.reps, equals(8));
        expect(result.rpe, equals(9));
        expect(result.notes, equals('Updated set'));
        
        // Verify update in database
        final foundSet = await setRepository.findById(testSet.id);
        expect(foundSet!.weight, equals(105.0));
        expect(foundSet.reps, equals(8));
      });

      test('should throw exception when updating non-existent set', () async {
        final nonExistentSet = testSet.copyWith(id: 'non_existent');

        expect(
          () => setRepository.update(nonExistentSet),
          throwsA(isA<RepositoryException>()),
        );
      });
    });

    group('Delete Operations', () {
      setUp(() async {
        await setRepository.create(testSet);
      });

      test('should delete set by id', () async {
        final deleted = await setRepository.deleteById(testSet.id);
        expect(deleted, isTrue);

        final foundSet = await setRepository.findById(testSet.id);
        expect(foundSet, isNull);
      });

      test('should return false when deleting non-existent set', () async {
        final deleted = await setRepository.deleteById('non_existent_id');
        expect(deleted, isFalse);
      });
    });

    group('Analytics', () {
      setUp(() async {
        // Create multiple sets for analytics
        final sets = [
          testSet,
          testSet.copyWith(id: 'set_2', weight: 105.0, reps: 8),
          testSet.copyWith(id: 'set_3', weight: 110.0, reps: 6),
          testSet.copyWith(id: 'set_4', exerciseId: 'bench_press', weight: 80.0, reps: 12),
        ];
        
        for (final set in sets) {
          await setRepository.create(set);
        }
      });

      test('should get personal records', () async {
        final prs = await setRepository.getPersonalRecords('test_user');
        
        expect(prs, isNotEmpty);
        
        // Find squat PR
        final squatPR = prs.firstWhere(
          (pr) => pr['exercise_id'] == 'squat',
          orElse: () => <String, dynamic>{},
        );
        
        expect(squatPR, isNotEmpty);
        expect(squatPR['max_weight'], equals(110.0));
        expect(squatPR['estimated_1rm'], isA<double>());
        expect(squatPR['achieved_at'], isA<DateTime>());
      });

      test('should calculate volume for date range', () async {
        final startDate = DateTime.now().subtract(Duration(days: 1));
        final endDate = DateTime.now().add(Duration(days: 1));
        
        final volume = await setRepository.calculateVolumeForDateRange(
          'test_user',
          startDate,
          endDate,
        );
        
        expect(volume, greaterThan(0));
        
        // Expected volume: (100*10) + (105*8) + (110*6) + (80*12) = 1000 + 840 + 660 + 960 = 3460
        expect(volume, equals(3460.0));
      });
    });

    group('Data Validation', () {
      test('should validate set data before operations', () async {
        final invalidSet = WorkoutSet(
          id: 'test',
          sessionId: 'test_session',
          exerciseId: 'squat',
          weight: -10.0, // Invalid: negative weight
          reps: 0, // Invalid: zero reps
          rpe: 15, // Invalid: RPE > 10
          setOrder: -1, // Invalid: negative order
          createdAt: DateTime.now(),
        );

        expect(
          () => setRepository.create(invalidSet),
          throwsA(isA<RepositoryException>()),
        );
      });

      test('should handle edge case values', () async {
        final edgeCaseSet = testSet.copyWith(
          weight: 0.5, // Minimum valid weight
          reps: 1, // Minimum valid reps
          rpe: 1, // Minimum valid RPE
          restSeconds: 0, // Minimum rest time
        );

        final createdSet = await setRepository.create(edgeCaseSet);
        expect(createdSet.weight, equals(0.5));
        expect(createdSet.reps, equals(1));
        expect(createdSet.rpe, equals(1));
      });
    });

    group('Performance Tests', () {
      test('should handle large batch operations efficiently', () async {
        final stopwatch = Stopwatch()..start();
        
        // Create many sets
        final sets = <WorkoutSet>[];
        for (int i = 1; i <= 100; i++) {
          sets.add(testSet.copyWith(
            id: 'batch_set_$i',
            weight: 100.0 + i,
            setOrder: i,
          ));
        }
        
        await setRepository.createBatch(sets);
        
        stopwatch.stop();
        
        // Should complete within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
        
        // Verify all sets were created
        final foundSets = await setRepository.findBySessionId('test_session');
        expect(foundSets.length, greaterThanOrEqualTo(100));
      });
    });
  });
}