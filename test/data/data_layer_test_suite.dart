import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'datasources/local/database_helper_test.dart' as database_helper_tests;
import 'repositories/user_repository_test.dart' as user_repository_tests;
import 'repositories/exercise_repository_test.dart' as exercise_repository_tests;
import 'repositories/workout_repository_test.dart' as workout_repository_tests;

/// Comprehensive test suite for the data access layer
/// 
/// This test suite covers:
/// - Database initialization and schema validation
/// - Repository pattern implementation
/// - CRUD operations for all entities
/// - Data validation and error handling
/// - Performance and integration tests
void main() {
  group('Data Layer Test Suite', () {
    group('Database Helper Tests', () {
      database_helper_tests.main();
    });

    group('User Repository Tests', () {
      user_repository_tests.main();
    });

    group('Exercise Repository Tests', () {
      exercise_repository_tests.main();
    });

    group('Workout Repository Tests', () {
      workout_repository_tests.main();
    });
  });
}