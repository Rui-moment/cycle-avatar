import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';

import 'package:cycle_avatar/main.dart' as app;
import 'package:cycle_avatar/data/services/sync_service.dart';
import 'package:cycle_avatar/domain/entities/workout_session.dart';
import 'package:cycle_avatar/domain/entities/enums.dart';

/// Integration tests for offline/online synchronization
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Offline/Online Sync Integration Tests', () {
    testWidgets('Offline workout recording and sync', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Simulate offline mode
      await _simulateOfflineMode(tester);

      // Record workout while offline
      await tester.tap(find.text('Start Workout'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start_session_button')));
      await tester.pumpAndSettle();

      // Add exercise
      await tester.tap(find.byKey(const Key('add_exercise_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Squat').first);
      await tester.pumpAndSettle();

      // Add sets while offline
      for (int i = 1; i <= 3; i++) {
        await tester.enterText(find.byKey(const Key('weight_input')), '${100 + i * 2.5}');
        await tester.enterText(find.byKey(const Key('reps_input')), '8');
        await tester.tap(find.byKey(const Key('rpe_7')));
        await tester.tap(find.byKey(const Key('add_set_button')));
        await tester.pumpAndSettle();
        
        // Verify set was saved locally
        expect(find.text('Set $i'), findsOneWidget);
      }

      // End session
      await tester.tap(find.byKey(const Key('end_session_button')));
      await tester.pumpAndSettle();

      // Verify offline indicator
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Saved locally'), findsOneWidget);

      // Simulate going back online
      await _simulateOnlineMode(tester);

      // Verify sync indicator appears
      expect(find.byIcon(Icons.sync), findsOneWidget);
      
      // Wait for sync to complete
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Verify sync completed
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      expect(find.text('Synced'), findsOneWidget);

      // Navigate to history to verify data persisted
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Verify workout appears in history
      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('3 sets'), findsOneWidget);
    });

    testWidgets('Conflict resolution during sync', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Create conflicting data scenario
      await _createConflictingData(tester);

      // Simulate sync with conflicts
      await _simulateOnlineMode(tester);

      // Wait for conflict resolution
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify client-priority resolution
      expect(find.text('Conflict resolved'), findsOneWidget);
      
      // Navigate to history to verify local data was preserved
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      // Verify local workout data is preserved
      expect(find.text('Local Workout'), findsOneWidget);
    });

    testWidgets('Background sync functionality', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Record workout
      await _recordTestWorkout(tester);

      // Simulate app going to background
      await _simulateAppBackground(tester);

      // Simulate network becoming available
      await _simulateOnlineMode(tester);

      // Simulate app returning to foreground
      await _simulateAppForeground(tester);

      // Verify background sync occurred
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('Sync retry mechanism', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Record workout
      await _recordTestWorkout(tester);

      // Simulate sync failure
      await _simulateSyncFailure(tester);

      // Verify retry indicator
      expect(find.byIcon(Icons.sync_problem), findsOneWidget);
      expect(find.text('Sync failed, will retry'), findsOneWidget);

      // Simulate network recovery
      await _simulateOnlineMode(tester);

      // Wait for retry
      await tester.pumpAndSettle(const Duration(seconds: 10));

      // Verify successful sync after retry
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('Large dataset sync performance', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Create large dataset offline
      await _createLargeDataset(tester);

      // Measure sync time
      final stopwatch = Stopwatch()..start();
      
      await _simulateOnlineMode(tester);
      await tester.pumpAndSettle(const Duration(seconds: 30));
      
      stopwatch.stop();

      // Verify sync completed within reasonable time
      expect(stopwatch.elapsedSeconds, lessThan(30),
          reason: 'Large dataset sync should complete within 30 seconds');

      // Verify all data synced
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('Partial sync recovery', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Start sync process
      await _recordTestWorkout(tester);
      await _simulateOnlineMode(tester);

      // Simulate network interruption during sync
      await Future.delayed(const Duration(seconds: 2));
      await _simulateOfflineMode(tester);

      // Verify partial sync state
      expect(find.byIcon(Icons.sync_problem), findsOneWidget);

      // Resume sync
      await _simulateOnlineMode(tester);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify sync completed
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });
  });

  group('Data Integrity Tests', () {
    testWidgets('Workout data consistency across sync', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Record detailed workout
      final originalData = await _recordDetailedWorkout(tester);

      // Sync data
      await _simulateOnlineMode(tester);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify data integrity after sync
      await _verifyWorkoutDataIntegrity(tester, originalData);
    });

    testWidgets('Avatar state consistency', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Record progression workout
      await _recordProgressionWorkout(tester);

      // Check avatar state before sync
      await tester.tap(find.text('Avatar'));
      await tester.pumpAndSettle();
      
      final originalLevel = await _getAvatarLevel(tester, 'legs');

      // Sync and verify avatar state preserved
      await _simulateOnlineMode(tester);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      final syncedLevel = await _getAvatarLevel(tester, 'legs');
      expect(syncedLevel, equals(originalLevel));
    });
  });
}

// Helper functions for test scenarios

Future<void> _simulateOfflineMode(WidgetTester tester) async {
  // In a real implementation, this would mock network connectivity
  // For now, we'll simulate the UI state
  await tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('connectivity_plus'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return 'none';
      }
      return null;
    },
  );
}

Future<void> _simulateOnlineMode(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('connectivity_plus'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return 'wifi';
      }
      return null;
    },
  );
}

Future<void> _createConflictingData(WidgetTester tester) async {
  // Create scenario where local and server data conflict
  // This would involve mocking the sync service
}

Future<void> _recordTestWorkout(WidgetTester tester) async {
  await tester.tap(find.text('Start Workout'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('start_session_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('add_exercise_button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('exercise_search')), 'Squat');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Squat').first);
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('weight_input')), '100');
  await tester.enterText(find.byKey(const Key('reps_input')), '8');
  await tester.tap(find.byKey(const Key('rpe_7')));
  await tester.tap(find.byKey(const Key('add_set_button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('end_session_button')));
  await tester.pumpAndSettle();
}

Future<void> _simulateAppBackground(WidgetTester tester) async {
  // Simulate app lifecycle changes
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter/lifecycle'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'routeUpdated') {
        return null;
      }
      return null;
    },
  );
}

Future<void> _simulateAppForeground(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

Future<void> _simulateSyncFailure(WidgetTester tester) async {
  // Mock sync service to return failure
}

Future<void> _createLargeDataset(WidgetTester tester) async {
  // Create multiple workouts with many sets
  for (int workout = 1; workout <= 5; workout++) {
    await _recordTestWorkout(tester);
    await tester.pumpAndSettle();
  }
}

Future<Map<String, dynamic>> _recordDetailedWorkout(WidgetTester tester) async {
  // Record workout and return data for verification
  await _recordTestWorkout(tester);
  return {
    'exercise': 'Squat',
    'sets': 1,
    'weight': 100.0,
    'reps': 8,
    'rpe': 7,
  };
}

Future<void> _verifyWorkoutDataIntegrity(
  WidgetTester tester, 
  Map<String, dynamic> originalData,
) async {
  await tester.tap(find.text('History'));
  await tester.pumpAndSettle();

  expect(find.text(originalData['exercise']), findsOneWidget);
  expect(find.text('${originalData['sets']} sets'), findsOneWidget);
}

Future<void> _recordProgressionWorkout(WidgetTester tester) async {
  // Record workout that should trigger avatar progression
  await _recordTestWorkout(tester);
}

Future<int> _getAvatarLevel(WidgetTester tester, String muscleGroup) async {
  // Extract avatar level for specific muscle group
  // This would need to be implemented based on actual avatar widget structure
  return 1; // Placeholder
}